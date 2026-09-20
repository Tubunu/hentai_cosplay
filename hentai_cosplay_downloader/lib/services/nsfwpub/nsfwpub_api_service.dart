import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/album_item.dart';
import '../network_client.dart';

enum NsfwpubCategory {
  all('全部', '/'),
  cosplay('Cosplay', '/category/cosplay'),
  asian('亚洲', '/category/asian'),
  thots('网红', '/category/thots'),
  tiktok('TikTok', '/category/tiktok'),
  art('艺术', '/category/art'),
  celebs('名人', '/category/celebs'),
  erotic('性感', '/category/erotic'),
  top('热门榜', '/top');

  final String label;
  final String path;
  const NsfwpubCategory(this.label, this.path);
}

class NsfwpubPageData {
  final List<AlbumItem> items;
  final int currentPage;
  final int totalPages;

  const NsfwpubPageData({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });
}

class NsfwpubApiService {
  static const String kBaseUrl = 'https://nsfwpub.com';
  static String? _configuredProxy;
  static Dio _dio = _createDio();

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
    try {
      _dio.close(force: true);
    } catch (_) {}
    _dio = _createDio();
  }

  static Dio _createDio() {
    return NetworkClient.createDio(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 45),
      specificProxy: _configuredProxy,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Referer': 'https://nsfwpub.com/',
        'sec-ch-ua': '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'document',
        'sec-fetch-mode': 'navigate',
        'sec-fetch-site': 'same-origin',
        'upgrade-insecure-requests': '1',
      },
    );
  }

  static String buildUrl({
    int page = 1,
    NsfwpubCategory category = NsfwpubCategory.all,
    String? keyword,
  }) {
    final cleanKw = keyword?.trim();
    if (cleanKw != null && cleanKw.isNotEmpty) {
      if (page > 1) {
        return '$kBaseUrl/search/${Uri.encodeComponent(cleanKw)}?page=$page';
      }
      return '$kBaseUrl/search/${Uri.encodeComponent(cleanKw)}';
    }

    final catPath = category.path.replaceAll(RegExp(r'^/|/$'), '');
    if (catPath.isEmpty) {
      if (page > 1) {
        return '$kBaseUrl/?page=$page';
      }
      return '$kBaseUrl/';
    }

    if (page > 1) {
      return '$kBaseUrl/$catPath?page=$page';
    }
    return '$kBaseUrl/$catPath';
  }

  /// Fetch list page data with automatic retry
  static Future<NsfwpubPageData> fetchPageData({
    int page = 1,
    NsfwpubCategory category = NsfwpubCategory.all,
    String? keyword,
  }) async {
    final dio = _dio;
    final url = buildUrl(page: page, category: category, keyword: keyword);
    debugPrint('[NsfwpubApiService] Fetching list: $url');

    Response<String>? response;
    try {
      response = await dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
    } catch (e) {
      debugPrint('[NsfwpubApiService] First attempt failed ($e), retrying once...');
      response = await dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
    }

    final html = response.data ?? '';
    return _parseListPageHtml(html, page);
  }

  static NsfwpubPageData _parseListPageHtml(String html, int requestPage) {
    final doc = html_parser.parse(html);
    final cardEls = doc.querySelectorAll('.grid-item, div.grid-item');
    final items = <AlbumItem>[];
    final seenSlugs = <String>{};

    for (final el in cardEls) {
      final aPic = el.querySelector('a[href*="/pics/"]');
      if (aPic == null) continue;

      var href = aPic.attributes['href']?.trim() ?? '';
      if (href.isEmpty) continue;
      if (!href.startsWith('http')) {
        href = '$kBaseUrl${href.startsWith('/') ? '' : '/'}$href';
      }

      final imgEl = el.querySelector('img');
      var coverUrl = imgEl?.attributes['src']?.trim() ??
          imgEl?.attributes['data-src']?.trim() ??
          imgEl?.attributes['data-lazy-src']?.trim();
      if (coverUrl != null && !coverUrl.startsWith('http')) {
        coverUrl = '$kBaseUrl${coverUrl.startsWith('/') ? '' : '/'}$coverUrl';
      }

      // Title
      var title = aPic.text.trim();
      if (title.isEmpty) {
        title = imgEl?.attributes['alt']?.trim() ?? '';
      }
      if (title.isEmpty) {
        title = 'NSFWPub 图集';
      }

      // Model / Author badge
      final modelBadge = el.querySelector('a[href*="/model/"]');
      final author = modelBadge?.text.trim() ?? 'NSFWPub';

      // Cosplay / Character tag badge
      final cosplayBadge = el.querySelector('a[href*="/cosplay/"]');
      final character = cosplayBadge?.text.trim() ?? '';

      // Photo count
      final cameraBadge = el.querySelector('span.badge i.bi-camera-fill')?.parent;
      final countText = cameraBadge?.text.trim() ?? '';
      final photoCount = int.tryParse(countText.replaceAll(RegExp(r'\D'), '')) ?? 0;

      // Extract slug from /pics/103248
      final slug = Uri.parse(href).pathSegments.isNotEmpty
          ? Uri.parse(href).pathSegments.last
          : href.hashCode.toString();

      if (seenSlugs.contains(slug)) continue;
      seenSlugs.add(slug);

      final tags = <String>[];
      if (author.isNotEmpty && author != 'NSFWPub') tags.add(author);
      if (character.isNotEmpty) tags.add(character);

      items.add(
        AlbumItem(
          title: title,
          slug: slug,
          detailUrl: href,
          coverUrl: coverUrl,
          date: '',
          author: author,
          tags: tags,
          sourceType: MediaSourceType.nsfwpub,
          rawData: {
            'photo_count': photoCount,
            'model': author,
            'cosplay': character,
            'source': 'nsfwpub',
          },
        ),
      );
    }

    // Parse pagination (e.g. href="...page=2")
    int totalPages = requestPage;
    final pageEls = doc.querySelectorAll('a[href*="page="]');
    for (final pe in pageEls) {
      final href = pe.attributes['href'] ?? '';
      final m = RegExp(r'[?&]page=(\d+)').firstMatch(href);
      if (m != null) {
        final pNum = int.tryParse(m.group(1)!);
        if (pNum != null && pNum > totalPages) {
          totalPages = pNum;
        }
      }
    }

    if (totalPages <= requestPage && items.length >= 10) {
      totalPages = requestPage + 1;
    }

    return NsfwpubPageData(
      items: items,
      currentPage: requestPage,
      totalPages: totalPages,
    );
  }

  /// Fetch full album images from detail page (/pics/{id})
  static Future<AlbumItem> fetchAlbumDetail(AlbumItem item) async {
    final dio = _dio;
    debugPrint('[NsfwpubApiService] Fetching detail: ${item.detailUrl}');

    final response = await dio.get<String>(
      item.detailUrl,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data ?? '';
    final doc = html_parser.parse(html);

    final imageUrls = <String>[];
    final previewUrls = <String>[];

    for (final img in doc.querySelectorAll('img')) {
      var src = img.attributes['src']?.trim() ?? img.attributes['data-src']?.trim() ?? '';
      if (src.isEmpty) continue;
      if (src.contains('/logo.png') || src.contains('/assets/') || src.contains('blank.gif')) continue;

      if (!src.startsWith('http')) {
        src = '$kBaseUrl${src.startsWith('/') ? '' : '/'}$src';
      }

      // Filter album images: /images/a/ or /images/albums/
      if (src.contains('/images/a/') || src.contains('/images/albums/') || src.contains('.webp') || src.contains('.jpg')) {
        if (!imageUrls.contains(src)) {
          imageUrls.add(src);
          previewUrls.add(src);
        }
      }
    }

    // Parse tags from detail page
    final tags = List<String>.from(item.tags);
    for (final a in doc.querySelectorAll('a[href*="/model/"], a[href*="/cosplay/"], a[href*="/category/"]')) {
      final t = a.text.trim();
      if (t.isNotEmpty && !tags.contains(t) && !['Categories', 'Videos', 'Top', 'Random'].contains(t)) {
        tags.add(t);
      }
    }

    final updatedRawData = Map<String, dynamic>.from(item.rawData);
    updatedRawData['source'] = 'nsfwpub';
    updatedRawData['total_photos'] = imageUrls.length;

    return item.copyWith(
      imageUrls: imageUrls,
      previewUrls: previewUrls,
      tags: tags,
      isDetailLoaded: true,
      rawData: updatedRawData,
    );
  }
}
