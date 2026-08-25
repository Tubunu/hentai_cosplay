import 'dart:convert';

class HistoryRecord {
  final String id;
  final String title;
  final String author;
  final String? coverUrl;
  final String targetFolder;
  final int imageCount;
  int downloadedBytes;
  final DateTime completedAt;
  final String detailUrl;
  final bool isVideo;
  final String? duration;

  HistoryRecord({
    required this.id,
    required this.title,
    required this.author,
    this.coverUrl,
    required this.targetFolder,
    required this.imageCount,
    required this.downloadedBytes,
    required this.completedAt,
    required this.detailUrl,
    this.isVideo = false,
    this.duration,
  });

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    return HistoryRecord(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      coverUrl: json['coverUrl'] as String?,
      targetFolder: json['targetFolder'] ?? '',
      imageCount: (json['imageCount'] as num?)?.toInt() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      completedAt: DateTime.tryParse(json['completedAt'] ?? '') ?? DateTime.now(),
      detailUrl: json['detailUrl'] ?? '',
      isVideo: json['isVideo'] as bool? ?? false,
      duration: json['duration'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'coverUrl': coverUrl,
    'targetFolder': targetFolder,
    'imageCount': imageCount,
    'downloadedBytes': downloadedBytes,
    'completedAt': completedAt.toIso8601String(),
    'detailUrl': detailUrl,
    'isVideo': isVideo,
    'duration': duration,
  };

  String toRawJson() => jsonEncode(toJson());
  factory HistoryRecord.fromRawJson(String str) => HistoryRecord.fromJson(jsonDecode(str));
}
