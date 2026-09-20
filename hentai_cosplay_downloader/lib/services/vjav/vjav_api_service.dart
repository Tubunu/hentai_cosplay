import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../models/video_item.dart';
import '../network_client.dart';

enum VjavCategory {
  latest('最新更新', 'latest-updates'),
  popular('最受关注', 'most-popular'),
  topRated('最高评分', 'top-rated'),
  duration('长视频', 'duration');

  final String label;
  final String sort;
  const VjavCategory(this.label, this.sort);
}

class VjavPageData {
  final List<VideoItem> items;
  final int currentPage;
  final int totalPages;
  final int totalCount;

  const VjavPageData({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
  });
}

class VjavApiService {
  static const String kBaseUrl = 'https://vjav.com';
  static String? _configuredProxy;

  // Custom base64-like cipher alphabet with Cyrillic characters used by VJAV
  static const String _cipherAlphabet =
      '\u0410\u0412\u0421D\u0415FGHIJKL\u041cNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,~';

  static Dio _dio = _createDio();

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
    try {
      _dio.close(force: true);
    } catch (_) {}
    _dio = _createDio();
  }

  static Dio _createDio() {
    return NetworkClient.createDio(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 45),
      specificProxy: _configuredProxy,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        'Referer': 'https://vjav.com/',
        'sec-ch-ua': '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-origin',
      },
    );
  }

  /// Builds catalog JSON or search API URL
  static String buildUrl({
    int page = 1,
    VjavCategory category = VjavCategory.latest,
    String? keyword,
  }) {
    if (keyword != null && keyword.trim().isNotEmpty) {
      final encoded = Uri.encodeComponent(keyword.trim());
      return '$kBaseUrl/api/videos2.php?params=86400/str/relevance/60/search..$page.all..&s=$encoded';
    }

    return '$kBaseUrl/api/json/videos2/86400/str/${category.sort}/60/..$page.all...json';
  }

  /// Fetches a page of video items via VJAV JSON API
  static Future<VjavPageData> fetchVideos({
    int page = 1,
    VjavCategory category = VjavCategory.latest,
    String? keyword,
  }) async {
    final dio = _dio;
    final url = buildUrl(page: page, category: category, keyword: keyword);
    debugPrint('[VjavApiService] Fetching API: $url');

    final response = await dio.get<dynamic>(url);
    dynamic rawData = response.data;
    if (rawData is String) {
      try {
        rawData = jsonDecode(rawData);
      } catch (e) {
        debugPrint('[VjavApiService] Failed to decode JSON: $e');
      }
    }

    if (rawData is! Map<String, dynamic>) {
      return VjavPageData(items: [], currentPage: page, totalPages: 1, totalCount: 0);
    }

    return parsePageData(rawData, page);
  }

  @visibleForTesting
  static VjavPageData parsePageData(Map<String, dynamic> data, int requestPage) {
    final rawVideos = data['videos'] as List<dynamic>? ?? [];
    final items = <VideoItem>[];
    final seenIds = <String>{};

    for (final raw in rawVideos) {
      if (raw is! Map<String, dynamic>) continue;
      final videoId = raw['video_id']?.toString() ?? '';
      if (videoId.isEmpty || seenIds.contains(videoId)) continue;
      seenIds.add(videoId);

      final title = raw['title']?.toString() ?? 'VJAV Video';
      final dir = raw['dir']?.toString() ?? videoId;
      final detailUrl = '$kBaseUrl/videos/$videoId/$dir/';
      final coverUrl = raw['scr']?.toString() ??
          'https://tn.vjav.com/contents/videos_screenshots/${(int.tryParse(videoId) ?? 0) ~/ 1000 * 1000}/$videoId/240x180/1.jpg';

      final duration = raw['duration']?.toString() ?? '';
      final rawViews = raw['video_viewed'];
      var views = '';
      if (rawViews is int) {
        if (rawViews >= 1000000) {
          views = '${(rawViews / 1000000).toStringAsFixed(1)}M';
        } else if (rawViews >= 1000) {
          views = '${(rawViews / 1000).toStringAsFixed(1)}K';
        } else {
          views = '$rawViews';
        }
      } else if (rawViews != null) {
        views = rawViews.toString();
      }

      final rating = raw['rating']?.toString() ?? '';
      final models = raw['models']?.toString() ?? '';
      final categories = raw['categories']?.toString() ?? '';

      final tags = <String>[];
      if (models.isNotEmpty) {
        tags.addAll(models.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
      }
      if (categories.isNotEmpty) {
        tags.addAll(categories.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
      }

      items.add(
        VideoItem(
          title: title,
          slug: videoId,
          detailUrl: detailUrl,
          coverUrl: coverUrl,
          duration: duration,
          views: views,
          date: '',
          author: 'VJAV',
          tags: tags,
          rawData: {
            'video_id': videoId,
            'dir': dir,
            'duration': duration,
            'views': views,
            'rating': rating,
            'models': models,
            'categories': categories,
            'source': 'vjav',
          },
        ),
      );
    }

    final totalCount = (data['total_count'] is int) ? data['total_count'] as int : 0;
    int totalPages = requestPage;
    if (data['pages'] is int) {
      totalPages = data['pages'] as int;
    } else if (totalCount > 0) {
      totalPages = (totalCount / 60).ceil();
    }

    return VjavPageData(
      items: items,
      currentPage: requestPage,
      totalPages: totalPages < requestPage ? requestPage : totalPages,
      totalCount: totalCount,
    );
  }

  /// Decodes VJAV's custom encrypted video stream URL into direct path
  static String decodeStreamUrl(String encrypted) {
    if (encrypted.isEmpty) return '';

    // Remove any character outside the custom alphabet
    final clean = encrypted.replaceAll(
      RegExp(r'[^\u0410\u0412\u0421\u0415\u041cA-Za-z0-9\.\,\~]'),
      '',
    );

    final charCodes = <int>[];
    int s = 0;
    while (s < clean.length) {
      final c0 = s < clean.length ? _cipherAlphabet.indexOf(clean[s++]) : 64;
      final c1 = s < clean.length ? _cipherAlphabet.indexOf(clean[s++]) : 64;
      final c2 = s < clean.length ? _cipherAlphabet.indexOf(clean[s++]) : 64;
      final c3 = s < clean.length ? _cipherAlphabet.indexOf(clean[s++]) : 64;

      final o = (c0 << 2) | (c1 >> 4);
      final i = ((15 & c1) << 4) | (c2 >> 2);
      final r = ((3 & c2) << 6) | c3;

      charCodes.add(o & 0xff);
      if (c2 != 64 && c2 != -1) {
        charCodes.add(i & 0xff);
      }
      if (c3 != 64 && c3 != -1) {
        charCodes.add(r & 0xff);
      }
    }

    final rawString = String.fromCharCodes(charCodes);
    return Uri.decodeFull(rawString);
  }

  /// Resolves direct high-speed video MP4 stream
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    final dio = _dio;
    final videoId = item.rawData['video_id']?.toString() ?? item.slug;
    final vfUrl = '$kBaseUrl/api/videofile.php?video_id=$videoId&lifetime=864000';
    debugPrint('[VjavApiService] Resolving videofile: $vfUrl');

    var videoStreamUrl = '';
    try {
      final response = await dio.get<dynamic>(vfUrl);
      dynamic rawData = response.data;
      if (rawData is String) {
        try {
          rawData = jsonDecode(rawData);
        } catch (_) {}
      }

      if (rawData is List && rawData.isNotEmpty) {
        final first = rawData.first;
        if (first is Map<String, dynamic>) {
          final encUrl = first['video_url']?.toString() ?? '';
          if (encUrl.isNotEmpty) {
            final path = decodeStreamUrl(encUrl);
            if (path.isNotEmpty) {
              videoStreamUrl = path.startsWith('http') ? path : '$kBaseUrl$path';
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[VjavApiService] Error resolving videofile: $e');
    }

    final updatedRawData = Map<String, dynamic>.from(item.rawData);
    updatedRawData['source'] = 'vjav';
    updatedRawData['video_url'] = videoStreamUrl;

    return item.copyWith(
      videoUrl: videoStreamUrl.isNotEmpty ? videoStreamUrl : item.detailUrl,
      isDetailLoaded: true,
      rawData: updatedRawData,
    );
  }
}
