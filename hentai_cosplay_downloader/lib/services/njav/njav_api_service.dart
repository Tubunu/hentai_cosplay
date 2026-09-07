import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';
import '../network_client.dart';

enum NjavCategory {
  recentUpdate('最新更新', '/recent-update/'),
  newRelease('最新发布', '/new-release/'),
  censored('日本有码', '/censored/'),
  uncensored('日本无码', '/uncensored/'),
  uncensoredLeaked('无码破解', '/uncensored-leaked/'),
  amateur('素人专区', '/amateur/'),
  chineseAv('国产自制', '/chinese-av/'),
  home('精选推荐', '/');

  final String label;
  final String path;
  const NjavCategory(this.label, this.path);
}

class NjavPageData {
  final List<VideoItem> items;
  final int currentPage;
  final int totalPages;

  const NjavPageData({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });
}

class NjavApiService {
  static const String kBaseUrl = 'https://www.njav.com';
  static String? _configuredProxy;

  static void setProxy(String? proxy) {
    _configuredProxy = proxy;
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
        'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        'Referer': 'https://www.njav.com/zh/',
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

  /// Builds the catalog or search URL for NJAV
  static String buildUrl({
    int page = 1,
    NjavCategory category = NjavCategory.recentUpdate,
    String? keyword,
  }) {
    if (keyword != null && keyword.trim().isNotEmpty) {
      final encoded = Uri.encodeComponent(keyword.trim());
      if (page <= 1) {
        return '$kBaseUrl/zh/search?keyword=$encoded';
      }
      return '$kBaseUrl/zh/search?keyword=$encoded&page=$page';
    }

    final catPath = category.path.startsWith('/') ? category.path : '/${category.path}';
    final basePath = '$kBaseUrl/zh$catPath';
    if (page <= 1) {
      return basePath;
    }
    return '$basePath?page=$page';
  }

  /// Fetches a page of video items
  static Future<NjavPageData> fetchVideos({
    int page = 1,
    NjavCategory category = NjavCategory.recentUpdate,
    String? keyword,
  }) async {
    final dio = _createDio();
    final url = buildUrl(page: page, category: category, keyword: keyword);
    debugPrint('[NjavApiService] Fetching list: $url');

    final response = await dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data ?? '';
    return _parseListPageHtml(html, page);
  }

  @visibleForTesting
  static NjavPageData parseListPageHtmlForTest(String html, int requestPage) =>
      _parseListPageHtml(html, requestPage);

  static NjavPageData _parseListPageHtml(String html, int requestPage) {
    final doc = html_parser.parse(html);
    final cardEls = doc.querySelectorAll('.box-item, .box-item-area, div[class*="box-item"]');
    final items = <VideoItem>[];
    final seenSlugs = <String>{};

    for (final el in cardEls) {
      final aLink = el.querySelector('a[href*="xvideos/"], a[href*="/v/"]');
      if (aLink == null) continue;

      var href = aLink.attributes['href']?.trim() ?? '';
      if (href.isEmpty) continue;
      if (!href.startsWith('http')) {
        href = '$kBaseUrl/zh/${href.startsWith('/') ? href.substring(1) : href}';
      }

      // Extract slug from URL path (e.g. xvideos/hrsm-158 -> hrsm-158)
      final uri = Uri.tryParse(href);
      final segments = uri?.pathSegments ?? [];
      final slug = segments.isNotEmpty ? segments.last : href;
      if (slug.isEmpty || seenSlugs.contains(slug)) continue;
      seenSlugs.add(slug);

      // Title: .detail a or .name or a.title or img[alt]
      final titleA = el.querySelector('.detail a') ?? el.querySelector('.name a') ?? el.querySelector('.name');
      var title = titleA?.text.trim() ?? '';
      if (title.isEmpty) {
        final imgEl = el.querySelector('img');
        title = imgEl?.attributes['alt']?.trim() ?? '';
      }
      if (title.isEmpty) {
        title = slug.toUpperCase();
      }

      // Thumbnail image
      final imgEl = el.querySelector('img');
      var coverUrl = imgEl?.attributes['data-src']?.trim() ??
          imgEl?.attributes['data-original']?.trim() ??
          imgEl?.attributes['src']?.trim();
      if (coverUrl != null && (coverUrl.startsWith('data:image') || coverUrl.contains('blank.gif'))) {
        coverUrl = imgEl?.attributes['data-src']?.trim() ?? imgEl?.attributes['data-original']?.trim();
      }
      // Fallback to high-res thumbnail pattern
      if (coverUrl == null || coverUrl.isEmpty || coverUrl.startsWith('data:image')) {
        coverUrl = 'https://static.javcdn.vip/resize/$slug/thumb_h.webp';
      }

      // Duration: .duration or .ribbon
      final durEl = el.querySelector('.duration') ?? el.querySelector('.ribbon');
      final duration = durEl?.text.trim() ?? '';

      // Preview MP4 video URL
      var previewMp4 = '';
      final thumbContainer = el.querySelector('.thumb') ?? el;
      final vScope = thumbContainer.attributes['v-scope'] ?? '';
      final previewMatch = RegExp(r'''Preview\(['"]([^'"]+)['"]\)''').firstMatch(vScope);
      if (previewMatch != null) {
        previewMp4 = previewMatch.group(1) ?? '';
      } else {
        previewMp4 = 'https://static.javcdn.vip/preview/$slug/preview.mp4';
      }

      items.add(
        VideoItem(
          title: title,
          slug: slug,
          detailUrl: href,
          coverUrl: coverUrl,
          duration: duration,
          views: '',
          date: '',
          author: 'NJAV',
          rawData: {
            'duration': duration,
            'slug': slug,
            'source': 'njav',
            'preview_video': previewMp4,
            'embed_url': '$kBaseUrl/vv/$slug',
          },
        ),
      );
    }

    // Parse pagination
    int totalPages = requestPage;
    final pageLinks = doc.querySelectorAll('.pagination a, .pager a, ul.pagination a');
    for (final a in pageLinks) {
      final text = a.text.trim();
      final numVal = int.tryParse(text);
      if (numVal != null && numVal > totalPages) {
        totalPages = numVal;
      }
      final href = a.attributes['href'] ?? '';
      final pageParamMatch = RegExp(r'[?&]page=(\d+)').firstMatch(href);
      if (pageParamMatch != null) {
        final p = int.tryParse(pageParamMatch.group(1)!);
        if (p != null && p > totalPages) {
          totalPages = p;
        }
      }
    }

    return NjavPageData(
      items: items,
      currentPage: requestPage,
      totalPages: totalPages < requestPage ? requestPage : totalPages,
    );
  }

  /// Resolves detailed video metadata
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    final dio = _createDio();
    debugPrint('[NjavApiService] Resolving detail: ${item.detailUrl}');

    final response = await dio.get<String>(
      item.detailUrl,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data ?? '';
    final doc = html_parser.parse(html);

    // Title: h1 or script title or meta
    final titleEl = doc.querySelector('h1.title') ?? doc.querySelector('h1');
    var fullTitle = titleEl?.text.trim() ?? '';
    if (fullTitle.isEmpty) {
      final scriptTitleMatch = RegExp(r'''let\s+title\s*=\s*["']([^"']+)["'];''').firstMatch(html);
      fullTitle = scriptTitleMatch?.group(1)?.trim() ?? item.title;
    }

    // Cover image
    final coverEl = doc.querySelector('.poster img') ?? doc.querySelector('.video img');
    var posterUrl = coverEl?.attributes['src']?.trim() ??
        coverEl?.attributes['data-src']?.trim() ??
        item.coverUrl;
    if (posterUrl != null && posterUrl.startsWith('data:image')) {
      posterUrl = 'https://static.javcdn.vip/images/${item.slug}/thumb_h.webp';
    }

    // Tags & Actresses
    final tags = <String>[];
    for (final a in doc.querySelectorAll('a[href*="/tags/"], a[href*="/actress/"], a[href*="/genres/"], a[href*="/makers/"]')) {
      final t = a.text.trim();
      if (t.isNotEmpty && !tags.contains(t) && !['Home', 'JAV', 'nJAV'].contains(t)) {
        tags.add(t);
      }
    }

    // Date
    final dateMatch = RegExp(r'\b(20\d{2}-\d{2}-\d{2})\b').firstMatch(html);
    final date = dateMatch?.group(1) ?? item.date;

    // Direct Preview MP4
    var previewVideo = item.rawData['preview_video']?.toString() ?? '';
    if (previewVideo.isEmpty) {
      final mp4Match = RegExp(r'''https://static\.javcdn\.vip/preview/[^"']+/preview\.mp4''').firstMatch(html);
      previewVideo = mp4Match?.group(0) ?? 'https://static.javcdn.vip/preview/${item.slug}/preview.mp4';
    }

    final updatedRawData = Map<String, dynamic>.from(item.rawData);
    updatedRawData['source'] = 'njav';
    updatedRawData['preview_video'] = previewVideo;
    final embedUrl = '$kBaseUrl/vv/${item.slug}';
    updatedRawData['embed_url'] = embedUrl;

    return item.copyWith(
      title: fullTitle.isNotEmpty ? fullTitle : item.title,
      coverUrl: posterUrl,
      videoUrl: embedUrl,
      date: date,
      tags: tags.isNotEmpty ? tags : item.tags,
      isDetailLoaded: true,
      rawData: updatedRawData,
    );
  }
}
