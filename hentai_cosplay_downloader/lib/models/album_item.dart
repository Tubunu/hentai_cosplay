import 'dart:convert';

/// Represents an album item from Hentai-Cosplay
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
      rawData: rawData ?? this.rawData,
    );
  }

  /// Extract and clean file / folder name for filesystem safety
  static String cleanFilename(String text) {
    return text.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  /// Clean author / category folder segment
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

  /// Infer author name from title or tags
  static String inferAuthor(String title) {
    // Check patterns like Coser@Author, Coser: Author, [Author], Author - Title
    final coserMatch = RegExp(r'(?:Coser|coser|网红COSER|网红Coser)[\s@:：]*([^\s\-:：_(\[]+)', caseSensitive: false).firstMatch(title);
    if (coserMatch != null) {
      final name = coserMatch.group(1)?.trim();
      if (name != null && name.isNotEmpty) {
        return cleanArchiveSegment(name);
      }
    }

    // Check bracket patterns e.g. [Byoru] or 【Byoru】
    final bracketMatch = RegExp(r'[\[【]([^\]】]+)[\]】]').firstMatch(title);
    if (bracketMatch != null) {
      final name = bracketMatch.group(1)?.trim();
      if (name != null && name.isNotEmpty && !name.contains('Internet Collection') && !name.contains('网络搜集') && !name.contains('VIP')) {
        return cleanArchiveSegment(name);
      }
    }

    // Split title by hyphen or en-dash like "Author – Title" or "Author - Title"
    final parts = title.split(RegExp(r'[\-–—]{1,3}')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return cleanArchiveSegment(parts.first);
    }

    // If title starts with a word before colon
    final colonParts = title.split(RegExp(r'[:：]')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (colonParts.length >= 2) {
      return cleanArchiveSegment(colonParts.first);
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

  factory AlbumItem.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? '未命名图包').toString();
    final slug = (json['slug'] ?? '').toString();
    final detailUrl = (json['detailUrl'] ?? '').toString();
    final coverUrl = json['coverUrl']?.toString();
    final date = (json['date'] ?? '').toString();
    final author = (json['author'] ?? inferAuthor(title)).toString();
    final tags = (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final imageUrls = (json['imageUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final previewUrls = (json['previewUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final isDetailLoaded = json['isDetailLoaded'] == true;
    final rawData = (json['rawData'] as Map<String, dynamic>?) ?? {};

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
    'rawData': rawData,
  };

  String toRawJson() => jsonEncode(toJson());
  factory AlbumItem.fromRawJson(String str) => AlbumItem.fromJson(jsonDecode(str));
}
