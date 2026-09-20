import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
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
import 'app_logger.dart';

class AppHttpOverrides extends HttpOverrides {
  final String proxyString;

  AppHttpOverrides(this.proxyString);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // Allow insecure certificates globally (e.g. Let's Encrypt ECDSA certs on older Android and CDN proxying)
    client.badCertificateCallback = (cert, host, port) => true;

    final cleanProxy = proxyString.trim();
    if (cleanProxy.isNotEmpty) {
      final clean = cleanProxy.replaceAll(RegExp(r'https?://|socks5?://'), '');
      if (cleanProxy.toLowerCase().startsWith('socks')) {
        client.findProxy = (uri) => 'SOCKS5 $clean; DIRECT';
      } else {
        client.findProxy = (uri) => 'PROXY $clean; DIRECT';
      }
    } else {
      client.findProxy = HttpClient.findProxyFromEnvironment;
    }
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

  static void applyProxy(String? proxy) {
    final p = proxy ?? '';
    
    // Apply proxy to all native Dart Http clients (for flutter_cache_manager, CachedNetworkImage, etc.)
    HttpOverrides.global = AppHttpOverrides(p);

    NetworkClient.setProxy(p);
    HCApiService.setProxy(p);
    VideoApiService.setProxy(p);
    MztApiService.setProxy(p);
    ApiClient().setProxy(p);
    MisskonApiService.setProxy(p);
    CoomerApiService.setProxy(p);
    PinseApiService.setProxy(p);
    PornboxApiService.setProxy(p);
    KuraaApiService.setProxy(p);
    TwitterRankingApiService.setProxy(p);
    ExHentaiApiService.setProxy(p);
    PixibbApiService.setProxy(p);
    CosplayteleApiService.setProxy(p);
    NucosplayApiService.setProxy(p);
    Hanime1ApiService.setProxy(p);
    EpornerApiService.setProxy(p);
    HqpornerApiService.setProxy(p);
    SpankbangApiService.setProxy(p);
    PornhubApiService.setProxy(p);
    XVideosApiService.setProxy(p);
    IwaraApiService.setProxy(p);
    Rule34VideoApiService.setProxy(p);
    CosvaultApiService.setProxy(p);
    GalleryepicApiService.setProxy(p);
    CosxplayApiService.setProxy(p);
    CosplayporntubeApiService.setProxy(p);
    XhamsterApiService.setProxy(p);
    XnxxApiService.setProxy(p);
    Av123ApiService.setProxy(p);
    JavguruApiService.setProxy(p);
    JavmostApiService.setProxy(p);
    NjavApiService.setProxy(p);
    NsfwpubApiService.setProxy(p);
    ThothubApiService.setProxy(p);
    VjavApiService.setProxy(p);
    MemojavApiService.setProxy(p);
    HohojApiService.setProxy(p);

    // 通知所有动态注册的代理应用器
    for (final applicator in _proxyApplicators) {
      try {
        applicator(p);
      } catch (_) {}
    }
  }

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final config = loadConfig();
    NetworkClient.setAllowInsecureCertificates(config.allowInsecureCertificates);
    applyProxy(config.customProxy);
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
    applyProxy(config.customProxy);
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
