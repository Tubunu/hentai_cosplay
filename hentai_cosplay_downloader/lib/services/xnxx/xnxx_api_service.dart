import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';
import '../network_client.dart';

enum XnxxCategory {
  hits('热门浏览', '/hits'),
  best('最佳影片', '/best'),
  cosplay('Cosplay', '/search/cosplay'),
  asian('亚洲', '/search/asian');

  final String label;
  final String path;
  const XnxxCategory(this.label, this.path);
}

class XnxxPageData {
  final List<VideoItem> items;
  final int currentPage;
  final int totalPages;

  const XnxxPageData({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });
}

class XnxxApiService {
  static const String kBaseUrl = 'https://www.xnxx.com';

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
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      specificProxy: _configuredProxy,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        'Referer': '$kBaseUrl/',
        'Cookie': 'hasVisited=1; age_verified=1;',
      },
    );
  }

  /// Get list of selectable months for Best Videos mode (e.g. 2026-08, 2026-07, ...)
  static List<String> getAvailableBestMonths({int count = 48}) {
    final now = DateTime.now();
    final List<String> months = [];
    for (int i = 0; i < count; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final y = d.year;
      final m = d.month.toString().padLeft(2, '0');
      months.add('$y-$m');
    }
    return months;
  }

  static String getDefaultBestMonth() {
    final months = getAvailableBestMonths(count: 2);
    return months.length > 1 ? months[1] : months.first;
  }

  static String buildUrl({
    int page = 1,
    XnxxCategory category = XnxxCategory.hits,
    String? bestMonth,
    String? keyword,
  }) {
    final cleanKw = keyword?.trim();
    if (cleanKw != null && cleanKw.isNotEmpty) {
      final encodedKw = Uri.encodeComponent(cleanKw);
      final pageOffset = page > 1 ? page - 1 : 0;
      if (pageOffset > 0) {
        return '$kBaseUrl/search/$encodedKw/$pageOffset';
      }
      return '$kBaseUrl/search/$encodedKw';
    }

    if (category == XnxxCategory.best) {
      final month = bestMonth ?? getDefaultBestMonth();
      final pageOffset = page > 1 ? page - 1 : 0;
      if (pageOffset > 0) {
        return '$kBaseUrl/best/$month/$pageOffset';
      }
      return '$kBaseUrl/best/$month';
    }

    final catPath = category.path.replaceAll(RegExp(r'^/|/$'), '');
    final pageOffset = page > 1 ? page - 1 : 0;
    if (pageOffset > 0) {
      return '$kBaseUrl/$catPath/$pageOffset';
    }
    return '$kBaseUrl/$catPath';
  }

  /// Fetch list page data
  static Future<XnxxPageData> fetchPageData({
    int page = 1,
    XnxxCategory category = XnxxCategory.hits,
    String? bestMonth,
    String? keyword,
  }) async {
    final dio = _dio;
    final url = buildUrl(page: page, category: category, bestMonth: bestMonth, keyword: keyword);
    debugPrint('[XnxxApiService] Fetching list: $url');

    final response = await dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data ?? '';
    return _parseListPageHtml(html, page);
  }

  @visibleForTesting
  static XnxxPageData parseListPageHtmlForTest(String html, int requestPage) =>
      _parseListPageHtml(html, requestPage);

  static XnxxPageData _parseListPageHtml(String html, int requestPage) {
    final doc = html_parser.parse(html);
    final cardEls = doc.querySelectorAll('.thumb-block:not(.thumb-cat), div[id^="video"]');
    final items = <VideoItem>[];
    final seenSlugs = <String>{};

    for (final el in cardEls) {
      // Prioritize title element inside .thumb-under p a (holds authentic full title)
      final titleA = el.querySelector('.thumb-under p a') ??
          el.querySelector('.thumb-under a') ??
          el.querySelector('p.title a') ??
          el.querySelector('a.title');

      final thumbA = el.querySelector('.thumb a') ??
          el.querySelector('a[href*="/video-"]');

      final aLink = titleA ?? thumbA;
      if (aLink == null) continue;

      var href = aLink.attributes['href']?.trim() ?? '';
      if (href.isEmpty && thumbA != null) {
        href = thumbA.attributes['href']?.trim() ?? '';
      }
      if (href.isEmpty) continue;
      if (!href.startsWith('http')) {
        href = '$kBaseUrl${href.startsWith('/') ? '' : '/'}$href';
      }

      var title = titleA?.attributes['title']?.trim() ??
          titleA?.text.trim() ??
          aLink.attributes['title']?.trim() ??
          aLink.text.trim();

      if (title.isEmpty) {
        final imgEl = el.querySelector('img');
        title = imgEl?.attributes['alt']?.trim() ??
            imgEl?.attributes['title']?.trim() ??
            '';
      }
      if (title.isEmpty) {
        final segments = Uri.parse(href).pathSegments;
        if (segments.length >= 2 && segments[1] != '_-_' && segments[1].isNotEmpty) {
          title = segments[1].replaceAll('_', ' ').trim();
        }
      }

      final imgEl = el.querySelector('img');
      var coverUrl = imgEl?.attributes['data-src']?.trim() ??
          imgEl?.attributes['data-sfwthumb']?.trim() ??
          imgEl?.attributes['src']?.trim();
      if (coverUrl != null && coverUrl.contains('blank.gif')) {
        coverUrl = imgEl?.attributes['data-src']?.trim() ?? imgEl?.attributes['data-sfwthumb']?.trim();
      }
      if (coverUrl != null && !coverUrl.startsWith('http')) {
        coverUrl = '$kBaseUrl${coverUrl.startsWith('/') ? '' : '/'}$coverUrl';
      }

      final durEl = el.querySelector('.metadata .left') ?? el.querySelector('.duration');
      final rawDur = durEl?.text ?? '';
      final durMatch = RegExp(r'(\d+\s*min(?:\s*\d+\s*sec)?|\d+\s*sec|\d+:\d+(?::\d+)?)', caseSensitive: false).firstMatch(rawDur);
      final duration = durMatch?.group(1)?.trim() ?? '';

      final resMatch = RegExp(r'\b(\d{3,4}p)\b', caseSensitive: false).firstMatch(rawDur);
      final resolution = resMatch?.group(1) ?? '';

      final viewsEl = el.querySelector('.metadata .right') ?? el.querySelector('.views');
      final rawViews = viewsEl?.text ?? '';
      final viewsMatch = RegExp(r'([\d,]+(?:\.\d+)?\s*[MKmk]?%?)').firstMatch(rawViews);
      final views = viewsMatch != null ? viewsMatch.group(1)!.trim() : rawViews.replaceAll(RegExp(r'\s+'), ' ').trim();

      final slug = Uri.parse(href).pathSegments.isNotEmpty
          ? Uri.parse(href).pathSegments.first.replaceAll('video-', '')
          : href;

      if (seenSlugs.contains(slug)) continue;
      seenSlugs.add(slug);

      items.add(
        VideoItem(
          title: title.isNotEmpty ? title : 'XNXX Video',
          slug: slug,
          detailUrl: href,
          coverUrl: coverUrl,
          duration: duration,
          views: views,
          date: '',
          author: 'XNXX',
          rawData: {
            'duration': duration,
            'resolution': resolution,
            'views': views,
            'source': 'xnxx',
          },
        ),
      );
    }

    // Parse pagination
    int totalPages = requestPage;
    final pageEls = doc.querySelectorAll('a[href*="/"]');
    for (final pe in pageEls) {
      final href = pe.attributes['href'] ?? '';
      final m = RegExp(r'/(?:search/[^/]+/|hits/|best/[^/]+/|tags/[^/]+/)?(\d+)(?:/)?$').firstMatch(href);
      if (m != null) {
        final pOffset = int.tryParse(m.group(1)!);
        if (pOffset != null && (pOffset + 1) > totalPages && (pOffset + 1) < 1000) {
          totalPages = pOffset + 1;
        }
      }
    }

    if (totalPages <= requestPage && items.length >= 15) {
      totalPages = requestPage + 1;
    }

    return XnxxPageData(
      items: items,
      currentPage: requestPage,
      totalPages: totalPages,
    );
  }

  /// Resolve full video details including high/low MP4 or HLS streaming URLs
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    final dio = _dio;
    debugPrint('[XnxxApiService] Resolving detail: ${item.detailUrl}');

    final response = await dio.get<String>(
      item.detailUrl,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data ?? '';
    final doc = html_parser.parse(html);

    var videoUrl = '';
    var videoHigh = '';
    var videoLow = '';
    var videoHls = '';
    var posterUrl = item.coverUrl;

    // 1. Title
    final titleMatch = RegExp(r'''html5player\.setVideoTitle\(['"](.*?)['"]\)''').firstMatch(html);
    final title = titleMatch?.group(1)?.trim() ?? doc.querySelector('h1')?.text.trim() ?? item.title;

    // 2. High MP4
    final highMatch = RegExp(r'''html5player\.setVideoUrlHigh\(['"](.*?)['"]\)''').firstMatch(html);
    if (highMatch != null) {
      videoHigh = highMatch.group(1) ?? '';
    }

    // 3. Low MP4
    final lowMatch = RegExp(r'''html5player\.setVideoUrlLow\(['"](.*?)['"]\)''').firstMatch(html);
    if (lowMatch != null) {
      videoLow = lowMatch.group(1) ?? '';
    }

    // 4. HLS m3u8
    final hlsMatch = RegExp(r'''html5player\.setVideoHLS\(['"](.*?)['"]\)''').firstMatch(html);
    if (hlsMatch != null) {
      videoHls = hlsMatch.group(1) ?? '';
    }

    // 5. Poster
    final thumbMatch = RegExp(r'''html5player\.setThumbUrl\(['"](.*?)['"]\)''').firstMatch(html);
    if (thumbMatch != null) {
      posterUrl = thumbMatch.group(1) ?? posterUrl;
    }

    // Priority for videoUrl: High MP4 -> HLS -> Low MP4
    if (videoHigh.isNotEmpty) {
      videoUrl = videoHigh;
    } else if (videoHls.isNotEmpty) {
      videoUrl = videoHls;
    } else if (videoLow.isNotEmpty) {
      videoUrl = videoLow;
    }

    // Fallback regex for mp4
    if (videoUrl.isEmpty) {
      final mp4Match = RegExp(r'https?://[^\s"<>]+\.mp4(?:\?[^\s"<>]*)?').firstMatch(html);
      if (mp4Match != null) {
        videoUrl = mp4Match.group(0) ?? '';
      }
    }

    // 6. Metadata parsing (Duration, Resolution, Views)
    final metaText = doc.querySelector('.video-metadata, .metadata')?.text ?? '';
    final durMatch = RegExp(r'(\d+\s*min(?:\s*\d+\s*sec)?|\d+\s*sec|\d+:\d+(?::\d+)?)', caseSensitive: false).firstMatch(metaText);
    final duration = durMatch?.group(1)?.trim() ?? item.duration;

    final resMatch = RegExp(r'\b(\d{3,4}p)\b', caseSensitive: false).firstMatch(metaText);
    final resolution = resMatch?.group(1) ?? (item.rawData['resolution'] as String? ?? '');

    final viewsMatch = RegExp(r'([\d,]+(?:\.\d+)?\s*[MKmk]?%?)').firstMatch(metaText);
    final views = viewsMatch?.group(1)?.trim() ?? item.views;

    // 7. Tags
    final tags = <String>[];
    for (final a in doc.querySelectorAll('a[href*="/search/"], .video-tags a, a[href*="/tags/"]')) {
      final t = a.text.trim();
      if (t.isNotEmpty &&
          !tags.contains(t) &&
          !['Home', 'Best', 'Hits', 'Edit tags and models', 'Edit tags', 'Upload a video', 'Report'].contains(t) &&
          !t.startsWith('+') &&
          t.length < 30) {
        tags.add(t);
      }
    }

    final updatedRawData = Map<String, dynamic>.from(item.rawData);
    updatedRawData['source'] = 'xnxx';
    updatedRawData['video_high'] = videoHigh;
    updatedRawData['video_low'] = videoLow;
    updatedRawData['video_hls'] = videoHls;
    updatedRawData['video_url'] = videoUrl;
    updatedRawData['resolution'] = resolution;
    updatedRawData['duration'] = duration;
    updatedRawData['views'] = views;

    return item.copyWith(
      title: title.isNotEmpty ? title : item.title,
      coverUrl: posterUrl,
      videoUrl: videoUrl.isNotEmpty ? videoUrl : item.detailUrl,
      duration: duration,
      views: views,
      tags: tags.isNotEmpty ? tags : item.tags,
      isDetailLoaded: true,
      rawData: updatedRawData,
    );
  }
}
