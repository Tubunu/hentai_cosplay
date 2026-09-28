import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/app_config.dart';
import '../../models/chromego/proxy_node.dart';
import '../app_logger.dart';
import '../chromego/singbox_config_generator.dart';
import '../config_service.dart';

enum LibboxState {
  stopped,
  starting,
  running,
  stopping,
  error,
}

/// 内置 Libbox / Sing-box 回环代理核心管理器
/// 负责管理应用内 127.0.0.1 回环代理服务的生命周期、节点切换、延迟测速与状态通知
class LibboxManager extends ChangeNotifier {
  static final LibboxManager instance = LibboxManager._();
  LibboxManager._();

  static const MethodChannel _channel = MethodChannel('com.hentaicosplay/libbox');

  LibboxState _state = LibboxState.stopped;
  ProxyNode? _activeNode;
  int _listenPort = 20808;
  int? _latencyMs;
  String? _errorMessage;
  String? _activeConfigJson;
  Process? _desktopProcess;

  LibboxState get state => _state;
  ProxyNode? get activeNode => _activeNode;
  int get listenPort => _listenPort;
  int? get latencyMs => _latencyMs;
  String? get errorMessage => _errorMessage;
  String? get activeConfigJson => _activeConfigJson;
  bool get isRunning => _state == LibboxState.running;

  /// 初始化内置代理管理器（在应用启动时自动恢复已连接节点）
  Future<void> init() async {
    final savedNode = ConfigService.loadActiveNode();
    final config = ConfigService.loadConfig();
    if (savedNode != null && config.proxyMode == AppProxyMode.builtin) {
      // 延迟到首帧渲染完成后在后台平滑恢复核心，确保主应用界面秒开，绝不阻碍启动
      Future.delayed(const Duration(milliseconds: 1500), () {
        start(savedNode, port: config.builtinProxyPort).catchError((e) {
          AppLogger.w('LibboxManager', '启动时恢复内置代理核心失败: $e');
          return false;
        });
      });
    }
  }

  /// 启动内置代理并连接到指定节点
  Future<bool> start(ProxyNode node, {int? port}) async {
    // 若当前正在运行，先停止旧核心释放端口
    if (_state == LibboxState.running || _state == LibboxState.starting) {
      await _stopCore();
    }

    final effectivePort = port ?? ConfigService.loadConfig().builtinProxyPort;
    _listenPort = effectivePort;
    _state = LibboxState.starting;
    _activeNode = node;
    _errorMessage = null;
    _latencyMs = null;
    notifyListeners();

    try {
      final configJson = SingboxConfigGenerator.generateConfigJson(
        node,
        listenPort: effectivePort,
      );
      _activeConfigJson = configJson;

      // 1. 尝试通过平台通道或本地进程启动核心
      await _startCore(configJson, effectivePort);

      _state = LibboxState.running;
      notifyListeners();

      // 2. 自动切换 AppConfig 的代理模式为内置代理并持久化活跃节点
      await ConfigService.saveActiveNode(node);
      final config = ConfigService.loadConfig();
      config.proxyMode = AppProxyMode.builtin;
      config.builtinProxyPort = effectivePort;
      await ConfigService.saveConfig(config);

      // 3. 异步测速当前连接延迟 (延迟 600ms 避开核心启动握手期)
      unawaited(
        Future.delayed(const Duration(milliseconds: 600), () => testActiveNodeLatency())
            .catchError((_) => null),
      );

      AppLogger.i('LibboxManager', '内置代理已成功启动: 127.0.0.1:$effectivePort, 节点: ${node.cleanName()}');
      return true;
    } catch (e, st) {
      _state = LibboxState.error;
      _errorMessage = e is UnsupportedError ? e.message : e.toString();
      AppLogger.e('LibboxManager', '启动内置代理失败: $_errorMessage', e, st);
      notifyListeners();
      return false;
    }
  }

  /// 停止内置代理服务
  Future<void> stop() async {
    if (_state == LibboxState.stopped) return;

    _state = LibboxState.stopping;
    notifyListeners();

    try {
      await _stopCore();
    } catch (e) {
      AppLogger.w('LibboxManager', '停止核心时发生异常: $e');
    }

    await ConfigService.saveActiveNode(null);
    _state = LibboxState.stopped;
    _activeNode = null;
    _latencyMs = null;
    _errorMessage = null;
    notifyListeners();
    AppLogger.i('LibboxManager', '内置代理已停止');
  }

  /// 切换节点
  Future<bool> switchNode(ProxyNode node) async {
    await stop();
    return await start(node, port: _listenPort);
  }

  /// 测试当前运行节点的真实网络延迟（通过 127.0.0.1 代理端口访问公共测速点）
  Future<int?> testActiveNodeLatency() async {
    if (!isRunning) return null;
    final targetNode = _activeNode;

    final sw = Stopwatch()..start();
    final client = HttpClient();
    try {
      client.findProxy = (uri) => 'PROXY 127.0.0.1:$_listenPort; DIRECT';
      client.connectionTimeout = const Duration(seconds: 4);

      final req = await client.getUrl(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 4));
      final resp = await req.close().timeout(const Duration(seconds: 4));
      await resp.drain();

      sw.stop();
      final ms = sw.elapsedMilliseconds;
      if (!isRunning || _activeNode != targetNode) return null;
      _latencyMs = ms;
      notifyListeners();
      return ms;
    } catch (_) {
      // 备用测速点
      try {
        final req2 = await client.getUrl(Uri.parse('https://cloudflare.com/cdn-cgi/trace'))
            .timeout(const Duration(seconds: 3));
        final resp2 = await req2.close().timeout(const Duration(seconds: 3));
        await resp2.drain();
        sw.stop();
        final ms = sw.elapsedMilliseconds;
        if (!isRunning || _activeNode != targetNode) return null;
        _latencyMs = ms;
        notifyListeners();
        return ms;
      } catch (e2) {
        if (!isRunning || _activeNode != targetNode) return null;
        _latencyMs = null;
        notifyListeners();
        return null;
      }
    } finally {
      client.close(force: true);
    }
  }

  /// 底层核心启动逻辑（支持平台通道与本地回退）
  Future<void> _startCore(String configJson, int port) async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final result = await _channel.invokeMethod<bool>('start', {
          'config': configJson,
          'port': port,
        });
        if (result != true) {
          throw Exception('Native Libbox service reported start failure');
        }
        return;
      } on MissingPluginException {
        throw UnsupportedError('原生平台尚未集成 Libbox 引擎二进制，请先切换为【外部端口】模式。');
      } on PlatformException catch (e) {
        throw Exception(e.message ?? e.details?.toString() ?? '启动内置核心失败');
      }
    } else if (Platform.isWindows) {
      final exeCandidates = [
        r'j:\ChromeGo\singbox\sing-box.exe',
        '${File(Platform.resolvedExecutable).parent.path}\\singbox\\sing-box.exe',
        '${File(Platform.resolvedExecutable).parent.path}\\sing-box.exe',
        '${Directory.current.path}\\singbox\\sing-box.exe',
      ];
      String? matchedExe;
      for (final candidate in exeCandidates) {
        if (File(candidate).existsSync()) {
          matchedExe = candidate;
          break;
        }
      }

      if (matchedExe == null) {
        throw UnsupportedError('未找到 sing-box.exe 核心组件，请确认 ChromeGo/singbox 目录存在。');
      }

      final tempDir = Directory.systemTemp;
      final cfgFile = File('${tempDir.path}/singbox_temp.json');
      await cfgFile.writeAsString(configJson);

      _desktopProcess?.kill();
      final process = await Process.start(
        matchedExe,
        ['run', '-c', cfgFile.path],
      );
      _desktopProcess = process;

      // 捕获可能发生的早期致命错误（如端口已被占用、配置解析错误等）
      final earlyErrors = <String>[];
      final errSub = process.stderr.transform(utf8.decoder).listen((data) {
        earlyErrors.add(data);
      });
      unawaited(process.stdout.drain());

      final exitCode = await process.exitCode.timeout(
        const Duration(milliseconds: 350),
        onTimeout: () => -999,
      );

      if (exitCode != -999) {
        await errSub.cancel();
        final errText = earlyErrors.join().trim();
        throw Exception('sing-box 启动后立即退出 (exitCode: $exitCode)${errText.isNotEmpty ? ': $errText' : ''}');
      }
      return;
    } else {
      throw UnsupportedError('当前操作系统平台暂未支持启动内置代理核心。');
    }
  }

  /// 底层核心停止逻辑
  Future<void> _stopCore() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await _channel.invokeMethod('stop');
      } catch (_) {}
    } else if (Platform.isWindows) {
      try {
        _desktopProcess?.kill();
        _desktopProcess = null;
      } catch (_) {}
    }
  }
}
