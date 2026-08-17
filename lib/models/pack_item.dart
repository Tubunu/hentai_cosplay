import 'dart:convert';

/// Represents a single image pack item from Mzt API
class PackItem {
  final String title;
  final List<String> urls;
  final String? id;
  final String author;
  final Map<String, dynamic> rawData;

  PackItem({
    required this.title,
    required this.urls,
    this.id,
    required this.author,
    required this.rawData,
  });

  /// The first image URL for cover display
  String? get coverUrl => urls.isNotEmpty ? urls.first : null;

  /// Extract and clean file name
  static String cleanFilename(String text) {
    return text.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  /// Clean archive segment (folder name)
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

  /// Resolve author name from metadata or title (matching python infer_author)
  static String inferAuthor(String title, Map<String, dynamic> item) {
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

    // Split title by hyphen like "Author - Title"
    final parts = title.split(RegExp(r'-{1,3}')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.isNotEmpty) {
      return cleanArchiveSegment(parts.first);
    }
    return '未知作者';
  }

  /// Resolve file extension from URL
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

  factory PackItem.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? '未命名图包').toString();
    final urlsRaw = json['urls'] as List<dynamic>? ?? [];
    final urls = urlsRaw.map((e) => e.toString()).toList();
    final author = inferAuthor(title, json);
    final id = json['id']?.toString() ?? json['_id']?.toString();

    return PackItem(
      title: title,
      urls: urls,
      id: id,
      author: author,
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'urls': urls,
    'id': id,
    'author': author,
    'rawData': rawData,
  };
}
