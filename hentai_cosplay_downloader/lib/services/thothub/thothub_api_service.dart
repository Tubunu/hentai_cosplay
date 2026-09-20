import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';
import '../network_client.dart';

enum ThothubCategory {
  latest('最新发布', '/latest-updates/'),
  popular('热门推荐', '/most-popular/'),
  topRated('评分最高', '/top-rated/'),
  albums('精选图集', '/albums/');

  final String label;
  final String path;
  const ThothubCategory(this.label, this.path);
}

class ThothubPageData {
  final List<VideoItem> items;
  final int currentPage;
  final int totalPages;

  const ThothubPageData({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });
}

class ThothubApiService {
  static const String kBaseUrl = 'https://thothub.to';
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
        'Referer': 'https://thothub.to/',
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
    ThothubCategory category = ThothubCategory.latest,
    String? keyword,
  }) {
    final cleanKw = keyword?.trim();
    if (cleanKw != null && cleanKw.isNotEmpty) {
      final encoded = Uri.encodeComponent(cleanKw);
      if (page > 1) {
        return '$kBaseUrl/search/$encoded/$page/';
      }
      return '$kBaseUrl/search/$encoded/';
    }

    final catPath = category.path.replaceAll(RegExp(r'^/|/$'), '');
    if (page > 1) {
      return '$kBaseUrl/$catPath/$page/';
    }
    return '$kBaseUrl/$catPath/';
  }

  /// Fetch list page data with automatic retry
  static Future<ThothubPageData> fetchPageData({
    int page = 1,
    ThothubCategory category = ThothubCategory.latest,
    String? keyword,
  }) async {
    final dio = _dio;
    final url = buildUrl(page: page, category: category, keyword: keyword);
    debugPrint('[ThothubApiService] Fetching list: $url');

    Response<String>? response;
    try {
      response = await dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
    } catch (e) {
      debugPrint('[ThothubApiService] First attempt failed ($e), retrying once...');
      response = await dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
    }

    final html = response.data ?? '';
    return _parseListPageHtml(html, page);
  }

  static ThothubPageData _parseListPageHtml(String html, int requestPage) {
    final doc = html_parser.parse(html);
    final cardEls = doc.querySelectorAll('.item');
    final items = <VideoItem>[];
    final seenSlugs = <String>{};

    for (final el in cardEls) {
      final aLink = el.querySelector('a[href*="/videos/"], a[href*="/albums/"]');
      if (aLink == null) continue;

      var href = aLink.attributes['href']?.trim() ?? '';
      if (href.isEmpty) continue;
      if (!href.startsWith('http')) {
        href = '$kBaseUrl${href.startsWith('/') ? '' : '/'}$href';
      }

      final titleEl = el.querySelector('strong.title') ?? aLink.querySelector('strong');
      var title = titleEl?.text.trim() ?? aLink.attributes['title']?.trim() ?? '';
      if (title.isEmpty) {
        title = 'Thothub Video';
      }

      final imgEl = el.querySelector('img.thumb') ?? el.querySelector('img');
      var coverUrl = imgEl?.attributes['data-original']?.trim() ??
          imgEl?.attributes['data-src']?.trim() ??
          imgEl?.attributes['src']?.trim();
      if (coverUrl != null && coverUrl.contains('data:image')) {
        coverUrl = imgEl?.attributes['data-original']?.trim() ?? imgEl?.attributes['data-src']?.trim();
      }
      if (coverUrl != null && !coverUrl.startsWith('http')) {
        coverUrl = '$kBaseUrl${coverUrl.startsWith('/') ? '' : '/'}$coverUrl';
      }

      // Duration & Views
      final durationEl = el.querySelector('.views-counter2');
      final rawDuration = durationEl?.text.trim() ?? '';
      final durMatch = RegExp(r'(\d+:\d+(?::\d+)?)').firstMatch(rawDuration);
      final duration = durMatch?.group(1) ?? rawDuration;

      final viewsEl = el.querySelector('.views-counter');
      final views = viewsEl?.text.trim() ?? '';

      // Date
      final dateEl = el.querySelector('div[style*="color:#999"]');
      final date = dateEl?.text.trim() ?? '';

      // Extract video ID or slug
      final mId = RegExp(r'/videos/(\d+)/|/albums/(\d+)/').firstMatch(href);
      final slug = mId != null ? (mId.group(1) ?? mId.group(2)!) : Uri.parse(href).pathSegments.last;

      if (seenSlugs.contains(slug)) continue;
      seenSlugs.add(slug);

      items.add(
        VideoItem(
          title: title,
          slug: slug,
          detailUrl: href,
          coverUrl: coverUrl,
          duration: duration,
          views: views,
          date: date,
          author: 'Thothub',
          rawData: {
            'duration': duration,
            'views': views,
            'date': date,
            'source': 'thothub',
          },
        ),
      );
    }

    // Parse pagination
    int totalPages = requestPage;
    final pageEls = doc.querySelectorAll('.pagination a, .paging a, a[href*="/"]');
    for (final pe in pageEls) {
      final t = pe.text.trim();
      final pNum = int.tryParse(t);
      if (pNum != null && pNum > totalPages) {
        totalPages = pNum;
      }
      final href = pe.attributes['href'] ?? '';
      final m = RegExp(r'/(\d+)/?$').firstMatch(href);
      if (m != null) {
        final pOffset = int.tryParse(m.group(1)!);
        if (pOffset != null && pOffset > totalPages && pOffset < 1000) {
          totalPages = pOffset;
        }
      }
    }

    if (totalPages <= requestPage && items.length >= 20) {
      totalPages = requestPage + 1;
    }

    return ThothubPageData(
      items: items,
      currentPage: requestPage,
      totalPages: totalPages,
    );
  }

  /// Resolve full video details
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    final dio = _dio;
    debugPrint('[ThothubApiService] Resolving detail: ${item.detailUrl}');

    final response = await dio.get<String>(
      item.detailUrl,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data ?? '';
    final doc = html_parser.parse(html);

    var videoUrl = '';
    var posterUrl = item.coverUrl;

    // 1. Extract flashvars from script
    final mVideoId = RegExp(r"video_id:\s*'(\d+)'").firstMatch(html);
    final videoId = mVideoId?.group(1) ?? item.slug;

    final mVideoUrl = RegExp(r"video_url:\s*'([^']+)'").firstMatch(html);
    if (mVideoUrl != null) {
      final rawVideoUrl = mVideoUrl.group(1)!;
      // If function/0/..., strip prefix or keep clean URL
      videoUrl = rawVideoUrl.replaceAll(RegExp(r'^function/\d+/'), '');
    }

    // 2. Poster preview
    final mPreviewUrl = RegExp(r"preview_url:\s*'([^']+)'").firstMatch(html);
    if (mPreviewUrl != null) {
      posterUrl = mPreviewUrl.group(1);
    }

    // 3. Fallback direct video tag
    final videoEl = doc.querySelector('video');
    if (videoEl != null) {
      final src = videoEl.attributes['src'];
      if (src != null && src.isNotEmpty) {
        videoUrl = src;
      }
    }

    // 4. Tags & Categories
    final tags = <String>[];
    for (final a in doc.querySelectorAll('a[href*="/categories/"], a[href*="/tags/"], a[href*="/models/"]')) {
      final t = a.text.trim();
      if (t.isNotEmpty &&
          !tags.contains(t) &&
          !['Categories', 'Latest', 'Popular', 'Albums', 'Upload'].contains(t)) {
        tags.add(t);
      }
    }

    final updatedRawData = Map<String, dynamic>.from(item.rawData);
    updatedRawData['source'] = 'thothub';
    updatedRawData['video_id'] = videoId;
    updatedRawData['embed_url'] = 'https://thothub.to/embed/$videoId';
    updatedRawData['video_url'] = videoUrl;

    return item.copyWith(
      coverUrl: posterUrl,
      videoUrl: videoUrl.isNotEmpty ? videoUrl : item.detailUrl,
      tags: tags.isNotEmpty ? tags : item.tags,
      isDetailLoaded: true,
      rawData: updatedRawData,
    );
  }
}
