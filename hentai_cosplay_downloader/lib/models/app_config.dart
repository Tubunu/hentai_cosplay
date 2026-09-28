import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/proxy/site_registry.dart';

enum AppProxyMode {
  builtin, // 内置 Libbox/ChromeGo 代理 (推荐)
  custom,  // 外部自定义代理 (如 127.0.0.1:7890)
  direct,  // 完全直连 (关闭代理)
}

enum ProxyRoutingStrategy {
  perSite, // 智能分站点代理 (推荐)
  global,  // 全局走代理
}

const String kAlbumMetadataFilename = '.hc_album.json';
const String kMztMetadataFilename = '.mzt_pack.json';

const List<String> kDefaultMztProxyDomains = [
  'https://tgproxy.1258012.xyz',
  'https://tgproxy1.1258012.xyz',
  'https://tgproxy2.1258012.xyz',
];

const List<String> kDefaultFavoriteResourceSites = [
  'hc_gallery',
  'jable',
  'mzt',
  'hanime1',
  'njav',
  'misskon',
];

class AppConfig {
  String savePath;
  int packWorkers;
  int imgWorkers;
  int retryCount;
  int startPage;
  int? endPage;
  String customProxy; // e.g. '127.0.0.1:7890' or ''
  AppProxyMode proxyMode;
  ProxyRoutingStrategy proxyRoutingStrategy;
  int builtinProxyPort;
  Map<String, bool> siteProxyToggles;
  List<String> mztProxyDomains;
  bool autoArchive;
  String archiveStrategy; // 'author' or 'date'
  String themeMode; // 'system', 'light', 'dark'
  String accentColor; // 'rose', 'purple', 'blue', 'cyberpunk'
  double navBarOpacity; // 0.1 ~ 1.0
  String jableResolutionPref; // '1080p', 'highest', '720p', '480p', 'lowest'
  int jableWorkers;
  List<String> onlineResourceSortOrder;
  List<String> hiddenResourceSites;
  List<String> favoriteResourceSites;
  int lastActiveTabIndex;
  String lastImageSiteKey;
  String lastVideoSiteKey;
  bool disguiseMode;
  String disguiseUnlockCode;
  bool disguiseQuickUnlock;
  bool disguiseRelockOnBackground;
  bool disguiseBiometricUnlock;
  bool autoHideNavigationOnScroll;
  int photoPreloadCount;
  bool allowInsecureCertificates;

  AppConfig({
    this.savePath = '',
    this.packWorkers = 3,
    this.imgWorkers = 12,
    this.retryCount = 3,
    this.startPage = 1,
    this.endPage,
    this.customProxy = '',
    this.proxyMode = AppProxyMode.builtin,
    this.proxyRoutingStrategy = ProxyRoutingStrategy.perSite,
    this.builtinProxyPort = 20808,
    Map<String, bool>? siteProxyToggles,
    List<String>? mztProxyDomains,
    this.autoArchive = true,
    this.archiveStrategy = 'author',
    this.themeMode = 'system',
    this.accentColor = 'rose',
    this.navBarOpacity = 0.85,
    this.jableResolutionPref = '1080p',
    this.jableWorkers = 3,
    List<String>? onlineResourceSortOrder,
    List<String>? hiddenResourceSites,
    List<String>? favoriteResourceSites,
    this.lastActiveTabIndex = 0,
    this.lastImageSiteKey = 'hc_gallery',
    this.lastVideoSiteKey = 'jable',
    this.disguiseMode = false,
    this.disguiseUnlockCode = 'open',
    this.disguiseQuickUnlock = true,
    this.disguiseRelockOnBackground = false,
    this.disguiseBiometricUnlock = false,
    this.autoHideNavigationOnScroll = true,
    this.photoPreloadCount = 8,
    this.allowInsecureCertificates = false,
  })  : siteProxyToggles = siteProxyToggles ?? SiteRegistry.getDefaultToggles(),
        mztProxyDomains = mztProxyDomains ?? List.from(kDefaultMztProxyDomains),
        onlineResourceSortOrder = onlineResourceSortOrder ?? [],
        hiddenResourceSites = hiddenResourceSites ?? [],
        favoriteResourceSites = favoriteResourceSites ?? List.from(kDefaultFavoriteResourceSites);

  AppConfig copyWith({
    String? savePath,
    int? packWorkers,
    int? imgWorkers,
    int? retryCount,
    int? startPage,
    int? endPage,
    String? customProxy,
    AppProxyMode? proxyMode,
    ProxyRoutingStrategy? proxyRoutingStrategy,
    int? builtinProxyPort,
    Map<String, bool>? siteProxyToggles,
    List<String>? mztProxyDomains,
    bool? autoArchive,
    String? archiveStrategy,
    String? themeMode,
    String? accentColor,
    double? navBarOpacity,
    String? jableResolutionPref,
    int? jableWorkers,
    List<String>? onlineResourceSortOrder,
    List<String>? hiddenResourceSites,
    List<String>? favoriteResourceSites,
    int? lastActiveTabIndex,
    String? lastImageSiteKey,
    String? lastVideoSiteKey,
    bool? disguiseMode,
    String? disguiseUnlockCode,
    bool? disguiseQuickUnlock,
    bool? disguiseRelockOnBackground,
    bool? disguiseBiometricUnlock,
    bool? autoHideNavigationOnScroll,
    int? photoPreloadCount,
    bool? allowInsecureCertificates,
  }) {
    return AppConfig(
      savePath: savePath ?? this.savePath,
      packWorkers: packWorkers ?? this.packWorkers,
      imgWorkers: imgWorkers ?? this.imgWorkers,
      retryCount: retryCount ?? this.retryCount,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      customProxy: customProxy ?? this.customProxy,
      proxyMode: proxyMode ?? this.proxyMode,
      proxyRoutingStrategy: proxyRoutingStrategy ?? this.proxyRoutingStrategy,
      builtinProxyPort: builtinProxyPort ?? this.builtinProxyPort,
      siteProxyToggles: siteProxyToggles ?? Map.from(this.siteProxyToggles),
      mztProxyDomains: mztProxyDomains ?? List.from(this.mztProxyDomains),
      autoArchive: autoArchive ?? this.autoArchive,
      archiveStrategy: archiveStrategy ?? this.archiveStrategy,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      navBarOpacity: navBarOpacity ?? this.navBarOpacity,
      jableResolutionPref: jableResolutionPref ?? this.jableResolutionPref,
      jableWorkers: jableWorkers ?? this.jableWorkers,
      onlineResourceSortOrder: onlineResourceSortOrder ?? List.from(this.onlineResourceSortOrder),
      hiddenResourceSites: hiddenResourceSites ?? List.from(this.hiddenResourceSites),
      favoriteResourceSites: favoriteResourceSites ?? List.from(this.favoriteResourceSites),
      lastActiveTabIndex: lastActiveTabIndex ?? this.lastActiveTabIndex,
      lastImageSiteKey: lastImageSiteKey ?? this.lastImageSiteKey,
      lastVideoSiteKey: lastVideoSiteKey ?? this.lastVideoSiteKey,
      disguiseMode: disguiseMode ?? this.disguiseMode,
      disguiseUnlockCode: disguiseUnlockCode ?? this.disguiseUnlockCode,
      disguiseQuickUnlock: disguiseQuickUnlock ?? this.disguiseQuickUnlock,
      disguiseRelockOnBackground: disguiseRelockOnBackground ?? this.disguiseRelockOnBackground,
      disguiseBiometricUnlock: disguiseBiometricUnlock ?? this.disguiseBiometricUnlock,
      autoHideNavigationOnScroll: autoHideNavigationOnScroll ?? this.autoHideNavigationOnScroll,
      photoPreloadCount: photoPreloadCount ?? this.photoPreloadCount,
      allowInsecureCertificates: allowInsecureCertificates ?? this.allowInsecureCertificates,
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      savePath: json['savePath'] ?? '',
      packWorkers: (json['packWorkers'] as num?)?.toInt().clamp(1, 10) ?? 3,
      imgWorkers: (json['imgWorkers'] as num?)?.toInt().clamp(1, 32) ?? 12,
      retryCount: (json['retryCount'] as num?)?.toInt().clamp(1, 10) ?? 3,
      startPage: (json['startPage'] as num?)?.toInt().clamp(1, 99999) ?? 1,
      endPage: (json['endPage'] as num?)?.toInt(),
      customProxy: json['customProxy'] ?? '',
      proxyMode: () {
        final modeStr = json['proxyMode'] as String?;
        if (modeStr == 'direct') return AppProxyMode.direct;
        if (modeStr == 'custom') return AppProxyMode.custom;
        return AppProxyMode.builtin;
      }(),
      proxyRoutingStrategy: () {
        final stratStr = json['proxyRoutingStrategy'] as String?;
        if (stratStr == 'global') return ProxyRoutingStrategy.global;
        return ProxyRoutingStrategy.perSite;
      }(),
      builtinProxyPort: (json['builtinProxyPort'] as num?)?.toInt().clamp(1024, 65535) ?? 20808,
      siteProxyToggles: () {
        final saved = (json['siteProxyToggles'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v == true),
            );
        final defaults = SiteRegistry.getDefaultToggles();
        if (saved == null) return defaults;
        for (final entry in defaults.entries) {
          saved.putIfAbsent(entry.key, () => entry.value);
        }
        return saved;
      }(),
      mztProxyDomains: (json['mztProxyDomains'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          List.from(kDefaultMztProxyDomains),
      autoArchive: json['autoArchive'] ?? true,
      archiveStrategy: json['archiveStrategy'] ?? 'author',
      themeMode: json['themeMode'] ?? 'system',
      accentColor: json['accentColor'] ?? 'rose',
      navBarOpacity: (json['navBarOpacity'] as num?)?.toDouble().clamp(0.1, 1.0) ?? 0.85,
      jableResolutionPref: json['jableResolutionPref'] ?? '1080p',
      jableWorkers: (json['jableWorkers'] as num?)?.toInt().clamp(1, 10) ?? 3,
      onlineResourceSortOrder: (json['onlineResourceSortOrder'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      hiddenResourceSites: (json['hiddenResourceSites'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      favoriteResourceSites: (json['favoriteResourceSites'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          List.from(kDefaultFavoriteResourceSites),
      lastActiveTabIndex: (json['lastActiveTabIndex'] as num?)?.toInt().clamp(0, 4) ?? 0,
      lastImageSiteKey: json['lastImageSiteKey'] as String? ?? 'hc_gallery',
      lastVideoSiteKey: json['lastVideoSiteKey'] as String? ?? 'jable',
      disguiseMode: json['disguiseMode'] as bool? ?? false,
      disguiseUnlockCode: json['disguiseUnlockCode'] as String? ?? 'open',
      disguiseQuickUnlock: json['disguiseQuickUnlock'] as bool? ?? true,
      disguiseRelockOnBackground: json['disguiseRelockOnBackground'] as bool? ?? false,
      disguiseBiometricUnlock: json['disguiseBiometricUnlock'] as bool? ?? false,
      autoHideNavigationOnScroll: json['autoHideNavigationOnScroll'] as bool? ?? true,
      photoPreloadCount: (json['photoPreloadCount'] as num?)?.toInt().clamp(3, 10) ?? 8,
      allowInsecureCertificates: json['allowInsecureCertificates'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'savePath': savePath,
    'packWorkers': packWorkers,
    'imgWorkers': imgWorkers,
    'retryCount': retryCount,
    'startPage': startPage,
    'endPage': endPage,
    'customProxy': customProxy,
    'proxyMode': proxyMode.name,
    'proxyRoutingStrategy': proxyRoutingStrategy.name,
    'builtinProxyPort': builtinProxyPort,
    'siteProxyToggles': siteProxyToggles,
    'mztProxyDomains': mztProxyDomains,
    'autoArchive': autoArchive,
    'archiveStrategy': archiveStrategy,
    'themeMode': themeMode,
    'accentColor': accentColor,
    'navBarOpacity': navBarOpacity,
    'jableResolutionPref': jableResolutionPref,
    'jableWorkers': jableWorkers,
    'onlineResourceSortOrder': onlineResourceSortOrder,
    'hiddenResourceSites': hiddenResourceSites,
    'favoriteResourceSites': favoriteResourceSites,
    'lastActiveTabIndex': lastActiveTabIndex,
    'lastImageSiteKey': lastImageSiteKey,
    'lastVideoSiteKey': lastVideoSiteKey,
    'disguiseMode': disguiseMode,
    'disguiseUnlockCode': disguiseUnlockCode,
    'disguiseQuickUnlock': disguiseQuickUnlock,
    'disguiseRelockOnBackground': disguiseRelockOnBackground,
    'disguiseBiometricUnlock': disguiseBiometricUnlock,
    'autoHideNavigationOnScroll': autoHideNavigationOnScroll,
    'photoPreloadCount': photoPreloadCount,
    'allowInsecureCertificates': allowInsecureCertificates,
  };

  String toRawJson() => jsonEncode(toJson());
  factory AppConfig.fromRawJson(String str) => AppConfig.fromJson(jsonDecode(str));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppConfig &&
        other.savePath == savePath &&
        other.packWorkers == packWorkers &&
        other.imgWorkers == imgWorkers &&
        other.retryCount == retryCount &&
        other.startPage == startPage &&
        other.endPage == endPage &&
        other.customProxy == customProxy &&
        other.proxyMode == proxyMode &&
        other.proxyRoutingStrategy == proxyRoutingStrategy &&
        other.builtinProxyPort == builtinProxyPort &&
        mapEquals(other.siteProxyToggles, siteProxyToggles) &&
        listEquals(other.mztProxyDomains, mztProxyDomains) &&
        other.autoArchive == autoArchive &&
        other.archiveStrategy == archiveStrategy &&
        other.themeMode == themeMode &&
        other.accentColor == accentColor &&
        other.navBarOpacity == navBarOpacity &&
        other.jableResolutionPref == jableResolutionPref &&
        other.jableWorkers == jableWorkers &&
        listEquals(other.onlineResourceSortOrder, onlineResourceSortOrder) &&
        listEquals(other.hiddenResourceSites, hiddenResourceSites) &&
        listEquals(other.favoriteResourceSites, favoriteResourceSites) &&
        other.lastActiveTabIndex == lastActiveTabIndex &&
        other.lastImageSiteKey == lastImageSiteKey &&
        other.lastVideoSiteKey == lastVideoSiteKey &&
        other.disguiseMode == disguiseMode &&
        other.disguiseUnlockCode == disguiseUnlockCode &&
        other.disguiseQuickUnlock == disguiseQuickUnlock &&
        other.disguiseRelockOnBackground == disguiseRelockOnBackground &&
        other.disguiseBiometricUnlock == disguiseBiometricUnlock &&
        other.autoHideNavigationOnScroll == autoHideNavigationOnScroll &&
        other.photoPreloadCount == photoPreloadCount &&
        other.allowInsecureCertificates == allowInsecureCertificates;
  }

  @override
  int get hashCode => Object.hashAll([
        savePath,
        packWorkers,
        imgWorkers,
        retryCount,
        startPage,
        endPage,
        customProxy,
        proxyMode,
        proxyRoutingStrategy,
        builtinProxyPort,
        Object.hashAll(siteProxyToggles.entries),
        Object.hashAll(mztProxyDomains),
        autoArchive,
        archiveStrategy,
        themeMode,
        accentColor,
        navBarOpacity,
        jableResolutionPref,
        jableWorkers,
        Object.hashAll(onlineResourceSortOrder),
        Object.hashAll(hiddenResourceSites),
        Object.hashAll(favoriteResourceSites),
        lastActiveTabIndex,
        lastImageSiteKey,
        lastVideoSiteKey,
        disguiseMode,
        disguiseUnlockCode,
        disguiseQuickUnlock,
        disguiseRelockOnBackground,
        disguiseBiometricUnlock,
        autoHideNavigationOnScroll,
        photoPreloadCount,
        allowInsecureCertificates,
      ]);
}
