import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../../models/album_item.dart';

enum MisskonCategory {
  latest('最新发布', '/'),
  top3('近3天热门', '/top3/'),
  top7('近7天热门', '/top7/'),
  top30('近30天热门', '/top30/'),
  top60('近60天热门', '/top60/'),
  topYear('年度热门', '/top-year/');

  final String label;
  final String path;
  const MisskonCategory(this.label, this.path);
}

class MisskonApiResponse {
  final List<AlbumItem> items;
  final int page;
  final int totalPages;
  final int total;

  MisskonApiResponse({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

class MisskonApiService {
  static const String kBaseUrl = 'https://misskon.com';

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
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
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

  /// Build request URL based on category, tag, keyword and page
  static String buildUrl({
    int page = 1,
    MisskonCategory category = MisskonCategory.latest,
    String? tag,
    String? keyword,
  }) {
    if (keyword != null && keyword.trim().isNotEmpty) {
      final encodedKw = Uri.encodeComponent(keyword.trim());
      if (page > 1) {
        return '$kBaseUrl/page/$page/?s=$encodedKw';
      }
      return '$kBaseUrl/?s=$encodedKw';
    }

    if (tag != null && tag.trim().isNotEmpty) {
      final cleanTag = tag.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');
      if (page > 1) {
        return '$kBaseUrl/tag/$cleanTag/page/$page/';
      }
      return '$kBaseUrl/tag/$cleanTag/';
    }

    final catPath = category.path;
    if (page > 1) {
      if (category == MisskonCategory.latest) {
        return '$kBaseUrl/page/$page/';
      }
      // e.g. /top3/page/2/
      return '$kBaseUrl${catPath}page/$page/';
    }
    return '$kBaseUrl$catPath';
  }

  /// Fetch page data from MissKon
  static Future<MisskonApiResponse?> fetchPageData({
    int page = 1,
    MisskonCategory category = MisskonCategory.latest,
    String? tag,
    String? keyword,
  }) async {
    try {
      final url = buildUrl(page: page, category: category, tag: tag, keyword: keyword);
      debugPrint('[MisskonApiService] Fetching: $url');

      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        return _parseListPageHtml(response.data!, page);
      }
    } catch (e) {
      debugPrint('[MisskonApiService] Error fetching page $page: $e');
    }
    return null;
  }

  /// Parse MissKon list page HTML
  static MisskonApiResponse _parseListPageHtml(String html, int requestedPage) {
    final document = html_parser.parse(html);
    final List<AlbumItem> items = [];

    // Articles are in <article class="item-list"> or <article class="post-listing ...">
    final articles = document.querySelectorAll('article');

    for (final article in articles) {
      try {
        final titleEl = article.querySelector('.post-box-title a') ?? article.querySelector('h2 a') ?? article.querySelector('h3 a');
        if (titleEl == null) continue;

        final title = titleEl.text.trim();
        final detailUrl = titleEl.attributes['href'] ?? '';
        if (detailUrl.isEmpty) continue;

        // Thumbnail cover image
        String? coverUrl;
        final imgEl = article.querySelector('.post-thumbnail img') ?? article.querySelector('img');
        if (imgEl != null) {
          coverUrl = imgEl.attributes['data-src'] ??
              imgEl.attributes['data-lazy-src'] ??
              imgEl.attributes['srcset']?.split(' ').first ??
              imgEl.attributes['src'];

          if (coverUrl != null && coverUrl.startsWith('data:image')) {
            coverUrl = imgEl.attributes['data-src'] ?? imgEl.attributes['data-srcset']?.split(' ').first;
          }
        }

        // Views count
        final viewsEl = article.querySelector('.post-views');
        final views = viewsEl?.text.replaceAll(RegExp(r'[^\d,]'), '').trim() ?? '';

        // Tags / Categories
        final List<String> tags = [];
        final tagLinks = article.querySelectorAll('.post-cats a, .post-meta a, a[rel="tag"]');
        for (final t in tagLinks) {
          final tText = t.text.trim();
          if (tText.isNotEmpty && !tags.contains(tText)) {
            tags.add(tText);
          }
        }

        // Slug from detailUrl
        String slug = '';
        final uri = Uri.tryParse(detailUrl);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          slug = uri.pathSegments.where((s) => s.isNotEmpty).last;
        }
        if (slug.isEmpty) {
          slug = 'mk_${title.hashCode.abs()}';
        }

        // Author from tags or title
        String author = tags.isNotEmpty ? tags.first : AlbumItem.inferAuthor(title, {});

        items.add(
          AlbumItem(
            title: title,
            slug: slug,
            detailUrl: detailUrl,
            coverUrl: coverUrl,
            date: views.isNotEmpty ? '$views 浏览' : '',
            author: author,
            tags: tags,
            sourceType: MediaSourceType.misskon,
            rawData: {
              'views': views,
              'detailUrl': detailUrl,
            },
          ),
        );
      } catch (e) {
        debugPrint('[MisskonApiService] Parse article error: $e');
      }
    }

    // Determine total pages
    int totalPages = requestedPage;
    final paginationEl = document.querySelector('.pagination') ?? document.querySelector('.page-nav') ?? document.querySelector('.pages');
    if (paginationEl != null) {
      // Look for "Page 1 of 120"
      final pagesText = paginationEl.text;
      final match = RegExp(r'of\s+(\d+)', caseSensitive: false).firstMatch(pagesText);
      if (match != null) {
        totalPages = int.tryParse(match.group(1)!) ?? requestedPage;
      } else {
        // Look for number in page links
        final pageLinks = paginationEl.querySelectorAll('a');
        for (final a in pageLinks) {
          final num = int.tryParse(a.text.trim());
          if (num != null && num > totalPages) {
            totalPages = num;
          }
        }
      }
    }

    if (items.isNotEmpty && totalPages <= requestedPage) {
      totalPages = requestedPage + 1; // Allow exploring further
    }

    return MisskonApiResponse(
      items: items,
      page: requestedPage,
      totalPages: totalPages.clamp(1, 9999),
      total: items.length * totalPages,
    );
  }

  /// Fetch full detail for a MissKon album (all pages & high resolution images)
  static Future<AlbumItem?> fetchAlbumDetail(AlbumItem item) async {
    if (item.detailUrl.isEmpty) return item;

    try {
      debugPrint('[MisskonApiService] Fetching detail: ${item.detailUrl}');
      final response = await _dio.get<String>(
        item.detailUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode != 200 || response.data == null) {
        return item;
      }

      final document = html_parser.parse(response.data!);
      final Set<String> allImages = {};
      final List<String> tags = List.from(item.tags);
      String unrarPassword = 'misskon.com';
      String fileSize = '';
      String modelName = '';
      String dimensions = '';

      // Parse info box
      final infoBox = document.querySelector('.box.info') ?? document.querySelector('.box-inner-block');
      if (infoBox != null) {
        final text = infoBox.text;
        final passMatch = RegExp(r'Password\s*(?:unrar)?:\s*([^\s<]+)', caseSensitive: false).firstMatch(text);
        if (passMatch != null) {
          unrarPassword = passMatch.group(1)!;
        }

        final sizeMatch = RegExp(r'File\s*size:\s*([^\n\r<]+)', caseSensitive: false).firstMatch(text);
        if (sizeMatch != null) {
          fileSize = sizeMatch.group(1)!.trim();
        }

        final modelMatch = RegExp(r'Model:\s*([^\n\r<]+)', caseSensitive: false).firstMatch(text);
        if (modelMatch != null) {
          modelName = modelMatch.group(1)!.trim();
        }

        final dimMatch = RegExp(r'Dimensions:\s*([^\n\r<]+)', caseSensitive: false).firstMatch(text);
        if (dimMatch != null) {
          dimensions = dimMatch.group(1)!.trim();
        }
      }

      // Parse tags in post
      final tagEls = document.querySelectorAll('.post-tag a, .entry a[rel="tag"]');
      for (final t in tagEls) {
        final tText = t.text.trim();
        if (tText.isNotEmpty && !tags.contains(tText)) {
          tags.add(tText);
        }
      }

      // Extract images from page 1
      _extractImagesFromDoc(document, allImages);

      // Check for multi-page in post: e.g. https://misskon.com/xxx/2/, /3/ ...
      final baseUrlClean = item.detailUrl.replaceAll(RegExp(r'/$'), '');
      final baseUri = Uri.parse(item.detailUrl);
      final Set<String> subPageUrls = {};

      final allPageLinks = document.querySelectorAll('a[href], .page-link a, .page-links a, .post-page-numbers a, a.post-page-numbers');
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

      // If page links not found in HTML, proactively check page 2 and 3
      if (subPageUrls.isEmpty) {
        for (int p = 2; p <= 4; p++) {
          subPageUrls.add('$baseUrlClean/$p/');
        }
      }

      // Concurrently fetch remaining pages if multi-page set
      if (subPageUrls.isNotEmpty) {
        debugPrint('[MisskonApiService] Fetching ${subPageUrls.length} subpages for ${item.title}');
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
                _extractImagesFromDoc(subDoc, subImgs);
                return subImgs;
              }
            } catch (_) {}
            return <String>{};
          }),
        );

        for (final set in results) {
          allImages.addAll(set);
        }
      }

      final imageList = allImages.toList();
      final coverUrl = item.coverUrl ?? (imageList.isNotEmpty ? imageList.first : null);
      final author = modelName.isNotEmpty ? modelName : (tags.isNotEmpty ? tags.first : item.author);

      final rawData = Map<String, dynamic>.from(item.rawData);
      rawData['unrarPassword'] = unrarPassword;
      rawData['fileSize'] = fileSize;
      rawData['dimensions'] = dimensions;
      rawData['modelName'] = modelName;

      return item.copyWith(
        author: author,
        coverUrl: coverUrl,
        tags: tags,
        imageUrls: imageList,
        previewUrls: imageList,
        isDetailLoaded: true,
        sourceType: MediaSourceType.misskon,
        rawData: rawData,
      );
    } catch (e) {
      debugPrint('[MisskonApiService] Error in fetchAlbumDetail: $e');
      return item;
    }
  }

  /// Helper to extract direct image URLs from an HTML document
  static void _extractImagesFromDoc(dom.Document document, Set<String> images) {
    final entry = document.querySelector('.entry') ?? document.querySelector('.post-inner') ?? document.body;
    if (entry == null) return;

    final imgEls = entry.querySelectorAll('img');
    for (final img in imgEls) {
      var src = img.attributes['data-src'] ??
          img.attributes['data-lazy-src'] ??
          img.attributes['src'];

      if (src != null && !src.startsWith('data:image') && _isValidImageUrl(src)) {
        if (src.startsWith('//')) {
          src = 'https:$src';
        }
        images.add(src);
      }
    }
  }

  static bool _isValidImageUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    if (lower.contains('avatar') ||
        lower.contains('logo') ||
        lower.contains('favicon') ||
        lower.contains('banner') ||
        lower.contains('icon')) {
      return false;
    }
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('.gif') ||
        lower.contains('/uploads/');
  }
}
