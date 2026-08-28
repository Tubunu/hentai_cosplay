import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';
import 'coomer/coomer_api_service.dart';
import 'hc_api_service.dart';
import 'jable/api_client.dart';
import 'kuraa/kuraa_api_service.dart';
import 'misskon/misskon_api_service.dart';
import 'mzt_api_service.dart';
import 'pinse/pinse_api_service.dart';
import 'pornbox/pornbox_api_service.dart';
import 'exhentai/exhentai_api_service.dart';
import 'pixibb/pixibb_api_service.dart';
import 'cosplaytele/cosplaytele_api_service.dart';
import 'nucosplay/nucosplay_api_service.dart';
import 'eporner/eporner_api_service.dart';
import 'hanime1/hanime1_api_service.dart';
import 'hqporner/hqporner_api_service.dart';
import 'spankbang/spankbang_api_service.dart';
import 'twitter_rankings/twitter_ranking_api_service.dart';
import 'video_api_service.dart';

class ConfigService {
  static const String _kConfigKey = 'hentai_cosplay_app_config';
  static SharedPreferences? _prefs;

  static void applyProxy(String? proxy) {
    final p = proxy ?? '';
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
}
