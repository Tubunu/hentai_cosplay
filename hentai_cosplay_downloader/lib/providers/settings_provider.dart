import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../models/resource_site_item.dart';
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
      debugPrint('Error ensuring default save path: $e, falling back to default.');
      try {
        final fallback = await StorageService.getDefaultDownloadPath();
        _config.savePath = fallback;
        await ConfigService.saveConfig(_config);
        notifyListeners();
      } catch (fallbackErr) {
        debugPrint('Fallback error: $fallbackErr');
      }
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

  Future<void> setPhotoPreloadCount(int count) async {
    _config.photoPreloadCount = count;
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

  Future<void> setAllowInsecureCertificates(bool allow) async {
    _config.allowInsecureCertificates = allow;
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

  Future<void> setAutoHideNavigationOnScroll(bool enabled) async {
    _config.autoHideNavigationOnScroll = enabled;
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

  Future<void> updateHiddenResourceSites(List<String> hiddenSites) async {
    _config.hiddenResourceSites = List.from(hiddenSites);
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<bool> toggleHideResourceSite(String siteKey, {int totalSitesCount = 35}) async {
    final list = List<String>.from(_config.hiddenResourceSites);
    if (list.contains(siteKey)) {
      list.remove(siteKey);
    } else {
      // Ensure at least 1 site remains visible
      if (list.length >= totalSitesCount - 1) {
        return false;
      }
      list.add(siteKey);
    }
    _config.hiddenResourceSites = list;
    await ConfigService.saveConfig(_config);
    notifyListeners();
    return true;
  }

  bool isFavoriteResourceSite(String key) {
    return _config.favoriteResourceSites.contains(key);
  }

  Future<void> toggleFavoriteResourceSite(String key) async {
    final list = List<String>.from(_config.favoriteResourceSites);
    if (list.contains(key)) {
      list.remove(key);
    } else {
      list.add(key);
    }
    _config.favoriteResourceSites = list;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> batchSetCategoryVisibility(List<String> keysInCategory, bool show) async {
    final list = List<String>.from(_config.hiddenResourceSites);
    if (show) {
      list.removeWhere((k) => keysInCategory.contains(k));
    } else {
      for (final k in keysInCategory) {
        if (!list.contains(k)) {
          list.add(k);
        }
      }
    }
    _config.hiddenResourceSites = list;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> unhideAllResourceSites() async {
    _config.hiddenResourceSites = [];
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> resetOnlineResourceOrderAndVisibility() async {
    _config.onlineResourceSortOrder = [];
    _config.hiddenResourceSites = [];
    _config.favoriteResourceSites = List.from(kDefaultFavoriteResourceSites);
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> persistConfig() async {
    await ConfigService.saveConfig(_config);
  }

  Future<void> setLastActiveTabIndex(int index) async {
    if (_config.lastActiveTabIndex == index) return;
    _config.lastActiveTabIndex = index;
    await ConfigService.saveConfig(_config);
  }

  Future<void> setLastSiteKey(ResourceMediaType mediaType, String siteKey) async {
    if (mediaType == ResourceMediaType.image) {
      if (_config.lastImageSiteKey == siteKey) return;
      _config.lastImageSiteKey = siteKey;
    } else {
      if (_config.lastVideoSiteKey == siteKey) return;
      _config.lastVideoSiteKey = siteKey;
    }
    await ConfigService.saveConfig(_config);
  }

  Future<void> setDisguiseMode(bool enabled) async {
    _config.disguiseMode = enabled;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> setDisguiseUnlockCode(String code) async {
    _config.disguiseUnlockCode = code.trim();
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> setDisguiseQuickUnlock(bool enabled) async {
    _config.disguiseQuickUnlock = enabled;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> setDisguiseRelockOnBackground(bool enabled) async {
    _config.disguiseRelockOnBackground = enabled;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<void> setDisguiseBiometricUnlock(bool enabled) async {
    _config.disguiseBiometricUnlock = enabled;
    await ConfigService.saveConfig(_config);
    notifyListeners();
  }

  Future<int?> testConnectivity() async {
    return await HCApiService.testConnectivity(proxy: _config.customProxy);
  }
}
