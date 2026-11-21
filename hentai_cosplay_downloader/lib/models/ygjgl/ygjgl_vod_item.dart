import 'dart:convert';
import '../video_item.dart';

/// Represents a video-on-demand item from ygjgl.one
class YgjglVodItem {
  final String id;
  final String title;
  final String actor;
  final List<String> tags;
  final String published;
  final String size;
  final String duration;
  final String coverUrl;
  final String? coverSmallUrl;
  final bool isFree;
  final int coin;
  final List<String> pics;
  final List<String> picsThumb;
  final int views;
  final int likes;
  final int collections;
  final int downloads;
  final String? mp4Url;

  const YgjglVodItem({
    required this.id,
    required this.title,
    this.actor = '',
    this.tags = const [],
    this.published = '',
    this.size = '',
    this.duration = '',
    required this.coverUrl,
    this.coverSmallUrl,
    this.isFree = false,
    this.coin = 0,
    this.pics = const [],
    this.picsThumb = const [],
    this.views = 0,
    this.likes = 0,
    this.collections = 0,
    this.downloads = 0,
    this.mp4Url,
  });

  factory YgjglVodItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    final rawTitle = json['title']?.toString() ?? '';
    final rawActor = json['actor']?.toString() ?? '';
    final rawPublished = json['published']?.toString() ?? '';
    final rawSize = json['size']?.toString() ?? '';
    final rawDuration = json['duration']?.toString() ?? '';
    final isFreeVal = (json['is_free'] == 1 ||
        json['is_free'] == true ||
        json['free'] == 1 ||
        json['free'] == true);
    final coinVal = (json['coin'] is num) ? (json['coin'] as num).toInt() : 0;

    // Cover url resolution
    // The official ygjgl.one web frontend always routes video covers via https://ygjgl.one/img/$rawId/cover?w=480
    // Upstream raw gdliren123.com domains in json['cover'] are internal storage CDN that often fail or trigger TLS renegotiation on mobile devices.
    String cov;
    String? covSm;
    if (rawId.isNotEmpty) {
      cov = 'https://ygjgl.one/img/$rawId/cover?w=480';
      covSm = 'https://ygjgl.one/img/$rawId/cover?w=320';
    } else {
      cov = json['cover']?.toString() ?? json['cover_url']?.toString() ?? '';
      covSm = json['cover_small']?.toString() ?? json['cover_small_url']?.toString();
    }

    // Parse preview images
    List<String> rawPics = [];
    if (json['pics'] != null) {
      if (json['pics'] is List) {
        rawPics = (json['pics'] as List).map((e) => e.toString()).toList();
      } else if (json['pics'] is String) {
        try {
          final decoded = jsonDecode(json['pics'] as String);
          if (decoded is List) {
            rawPics = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
    }

    List<String> parsedPics = [];
    List<String> parsedPicsThumb = [];
    if (rawId.isNotEmpty && rawPics.isNotEmpty) {
      // Official play page uses /img/{id}/{index}
      parsedPics = List.generate(rawPics.length, (i) => 'https://ygjgl.one/img/$rawId/$i');
      parsedPicsThumb = List.generate(rawPics.length, (i) => 'https://ygjgl.one/img/$rawId/$i?w=320');
    } else if (rawId.isNotEmpty) {
      // If no preview shots, fall back to cover as in play.html
      parsedPics = ['https://ygjgl.one/img/$rawId/cover?w=720'];
      parsedPicsThumb = ['https://ygjgl.one/img/$rawId/cover?w=320'];
    } else {
      parsedPics = rawPics;
      parsedPicsThumb = rawPics;
    }

    // Parse tags
    List<String> parsedTags = [];
    if (json['tags'] != null) {
      if (json['tags'] is List) {
        parsedTags = (json['tags'] as List).map((e) => e.toString().trim()).where((t) => t.isNotEmpty).toList();
      } else if (json['tags'] is String) {
        parsedTags = (json['tags'] as String)
            .split(',')
            .map((e) => e.trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }
    }

    return YgjglVodItem(
      id: rawId,
      title: rawTitle,
      actor: rawActor,
      tags: parsedTags,
      published: rawPublished,
      size: rawSize,
      duration: rawDuration,
      coverUrl: cov,
      coverSmallUrl: covSm,
      isFree: isFreeVal,
      coin: coinVal,
      pics: parsedPics,
      picsThumb: parsedPicsThumb,
      views: (json['views'] is num) ? (json['views'] as num).toInt() : 0,
      likes: ((json['like_number'] ?? json['likes']) is num)
          ? ((json['like_number'] ?? json['likes']) as num).toInt()
          : 0,
      collections: ((json['collection_number'] ?? json['collections']) is num)
          ? ((json['collection_number'] ?? json['collections']) as num).toInt()
          : 0,
      downloads: ((json['download_count'] ?? json['downloads']) is num)
          ? ((json['download_count'] ?? json['downloads']) as num).toInt()
          : 0,
      mp4Url: (json['mp4_url'] ?? json['mp4'])?.toString(),
    );
  }

  YgjglVodItem copyWith({
    String? mp4Url,
  }) {
    return YgjglVodItem(
      id: id,
      title: title,
      actor: actor,
      tags: tags,
      published: published,
      size: size,
      duration: duration,
      coverUrl: coverUrl,
      coverSmallUrl: coverSmallUrl,
      isFree: isFree,
      coin: coin,
      pics: pics,
      picsThumb: picsThumb,
      views: views,
      likes: likes,
      collections: collections,
      downloads: downloads,
      mp4Url: mp4Url ?? this.mp4Url,
    );
  }

  /// Convert to generic VideoItem for player, history, favorite and download interoperability
  VideoItem toVideoItem() {
    return VideoItem(
      title: title,
      slug: id,
      detailUrl: 'https://ygjgl.one/play?id=$id',
      coverUrl: coverUrl,
      duration: duration,
      views: views > 0 ? views.toString() : '',
      date: published,
      author: actor.isNotEmpty ? actor : '一个就够了',
      tags: tags,
      videoUrl: mp4Url,
      isDetailLoaded: mp4Url != null && mp4Url!.isNotEmpty,
      rawData: {
        'id': id,
        'size': size,
        'isFree': isFree,
        'coin': coin,
        'pics': pics,
        'site': 'ygjgl',
        'subCategory': 'vod',
      },
    );
  }
}
