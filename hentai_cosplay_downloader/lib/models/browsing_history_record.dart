import 'dart:convert';

class BrowsingHistoryRecord {
  final String id;
  final String title;
  final String author;
  final String? coverUrl;
  final String detailUrl;
  final String? videoUrl;
  final String siteKey;
  final String siteName;
  final int siteColorValue;
  final bool isVideo;
  final String? duration;
  final DateTime viewedAt;
  final Map<String, dynamic>? extra;

  BrowsingHistoryRecord({
    required this.id,
    required this.title,
    required this.author,
    this.coverUrl,
    required this.detailUrl,
    this.videoUrl,
    required this.siteKey,
    required this.siteName,
    required this.siteColorValue,
    this.isVideo = false,
    this.duration,
    required this.viewedAt,
    this.extra,
  });

  factory BrowsingHistoryRecord.fromJson(Map<String, dynamic> json) {
    return BrowsingHistoryRecord(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      coverUrl: json['coverUrl'] as String?,
      detailUrl: json['detailUrl'] ?? '',
      videoUrl: json['videoUrl'] as String?,
      siteKey: json['siteKey'] ?? 'hc_gallery',
      siteName: json['siteName'] ?? 'HC 图集',
      siteColorValue: (json['siteColorValue'] as num?)?.toInt() ?? 0xFFFF2D55,
      isVideo: json['isVideo'] as bool? ?? false,
      duration: json['duration'] as String?,
      viewedAt: DateTime.tryParse(json['viewedAt'] ?? '') ?? DateTime.now(),
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'coverUrl': coverUrl,
    'detailUrl': detailUrl,
    'videoUrl': videoUrl,
    'siteKey': siteKey,
    'siteName': siteName,
    'siteColorValue': siteColorValue,
    'isVideo': isVideo,
    'duration': duration,
    'viewedAt': viewedAt.toIso8601String(),
    'extra': extra,
  };

  String toRawJson() => jsonEncode(toJson());
  factory BrowsingHistoryRecord.fromRawJson(String str) =>
      BrowsingHistoryRecord.fromJson(jsonDecode(str));
}
