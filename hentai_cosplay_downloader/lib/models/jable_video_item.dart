import 'dart:convert';
import 'package:path/path.dart' as p;

/// Represents a video card from JableTV, MissAV, or SupJav
class VideoCardModel {
  final String url;
  final String title;
  final String thumbnail;
  final String duration;
  final String date;
  final String siteName;

  VideoCardModel({
    required this.url,
    required this.title,
    required this.thumbnail,
    this.duration = '',
    this.date = '',
    this.siteName = 'JableTV',
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'title': title,
      'thumbnail': thumbnail,
      'duration': duration,
      'date': date,
      'siteName': siteName,
    };
  }

  factory VideoCardModel.fromMap(Map<String, dynamic> map) {
    return VideoCardModel(
      url: map['url'] ?? '',
      title: map['title'] ?? '',
      thumbnail: map['thumbnail'] ?? '',
      duration: map['duration'] ?? '',
      date: map['date'] ?? '',
      siteName: map['siteName'] ?? 'JableTV',
    );
  }

  String toJson() => jsonEncode(toMap());
  factory VideoCardModel.fromJson(String source) => VideoCardModel.fromMap(jsonDecode(source));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoCardModel &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          siteName == other.siteName;

  @override
  int get hashCode => Object.hash(url, siteName);
}

/// Represents a category navigation section
class CategoryModel {
  final String name;
  final String url;
  final String slug;
  final int count;

  CategoryModel({
    required this.name,
    required this.url,
    this.slug = '',
    this.count = 0,
  });
}

/// Resolved video details containing stream m3u8 URL and required request headers
class VideoDetailModel {
  final String title;
  final String imageUrl;
  final String m3u8Url;
  final Map<String, String> headers;
  final String siteName;
  final String? webPlayerUrl;

  VideoDetailModel({
    required this.title,
    required this.imageUrl,
    required this.m3u8Url,
    required this.headers,
    this.siteName = 'JableTV',
    this.webPlayerUrl,
  });
}

/// Represents an offline downloaded JableTV / MissAV video file
class JableLocalVideoItem {
  final String id;
  final String title;
  final String filePath;
  final String? coverPath;
  final int fileSizeBytes;
  final DateTime createdAt;
  final String duration;
  final String sourceUrl;
  final String siteName;
  final List<String> tags;

  JableLocalVideoItem({
    required this.id,
    required this.title,
    required this.filePath,
    this.coverPath,
    required this.fileSizeBytes,
    required this.createdAt,
    this.duration = '',
    this.sourceUrl = '',
    this.siteName = 'JableTV',
    this.tags = const [],
  });

  String get formattedSize {
    if (fileSizeBytes <= 0) return '0 B';
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get fileName => p.basename(filePath);

  factory JableLocalVideoItem.fromJson(Map<String, dynamic> json) {
    return JableLocalVideoItem(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '未命名视频',
      filePath: json['filePath'] as String? ?? '',
      coverPath: json['coverPath'] as String?,
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      duration: json['duration'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      siteName: json['siteName'] as String? ?? 'JableTV',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'filePath': filePath,
    'coverPath': coverPath,
    'fileSizeBytes': fileSizeBytes,
    'createdAt': createdAt.toIso8601String(),
    'duration': duration,
    'sourceUrl': sourceUrl,
    'siteName': siteName,
    'tags': tags,
  };
}
