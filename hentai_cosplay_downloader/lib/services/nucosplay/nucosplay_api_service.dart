import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/album_item.dart';

enum NuCosplayCategory {
  latest('最新发布', '/'),
  cosplay('Cosplay 套图', '/category/cosplay/'),
  asian('亚洲 Coser', '/category/asian/'),
  western('欧美 Coser', '/category/western/');

  final String label;
  final String path;
  const NuCosplayCategory(this.label, this.path);
}

class NuCosplayApiResponse {
  final List<AlbumItem> items;
  final int page;
  final int totalPages;
  final int total;

  NuCosplayApiResponse({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

class NucosplayApiService {
  static const String kBaseUrl = 'https://nucosplay.com';

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
    NuCosplayCategory category = NuCosplayCategory.latest,
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
  static Future<NuCosplayApiResponse?> fetchPageData({
    int page = 1,
    NuCosplayCategory category = NuCosplayCategory.latest,
    String? keyword,
  }) async {
    try {
      final url = buildUrl(page: page, category: category, keyword: keyword);
      debugPrint('[NucosplayApiService] Fetching URL: $url');

      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        return _parseListPageHtml(response.data!, page);
      }
    } catch (e) {
      debugPrint('[NucosplayApiService] Error fetching page $page: $e');
    }
    return null;
  }

  /// Parse list page HTML
  static NuCosplayApiResponse _parseListPageHtml(String html, int requestedPage) {
    final document = html_parser.parse(html);
    final List<AlbumItem> items = [];
    final seenUrls = <String>{};
    final seenSlugs = <String>{};

    final postElements = document.querySelectorAll('article, .post-item, .post, .entry, .grid-item, .item, .thumb, a');

    for (final elem in postElements) {
      try {
        final linkElem = elem.localName == 'a' ? elem : elem.querySelector('h2 a, h3 a, .entry-title a, .post-title a, a.thumb, a');
        if (linkElem == null) continue;

        var href = linkElem.attributes['href'] ?? '';
        if (href.isEmpty || href == '#' || href.contains('wp-json') || href.contains('/feed/') || href.contains('asacp.org')) continue;
        if (!href.startsWith('http')) {
          href = '$kBaseUrl$href';
        }

        final slug = href.split('/').where((s) => s.isNotEmpty).last.replaceAll('.html', '');
        if (slug.isEmpty || !seenUrls.add(href) || !seenSlugs.add(slug)) continue;

        var title = linkElem.attributes['title'] ??
            elem.querySelector('.entry-title, h2, h3, .post-title, .title')?.text.trim() ??
            linkElem.text.trim();
        if (title.isEmpty) {
          title = slug.split('-').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' ').trim();
        }
        if (title.isEmpty) {
          title = 'NuCosplay #$slug';
        }

        final imgElem = elem.querySelector('img');
        var coverUrl = imgElem?.attributes['data-src'] ??
            imgElem?.attributes['data-lazy-src'] ??
            imgElem?.attributes['data-orig-file'] ??
            imgElem?.attributes['src'] ??
            '';
        if (coverUrl.contains('logo.png') || coverUrl.contains('avatar')) continue;
        if (coverUrl.startsWith('//')) {
          coverUrl = 'https:$coverUrl';
        } else if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = '$kBaseUrl$coverUrl';
        }

        if (coverUrl.isEmpty || !coverUrl.startsWith('http')) continue;

        final authorElem = elem.querySelector('.author, .byline, .post-author');
        final author = authorElem?.text.trim().replaceAll(RegExp(r'^by\s+', caseSensitive: false), '') ?? 'NuCosplay';

        final dateElem = elem.querySelector('.published, time, .post-date, .entry-date');
        final date = dateElem?.text.trim() ?? '今日';

        final tagElements = elem.querySelectorAll('.cat-links a, .tags-links a, .post-tags a');
        final tags = tagElements.map((t) => t.text.trim()).where((t) => t.isNotEmpty).toList();
        if (tags.isEmpty) tags.add('NuCosplay');

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
            sourceType: MediaSourceType.nucosplay,
            rawData: {'detailUrl': href},
          ),
        );
      } catch (e) {
        debugPrint('[NucosplayApiService] Error parsing card: $e');
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

    return NuCosplayApiResponse(
      items: items,
      page: requestedPage,
      totalPages: totalPages,
      total: items.length * totalPages,
    );
  }

  /// Fetch full album detail & all original images
  static Future<AlbumItem?> fetchAlbumDetail(AlbumItem item) async {
    try {
      debugPrint('[NucosplayApiService] Fetching detail: ${item.detailUrl}');
      final response = await _dio.get<String>(
        item.detailUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data!;
        final document = html_parser.parse(html);

        final List<String> imageUrls = [];
        final List<String> previewUrls = [];

        final imgElements = document.querySelectorAll('.entry-content img, .post-content img, .gallery img, .wp-block-image img, figure img');

        for (final img in imgElements) {
          var src = img.attributes['data-orig-file'] ??
              img.attributes['data-full-url'] ??
              img.attributes['data-src'] ??
              img.attributes['data-lazy-src'] ??
              img.attributes['src'] ??
              '';

          if (src.isEmpty || src.contains('logo.png') || src.contains('avatar') || src.contains('.svg')) {
            continue;
          }

          if (!src.startsWith('http')) {
            src = '$kBaseUrl$src';
          }

          src = src.replaceAll(RegExp(r'-\d+x\d+\.(jpg|jpeg|png|webp)'), '.\$1');

          if (!imageUrls.contains(src)) {
            imageUrls.add(src);
            previewUrls.add(src);
          }
        }

        final tagElements = document.querySelectorAll('.tags-links a, .post-tags a, .tagcloud a');
        final tags = List<String>.from(item.tags);
        for (final t in tagElements) {
          final tagText = t.text.trim();
          if (tagText.isNotEmpty && !tags.contains(tagText)) {
            tags.add(tagText);
          }
        }

        return item.copyWith(
          imageUrls: imageUrls,
          previewUrls: previewUrls,
          tags: tags,
          isDetailLoaded: true,
        );
      }
    } catch (e) {
      debugPrint('[NucosplayApiService] Error fetching detail: $e');
    }

    return item;
  }
}
