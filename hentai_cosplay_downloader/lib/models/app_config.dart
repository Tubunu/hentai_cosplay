import 'dart:convert';

const String kAlbumMetadataFilename = '.hc_album.json';
const String kMztMetadataFilename = '.mzt_pack.json';

const List<String> kDefaultMztProxyDomains = [
  'https://tgproxy.1258012.xyz',
  'https://tgproxy1.1258012.xyz',
  'https://tgproxy2.1258012.xyz',
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
  }) : mztProxyDomains = mztProxyDomains ?? List.from(kDefaultMztProxyDomains);

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
  };

  String toRawJson() => jsonEncode(toJson());
  factory AppConfig.fromRawJson(String str) => AppConfig.fromJson(jsonDecode(str));
}
