import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import '../../models/album_item.dart';

enum PixibbCategory {
  all('全部图集', '/albums/'),
  cosplay('Cosplay 写真', '/category/cosplay/'),
  gravure('Gravure 模特', '/tag/gravure/'),
  models('精选模特', '/models/'),
  anime('动漫二次元', '/category/anime/'),
  aiLookbook('AI 写真', '/category/ai-lookbook/');

  final String label;
  final String path;
  const PixibbCategory(this.label, this.path);
}

class PixibbApiResponse {
  final List<AlbumItem> items;
  final int page;
  final int totalPages;
  final int total;

  PixibbApiResponse({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

class PixibbApiService {
  static const String kBaseUrl = 'https://hub.pixibb.com';

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
    PixibbCategory category = PixibbCategory.all,
    String? keyword,
  }) {
    if (keyword != null && keyword.trim().isNotEmpty) {
      final encodedKw = Uri.encodeComponent(keyword.trim());
      return page > 1 ? '$kBaseUrl/page/$page/?s=$encodedKw' : '$kBaseUrl/?s=$encodedKw';
    }

    final catPath = category.path.endsWith('/') ? category.path : '${category.path}/';
    return page > 1 ? '$kBaseUrl${catPath}page/$page/' : '$kBaseUrl$catPath';
  }

  /// Fetch page data
  static Future<PixibbApiResponse?> fetchPageData({
    int page = 1,
    PixibbCategory category = PixibbCategory.all,
    String? keyword,
  }) async {
    try {
      final url = buildUrl(page: page, category: category, keyword: keyword);
      debugPrint('[PixibbApiService] Fetching URL: $url');

      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        return _parseListPageHtml(response.data!, page);
      }
    } catch (e) {
      debugPrint('[PixibbApiService] Error fetching page $page: $e');
    }
    return null;
  }

  /// Parse list page HTML with strict deduplication and empty filter
  static PixibbApiResponse _parseListPageHtml(String html, int requestedPage) {
    final document = html_parser.parse(html);
    final List<AlbumItem> items = [];
    final seenUrls = <String>{};
    final seenSlugs = <String>{};

    // Select article or post cards
    final postElements = document.querySelectorAll('article, .post-item, .post-card, .tx-post, .item-post');

    for (final elem in postElements) {
      try {
        final titleLink = elem.querySelector('h2 a, h3 a, h4 a, .entry-title a, .post-title a, a.tx-post__title, a.title');
        final anyLink = elem.querySelector('a[href*="pixibb.com/"], a[href*="pixieugirls.com/"]');
        final linkElem = titleLink ?? anyLink;
        if (linkElem == null) continue;

        var href = linkElem.attributes['href'] ?? '';
        if (href.isEmpty ||
            href == '#' ||
            href.contains('wp-json') ||
            href.contains('/feed/') ||
            href.contains('/category/') ||
            href.contains('/tag/') ||
            href.contains('/author/') ||
            href.contains('/page/') ||
            href.contains('/home1/') ||
            href.contains('/home2/') ||
            href.contains('/home3/')) {
          continue;
        }

        if (!href.startsWith('http')) {
          href = '$kBaseUrl$href';
        }

        final slug = href.split('/').where((s) => s.isNotEmpty).last;
        if (slug.isEmpty || !seenUrls.add(href) || !seenSlugs.add(slug)) continue;

        var title = titleLink?.text.trim() ??
            elem.querySelector('.entry-title, h2, h3, .post-title, .title')?.text.trim() ??
            linkElem.attributes['title'] ??
            linkElem.text.trim();
        if (title.isEmpty || title.startsWith('#') || title.length < 3) continue;

        final imgElem = elem.querySelector('img');
        var coverUrl = imgElem?.attributes['data-src'] ??
            imgElem?.attributes['data-lazy-src'] ??
            imgElem?.attributes['data-orig-file'] ??
            imgElem?.attributes['src'] ??
            '';
        if (coverUrl.contains('logo.png') ||
            coverUrl.contains('avatar') ||
            coverUrl.contains('banner') ||
            coverUrl.contains('data:image')) {
          continue;
        }
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = '$kBaseUrl$coverUrl';
        }

        // Must have valid non-empty cover image to prevent blank/empty cards
        if (coverUrl.isEmpty || !coverUrl.startsWith('http')) continue;

        final authorElem = elem.querySelector('.author, .byline, .post-author');
        final author = authorElem?.text.trim().replaceAll(RegExp(r'^by\s+', caseSensitive: false), '') ?? 'PixiBB';

        final dateElem = elem.querySelector('.published, time, .post-date, .entry-date');
        final date = dateElem?.text.trim() ?? '今日';

        final tagElements = elem.querySelectorAll('.cat-links a, .tags-links a, .tag');
        final tags = tagElements.map((t) => t.text.trim()).where((t) => t.isNotEmpty && !t.startsWith('#')).toList();
        if (tags.isEmpty) tags.add('PixiBB');

        items.add(
          AlbumItem(
            title: title,
            slug: slug,
            detailUrl: href,
            coverUrl: coverUrl,
            date: date,
            author: author,
            tags: tags,
            imageUrls: [],
            previewUrls: [],
            isDetailLoaded: false,
            sourceType: MediaSourceType.pixibb,
            rawData: {'detailUrl': href},
          ),
        );
      } catch (e) {
        debugPrint('[PixibbApiService] Error parsing card: $e');
      }
    }

    // Pagination
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

    return PixibbApiResponse(
      items: items,
      page: requestedPage,
      totalPages: totalPages,
      total: items.length * totalPages,
    );
  }

  /// Fetch full album detail & all original images without related post pollution
  static Future<AlbumItem?> fetchAlbumDetail(AlbumItem item) async {
    try {
      debugPrint('[PixibbApiService] Fetching detail: ${item.detailUrl}');
      final response = await _dio.get<String>(
        item.detailUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data!;
        final document = html_parser.parse(html);

        final Set<String> allImages = {};
        final List<String> tags = List.from(item.tags);

        _extractImagesFromContent(document, allImages);

        // Check for multi-page in article: e.g. /2/, /3/
        final baseUrlClean = item.detailUrl.replaceAll(RegExp(r'/$'), '');
        final baseUri = Uri.parse(item.detailUrl);
        final Set<String> subPageUrls = {};

        final allPageLinks = document.querySelectorAll('.entry-content a[href], .page-links a, .post-page-numbers a, a.post-page-numbers');
        for (final a in allPageLinks) {
          final href = a.attributes['href'];
          if (href != null && href.isNotEmpty) {
            final pageMatch = RegExp(r'/(\d+)/?$').firstMatch(href);
            if (pageMatch != null) {
              final pageNum = int.tryParse(pageMatch.group(1)!);
              if (pageNum != null && pageNum > 1 && pageNum <= 30) {
                final fullUrl = href.startsWith('http')
                    ? href
                    : '${baseUri.scheme}://${baseUri.host}$href';
                if (fullUrl.startsWith(baseUrlClean) && fullUrl != item.detailUrl) {
                  subPageUrls.add(fullUrl);
                }
              }
            }
          }
        }

        // Fetch sub-pages in parallel
        if (subPageUrls.isNotEmpty) {
          final subResults = await Future.wait(
            subPageUrls.map(
              (pUrl) => _dio.get<String>(
                pUrl,
                options: Options(responseType: ResponseType.plain),
              ).catchError((_) => Response<String>(requestOptions: RequestOptions(), statusCode: 500)),
            ),
          );

          for (final subRes in subResults) {
            if (subRes.statusCode == 200 && subRes.data != null) {
              final subDoc = html_parser.parse(subRes.data!);
              _extractImagesFromContent(subDoc, allImages);
            }
          }
        }

        // Extract extra tags & date from post detail
        final tagNodes = document.querySelectorAll('.post-tags a, .cat-links a, .entry-meta a');
        for (final t in tagNodes) {
          final tagText = t.text.trim();
          if (tagText.isNotEmpty && !tags.contains(tagText) && !tagText.startsWith('#')) {
            tags.add(tagText);
          }
        }

        final List<String> finalImageUrls = allImages.toList();
        final coverUrl = item.coverUrl ?? (finalImageUrls.isNotEmpty ? finalImageUrls.first : null);

        return item.copyWith(
          coverUrl: coverUrl,
          tags: tags,
          imageUrls: finalImageUrls,
          previewUrls: finalImageUrls,
          isDetailLoaded: true,
          rawData: {
            ...item.rawData,
            'pageCount': finalImageUrls.length,
          },
        );
      }
    } catch (e) {
      debugPrint('[PixibbApiService] Error fetching album detail: $e');
    }

    return item;
  }

  /// Strict content-only image extractor (ignores sidebar, footer, related posts)
  static void _extractImagesFromContent(dom.Document document, Set<String> images) {
    // Look inside .entry-content, .post-content, .album-content, article
    final contentElem = document.querySelector('.entry-content, .post-content, .album-content, article .content, article');
    if (contentElem == null) return;

    final imgElements = contentElem.querySelectorAll('img');
    for (final img in imgElements) {
      // Ignore widgets, sidebars, related posts
      var parent = img.parent;
      bool isPolluted = false;
      while (parent != null) {
        final clz = parent.className.toLowerCase();
        final id = parent.id.toLowerCase();
        if (clz.contains('related') ||
            clz.contains('sidebar') ||
            clz.contains('widget') ||
            clz.contains('footer') ||
            clz.contains('author') ||
            clz.contains('comment') ||
            id.contains('related') ||
            id.contains('sidebar')) {
          isPolluted = true;
          break;
        }
        parent = parent.parent;
      }
      if (isPolluted) continue;

      var src = img.attributes['data-orig-file'] ??
          img.attributes['data-large-file'] ??
          img.attributes['data-src'] ??
          img.attributes['data-lazy-src'] ??
          img.attributes['src'] ??
          '';

      if (src.isEmpty ||
          src.contains('logo.png') ||
          src.contains('avatar') ||
          src.contains('banner') ||
          src.contains('data:image')) {
        continue;
      }

      if (!src.startsWith('http')) {
        src = '$kBaseUrl$src';
      }

      images.add(src);
    }

    // Also look for direct anchor links to image files (.jpg, .png, .webp)
    final anchorElements = contentElem.querySelectorAll('a[href*=".jpg"], a[href*=".jpeg"], a[href*=".png"], a[href*=".webp"]');
    for (final a in anchorElements) {
      var href = a.attributes['href'] ?? '';
      if (href.startsWith('http') && !href.contains('logo') && !href.contains('avatar')) {
        images.add(href);
      }
    }
  }
}
