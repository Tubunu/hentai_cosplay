import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';
import '../network_client.dart';

enum HohojCategory {
  all('全部', 'all'),
  censored('有码', 'censored'),
  chinese('中文字幕', 'chinese'),
  uncensored('无码', 'uncensored'),
  europe('欧美', 'europe');

  final String label;
  final String value;
  const HohojCategory(this.label, this.value);
}

enum HohojOrder {
  popular('最热门', 'popular'),
  latest('最新', 'latest'),
  views('最多观看', 'views'),
  likes('最多赞', 'likes');

  final String label;
  final String value;
  const HohojOrder(this.label, this.value);
}

class HohojPageData {
  final List<VideoItem> items;
  final int currentPage;
  final int totalPages;

  const HohojPageData({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });
}

class HohojApiService {
  static const String kBaseUrl = 'https://hohoj.tv';
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
      allowBadCertificates: true,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh-HK,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        'Referer': 'https://hohoj.tv/',
        'sec-ch-ua':
            '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'document',
        'sec-fetch-mode': 'navigate',
        'sec-fetch-site': 'same-origin',
        'upgrade-insecure-requests': '1',
      },
    );
  }

  /// Builds catalog or search URL for HoHoJ
  static String buildUrl({
    int page = 1,
    HohojCategory category = HohojCategory.all,
    HohojOrder order = HohojOrder.popular,
    String? keyword,
  }) {
    if (keyword != null && keyword.trim().isNotEmpty) {
      final encoded = Uri.encodeComponent(keyword.trim());
      return '$kBaseUrl/search?text=$encoded&p=$page';
    }

    return '$kBaseUrl/search?type=${category.value}&order=${order.value}&p=$page';
  }

  /// Fetches a page of video items
  static Future<HohojPageData> fetchVideos({
    int page = 1,
    HohojCategory category = HohojCategory.all,
    HohojOrder order = HohojOrder.popular,
    String? keyword,
  }) async {
    final dio = _dio;
    final url = buildUrl(
      page: page,
      category: category,
      order: order,
      keyword: keyword,
    );
    debugPrint('[HohojApiService] Fetching: $url');

    try {
      final response = await dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );

      final html = response.data ?? '';
      return _parseListPageHtml(html, page);
    } catch (e) {
      debugPrint('[HohojApiService] Error fetching $url: $e');
      rethrow;
    }
  }

  @visibleForTesting
  static HohojPageData parseListPageHtmlForTest(String html, int requestPage) =>
      _parseListPageHtml(html, requestPage);

  static HohojPageData _parseListPageHtml(String html, int requestPage) {
    final doc = html_parser.parse(html);
    final cardEls = doc.querySelectorAll('.video-item');
    final items = <VideoItem>[];
    final seenSlugs = <String>{};

    for (final el in cardEls) {
      final aLink = el.querySelector('a[href*="video?id="]');
      if (aLink == null) continue;

      var href = aLink.attributes['href']?.trim() ?? '';
      if (href.isEmpty) continue;
      if (!href.startsWith('http')) {
        href = '$kBaseUrl${href.startsWith('/') ? href : '/$href'}';
      }

      final uri = Uri.tryParse(href);
      final idParam = uri?.queryParameters['id'] ?? '';
      final slug = idParam.isNotEmpty
          ? idParam
          : (RegExp(r'id=(\d+)').firstMatch(href)?.group(1) ?? href);
      if (slug.isEmpty || seenSlugs.contains(slug)) continue;
      seenSlugs.add(slug);

      // Title
      final titleEl = el.querySelector('.video-item-title');
      var title = titleEl?.text.trim() ?? '';
      if (title.isEmpty) {
        final imgEl = el.querySelector('img');
        title = imgEl?.attributes['alt']?.trim() ?? '';
      }
      if (title.isEmpty) {
        title = 'HoHoJ-$slug';
      }

      // Cover image
      final imgEl = el.querySelector('img.img-placeholder') ?? el.querySelector('img');
      var coverUrl = imgEl?.attributes['src']?.trim() ??
          imgEl?.attributes['data-src']?.trim() ??
          '';
      if (coverUrl.startsWith('//')) {
        coverUrl = 'https:$coverUrl';
      } else if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
        coverUrl = '$kBaseUrl$coverUrl';
      }

      // Rating: Views & Likes
      final ratingSpans = el.querySelectorAll('.video-item-rating span');
      var views = '';
      var likes = '';
      if (ratingSpans.isNotEmpty) {
        views = ratingSpans[0].text.trim();
      }
      if (ratingSpans.length > 1) {
        likes = ratingSpans[1].text.trim();
      }

      // Badge (e.g. 中文字幕, 无码)
      final badgeEl = el.querySelector('.video-item-badge');
      final badge = badgeEl?.text.trim() ?? '';

      final tags = <String>[];
      if (badge.isNotEmpty) {
        tags.add(badge);
      }

      items.add(
        VideoItem(
          title: title,
          slug: slug,
          detailUrl: href,
          coverUrl: coverUrl,
          duration: '',
          views: views,
          date: '',
          author: 'HoHoJ',
          tags: tags,
          rawData: {
            'slug': slug,
            'source': 'hohoj',
            'views': views,
            'likes': likes,
            'badge': badge,
            'embed_url': '$kBaseUrl/embed?id=$slug',
          },
        ),
      );
    }

    // Pagination: HoHoJ loads via URL param ?p=1, ?p=2...
    // If we received a healthy amount of items (>= 16), assume there is a next page.
    int totalPages = requestPage;
    if (items.length >= 16) {
      totalPages = requestPage + 1;
    }

    return HohojPageData(
      items: items,
      currentPage: requestPage,
      totalPages: totalPages,
    );
  }

  /// Resolves detailed video metadata and extracts HLS m3u8 stream
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    final dio = _dio;
    debugPrint('[HohojApiService] Resolving detail: ${item.detailUrl}');

    final response = await dio.get<String>(
      item.detailUrl,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data ?? '';
    final doc = html_parser.parse(html);

    // Title
    final titleEl = doc.querySelector('h5.mt-3') ?? doc.querySelector('h1');
    var fullTitle = titleEl?.text.trim() ?? '';
    if (fullTitle.isEmpty) {
      final metaTitle = doc.querySelector('meta[property="og:title"]');
      fullTitle = metaTitle?.attributes['content']?.trim() ?? item.title;
    }

    // Cover / Poster
    final posterMeta = doc.querySelector('meta[property="og:image"]');
    var posterUrl = posterMeta?.attributes['content']?.trim() ?? item.coverUrl;
    if (posterUrl != null && posterUrl.startsWith('//')) {
      posterUrl = 'https:$posterUrl';
    }

    // Date
    var date = item.date;
    final dateEl = doc.querySelector('.info .ms-auto span');
    if (dateEl != null && dateEl.text.trim().isNotEmpty) {
      date = dateEl.text.trim();
    }

    // Views & Likes
    final viewsEl = doc.querySelector('.info i.fa-eye + span');
    final views = viewsEl?.text.trim() ?? item.views;
    final likesEl = doc.querySelector('#likes');
    final likes = likesEl?.text.trim() ?? (item.rawData['likes'] as String? ?? '');

    // Tags & Actresses
    final tags = List<String>.from(item.tags);
    final actresses = <String>[];

    for (final modelEl in doc.querySelectorAll('.model .model-name')) {
      final name = modelEl.text.trim();
      if (name.isNotEmpty && !actresses.contains(name)) {
        actresses.add(name);
        if (!tags.contains(name)) tags.insert(0, name);
      }
    }

    for (final ctgEl in doc.querySelectorAll('.ctg a')) {
      final ctg = ctgEl.text.trim();
      if (ctg.isNotEmpty && !tags.contains(ctg)) {
        tags.add(ctg);
      }
    }

    final tagMeta = doc.querySelector('meta[property="video:tag"]');
    final metaTags = tagMeta?.attributes['content']?.split(',') ?? [];
    for (final t in metaTags) {
      final trimmed = t.trim();
      if (trimmed.isNotEmpty && !tags.contains(trimmed) && tags.length < 20) {
        tags.add(trimmed);
      }
    }

    // Direct HLS m3u8 Extraction from Embed Page
    var videoUrl = '';
    final embedUrl = '$kBaseUrl/embed?id=${item.slug}';

    try {
      debugPrint('[HohojApiService] Fetching embed stream: $embedUrl');
      final embedResponse = await dio.get<String>(
        embedUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Referer': item.detailUrl},
        ),
      );

      final embedHtml = embedResponse.data ?? '';

      // Pattern 1: var videoSrc = "https://...";
      final varSrcMatch = RegExp(r'''videoSrc\s*=\s*["']([^"']+\.m3u8[^"']*)["']''').firstMatch(embedHtml);
      if (varSrcMatch != null) {
        videoUrl = varSrcMatch.group(1) ?? '';
      }

      // Pattern 2: <video id="my-video" src="...">
      if (videoUrl.isEmpty) {
        final videoTagMatch = RegExp(r'''<video[^>]+src=["']([^"']+\.m3u8[^"']*)["']''').firstMatch(embedHtml);
        if (videoTagMatch != null) {
          videoUrl = videoTagMatch.group(1) ?? '';
        }
      }

      // Pattern 3: Any m3u8 URL in embed HTML
      if (videoUrl.isEmpty) {
        final anyM3u8Match = RegExp(r'''https?://[^\s"'<>]+\.m3u8''').firstMatch(embedHtml);
        if (anyM3u8Match != null) {
          videoUrl = anyM3u8Match.group(0) ?? '';
        }
      }
    } catch (e) {
      debugPrint('[HohojApiService] Failed to extract embed m3u8: $e');
    }

    if (videoUrl.isEmpty) {
      videoUrl = embedUrl;
    }

    final updatedRawData = Map<String, dynamic>.from(item.rawData);
    updatedRawData['source'] = 'hohoj';
    updatedRawData['slug'] = item.slug;
    updatedRawData['views'] = views;
    updatedRawData['likes'] = likes;
    updatedRawData['embed_url'] = embedUrl;
    updatedRawData['direct_m3u8'] = videoUrl.contains('.m3u8') ? videoUrl : '';
    if (actresses.isNotEmpty) updatedRawData['actresses'] = actresses;

    return item.copyWith(
      title: fullTitle.isNotEmpty ? fullTitle : item.title,
      coverUrl: posterUrl,
      videoUrl: videoUrl,
      views: views,
      date: date,
      tags: tags,
      author: actresses.isNotEmpty ? actresses.join(', ') : 'HoHoJ',
      isDetailLoaded: true,
      rawData: updatedRawData,
    );
  }
}
