import 'dart:convert';

const String kAlbumMetadataFilename = '.hc_album.json';

class AppConfig {
  String savePath;
  int packWorkers;
  int imgWorkers;
  int retryCount;
  int startPage;
  int? endPage;
  String customProxy; // e.g. '127.0.0.1:7890' or ''
  bool autoArchive;
  String archiveStrategy; // 'author' or 'date'
  String themeMode; // 'system', 'light', 'dark'
  String accentColor; // 'rose', 'purple', 'blue', 'cyberpunk'
  double navBarOpacity; // 0.1 ~ 1.0

  AppConfig({
    this.savePath = '',
    this.packWorkers = 3,
    this.imgWorkers = 12,
    this.retryCount = 3,
    this.startPage = 1,
    this.endPage,
    this.customProxy = '',
    this.autoArchive = true,
    this.archiveStrategy = 'author',
    this.themeMode = 'system',
    this.accentColor = 'rose',
    this.navBarOpacity = 0.85,
  });

  AppConfig copyWith({
    String? savePath,
    int? packWorkers,
    int? imgWorkers,
    int? retryCount,
    int? startPage,
    int? endPage,
    String? customProxy,
    bool? autoArchive,
    String? archiveStrategy,
    String? themeMode,
    String? accentColor,
    double? navBarOpacity,
  }) {
    return AppConfig(
      savePath: savePath ?? this.savePath,
      packWorkers: packWorkers ?? this.packWorkers,
      imgWorkers: imgWorkers ?? this.imgWorkers,
      retryCount: retryCount ?? this.retryCount,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      customProxy: customProxy ?? this.customProxy,
      autoArchive: autoArchive ?? this.autoArchive,
      archiveStrategy: archiveStrategy ?? this.archiveStrategy,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      navBarOpacity: navBarOpacity ?? this.navBarOpacity,
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      savePath: json['savePath'] ?? '',
      packWorkers: (json['packWorkers'] as num?)?.toInt() ?? 3,
      imgWorkers: (json['imgWorkers'] as num?)?.toInt() ?? 12,
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 3,
      startPage: (json['startPage'] as num?)?.toInt() ?? 1,
      endPage: (json['endPage'] as num?)?.toInt(),
      customProxy: json['customProxy'] ?? '',
      autoArchive: json['autoArchive'] ?? true,
      archiveStrategy: json['archiveStrategy'] ?? 'author',
      themeMode: json['themeMode'] ?? 'system',
      accentColor: json['accentColor'] ?? 'rose',
      navBarOpacity: (json['navBarOpacity'] as num?)?.toDouble() ?? 0.85,
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
    'autoArchive': autoArchive,
    'archiveStrategy': archiveStrategy,
    'themeMode': themeMode,
    'accentColor': accentColor,
    'navBarOpacity': navBarOpacity,
  };

  String toRawJson() => jsonEncode(toJson());
  factory AppConfig.fromRawJson(String str) => AppConfig.fromJson(jsonDecode(str));
}
