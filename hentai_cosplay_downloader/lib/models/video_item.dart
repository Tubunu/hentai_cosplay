import 'dart:convert';
import 'package:path/path.dart' as p;

/// Represents a video category ranking mode from porn-video-xxx.com
enum VideoCategory {
  latest('LATEST 最新', '/latest/'),
  ranking('RANKING 排行榜', '/ranking/'),
  rankingDay('RANKING DAY 日榜', '/ranking/type/day/'),
  rankingWeek('RANKING WEEK 周排行榜', '/ranking/type/week/'),
  rankingMonth('RANKING MONTH 月度排行榜', '/ranking/type/month/'),
  rankingPlay('RANKING PLAY 播放排行榜', '/ranking-play/'),
  rankingDownload('RANKING DOWNLOAD 下载排行榜', '/ranking-download/'),
  rankingBookmark('RANKING BOOKMARK 收藏排行', '/bookmark/'),
  rankingGood('RANKING GOOD 好评排行', '/evaluation/');

  final String label;
  final String path;
  const VideoCategory(this.label, this.path);
}

/// Represents an online video item from porn-video-xxx.com
class VideoItem {
  final String title;
  final String slug;
  final String detailUrl;
  final String? coverUrl;
  final String duration;
  final String views;
  final String date;
  final String author;
  final List<String> tags;
  final String? videoUrl;
  final bool isDetailLoaded;
  final Map<String, dynamic> rawData;

  VideoItem({
    required this.title,
    required this.slug,
    required this.detailUrl,
    this.coverUrl,
    this.duration = '',
    this.views = '',
    required this.date,
    required this.author,
    this.tags = const [],
    this.videoUrl,
    this.isDetailLoaded = false,
    this.rawData = const {},
  });

  VideoItem copyWith({
    String? title,
    String? slug,
    String? detailUrl,
    String? coverUrl,
    String? duration,
    String? views,
    String? date,
    String? author,
    List<String>? tags,
    String? videoUrl,
    bool? isDetailLoaded,
    Map<String, dynamic>? rawData,
  }) {
    return VideoItem(
      title: title ?? this.title,
      slug: slug ?? this.slug,
      detailUrl: detailUrl ?? this.detailUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      duration: duration ?? this.duration,
      views: views ?? this.views,
      date: date ?? this.date,
      author: author ?? this.author,
      tags: tags ?? this.tags,
      videoUrl: videoUrl ?? this.videoUrl,
      isDetailLoaded: isDetailLoaded ?? this.isDetailLoaded,
      rawData: rawData ?? this.rawData,
    );
  }

  /// Clean filename for filesystem safety
  static String cleanFilename(String text) {
    return text.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  /// Clean author / folder segment
  static String cleanArchiveSegment(String? val, {String fallback = '未知作者'}) {
    if (val == null || val.trim().isEmpty) {
      return fallback;
    }
    String cleaned = val.trim();
    for (final ch in [r'\', '/', ':', '*', '?', '"', '<', '>', '|']) {
      cleaned = cleaned.replaceAll(ch, '_');
    }
    return cleaned.isEmpty ? fallback : cleaned;
  }

  /// Infer author name from video title or tags
  static String inferAuthor(String title) {
    final coserMatch = RegExp(r'(?:Coser|coser|网红COSER|网红Coser)[\s@:：]*([^\s\-:：_(\[\]】）]+)', caseSensitive: false).firstMatch(title);
    if (coserMatch != null) {
      final name = coserMatch.group(1)?.trim();
      if (name != null && name.isNotEmpty) {
        return cleanArchiveSegment(name);
      }
    }

    final bracketMatch = RegExp(r'[\[【]([^\]】]+)[\]】]').firstMatch(title);
    if (bracketMatch != null) {
      var name = bracketMatch.group(1)?.trim();
      if (name != null && name.isNotEmpty && !name.contains('VIP') && !name.contains('HD') && !name.contains('1080P')) {
        name = name.replaceAll(RegExp(r'^(?:Coser|coser|网红COSER|网红Coser)[\s@:：]*', caseSensitive: false), '').trim();
        return cleanArchiveSegment(name);
      }
    }

    final dashMatch = RegExp(r'^([^\-]+)\s*-\s*').firstMatch(title);
    if (dashMatch != null) {
      final name = dashMatch.group(1)?.trim();
      if (name != null && name.isNotEmpty && name.length <= 20) {
        return cleanArchiveSegment(name);
      }
    }

    return '未知作者';
  }

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      title: json['title'] as String? ?? '未命名视频',
      slug: json['slug'] as String? ?? '',
      detailUrl: json['detailUrl'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      duration: json['duration'] as String? ?? '',
      views: json['views'] as String? ?? '',
      date: json['date'] as String? ?? '',
      author: json['author'] as String? ?? '未知作者',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      videoUrl: json['videoUrl'] as String?,
      isDetailLoaded: json['isDetailLoaded'] as bool? ?? false,
      rawData: json['rawData'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'slug': slug,
    'detailUrl': detailUrl,
    'coverUrl': coverUrl,
    'duration': duration,
    'views': views,
    'date': date,
    'author': author,
    'tags': tags,
    'videoUrl': videoUrl,
    'isDetailLoaded': isDetailLoaded,
    'rawData': rawData,
  };

  String toRawJson() => jsonEncode(toJson());
  factory VideoItem.fromRawJson(String str) => VideoItem.fromJson(jsonDecode(str));
}

/// Represents a locally saved video file
class LocalVideoItem {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final String? coverPath;
  final int fileSizeBytes;
  final DateTime createdAt;
  final String duration;
  final String sourceUrl;
  final List<String> tags;

  LocalVideoItem({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    this.coverPath,
    required this.fileSizeBytes,
    required this.createdAt,
    this.duration = '',
    this.sourceUrl = '',
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

  factory LocalVideoItem.fromJson(Map<String, dynamic> json) {
    return LocalVideoItem(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '未命名视频',
      author: json['author'] as String? ?? '未知作者',
      filePath: json['filePath'] as String? ?? '',
      coverPath: json['coverPath'] as String?,
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      duration: json['duration'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'filePath': filePath,
    'coverPath': coverPath,
    'fileSizeBytes': fileSizeBytes,
    'createdAt': createdAt.toIso8601String(),
    'duration': duration,
    'sourceUrl': sourceUrl,
    'tags': tags,
  };
}
