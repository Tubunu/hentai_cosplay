import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';
import 'hc_api_service.dart';
import 'jable/api_client.dart';
import 'mzt_api_service.dart';
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
