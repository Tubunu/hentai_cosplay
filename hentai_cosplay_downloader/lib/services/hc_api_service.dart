import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../models/album_item.dart';

class HCApiResponse {
  final List<AlbumItem> items;
  final int total;
  final int pageSize;
  final int page;
  final int totalPages;

  HCApiResponse({
    required this.items,
    required this.total,
    required this.pageSize,
    required this.page,
    required this.totalPages,
  });
}

class HCApiService {
  static const String kBaseUrl = 'https://zh.hentai-cosplay-xxx.com';
  static const String kSearchBaseUrl = '$kBaseUrl/search/';

  static String? _configuredProxy;

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
    _recreateDio();
  }

  static late Dio _dio;

  static void _recreateDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Referer': '$kBaseUrl/',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8,ja;q=0.7',
          'Connection': 'keep-alive',
        },
      ),
    );

    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;

      if (_configuredProxy != null && _configuredProxy!.isNotEmpty) {
        final clean = _configuredProxy!.replaceAll('http://', '').replaceAll('https://', '');
        client.findProxy = (uri) => 'PROXY $clean; DIRECT';
      } else {
        // Direct connection avoids system-level broken proxy interference
        client.findProxy = (uri) => 'DIRECT';
      }
      return client;
    };

    dio.httpClientAdapter = adapter;
    _dio = dio;
  }

  static final bool _initialized = () {
    _recreateDio();
    return true;
  }();

  /// Build page URL
  static String buildSearchUrl({int page = 1, String? keyword}) {
    if (!_initialized) _recreateDio();

    final cleanKeyword = keyword?.trim() ?? '';
    if (cleanKeyword.isEmpty) {
      if (page <= 1) {
        return '$kBaseUrl/';
      } else {
        return '$kBaseUrl/page/$page/';
      }
    } else {
      final encoded = Uri.encodeComponent(cleanKeyword);
      if (page <= 1) {
        return '$kBaseUrl/search/keyword/$encoded/';
      } else {
        return '$kBaseUrl/search/keyword/$encoded/page/$page/';
      }
    }
  }

  /// Parse album items strictly from the main "新到图像列表" / search results display area
  static List<AlbumItem> parseAlbumList(String html) {
    final List<AlbumItem> items = [];

    // Target the main display area first to avoid including "最近下载", "热门文章" etc.
    String targetHtml = html;
    final imageListMatch = RegExp(
      r'<ul id="image-list"[\s\S]*?</ul>',
      caseSensitive: false,
    ).firstMatch(html);

    if (imageListMatch != null) {
      targetHtml = imageListMatch.group(0) ?? html;
    } else {
      final displayAreaMatch = RegExp(
        r'<div id="display_area_image"[\s\S]*?(?:<div class="wp-pagenavi"|</ul>|$)',
        caseSensitive: false,
      ).firstMatch(html);
      if (displayAreaMatch != null) {
        targetHtml = displayAreaMatch.group(0) ?? html;
      } else {
        // Fallback: take content before wp-pagenavi or secondary sections
        final cutoff = html.indexOf('wp-pagenavi');
        if (cutoff != -1) {
          targetHtml = html.substring(0, cutoff);
        }
      }
    }

    // Match image-list-item block within the target area
    final itemRegex = RegExp(
      r'<div class="image-list-item">[\s\S]*?<div class="image-list-item-image">\s*<a href="([^"]+)">[\s\S]*?<img src="([^"]+)" alt="([^"]*)"[\s\S]*?<p class="image-list-item-title">\s*<a[^>]*>([^<]+)</a>[\s\S]*?<p class="image-list-item-regist-date">\s*<span>([^<]+)</span>',
      caseSensitive: false,
    );

    final matches = itemRegex.allMatches(targetHtml);
    for (final m in matches) {
      final rawPath = m.group(1)?.trim() ?? '';
      final coverUrl = m.group(2)?.trim() ?? '';
      final rawTitle = m.group(4)?.trim() ?? m.group(3)?.trim() ?? '未命名图包';
      final date = m.group(5)?.trim() ?? '';

      final fullDetailUrl = rawPath.startsWith('http') ? rawPath : '$kBaseUrl$rawPath';
      final slug = rawPath.replaceAll(RegExp(r'^/image/|/$'), '');
      final author = AlbumItem.inferAuthor(rawTitle);

      items.add(
        AlbumItem(
          title: rawTitle,
          slug: slug,
          detailUrl: fullDetailUrl,
          coverUrl: coverUrl,
          date: date,
          author: author,
        ),
      );
    }

    return items;
  }

  /// Parse total items count or last page number from HTML
  static int parseTotalPages(String html, int itemCount) {
    // 1. Try to find last page in wp-pagenavi: href="/page/18339/" or href="/search/page/18339/"
    final lastPageMatch = RegExp(
      r'class="last"[^>]*?href="[^"]*?/page/(\d+)/?"',
      caseSensitive: false,
    ).firstMatch(html);
    if (lastPageMatch != null) {
      final p = int.tryParse(lastPageMatch.group(1) ?? '');
      if (p != null && p > 0) return p;
    }

    // 2. Try to find all items count: <span class="immoral_all_items">366773</span>
    final countMatch = RegExp(r'class="immoral_all_items">(\d+)<', caseSensitive: false).firstMatch(html);
    if (countMatch != null) {
      final count = int.tryParse(countMatch.group(1) ?? '');
      if (count != null && count > 0) {
        return (count + 31) ~/ 32;
      }
    }

    // 3. Fallback: check larger page buttons
    final largerMatches = RegExp(r'class="page larger"\s+href="[^"]*?/page/(\d+)/?"', caseSensitive: false).allMatches(html);
    int maxP = 1;
    for (final m in largerMatches) {
      final p = int.tryParse(m.group(1) ?? '');
      if (p != null && p > maxP) maxP = p;
    }

    return maxP > 1 ? maxP : (itemCount > 0 ? 1 : 0);
  }

  /// Parse detail page total pages (handles multi-page albums with >100 images)
  static int parseDetailTotalPages(String html) {
    int maxPage = 1;

    // 1. Check wp-pagenavi last page link: class="last" href=".../page/3/"
    final lastPageMatch = RegExp(
      r'class="last"[^>]*?href="[^"]*?/page/(\d+)/?"',
      caseSensitive: false,
    ).firstMatch(html);
    if (lastPageMatch != null) {
      final p = int.tryParse(lastPageMatch.group(1) ?? '');
      if (p != null && p > maxPage) maxPage = p;
    }

    // 2. Check all pagination page links: class="page larger" or href=".../page/N/"
    final pageMatches = RegExp(
      r'href="[^"]*?/page/(\d+)/?"',
      caseSensitive: false,
    ).allMatches(html);
    for (final m in pageMatches) {
      final p = int.tryParse(m.group(1) ?? '');
      if (p != null && p > maxPage && p < 1000) {
        maxPage = p;
      }
    }

    // 3. Check page text indicators like "1/3" or "Page 1 of 3"
    final pagesTextMatch = RegExp(
      r'class=["\x27]pages["\x27][^>]*>[\s\S]*?(\d+)\s*[/／]\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(html);
    if (pagesTextMatch != null) {
      final p = int.tryParse(pagesTextMatch.group(2) ?? '');
      if (p != null && p > maxPage) maxPage = p;
    }

    return maxPage;
  }

  /// Helper to fetch raw HTML of a single URL with retries
  static Future<String?> _fetchHtml(String url, {int retryCount = 3}) async {
    if (!_initialized) _recreateDio();

    for (int i = 0; i < retryCount; i++) {
      try {
        final response = await _dio.get(
          url,
          options: Options(
            responseType: ResponseType.plain,
            headers: {
              'Referer': '$kBaseUrl/',
            },
          ),
        );
        if (response.statusCode == 200 && response.data != null) {
          return response.data.toString();
        }
      } catch (e) {
        if (i < retryCount - 1) {
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
    }
    return null;
  }

  /// Parse detail page: extract full resolution images and previews from ALL pages
  static Future<AlbumItem?> fetchAlbumDetail(AlbumItem item, {int retryCount = 3}) async {
    if (!_initialized) _recreateDio();

    final page1Html = await _fetchHtml(item.detailUrl, retryCount: retryCount);
    if (page1Html == null || page1Html.isEmpty) return null;

    try {
      // Extract title
      final titleMatch = RegExp(r'<title>([^<]+)</title>', caseSensitive: false).firstMatch(page1Html);
      final rawTitle = titleMatch?.group(1)?.replaceAll('- Hentai Cosplay', '').trim();
      final title = (rawTitle != null && rawTitle.isNotEmpty) ? rawTitle : item.title;

      // Image pattern
      final imgPattern = RegExp(
        r'<div class="icon-overlay">\s*<a href="([^"]+)"[^>]*>\s*<img src="([^"]+)"',
        caseSensitive: false,
      );

      final List<String> imageUrls = [];
      final List<String> previewUrls = [];
      final Set<String> seenUrls = {};

      void addImagesFromHtml(String html) {
        final matches = imgPattern.allMatches(html);
        for (final m in matches) {
          final full = m.group(1)?.trim();
          final thumb = m.group(2)?.trim();
          if (full != null && full.isNotEmpty && !seenUrls.contains(full)) {
            seenUrls.add(full);
            imageUrls.add(full);
            previewUrls.add(thumb ?? full);
          }
        }
      }

      // Add page 1 images
      addImagesFromHtml(page1Html);

      // Check if the album has multiple pages (e.g. >100 images)
      final totalPages = parseDetailTotalPages(page1Html);
      if (totalPages > 1) {
        final cleanBaseUrl = item.detailUrl.replaceAll(RegExp(r'/+$'), '');
        final List<Future<String?>> subPageFutures = [];

        for (int p = 2; p <= totalPages; p++) {
          final subPageUrl = '$cleanBaseUrl/page/$p/';
          subPageFutures.add(_fetchHtml(subPageUrl, retryCount: retryCount));
        }

        final subPagesHtml = await Future.wait(subPageFutures);
        for (final subHtml in subPagesHtml) {
          if (subHtml != null && subHtml.isNotEmpty) {
            addImagesFromHtml(subHtml);
          }
        }
      }

      // Extract tags if any
      final List<String> tags = [];
      final tagMatches = RegExp(r'<p id="detail_tag">([\s\S]*?)</p>', caseSensitive: false).firstMatch(page1Html);
      if (tagMatches != null) {
        final tagLinks = RegExp(r'<a[^>]*>([^<]+)</a>').allMatches(tagMatches.group(1) ?? '');
        for (final tm in tagLinks) {
          final t = tm.group(1)?.trim();
          if (t != null && t.isNotEmpty) tags.add(t);
        }
      }

      return item.copyWith(
        title: title,
        imageUrls: imageUrls,
        previewUrls: previewUrls,
        tags: tags,
        isDetailLoaded: true,
      );
    } catch (e) {
      debugPrint('Error parsing album detail: $e');
      return null;
    }
  }

  /// Fetch page data (Search or Tag or Keyword)
  static Future<HCApiResponse?> fetchPageData({
    required int page,
    String? keyword,
    int retryCount = 3,
  }) async {
    if (!_initialized) _recreateDio();

    final url = buildSearchUrl(page: page, keyword: keyword);

    for (int i = 0; i < retryCount; i++) {
      try {
        final response = await _dio.get(
          url,
          options: Options(
            responseType: ResponseType.plain,
            headers: {
              'Referer': '$kBaseUrl/',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final html = response.data.toString();
          final items = parseAlbumList(html);
          final totalPages = parseTotalPages(html, items.length);
          final totalItems = totalPages * 32;

          return HCApiResponse(
            items: items,
            total: totalItems,
            pageSize: 32,
            page: page,
            totalPages: totalPages > 0 ? totalPages : 1,
          );
        }
      } catch (e) {
        if (i < retryCount - 1) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }
    }
    return null;
  }

  /// Test connectivity and latency
  static Future<int?> testConnectivity({String? proxy}) async {
    final stopwatch = Stopwatch()..start();
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          },
        ),
      );

      final adapter = IOHttpClientAdapter();
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        if (proxy != null && proxy.isNotEmpty) {
          final clean = proxy.replaceAll('http://', '').replaceAll('https://', '');
          client.findProxy = (uri) => 'PROXY $clean; DIRECT';
        } else {
          client.findProxy = (uri) => 'DIRECT';
        }
        return client;
      };
      dio.httpClientAdapter = adapter;

      final res = await dio.get(
        '$kBaseUrl/search/',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      stopwatch.stop();
      if (res.statusCode != null && res.statusCode! < 400) {
        return stopwatch.elapsedMilliseconds;
      }
    } catch (_) {}
    return null;
  }
}
