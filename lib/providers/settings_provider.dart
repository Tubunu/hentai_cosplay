import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../services/config_service.dart';

class SettingsProvider extends ChangeNotifier {
  AppConfig _config = AppConfig();
  bool _isLoading = true;

  AppConfig get config => _config;
  bool get isLoading => _isLoading;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();
    _config = await ConfigService.loadConfig();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateConfig(AppConfig newConfig) async {
    _config = newConfig;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> updateSavePath(String path) async {
    _config.savePath = path;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> updateWorkers({int? packWorkers, int? imgWorkers, int? retryCount}) async {
    if (packWorkers != null) _config.packWorkers = packWorkers;
    if (imgWorkers != null) _config.imgWorkers = imgWorkers;
    if (retryCount != null) _config.retryCount = retryCount;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> updateProxyDomains(List<String> domains) async {
    _config.proxyDomains = domains;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> resetProxyDomains() async {
    _config.proxyDomains = List.from(kDefaultProxyDomains);
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> updateAutoArchive(bool autoArchive, String strategy) async {
    _config.autoArchive = autoArchive;
    _config.archiveStrategy = strategy;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> updateThemeMode(String mode) async {
    _config.themeMode = mode;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  ThemeMode get themeMode {
    switch (_config.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
