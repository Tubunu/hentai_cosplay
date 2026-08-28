import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';

enum EpornerCategory {
  topWeekly('本周热门', 'top-weekly'),
  topMonthly('月度精选', 'top-monthly'),
  latest('最新发布', 'latest'),
  longest('长视频', 'longest');

  final String label;
  final String order;
  const EpornerCategory(this.label, this.order);
}

class EpornerApiResponse {
  final List<VideoItem> items;
  final int page;
  final int totalPages;
  final int total;

  EpornerApiResponse({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

class EpornerApiService {
  static const String kBaseUrl = 'https://www.eporner.com';
  static const String kApiUrl = 'https://www.eporner.com/api/v2/video/search/';

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
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
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

  /// Fetch page data from EPorner Official REST JSON API
  static Future<EpornerApiResponse?> fetchPageData({
    int page = 1,
    EpornerCategory category = EpornerCategory.topWeekly,
    String? keyword,
  }) async {
    try {
      final queryParam = keyword != null && keyword.trim().isNotEmpty ? keyword.trim() : 'all';
      final url = '$kApiUrl?query=${Uri.encodeComponent(queryParam)}&per_page=20&page=$page&thumbsize=big&order=${category.order}&format=json';
      debugPrint('[EpornerApiService] Fetching API: $url');

      final response = await _dio.get(url);

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
      debugPrint('[EpornerApiService] Error fetching EPorner API: $e');
    }
    return null;
  }

  /// Parse EPorner official JSON response
  static EpornerApiResponse _parseJsonResponse(Map<String, dynamic> json, int requestedPage) {
    final List<VideoItem> items = [];
    final rawVideos = json['videos'] as List? ?? [];
    final total = json['total'] is int ? json['total'] as int : (int.tryParse(json['total']?.toString() ?? '0') ?? 0);

    for (final v in rawVideos) {
      if (v is! Map<String, dynamic>) continue;
      try {
        final id = v['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        final title = v['title']?.toString() ?? 'EPorner Video #$id';
        final detailUrl = v['url']?.toString() ?? '$kBaseUrl/video-$id/';
        final duration = v['length_min']?.toString() ?? '';
        final views = v['views']?.toString() ?? '';
        final rate = v['rate']?.toString() ?? '';
        final date = v['added']?.toString().split(' ').first ?? '今日';

        String? coverUrl;
        if (v['default_thumb'] is Map) {
          coverUrl = v['default_thumb']['src']?.toString();
        } else if (v['thumbs'] is List && (v['thumbs'] as List).isNotEmpty) {
          coverUrl = v['thumbs'][0]['src']?.toString();
        }

        final List<String> tags = ['EPorner', '4K/HD'];
        final kw = v['keywords']?.toString() ?? '';
        if (kw.isNotEmpty) {
          tags.addAll(kw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(6));
        }

        items.add(
          VideoItem(
            title: title,
            slug: 'eporner_$id',
            detailUrl: detailUrl,
            coverUrl: coverUrl,
            duration: duration,
            author: 'EPorner 4K',
            views: rate.isNotEmpty ? '★ $rate · $views 播放' : '$views 播放',
            date: date,
            tags: tags,
            videoUrl: null, // Resolves on demand
            isDetailLoaded: false,
            rawData: v,
          ),
        );
      } catch (e) {
        debugPrint('[EpornerApiService] Error parsing video item: $e');
      }
    }

    final totalPages = (total / 20).ceil().clamp(1, 500);

    return EpornerApiResponse(
      items: items,
      page: requestedPage,
      totalPages: totalPages,
      total: total,
    );
  }

  /// Resolve direct video stream
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    if (item.isDetailLoaded && item.videoUrl != null && item.videoUrl!.isNotEmpty) {
      return item;
    }

    try {
      debugPrint('[EpornerApiService] Resolving video: ${item.detailUrl}');
      final response = await _dio.get<String>(
        item.detailUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data!;
        final document = html_parser.parse(html);

        String? directVideoUrl;

        // Check video sources
        final videoSource = document.querySelector('video source') ?? document.querySelector('video');
        if (videoSource != null) {
          directVideoUrl = videoSource.attributes['src'];
        }

        // Search for mp4 in scripts / download links
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
      debugPrint('[EpornerApiService] Error resolving video detail: $e');
    }

    return item;
  }
}
