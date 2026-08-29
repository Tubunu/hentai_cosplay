import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../services/config_service.dart';
import '../services/hc_api_service.dart';
import '../services/mzt_api_service.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  AppConfig _config = ConfigService.loadConfig();

  AppConfig get config => _config;

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

  SettingsProvider() {
    _ensureDefaultSavePath();
  }

  Future<void> _ensureDefaultSavePath() async {
    try {
      final resolvedPath = await StorageService.resolveValidPath(_config.savePath);
      if (_config.savePath != resolvedPath) {
        _config.savePath = resolvedPath;
        await ConfigService.saveConfig(_config);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error ensuring default save path: $e');
    }
  }

  Future<void> updateConfig(AppConfig newConfig) async {
    _config = newConfig;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> setSavePath(String path) async {
    _config.savePath = path;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  Future<void> setCustomProxy(String proxy) async {
    _config.customProxy = proxy.trim();
    ConfigService.applyProxy(_config.customProxy);
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> setJableResolutionPref(String pref) async {
    _config.jableResolutionPref = pref;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> setJableWorkers(int workers) async {
    _config.jableWorkers = workers.clamp(1, 10);
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  void setJableWorkersLive(int workers) {
    _config.jableWorkers = workers.clamp(1, 10);
    notifyListeners();
  }

  Future<void> setConcurrency({int? packWorkers, int? imgWorkers, int? retryCount}) async {
    if (packWorkers != null) _config.packWorkers = packWorkers;
    if (imgWorkers != null) _config.imgWorkers = imgWorkers;
    if (retryCount != null) _config.retryCount = retryCount;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  void setConcurrencyLive({int? packWorkers, int? imgWorkers, int? retryCount}) {
    if (packWorkers != null) _config.packWorkers = packWorkers;
    if (imgWorkers != null) _config.imgWorkers = imgWorkers;
    if (retryCount != null) _config.retryCount = retryCount;
    notifyListeners();
  }

  Future<void> setAutoArchive(bool autoArchive) async {
    _config.autoArchive = autoArchive;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> updateMztProxyDomains(List<String> domains) async {
    _config.mztProxyDomains = List.from(domains);
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> resetMztProxyDomains() async {
    _config.mztProxyDomains = List.from(kDefaultMztProxyDomains);
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<int?> testMztProxyLatency(String domain) async {
    return await MztApiService.testProxyLatency(domain);
  }

  Future<int?> testMztBaseApiLatency() async {
    return await MztApiService.testBaseApiLatency();
  }

  Future<void> setThemeMode(String mode) async {
    _config.themeMode = mode;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> setAccentColor(String color) async {
    _config.accentColor = color;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> setNavBarOpacity(double opacity) async {
    _config.navBarOpacity = opacity.clamp(0.1, 1.0);
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  void setNavBarOpacityLive(double opacity) {
    _config.navBarOpacity = opacity.clamp(0.1, 1.0);
    notifyListeners();
  }

  Future<void> updateOnlineResourceSortOrder(List<String> order) async {
    _config.onlineResourceSortOrder = List.from(order);
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> resetOnlineResourceSortOrder() async {
    _config.onlineResourceSortOrder = [];
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> persistConfig() async {
    await ConfigService.saveConfig(_config);
  }

  Future<int?> testConnectivity() async {
    return await HCApiService.testConnectivity(proxy: _config.customProxy);
  }
}
