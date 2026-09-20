import 'package:flutter/material.dart';
import 'album_item.dart';
import 'browsing_history_record.dart';
import 'video_item.dart';

/// Represents a user-favorited item across any supported site (albums, videos, Jable).
class FavoriteItem {
  final String id;
  final String title;
  final String? coverUrl;
  final String detailUrl;
  final String author;
  final String date;
  final String mediaType; // 'album' | 'video'
  final MediaSourceType? sourceType;
  final String siteKey;
  final String siteName;
  final int siteColorValue;
  final int? imageCount;
  final String? duration;
  final List<String> tags;
  final String? videoUrl;
  final DateTime addedAt;
  final Map<String, dynamic> rawData;

  const FavoriteItem({
    required this.id,
    required this.title,
    this.coverUrl,
    required this.detailUrl,
    this.author = '',
    this.date = '',
    required this.mediaType,
    this.sourceType,
    required this.siteKey,
    required this.siteName,
    this.siteColorValue = 0xFFFF2D55,
    this.imageCount,
    this.duration,
    this.tags = const [],
    this.videoUrl,
    required this.addedAt,
    this.rawData = const {},
  });

  bool get isVideo => mediaType == 'video';
  bool get isAlbum => mediaType == 'album';
  Color get siteColor => Color(siteColorValue);

  /// Convert FavoriteItem to BrowsingHistoryRecord for navigation via HistoryRouter
  BrowsingHistoryRecord toHistoryRecord() {
    return BrowsingHistoryRecord(
      id: id,
      title: title,
      author: author,
      coverUrl: coverUrl,
      detailUrl: detailUrl,
      videoUrl: videoUrl,
      siteKey: siteKey,
      siteName: siteName,
      siteColorValue: siteColorValue,
      isVideo: isVideo,
      duration: duration ?? (imageCount != null && imageCount! > 0 ? '${imageCount}P' : null),
      viewedAt: addedAt,
      extra: {
        ...rawData,
        if (sourceType != null) 'sourceType': sourceType!.name,
      },
    );
  }

  /// Convert to AlbumItem representation
  AlbumItem toAlbumItem() {
    final rawImages = rawData['imageUrls'];
    final List<String> restoredImages = (rawImages is List && rawImages.isNotEmpty)
        ? rawImages.map((e) => e.toString()).toList()
        : (coverUrl != null && coverUrl!.isNotEmpty ? [coverUrl!] : []);

    return AlbumItem(
      title: title,
      slug: id,
      detailUrl: detailUrl,
      coverUrl: coverUrl,
      date: date,
      author: author,
      tags: tags,
      imageUrls: restoredImages,
      previewUrls: coverUrl != null && coverUrl!.isNotEmpty ? [coverUrl!] : [],
      isDetailLoaded: false,
      sourceType: sourceType ?? MediaSourceType.hc,
      rawData: rawData,
    );
  }

  /// Convert to VideoItem representation
  VideoItem toVideoItem() {
    return VideoItem(
      title: title,
      slug: id,
      detailUrl: detailUrl,
      coverUrl: coverUrl,
      duration: duration ?? '',
      date: date,
      author: author,
      tags: tags,
      videoUrl: videoUrl,
      rawData: rawData,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'coverUrl': coverUrl,
    'detailUrl': detailUrl,
    'author': author,
    'date': date,
    'mediaType': mediaType,
    'sourceType': sourceType?.name,
    'siteKey': siteKey,
    'siteName': siteName,
    'siteColorValue': siteColorValue,
    'imageCount': imageCount,
    'duration': duration,
    'tags': tags,
    'videoUrl': videoUrl,
    'addedAt': addedAt.toIso8601String(),
    'rawData': rawData,
  };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    MediaSourceType? parsedSourceType;
    if (json['sourceType'] != null) {
      try {
        parsedSourceType = MediaSourceType.values.byName(json['sourceType'] as String);
      } catch (_) {}
    }

    return FavoriteItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      detailUrl: json['detailUrl'] as String? ?? '',
      author: json['author'] as String? ?? '',
      date: json['date'] as String? ?? '',
      mediaType: json['mediaType'] as String? ?? 'album',
      sourceType: parsedSourceType,
      siteKey: json['siteKey'] as String? ?? 'hc',
      siteName: json['siteName'] as String? ?? 'Hentai Cosplay',
      siteColorValue: (json['siteColorValue'] as num?)?.toInt() ?? 0xFFFF2D55,
      imageCount: (json['imageCount'] as num?)?.toInt(),
      duration: json['duration'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      videoUrl: json['videoUrl'] as String?,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      rawData: (json['rawData'] as Map<String, dynamic>?) ?? const {},
    );
  }

  /// Factory helper for creating from AlbumItem
  factory FavoriteItem.fromAlbum(
    AlbumItem item, {
    String? siteKey,
    String? siteName,
    int? siteColorValue,
    Map<String, dynamic>? extra,
  }) {
    final effectiveSiteKey = siteKey ?? (item.sourceType == MediaSourceType.hc ? 'hc' : item.sourceType.name);
    final effectiveSiteName = siteName ?? item.sourceType.label;
    final effectiveColorValue = siteColorValue ??
        (item.sourceType == MediaSourceType.hc ? 0xFFFF2D55 : 0xFF007AFF);
    final effectiveSlug = item.slug.isNotEmpty ? item.slug : '${item.detailUrl.hashCode}';
    final id = '${effectiveSiteKey}_$effectiveSlug';

    // Limit stored preview imageUrls to at most 10 to avoid bloating SharedPreferences
    final sanitizedRawData = Map<String, dynamic>.from(item.rawData);
    if (sanitizedRawData['imageUrls'] is List) {
      final list = sanitizedRawData['imageUrls'] as List;
      if (list.length > 10) {
        sanitizedRawData['imageUrls'] = list.take(10).toList();
      }
    }

    final previewImages = item.imageUrls.isNotEmpty
        ? (item.imageUrls.length > 10 ? item.imageUrls.take(10).toList() : item.imageUrls)
        : null;

    return FavoriteItem(
      id: id,
      title: item.title,
      coverUrl: item.coverUrl,
      detailUrl: item.detailUrl,
      author: item.author,
      date: item.date,
      mediaType: 'album',
      sourceType: item.sourceType,
      siteKey: effectiveSiteKey,
      siteName: effectiveSiteName,
      siteColorValue: effectiveColorValue,
      imageCount: item.imageCount > 0 ? item.imageCount : null,
      tags: item.tags,
      addedAt: DateTime.now(),
      rawData: {
        ...sanitizedRawData,
        if (extra != null) ...extra,
        if (previewImages != null) 'imageUrls': previewImages,
      },
    );
  }

  /// Factory helper for creating from VideoItem
  factory FavoriteItem.fromVideo(
    VideoItem item, {
    String? siteKey,
    String? siteName,
    int? siteColorValue,
    Map<String, dynamic>? extra,
  }) {
    String effectiveSiteKey = siteKey ?? '';
    String effectiveSiteName = siteName ?? '';
    int effectiveColorValue = siteColorValue ?? 0xFFFF5252;

    if (effectiveSiteKey.isEmpty) {
      final rawSource = (item.rawData['source'] ?? item.rawData['siteKey'] ?? '').toString().toLowerCase();
      final urlLower = item.detailUrl.toLowerCase();

      bool matched = false;
      for (final rule in _kVideoSiteRules) {
        if (rule.patterns.any((p) => rawSource == p || urlLower.contains(p))) {
          effectiveSiteKey = rule.key;
          effectiveSiteName = rule.name;
          effectiveColorValue = rule.colorValue;
          matched = true;
          break;
        }
      }

      if (!matched) {
        effectiveSiteKey = 'hc_video';
        effectiveSiteName = 'HC 视频';
        effectiveColorValue = 0xFFFF5252;
      }
    }

    final effectiveSlug = item.slug.isNotEmpty ? item.slug : '${item.detailUrl.hashCode}';
    final id = '${effectiveSiteKey}_$effectiveSlug';
    return FavoriteItem(
      id: id,
      title: item.title,
      coverUrl: item.coverUrl,
      detailUrl: item.detailUrl,
      author: item.author,
      date: item.date,
      mediaType: 'video',
      siteKey: effectiveSiteKey,
      siteName: effectiveSiteName,
      siteColorValue: effectiveColorValue,
      duration: item.duration.isNotEmpty ? item.duration : null,
      tags: item.tags,
      videoUrl: item.videoUrl,
      addedAt: DateTime.now(),
      rawData: {
        ...item.rawData,
        if (extra != null) ...extra,
      },
    );
  }

  /// Factory helper for creating from BrowsingHistoryRecord
  factory FavoriteItem.fromHistory(BrowsingHistoryRecord record) {
    final sanitizedExtra = Map<String, dynamic>.from(record.extra ?? const {});
    if (sanitizedExtra['imageUrls'] is List) {
      final list = sanitizedExtra['imageUrls'] as List;
      if (list.length > 10) {
        sanitizedExtra['imageUrls'] = list.take(10).toList();
      }
    }

    return FavoriteItem(
      id: record.id,
      title: record.title,
      coverUrl: record.coverUrl,
      detailUrl: record.detailUrl,
      author: record.author,
      mediaType: record.isVideo ? 'video' : 'album',
      siteKey: record.siteKey,
      siteName: record.siteName,
      siteColorValue: record.siteColorValue,
      duration: record.duration,
      videoUrl: record.videoUrl,
      addedAt: DateTime.now(),
      rawData: sanitizedExtra,
    );
  }
}

class _VideoSiteRule {
  final String key;
  final String name;
  final int colorValue;
  final List<String> patterns;

  const _VideoSiteRule(this.key, this.name, this.colorValue, this.patterns);
}

const List<_VideoSiteRule> _kVideoSiteRules = [
  _VideoSiteRule('njav', 'NJAV', 0xFFFE628E, ['njav']),
  _VideoSiteRule('vjav', 'VJAV', 0xFFFF9900, ['vjav']),
  _VideoSiteRule('thothub', 'ThotHub', 0xFF9C27B0, ['thothub']),
  _VideoSiteRule('javguru', 'JavGuru', 0xFF00ADB5, ['javguru']),
  _VideoSiteRule('av123', '123AV', 0xFFE50914, ['av123', '123av']),
  _VideoSiteRule('javmost', 'JavMost', 0xFFA80000, ['javmost']),
  _VideoSiteRule('memojav', 'MemoJAV', 0xFF6C5CE7, ['memojav']),
  _VideoSiteRule('hohoj', 'HoHoJ', 0xFFE74C3C, ['hohoj']),
  _VideoSiteRule('hanime1', 'Hanime1', 0xFFFF3366, ['hanime1']),
  _VideoSiteRule('iwara', 'Iwara', 0xFF007AFF, ['iwara']),
  _VideoSiteRule('rule34video', 'Rule34Video', 0xFFE91E63, ['rule34video']),
  _VideoSiteRule('spankbang', 'SpankBang', 0xFFFA2C56, ['spankbang']),
  _VideoSiteRule('eporner', 'EPORNER', 0xFFFF5722, ['eporner']),
  _VideoSiteRule('hqporner', 'HQPORNER', 0xFFE50914, ['hqporner']),
  _VideoSiteRule('pornhub', 'Pornhub', 0xFFFF9900, ['pornhub']),
  _VideoSiteRule('xvideos', 'XVideos', 0xFFE50914, ['xvideos']),
  _VideoSiteRule('xnxx', 'XNXX', 0xFF007AFF, ['xnxx']),
  _VideoSiteRule('xhamster', 'xHamster', 0xFFFF9900, ['xhamster']),
  _VideoSiteRule('pinse', '品色', 0xFFE91E63, ['pinse']),
  _VideoSiteRule('pornbox', 'PornBox', 0xFF9C27B0, ['pornbox']),
  _VideoSiteRule('cosxplay', 'CosXPlay', 0xFFE91E63, ['cosxplay']),
  _VideoSiteRule('cosplayporntube', 'CosplayPornTube', 0xFFFF9800, ['cosplayporntube']),
  _VideoSiteRule('jable', 'Jable TV', 0xFFFF9900, ['jable']),
  _VideoSiteRule('missav', 'MissAV', 0xFFFF2D55, ['missav']),
  _VideoSiteRule('supjav', 'SupJav', 0xFF5856D6, ['supjav']),
  _VideoSiteRule('coomer', 'Coomer', 0xFF00AFF0, ['coomer']),
  _VideoSiteRule('twitter', 'Twitter', 0xFF1D9BF0, ['twitter', 'x.com']),
];

