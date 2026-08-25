import 'dart:convert';

/// Represents the source of the media album
enum MediaSourceType {
  hc('Hentai Cosplay', 'HC'),
  mzt('妹子图', 'MZT');

  final String label;
  final String badge;
  const MediaSourceType(this.label, this.badge);
}

/// Represents an album item from Hentai-Cosplay or MZT API
class AlbumItem {
  final String title;
  final String slug;
  final String detailUrl;
  final String? coverUrl;
  final String date;
  final String author;
  final List<String> tags;
  final List<String> imageUrls;
  final List<String> previewUrls;
  final bool isDetailLoaded;
  final MediaSourceType sourceType;
  final Map<String, dynamic> rawData;

  AlbumItem({
    required this.title,
    required this.slug,
    required this.detailUrl,
    this.coverUrl,
    required this.date,
    required this.author,
    this.tags = const [],
    this.imageUrls = const [],
    this.previewUrls = const [],
    this.isDetailLoaded = false,
    this.sourceType = MediaSourceType.hc,
    this.rawData = const {},
  });

  /// Get image count: if imageUrls is available use its length, otherwise guess or 0
  int get imageCount => imageUrls.length;

  /// Check if album has images
  bool get hasImages => imageUrls.isNotEmpty;

  AlbumItem copyWith({
    String? title,
    String? slug,
    String? detailUrl,
    String? coverUrl,
    String? date,
    String? author,
    List<String>? tags,
    List<String>? imageUrls,
    List<String>? previewUrls,
    bool? isDetailLoaded,
    MediaSourceType? sourceType,
    Map<String, dynamic>? rawData,
  }) {
    return AlbumItem(
      title: title ?? this.title,
      slug: slug ?? this.slug,
      detailUrl: detailUrl ?? this.detailUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      date: date ?? this.date,
      author: author ?? this.author,
      tags: tags ?? this.tags,
      imageUrls: imageUrls ?? this.imageUrls,
      previewUrls: previewUrls ?? this.previewUrls,
      isDetailLoaded: isDetailLoaded ?? this.isDetailLoaded,
      sourceType: sourceType ?? this.sourceType,
      rawData: rawData ?? this.rawData,
    );
  }

  static final RegExp _invalidCharsRegex = RegExp(r'[\\/:*?"<>|]');
  static final RegExp _windowsReservedRegex = RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$', caseSensitive: false);
  static final RegExp _coserRegex = RegExp(r'(?:Coser|coser|网红COSER|网红Coser)[\s@:：]*([^\s\-:：_(\[]+)', caseSensitive: false);
  static final RegExp _bracketRegex = RegExp(r'[\[【]([^\]】]+)[\]】]');
  static final RegExp _dashRegex = RegExp(r'[\-–—]{1,3}');
  static final RegExp _colonRegex = RegExp(r'[:：]');

  /// Extract and clean file / folder name for filesystem safety
  static String cleanFilename(String text) {
    var cleaned = text.replaceAll(_invalidCharsRegex, '_').trim();
    // Remove directory traversal sequences
    cleaned = cleaned.replaceAll(RegExp(r'\.{2,}'), '_');
    // Remove trailing dots and spaces (invalid on Windows)
    cleaned = cleaned.replaceAll(RegExp(r'[\.\s]+$'), '');
    // Prevent Windows reserved device names
    if (_windowsReservedRegex.hasMatch(cleaned)) {
      cleaned = '${cleaned}_safe';
    }
    return cleaned.isEmpty ? 'album_${DateTime.now().millisecondsSinceEpoch}' : cleaned;
  }

  /// Clean author / category folder segment
  static String cleanArchiveSegment(String? val, {String fallback = '未知作者'}) {
    if (val == null || val.trim().isEmpty) {
      return fallback;
    }
    var cleaned = val.trim().replaceAll(_invalidCharsRegex, '_');
    cleaned = cleaned.replaceAll(RegExp(r'\.{2,}'), '_');
    cleaned = cleaned.replaceAll(RegExp(r'[\.\s]+$'), '');
    if (_windowsReservedRegex.hasMatch(cleaned)) {
      cleaned = '${cleaned}_safe';
    }
    return cleaned.isEmpty ? fallback : cleaned;
  }

  /// Infer author name from title, tags or raw json metadata
  static String inferAuthor(String title, [Map<String, dynamic>? item]) {
    if (item != null) {
      for (final key in ['author', 'user', 'username', 'nickname', 'model', 'coser', 'creator']) {
        final value = item[key];
        if (value != null) {
          if (value is Map) {
            final name = value['name'] ?? value['nickname'] ?? value['title'];
            if (name != null && name.toString().trim().isNotEmpty) {
              return cleanArchiveSegment(name.toString());
            }
          } else if (value.toString().trim().isNotEmpty) {
            return cleanArchiveSegment(value.toString());
          }
        }
      }
    }

    final pagePattern = RegExp(r'^\d+\s*[pP]$|^\d+\s*张|^\d+\s*pics?$|^vol\.?\s*\d+', caseSensitive: false);
    bool isValidAuthorName(String? s) {
      if (s == null) return false;
      final trimmed = s.trim();
      if (trimmed.isEmpty) return false;
      if (pagePattern.hasMatch(trimmed)) return false;
      final lower = trimmed.toLowerCase();
      if (lower.contains('internet') ||
          lower.contains('network') ||
          lower.contains('collection') ||
          lower.contains('网络') ||
          lower.contains('搜集') ||
          lower.contains('vip') ||
          lower.contains('精选')) {
        return false;
      }
      return true;
    }

    // Check patterns like Coser@Author, Coser: Author, [Author], Author - Title
    final coserMatch = _coserRegex.firstMatch(title);
    if (coserMatch != null) {
      final name = coserMatch.group(1)?.trim();
      if (isValidAuthorName(name)) {
        return cleanArchiveSegment(name!);
      }
    }

    // Check bracket patterns e.g. [Byoru] or 【Byoru】
    final bracketMatches = _bracketRegex.allMatches(title);
    for (final m in bracketMatches) {
      final name = m.group(1)?.trim();
      if (isValidAuthorName(name)) {
        return cleanArchiveSegment(name!);
      }
    }

    // Clean bracket tags like [VIP] [45P] before dash/colon splitting
    var cleanedTitle = title.replaceAll(RegExp(r'[\[【][^\]】]+[\]】]'), ' ').trim();

    // Split title by hyphen or en-dash like "Author – Title" or "Author - Title"
    final parts = cleanedTitle.split(_dashRegex).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      for (final p in parts) {
        if (isValidAuthorName(p)) {
          return cleanArchiveSegment(p);
        }
      }
    }

    // If title starts with a word before colon
    final colonParts = cleanedTitle.split(_colonRegex).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (colonParts.length >= 2) {
      for (final p in colonParts) {
        if (isValidAuthorName(p)) {
          return cleanArchiveSegment(p);
        }
      }
    }

    if (isValidAuthorName(cleanedTitle)) {
      return cleanArchiveSegment(cleanedTitle);
    }

    return '精选Cosplay';
  }

  /// Resolve file extension from image URL
  static String resolveExt(String url) {
    try {
      final uri = Uri.parse(url);
      final lastSegment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (lastSegment.contains('.')) {
        final ext = lastSegment.split('.').last.toLowerCase();
        const validExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
        if (validExtensions.contains(ext) && ext.length <= 4) {
          return ext;
        }
      }
    } catch (_) {}
    return 'jpg';
  }

  /// Parse from MZT REST API response
  factory AlbumItem.fromMztJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? '未命名图包').toString();
    final urlsRaw = json['urls'] as List<dynamic>? ?? [];
    final urls = urlsRaw.map((e) => e.toString()).toList();
    final author = inferAuthor(title, json);
    final id = json['id']?.toString() ?? json['_id']?.toString() ?? '${title.hashCode.abs()}';

    return AlbumItem(
      title: title,
      slug: 'mzt_$id',
      detailUrl: '',
      coverUrl: urls.isNotEmpty ? urls.first : null,
      date: (json['date'] ?? json['created_at'] ?? '').toString(),
      author: author,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      imageUrls: urls,
      previewUrls: urls,
      isDetailLoaded: true,
      sourceType: MediaSourceType.mzt,
      rawData: json,
    );
  }

  factory AlbumItem.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? '未命名图包').toString();
    final slug = (json['slug'] ?? '').toString();
    final detailUrl = (json['detailUrl'] ?? '').toString();
    final coverUrl = json['coverUrl']?.toString();
    final date = (json['date'] ?? '').toString();
    final author = (json['author'] ?? inferAuthor(title, json)).toString();
    final tags = (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final imageUrls = (json['imageUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final previewUrls = (json['previewUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final isDetailLoaded = json['isDetailLoaded'] == true;
    final rawData = (json['rawData'] as Map<String, dynamic>?) ?? {};
    final sourceTypeName = json['sourceType']?.toString() ?? 'hc';
    final sourceType = sourceTypeName == 'mzt' ? MediaSourceType.mzt : MediaSourceType.hc;

    return AlbumItem(
      title: title,
      slug: slug,
      detailUrl: detailUrl,
      coverUrl: coverUrl,
      date: date,
      author: author,
      tags: tags,
      imageUrls: imageUrls,
      previewUrls: previewUrls,
      isDetailLoaded: isDetailLoaded,
      sourceType: sourceType,
      rawData: rawData,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'slug': slug,
    'detailUrl': detailUrl,
    'coverUrl': coverUrl,
    'date': date,
    'author': author,
    'tags': tags,
    'imageUrls': imageUrls,
    'previewUrls': previewUrls,
    'isDetailLoaded': isDetailLoaded,
    'sourceType': sourceType.name,
    'rawData': rawData,
  };

  String toRawJson() => jsonEncode(toJson());
  factory AlbumItem.fromRawJson(String str) => AlbumItem.fromJson(jsonDecode(str));
}

/// Browse category ranking modes
enum BrowseCategory {
  latest('最新', '/search/'),
  ranking('热门文章', '/ranking/'),
  rankingDownload('下载排行', '/ranking-download/'),
  rankingBookmark('收藏排行', '/ranking-bookmark/'),
  rankingLike('点赞排行', '/ranking-like/');

  final String label;
  final String path;
  const BrowseCategory(this.label, this.path);
}

/// Represents a tag or search keyword item with count
class RankingTagItem {
  final String name;
  final String count;
  final String targetUrl;
  final bool isTag;

  RankingTagItem({
    required this.name,
    required this.count,
    required this.targetUrl,
    required this.isTag,
  });
}

