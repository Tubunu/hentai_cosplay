import 'dart:convert';
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

class ConfigService {
  static const String _kConfigKey = 'hentai_cosplay_app_config';
  static SharedPreferences? _prefs;

  static void applyProxy(String? proxy) {
    final p = proxy ?? '';
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
  }

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final config = loadConfig();
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
    } catch (_) {
      return AppConfig();
    }
  }

  static Future<bool> saveConfig(AppConfig config) async {
    _prefs ??= await SharedPreferences.getInstance();
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
    } catch (_) {
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
