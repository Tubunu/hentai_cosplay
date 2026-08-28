import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
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

class RankingTagsResponse {
  final List<RankingTagItem> items;
  final int page;
  final int totalPages;

  RankingTagsResponse({
    required this.items,
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
    _dio = dio;
  }

  static final bool _initialized = () {
    _recreateDio();
    return true;
  }();

  /// Build page URL supporting categories, keywords, and tags
  static String buildBrowseUrl({
    BrowseCategory category = BrowseCategory.latest,
    String? keyword,
    String? tag,
    int page = 1,
  }) {
    if (!_initialized) _recreateDio();

    final cleanKeyword = keyword?.trim() ?? '';
    if (cleanKeyword.isNotEmpty) {
      final encoded = Uri.encodeComponent(cleanKeyword);
      if (page <= 1) {
        return '$kBaseUrl/search/keyword/$encoded/';
      } else {
        return '$kBaseUrl/search/keyword/$encoded/page/$page/';
      }
    }

    final cleanTag = tag?.trim() ?? '';
    if (cleanTag.isNotEmpty) {
      final encoded = Uri.encodeComponent(cleanTag);
      if (page <= 1) {
        return '$kBaseUrl/search/tag/$encoded/';
      } else {
        return '$kBaseUrl/search/tag/$encoded/page/$page/';
      }
    }

    // Category / Ranking URL
    final cleanPath = category.path.replaceAll(RegExp(r'^/|/$'), '');
    if (page <= 1) {
      return '$kBaseUrl/$cleanPath/';
    } else {
      return '$kBaseUrl/$cleanPath/page/$page/';
    }
  }

  /// Backward-compatible buildSearchUrl
  static String buildSearchUrl({int page = 1, String? keyword}) {
    return buildBrowseUrl(category: BrowseCategory.latest, keyword: keyword, page: page);
  }

  /// Build ranking tags or keywords URL
  static String buildRankingTagsUrl({required bool isTag, int page = 1}) {
    if (!_initialized) _recreateDio();
    final path = isTag ? 'ranking-tag' : 'ranking-keyword';
    if (page <= 1) {
      return '$kBaseUrl/$path/';
    } else {
      return '$kBaseUrl/$path/page/$page/';
    }
  }

  /// Parse album items strictly from the main "新到图像列表" / search results display area using DOM parser
  static List<AlbumItem> parseAlbumList(String html) {
    final List<AlbumItem> items = [];
    final doc = html_parser.parse(html);

    // Target the main display area to avoid including sidebar "最近下载", "热门文章" etc.
    final targetContainer = doc.querySelector('#image-list') ??
        doc.querySelector('#display_area_image') ??
        doc.body;
    if (targetContainer == null) return items;

    final itemElements = targetContainer.querySelectorAll('.image-list-item');
    for (final el in itemElements) {
      final linkEl = el.querySelector('.image-list-item-image a') ?? el.querySelector('a');
      final imgEl = el.querySelector('.image-list-item-image img') ?? el.querySelector('img');
      final titleEl = el.querySelector('.image-list-item-title a') ?? el.querySelector('.image-list-item-title');
      final dateEl = el.querySelector('.image-list-item-regist-date span') ?? el.querySelector('.image-list-item-regist-date');

      final rawPath = linkEl?.attributes['href']?.trim() ?? '';
      final coverUrl = imgEl?.attributes['src']?.trim() ?? '';
      final rawTitle = (titleEl?.text.trim().isNotEmpty == true)
          ? titleEl!.text.trim()
          : (imgEl?.attributes['alt']?.trim() ?? '未命名图包');
      final date = dateEl?.text.trim() ?? '';

      if (rawPath.isEmpty && coverUrl.isEmpty) continue;

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

  /// Parse total items count or last page number from HTML using DOM parser
  static int parseTotalPages(String html, int itemCount) {
    final doc = html_parser.parse(html);

    // 1. Try to find last page in wp-pagenavi: class="last"
    final lastLink = doc.querySelector('.wp-pagenavi a.last') ?? doc.querySelector('a.last');
    if (lastLink != null) {
      final href = lastLink.attributes['href'] ?? '';
      final match = RegExp(r'/page/(\d+)/?').firstMatch(href);
      if (match != null) {
        final p = int.tryParse(match.group(1) ?? '');
        if (p != null && p > 0) return p;
      }
    }

    // 2. Try to find all items count: <span class="immoral_all_items">366773</span>
    final countSpan = doc.querySelector('.immoral_all_items');
    if (countSpan != null) {
      final count = int.tryParse(countSpan.text.trim());
      if (count != null && count > 0) {
        return (count + 31) ~/ 32;
      }
    }

    // 3. Fallback: check larger page buttons
    final largerPageLinks = doc.querySelectorAll('.wp-pagenavi a.page.larger, a.page.larger');
    int maxP = 1;
    for (final l in largerPageLinks) {
      final p = int.tryParse(l.text.trim());
      if (p != null && p > maxP) maxP = p;
    }

    return maxP > 1 ? maxP : (itemCount > 0 ? 1 : 0);
  }

  /// Parse detail page total pages (handles multi-page albums with >100 images)
  static int parseDetailTotalPages(String html) {
    final doc = html_parser.parse(html);
    int maxPage = 1;

    // 1. Check wp-pagenavi last page link: class="last"
    final lastLink = doc.querySelector('.wp-pagenavi a.last') ?? doc.querySelector('a.last');
    if (lastLink != null) {
      final href = lastLink.attributes['href'] ?? '';
      final match = RegExp(r'/page/(\d+)/?').firstMatch(href);
      if (match != null) {
        final p = int.tryParse(match.group(1) ?? '');
        if (p != null && p > maxPage) maxPage = p;
      }
    }

    // 2. Check all pagination page links
    final pageLinks = doc.querySelectorAll('.wp-pagenavi a.page, .wp-pagenavi a');
    for (final l in pageLinks) {
      final p = int.tryParse(l.text.trim());
      if (p != null && p > maxPage && p < 1000) {
        maxPage = p;
      }
    }

    // 3. Check page text indicators like "1/3" or "Page 1 of 3"
    final pagesTextEl = doc.querySelector('.wp-pagenavi .pages') ?? doc.querySelector('.pages');
    if (pagesTextEl != null) {
      final match = RegExp(r'(\d+)\s*[/／]\s*(\d+)').firstMatch(pagesTextEl.text);
      if (match != null) {
        final p = int.tryParse(match.group(2) ?? '');
        if (p != null && p > maxPage) maxPage = p;
      }
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
      final doc1 = html_parser.parse(page1Html);
      // Extract title
      final titleTag = doc1.querySelector('title')?.text.replaceAll('- Hentai Cosplay', '').trim();
      final title = (titleTag != null && titleTag.isNotEmpty) ? titleTag : item.title;

      final List<String> imageUrls = [];
      final List<String> previewUrls = [];
      final Set<String> seenUrls = {};

      void addImagesFromDoc(dom.Document doc) {
        final overlays = doc.querySelectorAll('.icon-overlay');
        for (final el in overlays) {
          final linkEl = el.querySelector('a');
          final imgEl = el.querySelector('img');
          final full = linkEl?.attributes['href']?.trim();
          final thumb = imgEl?.attributes['src']?.trim();
          if (full != null && full.isNotEmpty && !seenUrls.contains(full)) {
            seenUrls.add(full);
            imageUrls.add(full);
            previewUrls.add(thumb ?? full);
          }
        }
        // Fallback for direct image container
        if (overlays.isEmpty) {
          final imgs = doc.querySelectorAll('#display_area_image img, #image-list img');
          for (final img in imgs) {
            final src = img.attributes['src']?.trim();
            if (src != null && src.isNotEmpty && !seenUrls.contains(src)) {
              seenUrls.add(src);
              imageUrls.add(src);
              previewUrls.add(src);
            }
          }
        }
      }

      // Add page 1 images
      addImagesFromDoc(doc1);

      // Check if the album has multiple pages (e.g. >100 images)
      final totalPages = parseDetailTotalPages(page1Html);
      if (totalPages > 1) {
        final cleanBaseUrl = item.detailUrl.replaceAll(RegExp(r'/+$'), '');
        const batchSize = 4;
        for (int pStart = 2; pStart <= totalPages; pStart += batchSize) {
          final pEnd = (pStart + batchSize - 1) < totalPages ? (pStart + batchSize - 1) : totalPages;
          final batchFutures = <Future<String?>>[];
          for (int p = pStart; p <= pEnd; p++) {
            final subPageUrl = '$cleanBaseUrl/page/$p/';
            batchFutures.add(_fetchHtml(subPageUrl, retryCount: retryCount));
          }
          final batchHtmls = await Future.wait(batchFutures);
          for (final subHtml in batchHtmls) {
            if (subHtml != null && subHtml.isNotEmpty) {
              addImagesFromDoc(html_parser.parse(subHtml));
            }
          }
        }
      }

      // Extract tags if any
      final List<String> tags = [];
      final tagElements = doc1.querySelectorAll('#detail_tag a, .detail_tag a');
      for (final el in tagElements) {
        final t = el.text.trim();
        if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
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

  /// Parse ranking tags or keywords from HTML using DOM parser
  static List<RankingTagItem> parseRankingTags(String html, bool isTag) {
    final List<RankingTagItem> items = [];
    final seen = <String>{};
    final doc = html_parser.parse(html);

    final tagLinks = doc.querySelectorAll('a[href*="/search/tag/"], a[href*="/search/keyword/"], a[href*="/ranking-tag/"], a[href*="/tag/"]');
    for (final el in tagLinks) {
      final rawHref = el.attributes['href']?.trim() ?? '';
      var rawName = el.text.trim();

      if (rawName.isEmpty ||
          rawName == '首页' ||
          rawName == '下一页' ||
          rawName == '上一页' ||
          rawName == '最后一页' ||
          rawName.contains('Hentai') ||
          rawName.contains('Cosplay')) {
        continue;
      }

      // Extract optional count e.g. (1234)
      String count = '';
      final countSpan = el.parent?.querySelector('span') ?? el.querySelector('span');
      if (countSpan != null) {
        count = countSpan.text.replaceAll(RegExp(r'[(),\s]'), '');
      } else {
        final match = RegExp(r'\(([\d,]+)\)').firstMatch(el.parent?.text ?? '');
        if (match != null) {
          count = match.group(1)?.replaceAll(',', '') ?? '';
        }
      }

      rawName = rawName.replaceAll(RegExp(r'\s*\([\d,]+\)\s*$'), '').trim();
      final fullUrl = rawHref.startsWith('http') ? rawHref : '$kBaseUrl$rawHref';

      if (!seen.contains(rawName) && rawName.isNotEmpty) {
        seen.add(rawName);
        items.add(
          RankingTagItem(
            name: rawName,
            count: count,
            targetUrl: fullUrl,
            isTag: isTag,
          ),
        );
      }
    }

    return items;
  }

  /// Fetch ranking tags or keywords with pagination
  static Future<RankingTagsResponse?> fetchRankingTags({
    required bool isTag,
    required int page,
    int retryCount = 3,
  }) async {
    if (!_initialized) _recreateDio();

    final url = buildRankingTagsUrl(isTag: isTag, page: page);

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
          final items = parseRankingTags(html, isTag);
          final totalPages = parseTotalPages(html, items.length);

          return RankingTagsResponse(
            items: items,
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

  /// Fetch page data (Category Ranking, Search Keyword, or Tag)
  static Future<HCApiResponse?> fetchPageData({
    BrowseCategory category = BrowseCategory.latest,
    String? keyword,
    String? tag,
    required int page,
    int retryCount = 3,
  }) async {
    if (!_initialized) _recreateDio();

    final url = buildBrowseUrl(
      category: category,
      keyword: keyword,
      tag: tag,
      page: page,
    );

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
          client.findProxy = HttpClient.findProxyFromEnvironment;
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
