import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';

enum SpankbangCategory {
  trending('热门趋势', '/trending_videos/'),
  popular('最多播放', '/most_popular/'),
  newVideos('最新发布', '/new_videos/'),
  fourK('4K 超清', '/4k/');

  final String label;
  final String path;
  const SpankbangCategory(this.label, this.path);
}

class SpankbangApiResponse {
  final List<VideoItem> items;
  final int page;
  final int totalPages;
  final int total;

  SpankbangApiResponse({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

class SpankbangApiService {
  static const String kBaseUrl = 'https://spankbang.porn';

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
          'Referer': '$kBaseUrl/',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
          'Cookie': 'sb_age_verified=1; age_gate=1; age_confirmed=1; country=US;',
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
    SpankbangCategory category = SpankbangCategory.trending,
    String? keyword,
  }) {
    if (keyword != null && keyword.trim().isNotEmpty) {
      final encodedKw = Uri.encodeComponent(keyword.trim());
      return '$kBaseUrl/s/$encodedKw/$page/';
    }

    final catPath = category.path.endsWith('/') ? category.path : '${category.path}/';
    return page > 1 ? '$kBaseUrl$catPath$page/' : '$kBaseUrl$catPath';
  }

  /// Fetch page data
  static Future<SpankbangApiResponse?> fetchPageData({
    int page = 1,
    SpankbangCategory category = SpankbangCategory.trending,
    String? keyword,
  }) async {
    try {
      final url = buildUrl(page: page, category: category, keyword: keyword);
      debugPrint('[SpankbangApiService] Fetching URL: $url');

      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        return _parseListPageHtml(response.data!, page);
      }
    } catch (e) {
      debugPrint('[SpankbangApiService] Error fetching page $page: $e');
    }
    return null;
  }

  /// Parse HTML list
  static SpankbangApiResponse _parseListPageHtml(String html, int requestedPage) {
    final document = html_parser.parse(html);
    final List<VideoItem> items = [];
    final seenUrls = <String>{};

    final videoElements = document.querySelectorAll('.video-item, .video-rotate, .item, [data-id]');

    for (final elem in videoElements) {
      try {
        final linkElem = elem.querySelector('a[href*="/video/"], a.thumb, a');
        if (linkElem == null) continue;

        var href = linkElem.attributes['href'] ?? '';
        if (href.isEmpty || href == '#' || !href.contains('/video/')) continue;
        if (!href.startsWith('http')) {
          href = '$kBaseUrl$href';
        }

        if (!seenUrls.add(href)) continue;

        final slug = href.split('/').where((s) => s.isNotEmpty).last;

        var title = linkElem.attributes['title'] ??
            elem.querySelector('.n, .title, h4, h3, .name')?.text.trim() ??
            linkElem.text.trim();
        if (title.isEmpty) continue;

        final imgElem = elem.querySelector('img');
        var coverUrl = imgElem?.attributes['data-src'] ??
            imgElem?.attributes['data-original'] ??
            imgElem?.attributes['src'] ??
            '';
        if (coverUrl.contains('logo.png') || coverUrl.contains('icon')) continue;
        if (coverUrl.startsWith('//')) {
          coverUrl = 'https:$coverUrl';
        } else if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = '$kBaseUrl$coverUrl';
        }

        final durationElem = elem.querySelector('.l, .duration, .time, .badge');
        final duration = durationElem?.text.trim() ?? '';

        final viewsElem = elem.querySelector('.v, .views, .stats');
        final views = viewsElem?.text.trim() ?? 'SpankBang HD';

        items.add(
          VideoItem(
            title: title,
            slug: 'spankbang_$slug',
            detailUrl: href,
            coverUrl: coverUrl.isNotEmpty ? coverUrl : null,
            duration: duration,
            author: 'SpankBang HD',
            views: views,
            date: '今日热门',
            tags: ['SpankBang', 'HD/4K'],
            videoUrl: null,
            isDetailLoaded: false,
            rawData: {'detailUrl': href},
          ),
        );
      } catch (e) {
        debugPrint('[SpankbangApiService] Error parsing video card: $e');
      }
    }

    int totalPages = requestedPage;
    final pageLinks = document.querySelectorAll('.pagination a, .page-numbers, .nav-links a');
    for (final pl in pageLinks) {
      final pageNum = int.tryParse(pl.text.trim());
      if (pageNum != null && pageNum > totalPages) {
        totalPages = pageNum;
      }
    }
    if (totalPages <= requestedPage && items.length >= 10) {
      totalPages = requestedPage + 1;
    }

    return SpankbangApiResponse(
      items: items,
      page: requestedPage,
      totalPages: totalPages,
      total: items.length * totalPages,
    );
  }

  /// Resolve direct video stream
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    if (item.isDetailLoaded && item.videoUrl != null && item.videoUrl!.isNotEmpty) {
      return item;
    }

    try {
      debugPrint('[SpankbangApiService] Resolving video: ${item.detailUrl}');
      final response = await _dio.get<String>(
        item.detailUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data!;
        final document = html_parser.parse(html);

        String? directVideoUrl;

        // Check video tag
        final videoSource = document.querySelector('video source') ?? document.querySelector('video');
        if (videoSource != null) {
          directVideoUrl = videoSource.attributes['src'];
        }

        // Search for mp4 in scripts
        if (directVideoUrl == null || directVideoUrl.isEmpty) {
          final mp4Match = RegExp(r'(https?://[^\s"<>&]+\.mp4[^\s"<>&]*)').firstMatch(html);
          if (mp4Match != null) {
            directVideoUrl = mp4Match.group(1);
          }
        }

        // Search for m3u8
        if (directVideoUrl == null || directVideoUrl.isEmpty) {
          final m3u8Match = RegExp(r'(https?://[^\s"<>&]+\.m3u8[^\s"<>&]*)').firstMatch(html);
          if (m3u8Match != null) {
            directVideoUrl = m3u8Match.group(1);
          }
        }

        return item.copyWith(
          videoUrl: directVideoUrl ?? item.detailUrl,
          isDetailLoaded: directVideoUrl != null && directVideoUrl.isNotEmpty,
        );
      }
    } catch (e) {
      debugPrint('[SpankbangApiService] Error resolving detail: $e');
    }

    return item;
  }
}
