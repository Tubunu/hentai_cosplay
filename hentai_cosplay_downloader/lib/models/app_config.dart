import 'dart:convert';
import 'package:flutter/foundation.dart';

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

  AppConfig({
    this.savePath = '',
    this.packWorkers = 3,
    this.imgWorkers = 12,
    this.retryCount = 3,
    this.startPage = 1,
    this.endPage,
    this.customProxy = '',
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
  })  : mztProxyDomains = mztProxyDomains ?? List.from(kDefaultMztProxyDomains),
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
  }) {
    return AppConfig(
      savePath: savePath ?? this.savePath,
      packWorkers: packWorkers ?? this.packWorkers,
      imgWorkers: imgWorkers ?? this.imgWorkers,
      retryCount: retryCount ?? this.retryCount,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      customProxy: customProxy ?? this.customProxy,
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
        other.disguiseRelockOnBackground == disguiseRelockOnBackground;
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
      ]);
}
