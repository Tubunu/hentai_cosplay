import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';
import '../network_client.dart';

class CosxplayPageData {
  final List<VideoItem> items;
  final int currentPage;
  final int totalPages;

  const CosxplayPageData({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });
}

class CosxplayTagItem {
  final String name;
  final String slug;
  final String path;

  const CosxplayTagItem({
    required this.name,
    required this.slug,
    required this.path,
  });
}

class CosxplayApiService {
  static const String kBaseUrl = 'https://cosxplay.com';

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
        'Referer': 'https://cosxplay.com/',
        'sec-ch-ua': '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'document',
        'sec-fetch-mode': 'navigate',
        'sec-fetch-site': 'none',
        'sec-fetch-user': '?1',
        'upgrade-insecure-requests': '1',
      },
    );
  }

  static String buildUrl({
    int page = 1,
    String? keyword,
    String? tagSlug,
    String? actorSlug,
  }) {
    final cleanKw = keyword?.trim();
    if (cleanKw != null && cleanKw.isNotEmpty) {
      if (page > 1) {
        return '$kBaseUrl/page/$page/?s=${Uri.encodeQueryComponent(cleanKw)}';
      }
      return '$kBaseUrl/?s=${Uri.encodeQueryComponent(cleanKw)}';
    }

    if (actorSlug != null && actorSlug.isNotEmpty) {
      final cleanActor = actorSlug.replaceAll(RegExp(r'^/|/$'), '');
      if (page > 1) {
        return '$kBaseUrl/$cleanActor/page/$page/';
      }
      return '$kBaseUrl/$cleanActor/';
    }

    if (tagSlug != null && tagSlug.isNotEmpty) {
      final cleanTag = tagSlug.replaceAll(RegExp(r'^/|/$'), '');
      if (page > 1) {
        return '$kBaseUrl/$cleanTag/page/$page/';
      }
      return '$kBaseUrl/$cleanTag/';
    }

    if (page > 1) {
      return '$kBaseUrl/page/$page/';
    }
    return '$kBaseUrl/';
  }

  /// Fetch list page data with automatic retry
  static Future<CosxplayPageData> fetchPageData({
    int page = 1,
    String? keyword,
    String? tagSlug,
    String? actorSlug,
  }) async {
    final dio = _dio;
    final url = buildUrl(page: page, keyword: keyword, tagSlug: tagSlug, actorSlug: actorSlug);
    debugPrint('[CosxplayApiService] Fetching list: $url');

    Response<String>? response;
    try {
      response = await dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
    } catch (e) {
      debugPrint('[CosxplayApiService] First attempt failed ($e), retrying once...');
      // Retry once with a fresh dio
      response = await dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
    }

    final html = response.data ?? '';
    return _parseListPageHtml(html, page);
  }

  static CosxplayPageData _parseListPageHtml(String html, int requestPage) {
    final doc = html_parser.parse(html);
    var cardEls = doc.querySelectorAll('div.video-block');
    if (cardEls.isEmpty) {
      cardEls = doc.querySelectorAll('article.post, div.post, .thumb-block');
    }
    final items = <VideoItem>[];

    for (final card in cardEls) {
      final aThumb = card.querySelector('a.thumb') ?? card.querySelector('a.infos') ?? card.querySelector('a');
      if (aThumb == null) continue;

      var href = aThumb.attributes['href']?.trim() ?? '';
      if (href.isEmpty) continue;
      if (!href.startsWith('http')) {
        href = '$kBaseUrl${href.startsWith('/') ? '' : '/'}$href';
      }

      final imgEl = aThumb.querySelector('img') ?? card.querySelector('img');
      var coverUrl = imgEl?.attributes['src']?.trim() ??
          imgEl?.attributes['data-src']?.trim() ??
          imgEl?.attributes['data-lazy-src']?.trim();
      if (coverUrl != null && !coverUrl.startsWith('http')) {
        coverUrl = '$kBaseUrl${coverUrl.startsWith('/') ? '' : '/'}$coverUrl';
      }

      final titleEl = card.querySelector('div.title') ?? card.querySelector('.title');
      var title = titleEl?.text.trim() ?? '';
      if (title.isEmpty) {
        title = aThumb.attributes['aria-label']?.trim() ?? imgEl?.attributes['alt']?.trim() ?? '';
      }
      if (title.isEmpty) {
        final uri = Uri.tryParse(href);
        title = uri?.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'CosXPlay Video') ?? 'CosXPlay Video';
      }

      final durationEl = card.querySelector('.duration') ?? card.querySelector('div.duration');
      final duration = durationEl?.text.trim() ?? '';

      final viewsEl = card.querySelector('.views-number') ?? card.querySelector('div.views-number');
      final views = viewsEl?.text.trim() ?? '';

      final trailerUrl = card.attributes['data-trailer-url']?.trim() ?? '';
      final postId = card.attributes['data-post-id']?.trim() ?? '';

      final slug = Uri.parse(href).path.replaceAll(RegExp(r'^/|/$'), '');

      items.add(
        VideoItem(
          title: title,
          slug: slug.isNotEmpty ? slug : postId,
          detailUrl: href,
          coverUrl: coverUrl,
          duration: duration,
          views: views,
          date: '',
          author: 'CosXPlay',
          rawData: {
            'duration': duration,
            'views': views,
            'trailer_url': trailerUrl,
            'post_id': postId,
            'source': 'cosxplay',
          },
        ),
      );
    }

    // Parse pagination
    int totalPages = requestPage;
    final pageLinks = doc.querySelectorAll('ul.pagination li a.page-link, ul.pagination li a, .pagination a');
    for (final pl in pageLinks) {
      final t = pl.text.replaceAll(',', '').replaceAll(' ', '').trim();
      final pNum = int.tryParse(t);
      if (pNum != null && pNum > totalPages) {
        totalPages = pNum;
      }
      final href = pl.attributes['href'] ?? '';
      final m = RegExp(r'/page/(\d+)/').firstMatch(href);
      if (m != null) {
        final numFromHref = int.tryParse(m.group(1)!);
        if (numFromHref != null && numFromHref > totalPages) {
          totalPages = numFromHref;
        }
      }
    }

    return CosxplayPageData(
      items: items,
      currentPage: requestPage,
      totalPages: totalPages < requestPage ? requestPage : totalPages,
    );
  }

  /// Resolve full video details including MP4 streaming URLs
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    final dio = _dio;
    debugPrint('[CosxplayApiService] Resolving detail: ${item.detailUrl}');

    final response = await dio.get<String>(
      item.detailUrl,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data ?? '';
    final doc = html_parser.parse(html);

    var videoHighUrl = '';
    var videoLowUrl = '';
    var posterUrl = item.coverUrl;

    final videoEl = doc.querySelector('video#video-placeholder, video');
    if (videoEl != null) {
      final p = videoEl.attributes['poster'] ?? videoEl.attributes['data-poster'];
      if (p != null && p.isNotEmpty) {
        posterUrl = p.startsWith('http') ? p : '$kBaseUrl$p';
      }

      final directSrc = videoEl.attributes['src'];
      if (directSrc != null && directSrc.isNotEmpty) {
        videoHighUrl = directSrc.startsWith('http') ? directSrc : '$kBaseUrl$directSrc';
      }

      for (final srcEl in videoEl.querySelectorAll('source')) {
        final sUrl = srcEl.attributes['src']?.trim() ?? '';
        final sTitle = srcEl.attributes['title']?.toLowerCase().trim() ?? '';
        if (sUrl.isEmpty) continue;
        final absUrl = sUrl.startsWith('http') ? sUrl : '$kBaseUrl$sUrl';

        if (sTitle == 'high' || videoHighUrl.isEmpty) {
          videoHighUrl = absUrl;
        } else if (sTitle == 'low') {
          videoLowUrl = absUrl;
        }
      }
    }

    final tags = <String>[];
    for (final a in doc.querySelectorAll('a[href*="/tag/"], a[href*="/actor/"], a[href*="/category/"]')) {
      final t = a.text.trim();
      if (t.isNotEmpty && !tags.contains(t)) {
        tags.add(t);
      }
    }

    final updatedRawData = Map<String, dynamic>.from(item.rawData);
    updatedRawData['video_high'] = videoHighUrl;
    updatedRawData['video_low'] = videoLowUrl.isNotEmpty ? videoLowUrl : videoHighUrl;
    updatedRawData['source'] = 'cosxplay';

    final effectiveVideoUrl = videoHighUrl.isNotEmpty
        ? videoHighUrl
        : (videoLowUrl.isNotEmpty ? videoLowUrl : item.detailUrl);

    return item.copyWith(
      coverUrl: posterUrl,
      videoUrl: effectiveVideoUrl,
      tags: tags.isNotEmpty ? tags : item.tags,
      isDetailLoaded: true,
      rawData: updatedRawData,
    );
  }
}
