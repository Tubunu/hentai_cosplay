import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';

enum PornboxCategory {
  latest('最新发布', '/store/trending'),
  popular('热门推荐', '/store/trending'),
  topRated('精选内容', '/store/trending');

  final String label;
  final String path;
  const PornboxCategory(this.label, this.path);
}

class PornboxApiResponse {
  final List<VideoItem> items;
  final int page;
  final int totalPages;
  final int total;

  PornboxApiResponse({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

class PornboxApiService {
  static const String kBaseUrl = 'https://pornbox.com';
  static const String kDefaultCookie =
      'JDIALOG3=1; age_verified=1; over18=1; consent=1; user_consent=1; http_referer=https://pornbox.com/; entry_point=https://pornbox.com/';

  static String? _configuredProxy;
  static Dio _dio = _createDio();

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
    _dio = _createDio();
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Referer': '$kBaseUrl/application',
          'Cookie': kDefaultCookie,
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'X-Requested-With': 'XMLHttpRequest',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ),
    );

    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      if (_configuredProxy != null && _configuredProxy!.isNotEmpty) {
        final clean = _configuredProxy!.replaceAll(RegExp(r'https?://|socks5?://'), '');
        if (_configuredProxy!.startsWith('socks')) {
          client.findProxy = (uri) => 'SOCKS5 $clean; DIRECT';
        } else {
          client.findProxy = (uri) => 'PROXY $clean; DIRECT';
        }
      } else {
        client.findProxy = HttpClient.findProxyFromEnvironment;
      }
      return client;
    };
    dio.httpClientAdapter = adapter;

    return dio;
  }

  /// Build request URL
  static String buildUrl({
    int page = 1,
    PornboxCategory category = PornboxCategory.latest,
    String? keyword,
    String? studio,
  }) {
    if (keyword != null && keyword.trim().isNotEmpty) {
      final encodedKw = Uri.encodeComponent(keyword.trim());
      return '$kBaseUrl/store/search?q=$encodedKw&page=$page';
    }

    if (studio != null && studio.trim().isNotEmpty) {
      final encodedStudio = Uri.encodeComponent(studio.trim());
      return '$kBaseUrl/store/search?q=$encodedStudio&page=$page';
    }

    return '$kBaseUrl${category.path}?page=$page';
  }

  /// Fetch page data from pornbox.com JSON API
  static Future<PornboxApiResponse?> fetchPageData({
    int page = 1,
    PornboxCategory category = PornboxCategory.latest,
    String? keyword,
    String? studio,
  }) async {
    try {
      final url = buildUrl(page: page, category: category, keyword: keyword, studio: studio);
      debugPrint('[PornboxApiService] Fetching JSON API: $url');

      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Cookie': kDefaultCookie,
            'X-Requested-With': 'XMLHttpRequest',
            'Accept': 'application/json, text/javascript, */*; q=0.01',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        dynamic jsonData = response.data;
        if (jsonData is String) {
          try {
            jsonData = jsonDecode(jsonData);
          } catch (_) {}
        }

        if (jsonData is Map<String, dynamic>) {
          return _parseJsonResponse(jsonData, page);
        }
      }
    } catch (e) {
      debugPrint('[PornboxApiService] JSON API error: $e. Trying fallback HTML...');
      return _fetchFallbackHtml(page: page, category: category, keyword: keyword);
    }
    return null;
  }

  /// Parse PornBox JSON structure
  static PornboxApiResponse _parseJsonResponse(Map<String, dynamic> json, int requestedPage) {
    final List<VideoItem> items = [];

    List contents = [];
    if (json['contents'] is List) {
      contents = json['contents'] as List;
    } else if (json['content'] is Map && json['content']['contents'] is List) {
      contents = json['content']['contents'] as List;
    }

    for (final itemJson in contents) {
      if (itemJson is! Map<String, dynamic>) continue;
      try {
        final id = itemJson['id']?.toString() ?? itemJson['content_id']?.toString() ?? '';
        if (id.isEmpty) continue;

        final title = itemJson['scene_name']?.toString() ??
            itemJson['name']?.toString() ??
            itemJson['customName']?.toString() ??
            'PornBox Scene #$id';

        final studio = itemJson['studio']?.toString() ?? 'PornBox';
        final runtime = itemJson['runtime']?.toString() ?? '';
        final publishDate = itemJson['publish_date']?.toString() ?? '';

        String? coverUrl;
        if (itemJson['thumbnail'] is Map) {
          final thumbMap = itemJson['thumbnail'] as Map;
          coverUrl = thumbMap['large']?.toString() ??
              thumbMap['mosaic']?.toString() ??
              thumbMap['list']?.toString() ??
              thumbMap['small']?.toString();
        }

        final videoPreview = itemJson['video_preview']?.toString();

        final List<String> tags = ['PornBox'];
        if (studio.isNotEmpty && studio != 'PornBox') {
          tags.add(studio.trim());
        }

        if (itemJson['models'] is List) {
          for (final m in itemJson['models']) {
            if (m is Map && m['model_name'] != null) {
              tags.add(m['model_name'].toString());
            }
          }
        }

        if (itemJson['niches'] is List) {
          for (final n in itemJson['niches']) {
            if (n is Map && n['niche'] != null) {
              tags.add(n['niche'].toString());
            }
          }
        }

        items.add(
          VideoItem(
            title: title.trim(),
            slug: 'pornbox_$id',
            detailUrl: '$kBaseUrl/application/watch-page/$id',
            coverUrl: coverUrl,
            duration: runtime,
            author: studio.trim(),
            views: '',
            date: publishDate.split('T').first,
            tags: tags,
            videoUrl: videoPreview,
            isDetailLoaded: videoPreview != null && videoPreview.isNotEmpty,
            rawData: itemJson,
          ),
        );
      } catch (e) {
        debugPrint('[PornboxApiService] Error parsing JSON scene item: $e');
      }
    }

    final totalPages = requestedPage + (items.length >= 10 ? 1 : 0);

    return PornboxApiResponse(
      items: items,
      page: requestedPage,
      totalPages: totalPages,
      total: items.length * totalPages,
    );
  }

  /// Fallback HTML fetcher
  static Future<PornboxApiResponse?> _fetchFallbackHtml({
    int page = 1,
    PornboxCategory category = PornboxCategory.latest,
    String? keyword,
  }) async {
    try {
      final response = await _dio.get<String>(
        '$kBaseUrl/application',
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Cookie': kDefaultCookie},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return _parseListPageHtml(response.data!, page);
      }
    } catch (e) {
      debugPrint('[PornboxApiService] Fallback HTML error: $e');
    }
    return null;
  }

  /// Fetch video detail alias
  static Future<VideoItem> fetchVideoDetail(VideoItem item) => resolveVideoDetail(item);

  /// Resolve direct video stream URL
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    if (item.isDetailLoaded && item.videoUrl != null && item.videoUrl!.isNotEmpty) {
      return item;
    }

    // If video_preview already in rawData
    if (item.rawData['video_preview'] != null && item.rawData['video_preview'].toString().isNotEmpty) {
      final videoUrl = item.rawData['video_preview'].toString();
      return item.copyWith(
        videoUrl: videoUrl,
        isDetailLoaded: true,
      );
    }

    try {
      debugPrint('[PornboxApiService] Resolving video detail: ${item.detailUrl}');
      final response = await _dio.get<String>(
        item.detailUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Cookie': kDefaultCookie},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data!;
        final document = html_parser.parse(html);

        String? directVideoUrl;
        String? title;
        String? author = item.author;
        String? duration = item.duration;
        String? views = item.views;
        String? coverUrl = item.coverUrl;
        final List<String> tags = List<String>.from(item.tags);

        // Check video tag
        final videoElem = document.querySelector('video source') ?? document.querySelector('video');
        if (videoElem != null) {
          final src = videoElem.attributes['src'];
          if (src != null && src.isNotEmpty) {
            directVideoUrl = src.startsWith('http') ? src : '$kBaseUrl$src';
          }
        }

        // Search for mp4 / m3u8 in scripts
        if (directVideoUrl == null || directVideoUrl.isEmpty) {
          final mp4Match = RegExp(r'(https?://[^\s"<>&]+\.mp4[^\s"<>&]*)').firstMatch(html);
          if (mp4Match != null) {
            directVideoUrl = mp4Match.group(1);
          }
        }

        return item.copyWith(
          title: title ?? item.title,
          author: author,
          duration: duration,
          views: views,
          coverUrl: coverUrl,
          videoUrl: directVideoUrl ?? item.videoUrl,
          tags: tags,
          isDetailLoaded: directVideoUrl != null && directVideoUrl.isNotEmpty,
        );
      }
    } catch (e) {
      debugPrint('[PornboxApiService] Error resolving video detail: $e');
    }

    return item;
  }

  /// Parse HTML string into list of VideoItem
  static PornboxApiResponse _parseListPageHtml(String html, int requestedPage) {
    final document = html_parser.parse(html);
    final List<VideoItem> items = [];

    final cardElements = document.querySelectorAll('.video-item, .video-card, .scene-item, .item-video, .thumb-item, .col-video');

    for (final card in cardElements) {
      try {
        final linkElem = card.querySelector('a[href*="/application/watch-page/"], a[href*="/scene/"], a.thumb, a.title');
        if (linkElem == null) continue;

        var detailHref = linkElem.attributes['href'] ?? '';
        if (detailHref.isEmpty || detailHref == '#') continue;
        if (!detailHref.startsWith('http')) {
          detailHref = '$kBaseUrl$detailHref';
        }

        final slug = detailHref.split('/').where((s) => s.isNotEmpty).last;

        var title = linkElem.attributes['title'] ??
            card.querySelector('.video-title, .title, .scene-name, h4, h3')?.text.trim() ??
            linkElem.text.trim();
        if (title.isEmpty) {
          title = 'PornBox Scene #$slug';
        }

        final imgElem = card.querySelector('img');
        var coverUrl = imgElem?.attributes['data-src'] ??
            imgElem?.attributes['data-original'] ??
            imgElem?.attributes['src'] ??
            '';
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = '$kBaseUrl$coverUrl';
        }

        final durationElem = card.querySelector('.duration, .video-duration, .badge-duration, .time');
        final duration = durationElem?.text.trim() ?? '';

        final authorElem = card.querySelector('.studio, .studio-name, .author');
        final author = authorElem?.text.trim() ?? 'PornBox';

        items.add(
          VideoItem(
            title: title,
            slug: slug,
            detailUrl: detailHref,
            coverUrl: coverUrl.isNotEmpty ? coverUrl : null,
            duration: duration,
            author: author,
            views: '',
            date: '',
            tags: ['PornBox', if (author.isNotEmpty) author],
          ),
        );
      } catch (e) {
        debugPrint('[PornboxApiService] Error parsing card: $e');
      }
    }

    return PornboxApiResponse(
      items: items,
      page: requestedPage,
      totalPages: requestedPage + 1,
      total: items.length * (requestedPage + 1),
    );
  }
}
