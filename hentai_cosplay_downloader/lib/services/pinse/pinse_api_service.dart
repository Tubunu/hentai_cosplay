import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';
import '../app_logger.dart';
import '../jable/api_client.dart';
import '../jable/cf_cookie_harvester.dart';

enum PinseCategory {
  latest('最近更新', '/v/'),
  hot('热门精选', '/v/hot/'),
  currentHot('今日热门', '/v/hot/'),
  mature('熟女', '/v/search?keyword=熟女'),
  bigBoobs('巨乳', '/v/search?keyword=巨乳'),
  highBeauty('高颜值', '/v/search?keyword=高颜值'),
  housewife('少妇', '/v/search?keyword=少妇'),
  aunt('阿姨', '/v/search?keyword=阿姨'),
  creampie('内射', '/v/search?keyword=内射'),
  student('学生', '/v/search?keyword=学生'),
  cheating('偷情', '/v/search?keyword=偷情');

  final String label;
  final String path;
  const PinseCategory(this.label, this.path);
}

class PinseApiResponse {
  final List<VideoItem> items;
  final int page;
  final int totalPages;
  final int total;

  PinseApiResponse({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

class PinseApiService {
  static const String kBaseUrl = 'https://91pinse.com';

  static String? _configuredProxy;
  static Dio _dio = _createDio();

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
    _dio = _createDio();
  }

  static Dio _createDio([bool direct = false]) {
    final dio = Dio(
      BaseOptions(
        baseUrl: kBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': '$kBaseUrl/',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
          'Cookie': 'jj_age_ok=1',
        },
      ),
    );

    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      if (!direct && _configuredProxy != null && _configuredProxy!.isNotEmpty) {
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

  /// Build list page URL
  static String buildUrl({
    int page = 1,
    PinseCategory category = PinseCategory.latest,
    String? keyword,
    String? author,
  }) {
    final effectiveKeyword = (keyword != null && keyword.trim().isNotEmpty)
        ? keyword.trim()
        : (author != null && author.trim().isNotEmpty ? author.trim() : null);

    if (effectiveKeyword != null && effectiveKeyword.isNotEmpty) {
      final encoded = Uri.encodeComponent(effectiveKeyword);
      if (page > 1) {
        return '$kBaseUrl/v/search?keyword=$encoded&page=$page';
      }
      return '$kBaseUrl/v/search?keyword=$encoded';
    }

    final catPath = category.path;
    if (catPath.contains('?')) {
      if (page > 1) {
        return '$kBaseUrl$catPath&page=$page';
      }
      return '$kBaseUrl$catPath';
    }

    final cleanPath = catPath.endsWith('/') ? catPath : '$catPath/';
    if (page > 1) {
      return '$kBaseUrl$cleanPath?page=$page';
    }
    return '$kBaseUrl$cleanPath';
  }

  /// Fetch video list from 91pinse
  static Future<PinseApiResponse?> fetchPageData({
    int page = 1,
    PinseCategory category = PinseCategory.latest,
    String? keyword,
    String? author,
  }) async {
    final url = buildUrl(
      page: page,
      category: category,
      keyword: keyword,
      author: author,
    );
    AppLogger.i('91品色', '开始获取列表数据: page=$page, category=${category.label}, keyword=$keyword, author=$author\n目标URL: $url');

    // 1. Primary: Use Headless Chromium Native WebView Pipeline (100% same as mobile Chrome)
    try {
      AppLogger.d('91品色', '通道1: 发起 Android 原生 Chromium WebView 请求 -> $url');
      final sw = Stopwatch()..start();
      final html = await CfCookieHarvester.fetchContentViaWebView(url, siteName: '91PinSe');
      sw.stop();
      if (html.isNotEmpty) {
        AppLogger.d('91品色', '通道1 (Chromium) 成功获取 HTML (长度: ${html.length}, 耗时: ${sw.elapsedMilliseconds}ms)');
        final parsed = _parseListPageHtml(html, page);
        if (parsed.items.isNotEmpty) {
          AppLogger.s('91品色', '通道1 解析成功: 获取到 ${parsed.items.length} 个视频 (总页数: ${parsed.totalPages})');
          return parsed;
        } else {
          final titleMatch = RegExp(r'<title>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(html);
          AppLogger.w('91品色', '通道1 HTML未匹配到视频 (标题: "${titleMatch?.group(1)?.trim()}", HTML长度: ${html.length})');
        }
      }
    } catch (e) {
      AppLogger.w('91品色', '通道1 (Chromium WebView) 请求异常: $e');
    }

    // 2. Secondary: ApiClient with cookie harvest
    try {
      AppLogger.d('91品色', '通道2: 发起 ApiClient 请求 -> $url');
      final html = await ApiClient().fetchHtml('91PinSe', url);
      if (html.isNotEmpty) {
        final parsed = _parseListPageHtml(html, page);
        if (parsed.items.isNotEmpty) {
          AppLogger.s('91品色', '通道2 (ApiClient) 成功解析: 获取到 ${parsed.items.length} 个视频');
          return parsed;
        }
      }
    } catch (e) {
      AppLogger.w('91品色', '通道2 (ApiClient) 异常: $e');
    }

    // 3. Secondary fallback: Direct Dio
    final urlsToTry = [
      url,
      url.replaceAll('https://91pinse.com', 'https://www.91pinse.com'),
    ];

    for (final targetUrl in urlsToTry) {
      try {
        AppLogger.d('91品色', '通道3 (Dio): 尝试请求 $targetUrl (代理配置: $_configuredProxy)');
        final response = await _dio.get<String>(
          targetUrl,
          options: Options(responseType: ResponseType.plain),
        );

        if (response.statusCode == 200 && response.data != null) {
          final parsed = _parseListPageHtml(response.data!, page);
          if (parsed.items.isNotEmpty) {
            AppLogger.s('91品色', '通道3 (Dio) 成功解析: 获取到 ${parsed.items.length} 个视频');
            return parsed;
          }
        }
      } catch (e) {
        AppLogger.w('91品色', '通道3 (Dio) 请求错误 $targetUrl: $e. 尝试 Direct 直连...');
        try {
          final directDio = _createDio(true);
          final response = await directDio.get<String>(
            targetUrl,
            options: Options(responseType: ResponseType.plain),
          );
          if (response.statusCode == 200 && response.data != null) {
            final parsed = _parseListPageHtml(response.data!, page);
            if (parsed.items.isNotEmpty) {
              AppLogger.s('91品色', '通道3 (Dio Direct) 成功解析: 获取到 ${parsed.items.length} 个视频');
              return parsed;
            }
          }
        } catch (e2) {
          AppLogger.e('91品色', '通道3 (Dio Direct) 失败: $e2');
        }
      }
    }
    AppLogger.e('91品色', '所有请求通道均未获取到有效视频数据');
    return null;
  }

  /// Fetch video detail alias
  static Future<VideoItem> fetchVideoDetail(VideoItem item) => resolveVideoDetail(item);

  /// Resolve direct video stream/m3u8 URL from 91PinSe playback API or video detail page
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    if (item.isDetailLoaded && item.videoUrl != null && item.videoUrl!.isNotEmpty && (item.videoUrl!.contains('.m3u8') || item.videoUrl!.contains('.mp4'))) {
      return item;
    }

    String? directVideoUrl;
    String? title = item.title;
    String? author = item.author;
    String? duration = item.duration;
    String? views = item.views;
    String? coverUrl = item.coverUrl;
    final List<String> tags = List<String>.from(item.tags);

    // 1. Try to extract video ID from detailUrl: e.g. /v/455670
    final vMatch = RegExp(r'/v/(\d+)').firstMatch(item.detailUrl) ?? RegExp(r'(\d+)').firstMatch(item.slug);
    final videoId = vMatch?.group(1);

    if (videoId != null && videoId.isNotEmpty) {
      final playbackUrl = '$kBaseUrl/api/videos/$videoId/playback';
      try {
        debugPrint('[PinseApiService] Requesting playback API: $playbackUrl');
        final pbRes = await _dio.post(
          playbackUrl,
          options: Options(
            headers: {
              'X-Requested-With': 'XMLHttpRequest',
              'Referer': item.detailUrl,
              'Origin': kBaseUrl,
              'Accept': 'application/json, text/javascript, */*; q=0.01',
            },
          ),
        );

        if (pbRes.statusCode == 200 && pbRes.data != null) {
          dynamic pbData = pbRes.data;
          if (pbData is String) {
            try {
              pbData = jsonDecode(pbData);
            } catch (_) {}
          }
          if (pbData is Map) {
            final streamUrl = pbData['url']?.toString() ?? pbData['fallback_url']?.toString();
            if (streamUrl != null && streamUrl.isNotEmpty && (streamUrl.contains('.m3u8') || streamUrl.contains('.mp4'))) {
              directVideoUrl = streamUrl;
              debugPrint('[PinseApiService] Successfully resolved direct stream from API: $directVideoUrl');
            }
          }
        }
      } catch (e) {
        debugPrint('[PinseApiService] Playback API error: $e. Retrying direct...');
        try {
          final directDio = _createDio(true);
          final pbRes = await directDio.post(
            playbackUrl,
            options: Options(
              headers: {
                'X-Requested-With': 'XMLHttpRequest',
                'Referer': item.detailUrl,
                'Origin': kBaseUrl,
                'Accept': 'application/json, text/javascript, */*; q=0.01',
              },
            ),
          );
          if (pbRes.statusCode == 200 && pbRes.data != null) {
            dynamic pbData = pbRes.data;
            if (pbData is String) {
              try {
                pbData = jsonDecode(pbData);
              } catch (_) {}
            }
            if (pbData is Map) {
              final streamUrl = pbData['url']?.toString() ?? pbData['fallback_url']?.toString();
              if (streamUrl != null && streamUrl.isNotEmpty && (streamUrl.contains('.m3u8') || streamUrl.contains('.mp4'))) {
                directVideoUrl = streamUrl;
              }
            }
          }
        } catch (_) {}
      }
    }

    // 2. Fallback to HTML scraping
    try {
      if (directVideoUrl == null || directVideoUrl.isEmpty) {
        debugPrint('[PinseApiService] Resolving video detail HTML: ${item.detailUrl}');
        String? html;
        try {
          html = await CfCookieHarvester.fetchContentViaWebView(item.detailUrl, siteName: '91PinSe');
        } catch (e) {
          debugPrint('[PinseApiService] Chromium WebView detail fetch error: $e');
          try {
            html = await ApiClient().fetchHtml('91PinSe', item.detailUrl, isDetailPage: true);
          } catch (e2) {
            debugPrint('[PinseApiService] ApiClient detail fetch error: $e2');
            try {
              final response = await _dio.get<String>(
                item.detailUrl,
                options: Options(responseType: ResponseType.plain),
              );
              if (response.statusCode == 200) {
                html = response.data;
              }
            } catch (e3) {
              final directDio = _createDio(true);
              final response = await directDio.get<String>(
                item.detailUrl,
                options: Options(responseType: ResponseType.plain),
              );
              if (response.statusCode == 200) {
                html = response.data;
              }
            }
          }
        }

        if (html != null && html.isNotEmpty) {
          final document = html_parser.parse(html);

          // Check video tag
          final videoElem = document.querySelector('video source') ?? document.querySelector('video');
          if (videoElem != null) {
            final src = videoElem.attributes['src'];
            if (src != null && src.isNotEmpty && (src.contains('.m3u8') || src.contains('.mp4'))) {
              directVideoUrl = src.startsWith('http') ? src : '$kBaseUrl$src';
            }
          }

          // Search for m3u8 in scripts
          if (directVideoUrl == null || directVideoUrl.isEmpty) {
            final m3u8Match = RegExp(r'(https?://[^\s"<>&]+\.m3u8[^\s"<>&]*)').firstMatch(html);
            if (m3u8Match != null) {
              directVideoUrl = m3u8Match.group(1);
            }
          }

          // Search for mp4 in scripts
          if (directVideoUrl == null || directVideoUrl.isEmpty) {
            final mp4Match = RegExp(r'(https?://[^\s"<>&]+\.mp4[^\s"<>&]*)').firstMatch(html);
            if (mp4Match != null) {
              directVideoUrl = mp4Match.group(1);
            }
          }

          // Extract title
          final titleElem = document.querySelector('h1.title') ??
              document.querySelector('h1') ??
              document.querySelector('.video-title');
          if (titleElem != null) {
            title = titleElem.text.trim();
          }

          // Extract tags
          final tagElements = document.querySelectorAll('.tags a, .tag-list a, .video-tags a');
          for (final tagElem in tagElements) {
            final tagText = tagElem.text.trim();
            if (tagText.isNotEmpty && !tags.contains(tagText)) {
              tags.add(tagText);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[PinseApiService] Error resolving video detail HTML: $e');
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

  /// Parse HTML string into list of VideoItem
  static PinseApiResponse _parseListPageHtml(String html, int requestedPage) {
    final document = html_parser.parse(html);
    final List<VideoItem> items = [];
    final seenUrls = <String>{};

    // Search for video card elements across common class patterns
    final cardElements = document.querySelectorAll('article.video-card, .video-card, .video-item, .col-video, .video-box, .myui-vodlist__box, .item-video, .vod-item, .list-item');

    for (final card in cardElements) {
      try {
        final linkElem = card.querySelector('a.video-card-title, a.title, a.video-title, a[href*="/v/"]');
        if (linkElem == null) continue;

        var detailHref = linkElem.attributes['href'] ?? '';
        if (detailHref.isEmpty || detailHref == '#' || detailHref.startsWith('javascript:')) continue;
        if (!detailHref.startsWith('http')) {
          detailHref = '$kBaseUrl$detailHref';
        }

        if (!seenUrls.add(detailHref)) continue;

        final slug = detailHref.split('/').where((s) => s.isNotEmpty).last.replaceAll('.html', '');

        // Extract real title
        var title = card.querySelector('.video-card-title')?.text.trim() ??
            card.querySelector('a[aria-label]')?.attributes['aria-label']?.trim() ??
            linkElem.attributes['title']?.trim() ??
            card.querySelector('.title, .video-title, .myui-vodlist__detail .title, h4')?.text.trim() ??
            '';

        if (title.isEmpty || RegExp(r'^\d+:\d+(:\d+)?$').hasMatch(title)) {
          final anyAria = card.querySelector('[aria-label]');
          title = anyAria?.attributes['aria-label']?.trim() ?? '91品色视频 #$slug';
        }

        final imgElem = card.querySelector('img');
        var coverUrl = imgElem?.attributes['data-original'] ??
            imgElem?.attributes['data-src'] ??
            imgElem?.attributes['src'] ??
            '';
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = '$kBaseUrl$coverUrl';
        }

        final durationElem = card.querySelector('.video-thumb span, .duration, .pic-text, .tag-duration, .badge-duration, .time');
        var duration = durationElem?.text.trim() ?? '';
        if (duration.isEmpty) {
          final thumbText = card.querySelector('.video-thumb')?.text.trim() ?? '';
          final durMatch = RegExp(r'(\d+:\d+(:\d+)?)').firstMatch(thumbText);
          if (durMatch != null) {
            duration = durMatch.group(1)!;
          }
        }

        final authorElem = card.querySelector('.video-card-author, .author, .user-name, .actor, .myui-vodlist__detail .text-muted');
        final author = authorElem?.text.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '91品色官方';

        final viewsElem = card.querySelector('.views, .hit, .play-count, .icon-play');
        final views = viewsElem?.text.trim() ?? '';

        items.add(
          VideoItem(
            title: title,
            slug: slug,
            detailUrl: detailHref,
            coverUrl: coverUrl.isNotEmpty ? coverUrl : null,
            duration: duration,
            author: author,
            views: views,
            date: '今日热门',
            tags: const ['91品色'],
          ),
        );
      } catch (e) {
        debugPrint('[PinseApiService] Error parsing card: $e');
      }
    }

    // Fallback: search for generic /v/ links if cardElements were empty
    if (items.isEmpty) {
      final allLinks = document.querySelectorAll('a[href*="/v/"]');
      for (final a in allLinks) {
        var href = a.attributes['href'] ?? '';
        if (href.contains('/v/')) {
          if (!href.startsWith('http')) {
            href = '$kBaseUrl$href';
          }
          if (!seenUrls.add(href)) continue;

          final title = a.attributes['title'] ?? a.text.trim();
          final img = a.querySelector('img');
          final cover = img?.attributes['data-original'] ?? img?.attributes['data-src'] ?? img?.attributes['src'];

          if (title.isNotEmpty && title.length > 2 && RegExp(r'/v/\d+').hasMatch(href)) {
            final slug = href.split('/').where((s) => s.isNotEmpty).last.replaceAll('.html', '');
            items.add(
              VideoItem(
                title: title,
                slug: slug,
                detailUrl: href,
                coverUrl: cover != null && cover.isNotEmpty ? (cover.startsWith('http') ? cover : '$kBaseUrl$cover') : null,
                duration: '',
                author: '91品色',
                views: '',
                date: '今日热门',
                tags: const ['91品色'],
              ),
            );
          }
        }
      }
    }

    // Parse Pagination
    int totalPages = requestedPage;
    final pageLinks = document.querySelectorAll('.pagination a, .page-link, .page-item a');
    for (final pl in pageLinks) {
      final num = int.tryParse(pl.text.trim());
      if (num != null && num > totalPages) {
        totalPages = num;
      }
    }

    return PinseApiResponse(
      items: items,
      page: requestedPage,
      totalPages: totalPages > requestedPage ? totalPages : requestedPage + 1,
      total: items.length * totalPages,
    );
  }
}
