import 'dart:convert';

const List<String> kDefaultProxyDomains = [
  'https://tgproxy.1258012.xyz',
  'https://tgproxy1.1258012.xyz',
  'https://tgproxy2.1258012.xyz',
];

const String kPackMetadataFilename = '.mzt_pack.json';

class AppConfig {
  String savePath;
  int packWorkers;
  int imgWorkers;
  int retryCount;
  int startPage;
  int? endPage;
  List<String> proxyDomains;
  bool autoArchive;
  String archiveStrategy; // 'author' or 'category'
  String themeMode; // 'system', 'light', 'dark'
  String accentColor; // 'rose', 'purple', 'blue'

  AppConfig({
    this.savePath = '',
    this.packWorkers = 12,
    this.imgWorkers = 20,
    this.retryCount = 3,
    this.startPage = 1,
    this.endPage,
    List<String>? proxyDomains,
    this.autoArchive = true,
    this.archiveStrategy = 'author',
    this.themeMode = 'system',
    this.accentColor = 'rose',
  }) : proxyDomains = proxyDomains ?? List.from(kDefaultProxyDomains);

  AppConfig copyWith({
    String? savePath,
    int? packWorkers,
    int? imgWorkers,
    int? retryCount,
    int? startPage,
    int? endPage,
    List<String>? proxyDomains,
    bool? autoArchive,
    String? archiveStrategy,
    String? themeMode,
    String? accentColor,
  }) {
    return AppConfig(
      savePath: savePath ?? this.savePath,
      packWorkers: packWorkers ?? this.packWorkers,
      imgWorkers: imgWorkers ?? this.imgWorkers,
      retryCount: retryCount ?? this.retryCount,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      proxyDomains: proxyDomains ?? List.from(this.proxyDomains),
      autoArchive: autoArchive ?? this.autoArchive,
      archiveStrategy: archiveStrategy ?? this.archiveStrategy,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      savePath: json['savePath'] ?? '',
      packWorkers: (json['packWorkers'] as num?)?.toInt() ?? 12,
      imgWorkers: (json['imgWorkers'] as num?)?.toInt() ?? 20,
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 3,
      startPage: (json['startPage'] as num?)?.toInt() ?? 1,
      endPage: (json['endPage'] as num?)?.toInt(),
      proxyDomains: (json['proxyDomains'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          List.from(kDefaultProxyDomains),
      autoArchive: json['autoArchive'] ?? true,
      archiveStrategy: json['archiveStrategy'] ?? 'author',
      themeMode: json['themeMode'] ?? 'system',
      accentColor: json['accentColor'] ?? 'rose',
    );
  }

  Map<String, dynamic> toJson() => {
    'savePath': savePath,
    'packWorkers': packWorkers,
    'imgWorkers': imgWorkers,
    'retryCount': retryCount,
    'startPage': startPage,
    'endPage': endPage,
    'proxyDomains': proxyDomains,
    'autoArchive': autoArchive,
    'archiveStrategy': archiveStrategy,
    'themeMode': themeMode,
    'accentColor': accentColor,
  };

  String toRawJson() => jsonEncode(toJson());
  factory AppConfig.fromRawJson(String str) => AppConfig.fromJson(jsonDecode(str));
}
