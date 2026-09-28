import '../../models/app_config.dart';
import '../config_service.dart';
import 'libbox_manager.dart';
import 'site_registry.dart';

/// 全局智能代理分流网关
/// 根据 [AppProxyMode] 与 [ProxyRoutingStrategy] 决定任意 Host 或 Site 是否走代理，
/// 并为原生 [HttpClient] (HttpOverrides) 和各类 API Client 提供代理格式。
class ProxyRouter {
  static AppConfig? _cachedConfig;

  /// 用于单元测试或强制回环验证
  static bool bypassCoreRunningCheckForTest = false;

  /// 更新内存中缓存的配置
  static void updateConfig(AppConfig config) {
    _cachedConfig = config;
  }

  /// 获取当前配置
  static AppConfig get currentConfig {
    return _cachedConfig ?? ConfigService.loadConfig();
  }

  /// 获取当前生效的代理地址 (如 "127.0.0.1:20808" 或自定义代理地址 "127.0.0.1:7890")
  /// 如果处于完全直连模式或内置核心未运行，返回空字符串
  static String getActiveProxyAddress() {
    final config = currentConfig;
    switch (config.proxyMode) {
      case AppProxyMode.direct:
        return '';
      case AppProxyMode.builtin:
        if (!bypassCoreRunningCheckForTest && !LibboxManager.instance.isRunning) {
          // 内置内核未运行时回退直连，避免向未监听的本地回环端口发请求导致拒绝连接异常
          return '';
        }
        return '127.0.0.1:${config.builtinProxyPort}';
      case AppProxyMode.custom:
        return config.customProxy.trim();
    }
  }

  /// 检查是否为本地回环或局域网私有地址（避免内网穿透死循环或拦截热点订阅）
  static bool _isLocalOrPrivateAddress(String rawHost) {
    var host = rawHost.toLowerCase().trim();
    if (host.startsWith('[') && host.contains(']')) {
      // 标准 IPv6 带端口或中括号格式: [::1] 或 [::1]:8080
      host = host.substring(1, host.indexOf(']'));
    } else if (host.contains(':') && host.indexOf(':') == host.lastIndexOf(':')) {
      // 仅包含单个冒号: IPv4:port 或 host:port (如 127.0.0.1:8080 或 localhost:8080)
      host = host.substring(0, host.indexOf(':'));
    }

    if (host.isEmpty || host == 'localhost' || host == '127.0.0.1' || host == '::1' || host == '0.0.0.0') {
      return true;
    }
    if (host.startsWith('127.')) {
      return true;
    }
    // 私有 IPv4 地址段：10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
    if (host.startsWith('192.168.') || host.startsWith('10.')) {
      return true;
    }
    if (host.startsWith('172.')) {
      final parts = host.split('.');
      if (parts.length == 4) {
        final second = int.tryParse(parts[1]);
        if (second != null && second >= 16 && second <= 31) {
          return true;
        }
      }
    }
    return false;
  }

  /// 判断指定 host 是否应该走代理
  static bool shouldProxyHost(String host) {
    // 本地回环与局域网私有地址永不走代理，避免本地服务（Wi-Fi订阅、测速服务等）出现死循环
    if (_isLocalOrPrivateAddress(host)) {
      return false;
    }

    final config = currentConfig;
    if (config.proxyMode == AppProxyMode.direct) {
      return false;
    }
    final proxyAddr = getActiveProxyAddress();
    if (proxyAddr.isEmpty) {
      return false;
    }
    if (config.proxyRoutingStrategy == ProxyRoutingStrategy.global) {
      return true;
    }

    // 智能分流策略：在站点注册表中匹配域名
    final site = SiteRegistry.matchSite(host);
    if (site != null) {
      return config.siteProxyToggles[site.key] ?? site.defaultProxy;
    }

    // 未知 host：在分流模式下默认直连，避免外部请求误走代理
    return false;
  }

  /// 判断指定 siteKey 是否应该走代理
  static bool shouldProxySite(String siteKey) {
    final config = currentConfig;
    if (config.proxyMode == AppProxyMode.direct) {
      return false;
    }
    final proxyAddr = getActiveProxyAddress();
    if (proxyAddr.isEmpty) {
      return false;
    }
    if (config.proxyRoutingStrategy == ProxyRoutingStrategy.global) {
      return true;
    }
    final site = SiteRegistry.getSite(siteKey);
    return config.siteProxyToggles[siteKey] ?? site?.defaultProxy ?? false;
  }

  /// 获取指定 siteKey 应该使用的代理服务器地址
  /// 如果该站点不走代理，返回空字符串 ''
  static String getProxyForSite(String siteKey) {
    if (!shouldProxySite(siteKey)) {
      return '';
    }
    return getActiveProxyAddress();
  }

  /// 为原生 Dart [HttpClient.findProxy] 计算 PAC 规则字符串
  /// 例如: "PROXY 127.0.0.1:20808; DIRECT" 或 "DIRECT"
  static String findProxyString(Uri uri) {
    if (!shouldProxyHost(uri.host)) {
      return 'DIRECT';
    }

    final rawProxy = getActiveProxyAddress();
    if (rawProxy.isEmpty) {
      return 'DIRECT';
    }

    final clean = rawProxy.replaceAll(RegExp(r'https?://|socks5?://'), '').trim();
    if (clean.isEmpty) {
      return 'DIRECT';
    }

    if (rawProxy.toLowerCase().startsWith('socks')) {
      return 'SOCKS5 $clean; DIRECT';
    } else {
      return 'PROXY $clean; DIRECT';
    }
  }
}
