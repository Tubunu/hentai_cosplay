import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';
import '../models/browsing_history_record.dart';
import 'coomer/coomer_api_service.dart';
import 'hc_api_service.dart';
import 'jable/api_client.dart';
import 'kuraa/kuraa_api_service.dart';
import 'misskon/misskon_api_service.dart';
import 'mzt_api_service.dart';
import 'pinse/pinse_api_service.dart';
import 'pornbox/pornbox_api_service.dart';
import 'pornhub/pornhub_api_service.dart';
import 'exhentai/exhentai_api_service.dart';
import 'pixibb/pixibb_api_service.dart';
import 'cosplaytele/cosplaytele_api_service.dart';
import 'nucosplay/nucosplay_api_service.dart';
import 'eporner/eporner_api_service.dart';
import 'hanime1/hanime1_api_service.dart';
import 'hqporner/hqporner_api_service.dart';
import 'iwara/iwara_api_service.dart';
import 'rule34video/rule34video_api_service.dart';
import 'spankbang/spankbang_api_service.dart';
import 'twitter_rankings/twitter_ranking_api_service.dart';
import 'video_api_service.dart';
import 'network_client.dart';
import 'xvideos/xvideos_api_service.dart';
import 'cosvault/cosvault_api_service.dart';
import 'galleryepic/galleryepic_api_service.dart';
import 'cosxplay/cosxplay_api_service.dart';
import 'cosplayporntube/cosplayporntube_api_service.dart';
import 'xhamster/xhamster_api_service.dart';
import 'xnxx/xnxx_api_service.dart';
import 'av123/av123_api_service.dart';
import 'javguru/javguru_api_service.dart';
import 'javmost/javmost_api_service.dart';
import 'njav/njav_api_service.dart';
import 'nsfwpub/nsfwpub_api_service.dart';
import 'thothub/thothub_api_service.dart';
import 'vjav/vjav_api_service.dart';
import 'memojav/memojav_api_service.dart';
import 'hohoj/hohoj_api_service.dart';
import 'proxy/proxy_router.dart';
import 'proxy/libbox_manager.dart';
import '../models/chromego/proxy_node.dart';
import 'app_logger.dart';

class AppHttpOverrides extends HttpOverrides {
  final String? proxyString;

  AppHttpOverrides([this.proxyString]);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // Allow insecure certificates globally (e.g. Let's Encrypt ECDSA certs on older Android and CDN proxying)
    client.badCertificateCallback = (cert, host, port) => true;

    // Use intelligent dynamic router or explicit proxy override
    client.findProxy = (uri) {
      if (proxyString != null && proxyString!.trim().isNotEmpty) {
        final cleanProxy = proxyString!.trim();
        final clean = cleanProxy.replaceAll(RegExp(r'https?://|socks5?://'), '');
        if (cleanProxy.toLowerCase().startsWith('socks')) {
          return 'SOCKS5 $clean; DIRECT';
        } else {
          return 'PROXY $clean; DIRECT';
        }
      }
      return ProxyRouter.findProxyString(uri);
    };

    return client;
  }
}

class ConfigService {
  static const String _kConfigKey = 'hentai_cosplay_app_config';
  static SharedPreferences? _prefs;
  static final List<void Function(String proxy)> _proxyApplicators = [];

  /// 注册代理应用器（供未来扩展使用）
  static void registerProxyApplicator(void Function(String proxy) applicator) {
    _proxyApplicators.add(applicator);
  }

  /// 依据完整配置应用智能代理策略（分流网关与内置/外部代理）
  static void applyProxySettings([AppConfig? cfg]) {
    final config = cfg ?? loadConfig();
    ProxyRouter.updateConfig(config);

    // Apply global dynamic PAC resolver for all native Dart HttpClient instances
    HttpOverrides.global = AppHttpOverrides();

    final globalOrDirectProxy = config.proxyRoutingStrategy == ProxyRoutingStrategy.global
        ? ProxyRouter.getActiveProxyAddress()
        : null;

    String p(String siteKey) => globalOrDirectProxy ?? ProxyRouter.getProxyForSite(siteKey);

    NetworkClient.setProxy(ProxyRouter.getActiveProxyAddress());
    HCApiService.setProxy(p('hc_gallery'));
    VideoApiService.setProxy(p('jable'));
    MztApiService.setProxy(p('mzt'));
    ApiClient().setProxy(p('jable'));
    MisskonApiService.setProxy(p('misskon'));
    CoomerApiService.setProxy(p('coomer'));
    PinseApiService.setProxy(p('pinse'));
    PornboxApiService.setProxy(p('pornbox'));
    KuraaApiService.setProxy(p('kuraa'));
    TwitterRankingApiService.setProxy(p('twitter'));
    ExHentaiApiService.setProxy(p('exhentai'));
    PixibbApiService.setProxy(p('pixibb'));
    CosplayteleApiService.setProxy(p('cosplaytele'));
    NucosplayApiService.setProxy(p('nucosplay'));
    Hanime1ApiService.setProxy(p('hanime1'));
    EpornerApiService.setProxy(p('eporner'));
    HqpornerApiService.setProxy(p('hqporner'));
    SpankbangApiService.setProxy(p('spankbang'));
    PornhubApiService.setProxy(p('pornhub'));
    XVideosApiService.setProxy(p('xvideos'));
    IwaraApiService.setProxy(p('iwara'));
    Rule34VideoApiService.setProxy(p('rule34video'));
    CosvaultApiService.setProxy(p('cosvault'));
    GalleryepicApiService.setProxy(p('galleryepic'));
    CosxplayApiService.setProxy(p('cosxplay'));
    CosplayporntubeApiService.setProxy(p('cosplayporntube'));
    XhamsterApiService.setProxy(p('xhamster'));
    XnxxApiService.setProxy(p('xnxx'));
    Av123ApiService.setProxy(p('av123'));
    JavguruApiService.setProxy(p('javguru'));
    JavmostApiService.setProxy(p('javmost'));
    NjavApiService.setProxy(p('njav'));
    NsfwpubApiService.setProxy(p('nsfwpub'));
    ThothubApiService.setProxy(p('thothub'));
    VjavApiService.setProxy(p('vjav'));
    MemojavApiService.setProxy(p('memojav'));
    HohojApiService.setProxy(p('hohoj'));

    // 通知所有动态注册的代理应用器
    final activeProxy = ProxyRouter.getActiveProxyAddress();
    for (final applicator in _proxyApplicators) {
      try {
        applicator(activeProxy);
      } catch (_) {}
    }

    // 针对 Android 平台 InAppWebView 配置全局代理重写（解决网页播放与海外站点白屏）
    if (Platform.isAndroid) {
      try {
        final proxyController = ProxyController.instance();
        if (activeProxy.isNotEmpty) {
          final clean = activeProxy.replaceAll(RegExp(r'https?://|socks5?://'), '').trim();
          unawaited(proxyController.setProxyOverride(
            settings: ProxySettings(
              proxyRules: [ProxyRule(url: clean)],
              bypassRules: ['localhost', '127.0.0.1', '::1', '<local>'],
            ),
          ));
        } else {
          unawaited(proxyController.clearProxyOverride());
        }
      } catch (e) {
        AppLogger.w('ConfigService', 'WebView proxy override notice: $e');
      }
    }
  }

  /// 兼容旧方法调用，重定向至 applyProxySettings
  static void applyProxy([String? proxy]) {
    if (proxy != null && _prefs != null) {
      final config = loadConfig();
      config.customProxy = proxy;
      applyProxySettings(config);
    } else {
      applyProxySettings();
    }
  }

  static const String _kLastActiveNodeKey = 'chromego_active_builtin_node';

  static Future<void> saveActiveNode(ProxyNode? node) async {
    _prefs ??= await SharedPreferences.getInstance();
    if (node == null) {
      await _prefs!.remove(_kLastActiveNodeKey);
    } else {
      await _prefs!.setString(_kLastActiveNodeKey, jsonEncode(node.toJson()));
    }
  }

  static ProxyNode? loadActiveNode() {
    if (_prefs == null) return null;
    final jsonStr = _prefs!.getString(_kLastActiveNodeKey);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return ProxyNode.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final config = loadConfig();
    NetworkClient.setAllowInsecureCertificates(config.allowInsecureCertificates);
    applyProxySettings(config);
    // 自动恢复并初始化内置代理核心（若已配置为内置模式）
    await LibboxManager.instance.init();
  }

  static AppConfig loadConfig() {
    if (_prefs == null) return AppConfig();
    final jsonStr = _prefs!.getString(_kConfigKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return AppConfig();
    }
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AppConfig.fromJson(map);
    } catch (e, st) {
      AppLogger.e('ConfigService', '解析配置失败，已回退默认配置', e, st);
      return AppConfig();
    }
  }

  static Future<bool> saveConfig(AppConfig config) async {
    _prefs ??= await SharedPreferences.getInstance();
    NetworkClient.setAllowInsecureCertificates(config.allowInsecureCertificates);
    applyProxySettings(config);
    return _prefs!.setString(_kConfigKey, config.toRawJson());
  }

  static const String _kActiveViewingRecordKey = 'hentai_cosplay_active_viewing_record';

  static Future<void> setActiveViewingRecord(BrowsingHistoryRecord record) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_kActiveViewingRecordKey, jsonEncode(record.toJson()));
  }

  static Future<void> clearActiveViewingRecord() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_kActiveViewingRecordKey);
  }

  static BrowsingHistoryRecord? getActiveViewingRecord() {
    if (_prefs == null) return null;
    final jsonStr = _prefs!.getString(_kActiveViewingRecordKey);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return BrowsingHistoryRecord.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (e, st) {
      AppLogger.e('ConfigService', '解析活跃浏览记录失败', e, st);
      return null;
    }
  }
}

class ViewingRouteObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null && (previousRoute.isFirst || previousRoute.settings.name == '/')) {
      ConfigService.clearActiveViewingRecord();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (previousRoute != null && (previousRoute.isFirst || previousRoute.settings.name == '/')) {
      ConfigService.clearActiveViewingRecord();
    }
  }
}
