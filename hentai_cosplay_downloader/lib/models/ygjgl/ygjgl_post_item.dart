import '../album_item.dart';
import '../video_item.dart';

/// Represents a photo album or radio post item from ygjgl.one
class YgjglPostItem {
  final String id;
  final String kind; // 'image' | 'audio'
  final String title;
  final String cover;
  final int imageCount;
  final String published;
  final int seriesId;
  final String seriesTitle;
  final int chapter;
  final List<String> tags;
  final String text;
  final String audioUrl;
  final String audioHls;
  final int views;
  final int likes;
  final int? rank;
  final String duration;
  final List<String> images;

  const YgjglPostItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.cover,
    this.imageCount = 0,
    this.published = '',
    this.seriesId = 0,
    this.seriesTitle = '',
    this.chapter = 0,
    this.tags = const [],
    this.text = '',
    this.audioUrl = '',
    this.audioHls = '',
    this.views = 0,
    this.likes = 0,
    this.rank,
    this.duration = '',
    this.images = const [],
  });

  bool get isAudio => kind == 'audio';
  bool get isImage => kind == 'image';

  factory YgjglPostItem.fromJson(Map<String, dynamic> json, {String defaultKind = 'image'}) {
    final rawId = json['id']?.toString() ?? '';
    final rawKind = json['kind']?.toString() ?? defaultKind;

    String cov = json['cover']?.toString() ?? '';
    if (cov.isEmpty || cov.startsWith('/')) {
      cov = 'https://ygjgl.one/imgp/$rawId/cover';
    }

    List<String> parsedTags = [];
    if (json['tags'] != null && json['tags'] is List) {
      parsedTags = (json['tags'] as List).map((e) => e.toString().trim()).where((t) => t.isNotEmpty).toList();
    }

    List<String> parsedImages = [];
    if (json['images'] != null && json['images'] is List) {
      parsedImages = (json['images'] as List).map((e) {
        final s = e.toString();
        if (s.startsWith('/')) {
          return 'https://ygjgl.one$s';
        }
        return s;
      }).toList();
    }

    return YgjglPostItem(
      id: rawId,
      kind: rawKind,
      title: json['title']?.toString() ?? '',
      cover: cov,
      imageCount: (json['image_count'] is num) ? (json['image_count'] as num).toInt() : parsedImages.length,
      published: json['published']?.toString() ?? '',
      seriesId: (json['series_id'] is num) ? (json['series_id'] as num).toInt() : 0,
      seriesTitle: json['series_title']?.toString() ?? '',
      chapter: (json['chapter'] is num) ? (json['chapter'] as num).toInt() : 0,
      tags: parsedTags,
      text: (json['text'] ?? json['description'])?.toString() ?? '',
      audioUrl: json['audio_url']?.toString() ?? '',
      audioHls: json['audio_hls']?.toString() ?? '',
      views: (json['views'] is num) ? (json['views'] as num).toInt() : 0,
      likes: (json['likes'] is num) ? (json['likes'] as num).toInt() : 0,
      rank: (json['rank'] is num) ? (json['rank'] as num).toInt() : null,
      duration: json['duration']?.toString() ?? '',
      images: parsedImages,
    );
  }

  YgjglPostItem copyWith({
    List<String>? images,
    String? audioUrl,
    String? audioHls,
    String? text,
    String? duration,
  }) {
    return YgjglPostItem(
      id: id,
      kind: kind,
      title: title,
      cover: cover,
      imageCount: images != null ? images.length : imageCount,
      published: published,
      seriesId: seriesId,
      seriesTitle: seriesTitle,
      chapter: chapter,
      tags: tags,
      text: text ?? this.text,
      audioUrl: audioUrl ?? this.audioUrl,
      audioHls: audioHls ?? this.audioHls,
      views: views,
      likes: likes,
      rank: rank,
      duration: duration ?? this.duration,
      images: images ?? this.images,
    );
  }

  /// Convert to generic AlbumItem for photo browsing and batch album download
  AlbumItem toAlbumItem() {
    return AlbumItem(
      title: title,
      slug: id,
      detailUrl: 'https://ygjgl.one/post?id=$id',
      coverUrl: cover,
      date: published,
      author: seriesTitle.isNotEmpty ? seriesTitle : (isAudio ? '电台' : '一个就够了'),
      tags: tags,
      imageUrls: images,
      previewUrls: images.take(12).toList(),
      isDetailLoaded: images.isNotEmpty,
      sourceType: MediaSourceType.ygjgl,
      rawData: {
        'id': id,
        'kind': kind,
        'seriesId': seriesId,
        'seriesTitle': seriesTitle,
        'text': text,
        'audioUrl': audioUrl,
        'audioHls': audioHls,
        'site': 'ygjgl',
        'subCategory': isAudio ? 'audio' : 'image',
      },
    );
  }

  /// Convert to generic VideoItem for audio playback and audio downloading
  VideoItem toVideoItem() {
    return VideoItem(
      title: title,
      slug: id,
      detailUrl: 'https://ygjgl.one/post?id=$id',
      coverUrl: cover,
      duration: duration,
      views: views > 0 ? views.toString() : '',
      date: published,
      author: tags.isNotEmpty ? tags.first : (seriesTitle.isNotEmpty ? seriesTitle : '电台音频'),
      tags: tags,
      videoUrl: audioUrl.isNotEmpty ? audioUrl : null,
      isDetailLoaded: audioUrl.isNotEmpty,
      rawData: {
        'id': id,
        'kind': 'audio',
        'audioUrl': audioUrl,
        'audioHls': audioHls,
        'text': text,
        'site': 'ygjgl',
        'subCategory': 'audio',
      },
    );
  }
}
