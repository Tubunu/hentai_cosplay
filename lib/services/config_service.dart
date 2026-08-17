import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';

class ConfigService {
  static const String _kConfigKey = 'mzt_app_config_v1';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Resolve a safe default storage path for Android and other platforms
  static Future<String> getDefaultDownloadPath() async {
    if (Platform.isAndroid) {
      // Try to use standard public Download directory if accessible
      final publicDownloadDir = Directory('/storage/emulated/0/Download/MztImages');
      try {
        if (!await publicDownloadDir.exists()) {
          await publicDownloadDir.create(recursive: true);
        }
        return publicDownloadDir.path;
      } catch (_) {
        // Fallback to app external files dir
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final fallbackDir = Directory('${extDir.path}/MztImages');
          await fallbackDir.create(recursive: true);
          return fallbackDir.path;
        }
      }
    }

    // Default for iOS / Desktop
    final docDir = await getApplicationDocumentsDirectory();
    final localDir = Directory('${docDir.path}/MztImages');
    await localDir.create(recursive: true);
    return localDir.path;
  }

  /// Load config from SharedPreferences
  static Future<AppConfig> loadConfig() async {
    await init();
    final jsonStr = _prefs?.getString(_kConfigKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final config = AppConfig.fromRawJson(jsonStr);
        if (config.savePath.isEmpty) {
          config.savePath = await getDefaultDownloadPath();
        }
        return config;
      } catch (_) {}
    }

    final defaultPath = await getDefaultDownloadPath();
    final config = AppConfig(savePath: defaultPath);
    await saveConfig(config);
    return config;
  }

  /// Save config to SharedPreferences
  static Future<bool> saveConfig(AppConfig config) async {
    await init();
    return await _prefs?.setString(_kConfigKey, config.toRawJson()) ?? false;
  }
}
