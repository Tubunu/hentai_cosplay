import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import '../../models/album_item.dart';

enum CosplayTeleCategory {
  latest('最新发布', '/'),
  cosplay('Cosplay 写真', '/category/cosplay/'),
  models('精选模特', '/category/models/'),
  telegram('Telegram 频道专区', '/category/telegram/');

  final String label;
  final String path;
  const CosplayTeleCategory(this.label, this.path);
}

class CosplayTeleApiResponse {
  final List<AlbumItem> items;
  final int page;
  final int totalPages;
  final int total;

  CosplayTeleApiResponse({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

class CosplayteleApiService {
  static const String kBaseUrl = 'https://cosplaytele.com';

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
    CosplayTeleCategory category = CosplayTeleCategory.latest,
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
  static Future<CosplayTeleApiResponse?> fetchPageData({
    int page = 1,
    CosplayTeleCategory category = CosplayTeleCategory.latest,
    String? keyword,
  }) async {
    try {
      final url = buildUrl(page: page, category: category, keyword: keyword);
      debugPrint('[CosplayteleApiService] Fetching URL: $url');

      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        return _parseListPageHtml(response.data!, page);
      }
    } catch (e) {
      debugPrint('[CosplayteleApiService] Error fetching page $page: $e');
    }
    return null;
  }

  /// Parse list page HTML with strict deduplication
  static CosplayTeleApiResponse _parseListPageHtml(String html, int requestedPage) {
    final document = html_parser.parse(html);
    final List<AlbumItem> items = [];
    final seenUrls = <String>{};
    final seenSlugs = <String>{};

    final postElements = document.querySelectorAll('article, .post-item, .post, .entry, .grid-post, [class*="post-"]');

    for (final elem in postElements) {
      try {
        final linkElem = elem.querySelector('h2 a, h3 a, .entry-title a, .post-title a, a.thumb, a');
        if (linkElem == null) continue;

        var href = linkElem.attributes['href'] ?? '';
        if (href.isEmpty || href == '#' || href.contains('wp-json') || href.contains('/feed/')) continue;
        if (!href.startsWith('http')) {
          href = '$kBaseUrl$href';
        }

        final slug = href.split('/').where((s) => s.isNotEmpty).last;
        if (slug.isEmpty || !seenUrls.add(href) || !seenSlugs.add(slug)) continue;

        var title = linkElem.attributes['title'] ??
            elem.querySelector('.entry-title, h2, h3, .post-title, .title')?.text.trim() ??
            linkElem.text.trim();
        if (title.isEmpty || title.length < 2) continue;

        final imgElem = elem.querySelector('img');
        var coverUrl = imgElem?.attributes['data-src'] ??
            imgElem?.attributes['data-lazy-src'] ??
            imgElem?.attributes['data-orig-file'] ??
            imgElem?.attributes['src'] ??
            '';
        if (coverUrl.contains('logo.png') || coverUrl.contains('avatar') || coverUrl.contains('banner')) continue;
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = '$kBaseUrl$coverUrl';
        }

        if (coverUrl.isEmpty || !coverUrl.startsWith('http')) continue;

        final authorElem = elem.querySelector('.author, .byline, .post-author');
        final author = authorElem?.text.trim().replaceAll(RegExp(r'^by\s+', caseSensitive: false), '') ?? 'CosplayTele';

        final dateElem = elem.querySelector('.published, time, .post-date, .entry-date');
        final date = dateElem?.text.trim() ?? '今日';

        final tagElements = elem.querySelectorAll('.cat-links a, .tags-links a, .post-tags a');
        final tags = tagElements.map((t) => t.text.trim()).where((t) => t.isNotEmpty).toList();
        if (tags.isEmpty) tags.add('CosplayTele');

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
            sourceType: MediaSourceType.cosplaytele,
            rawData: {'detailUrl': href},
          ),
        );
      } catch (e) {
        debugPrint('[CosplayteleApiService] Error parsing card: $e');
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

    return CosplayTeleApiResponse(
      items: items,
      page: requestedPage,
      totalPages: totalPages,
      total: items.length * totalPages,
    );
  }

  /// Fetch full album detail & all original images without related post pollution
  static Future<AlbumItem?> fetchAlbumDetail(AlbumItem item) async {
    try {
      debugPrint('[CosplayteleApiService] Fetching detail: ${item.detailUrl}');
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
            final resolved = baseUri.resolve(href).toString();
            final resolvedClean = resolved.replaceAll(RegExp(r'/$'), '');
            if (resolvedClean.startsWith(baseUrlClean) && resolvedClean != baseUrlClean) {
              final suffix = resolvedClean.substring(baseUrlClean.length);
              if (RegExp(r'^/\d+$').hasMatch(suffix)) {
                subPageUrls.add('$resolvedClean/');
              }
            }
          }
        }

        if (subPageUrls.isNotEmpty) {
          debugPrint('[CosplayteleApiService] Fetching ${subPageUrls.length} subpages for ${item.title}');
          final results = await Future.wait(
            subPageUrls.map((subUrl) async {
              try {
                final subRes = await _dio.get<String>(
                  subUrl,
                  options: Options(responseType: ResponseType.plain),
                );
                if (subRes.statusCode == 200 && subRes.data != null) {
                  final subDoc = html_parser.parse(subRes.data!);
                  final Set<String> subImgs = {};
                  _extractImagesFromContent(subDoc, subImgs);
                  return subImgs;
                }
              } catch (e) {
                debugPrint('[CosplayteleApiService] Error fetching subpage $subUrl: $e');
              }
              return <String>{};
            }),
          );

          for (final set in results) {
            allImages.addAll(set);
          }
        }

        final tagElements = document.querySelectorAll('.tags-links a, .post-tags a, .tagcloud a');
        for (final t in tagElements) {
          final tagText = t.text.trim();
          if (tagText.isNotEmpty && !tags.contains(tagText)) {
            tags.add(tagText);
          }
        }

        final imageList = allImages.toList();
        return item.copyWith(
          imageUrls: imageList,
          previewUrls: imageList,
          tags: tags,
          isDetailLoaded: true,
        );
      }
    } catch (e) {
      debugPrint('[CosplayteleApiService] Error fetching detail: $e');
    }

    return item;
  }

  static void _extractImagesFromContent(dom.Document document, Set<String> images) {
    // Remove all related posts and widgets before extracting
    final junkElements = document.querySelectorAll('.jp-relatedposts, .related-posts, .yarpp-related, .sidebar, .widget, footer, .comments, .sharedaddy');
    for (final junk in junkElements) {
      junk.remove();
    }

    final content = document.querySelector('.entry-content') ?? document.querySelector('.post-content') ?? document.querySelector('article') ?? document.body;
    if (content == null) return;

    final imgElements = content.querySelectorAll('img');
    for (final img in imgElements) {
      var src = img.attributes['data-orig-file'] ??
          img.attributes['data-full-url'] ??
          img.attributes['data-src'] ??
          img.attributes['data-lazy-src'] ??
          img.attributes['src'] ??
          '';

      if (src.isEmpty || src.contains('logo.png') || src.contains('avatar') || src.contains('.svg') || src.startsWith('data:')) {
        continue;
      }

      if (src.startsWith('//')) {
        src = 'https:$src';
      } else if (!src.startsWith('http')) {
        src = '$kBaseUrl$src';
      }

      src = src.replaceAll(RegExp(r'-\d+x\d+\.(jpg|jpeg|png|webp)'), '.\$1');
      images.add(src);
    }
  }
}
