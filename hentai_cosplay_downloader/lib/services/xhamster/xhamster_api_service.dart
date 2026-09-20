import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';
import '../network_client.dart';

enum XhamsterCategory {
  trending('热门', '/best'),
  newest('最新', '/newest'),
  cosplay('Cosplay', '/categories/cosplay'),
  asian('亚洲', '/categories/asian');

  final String label;
  final String path;
  const XhamsterCategory(this.label, this.path);
}

class XhamsterPageData {
  final List<VideoItem> items;
  final int currentPage;
  final int totalPages;

  const XhamsterPageData({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });
}

class XhamsterApiService {
  static const String kBaseUrl = 'https://xhamster.com';

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
      },
    );
  }

  static String buildUrl({
    int page = 1,
    XhamsterCategory category = XhamsterCategory.trending,
    String? keyword,
  }) {
    final cleanKw = keyword?.trim();
    if (cleanKw != null && cleanKw.isNotEmpty) {
      final encodedKw = Uri.encodeComponent(cleanKw);
      if (page > 1) {
        return '$kBaseUrl/search/$encodedKw?page=$page';
      }
      return '$kBaseUrl/search/$encodedKw';
    }

    final catPath = category.path.replaceAll(RegExp(r'^/|/$'), '');
    if (page > 1) {
      return '$kBaseUrl/$catPath/$page';
    }
    return '$kBaseUrl/$catPath';
  }

  /// Fetch list page data
  static Future<XhamsterPageData> fetchPageData({
    int page = 1,
    XhamsterCategory category = XhamsterCategory.trending,
    String? keyword,
  }) async {
    final dio = _dio;
    final url = buildUrl(page: page, category: category, keyword: keyword);
    debugPrint('[XhamsterApiService] Fetching list: $url');

    final response = await dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data ?? '';
    return _parseListPageHtml(html, page);
  }

  @visibleForTesting
  static XhamsterPageData parseListPageHtmlForTest(String html, int requestPage) =>
      _parseListPageHtml(html, requestPage);

  static XhamsterPageData _parseListPageHtml(String html, int requestPage) {
    // 1. Primary: Extract from window.initials SSR data (contains all 50 items with full thumbnails and metadata)
    final initialsMatch = RegExp(r'window\.initials\s*=\s*(\{.*?\});', dotAll: true).firstMatch(html);
    if (initialsMatch != null) {
      try {
        final jsonStr = initialsMatch.group(1)!;
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final videoThumbProps = _findVideoThumbProps(data);
        if (videoThumbProps != null && videoThumbProps.isNotEmpty) {
          final items = <VideoItem>[];
          final seenSlugs = <String>{};

          for (final raw in videoThumbProps) {
            if (raw is! Map<String, dynamic>) continue;
            final id = raw['id']?.toString() ?? '';
            final pageUrl = raw['pageURL']?.toString() ?? '';
            if (pageUrl.isEmpty) continue;

            final slug = id.isNotEmpty ? id : Uri.parse(pageUrl).pathSegments.last;
            if (seenSlugs.contains(slug)) continue;
            seenSlugs.add(slug);

            final title = raw['title']?.toString() ?? 'xHamster Video';
            final thumbUrl = raw['thumbURL']?.toString() ??
                raw['imageURL']?.toString() ??
                raw['previewThumbURL']?.toString();

            final rawDuration = raw['duration'];
            String duration = '';
            if (rawDuration is int) {
              final minutes = rawDuration ~/ 60;
              final seconds = rawDuration % 60;
              duration = '$minutes:${seconds.toString().padLeft(2, '0')}';
            } else if (rawDuration != null) {
              duration = rawDuration.toString();
            }

            final rawViews = raw['views'];
            String views = '';
            if (rawViews is int) {
              if (rawViews >= 1000000) {
                views = '${(rawViews / 1000000).toStringAsFixed(1)}M';
              } else if (rawViews >= 1000) {
                views = '${(rawViews / 1000).toStringAsFixed(1)}K';
              } else {
                views = '$rawViews';
              }
            } else if (rawViews != null) {
              views = rawViews.toString();
            }

            final trailerUrl = raw['trailerURL']?.toString() ??
                raw['trailerFallbackUrl']?.toString() ??
                '';

            items.add(
              VideoItem(
                title: title,
                slug: slug,
                detailUrl: pageUrl,
                coverUrl: thumbUrl,
                duration: duration,
                views: views,
                date: '',
                author: 'xHamster',
                rawData: {
                  'duration': duration,
                  'views': views,
                  'video_id': id,
                  'preview_video': trailerUrl,
                  'source': 'xhamster',
                },
              ),
            );
          }

          if (items.isNotEmpty) {
            final totalPages = _findTotalPages(data, requestPage);
            return XhamsterPageData(
              items: items,
              currentPage: requestPage,
              totalPages: totalPages < requestPage ? requestPage : totalPages,
            );
          }
        }
      } catch (e) {
        debugPrint('[XhamsterApiService] Error parsing initials: $e');
      }
    }

    // 2. Fallback: Parse HTML DOM cards
    final doc = html_parser.parse(html);
    final cardEls = doc.querySelectorAll('div[data-video-id], .thumb-list__item.video-thumb');
    final items = <VideoItem>[];
    final seenSlugs = <String>{};

    for (final el in cardEls) {
      final aLink = el.querySelector('a.video-thumb__image-container') ??
          el.querySelector('a.video-thumb-info__name') ??
          el.querySelector('a[href*="/videos/"]');
      if (aLink == null) continue;

      var href = aLink.attributes['href']?.trim() ?? '';
      if (href.isEmpty) continue;
      if (!href.startsWith('http')) {
        href = '$kBaseUrl${href.startsWith('/') ? '' : '/'}$href';
      }

      var title = aLink.attributes['aria-label']?.trim() ??
          aLink.attributes['title']?.trim() ??
          aLink.text.trim();
      if (title.isEmpty) {
        final titleA = el.querySelector('a.video-thumb-info__name');
        title = titleA?.attributes['title']?.trim() ?? titleA?.text.trim() ?? '';
      }

      final imgEl = el.querySelector('img.thumb-image-container__image') ??
          el.querySelector('noscript img') ??
          el.querySelector('img');
      var coverUrl = imgEl?.attributes['src']?.trim() ??
          imgEl?.attributes['data-src']?.trim() ??
          imgEl?.attributes['srcset']?.split(' ').first.trim();
      if (coverUrl != null && !coverUrl.startsWith('http')) {
        coverUrl = '$kBaseUrl${coverUrl.startsWith('/') ? '' : '/'}$coverUrl';
      }

      final durationEl = el.querySelector('div[data-role="video-duration"]') ??
          el.querySelector('.thumb-image-container__duration');
      final duration = durationEl?.text.trim() ?? '';

      final viewsEl = el.querySelector('.video-thumb-views') ?? el.querySelector('.views');
      final views = viewsEl?.text.trim() ?? '';

      final previewVideo = aLink.attributes['data-previewvideo']?.trim() ??
          aLink.attributes['data-previewvideo-fallback']?.trim() ??
          '';

      final videoId = el.attributes['data-video-id']?.trim() ?? '';
      final slug = videoId.isNotEmpty ? videoId : Uri.parse(href).pathSegments.last;

      if (seenSlugs.contains(slug)) continue;
      seenSlugs.add(slug);

      items.add(
        VideoItem(
          title: title.isNotEmpty ? title : 'xHamster Video',
          slug: slug,
          detailUrl: href,
          coverUrl: coverUrl,
          duration: duration,
          views: views,
          date: '',
          author: 'xHamster',
          rawData: {
            'duration': duration,
            'views': views,
            'video_id': videoId,
            'preview_video': previewVideo,
            'source': 'xhamster',
          },
        ),
      );
    }

    // Parse pagination
    int totalPages = requestPage;
    final pageEls = doc.querySelectorAll('a[href*="page="], [data-page], .pager-section a, .pagination a');
    for (final pe in pageEls) {
      final t = pe.text.replaceAll(',', '').replaceAll(' ', '').trim();
      final pNum = int.tryParse(t);
      if (pNum != null && pNum > totalPages) {
        totalPages = pNum;
      }
      final href = pe.attributes['href'] ?? '';
      final m = RegExp(r'[?&]page=(\d+)').firstMatch(href) ?? RegExp(r'/(\d+)(?:\?|$)').firstMatch(href);
      if (m != null) {
        final pFromHref = int.tryParse(m.group(1)!);
        if (pFromHref != null && pFromHref > totalPages) {
          totalPages = pFromHref;
        }
      }
    }

    return XhamsterPageData(
      items: items,
      currentPage: requestPage,
      totalPages: totalPages < requestPage ? requestPage : totalPages,
    );
  }

  /// Resolve full video details including direct HLS m3u8 or MP4 streaming URLs
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    final dio = _dio;
    debugPrint('[XhamsterApiService] Resolving detail: ${item.detailUrl}');

    final response = await dio.get<String>(
      item.detailUrl,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data ?? '';
    final doc = html_parser.parse(html);

    var videoUrl = '';
    var posterUrl = item.coverUrl;

    // 1. Extract direct HLS m3u8 stream
    final m3u8Matches = RegExp(r'https?://[^\s"<>]+\.m3u8(?:\?[^\s"<>]*)?').allMatches(html);
    for (final m in m3u8Matches) {
      final u = m.group(0);
      if (u != null && u.isNotEmpty) {
        videoUrl = u;
        break;
      }
    }

    // 2. Fallback to direct MP4 or preview trailer
    if (videoUrl.isEmpty) {
      final mp4Matches = RegExp(r'https?://[^\s"<>]+\.mp4(?:\?[^\s"<>]*)?').allMatches(html);
      for (final m in mp4Matches) {
        final u = m.group(0);
        if (u != null && u.isNotEmpty && !u.contains('blank') && !u.contains('banner')) {
          videoUrl = u;
          break;
        }
      }
    }

    // 3. Fallback to rawData preview video
    if (videoUrl.isEmpty) {
      final prev = item.rawData['preview_video'] as String?;
      if (prev != null && prev.isNotEmpty) {
        videoUrl = prev;
      }
    }

    // Poster
    final posterEl = doc.querySelector('video[poster], meta[property="og:image"]');
    final pSrc = posterEl?.attributes['poster'] ?? posterEl?.attributes['content'];
    if (pSrc != null && pSrc.isNotEmpty) {
      posterUrl = pSrc.startsWith('http') ? pSrc : '$kBaseUrl$pSrc';
    }

    // Tags
    final tags = <String>[];
    for (final a in doc.querySelectorAll('a[href*="/categories/"], a[href*="/tags/"], a[href*="/pornstars/"]')) {
      final t = a.text.trim();
      if (t.isNotEmpty && !tags.contains(t) && !['Home', 'Best', 'Newest'].contains(t)) {
        tags.add(t);
      }
    }

    final updatedRawData = Map<String, dynamic>.from(item.rawData);
    updatedRawData['source'] = 'xhamster';
    updatedRawData['video_url'] = videoUrl;

    return item.copyWith(
      coverUrl: posterUrl,
      videoUrl: videoUrl.isNotEmpty ? videoUrl : item.detailUrl,
      tags: tags.isNotEmpty ? tags : item.tags,
      isDetailLoaded: true,
      rawData: updatedRawData,
    );
  }

  /// Recursively find videoThumbProps in initials data (supports categories, search, best, and user channels)
  static List<dynamic>? _findVideoThumbProps(dynamic obj) {
    if (obj is Map<String, dynamic>) {
      // 1. Check known high-priority container keys
      final fromLayout = obj['layoutPage']?['videoListProps']?['videoThumbProps'];
      if (fromLayout is List && fromLayout.isNotEmpty) return fromLayout;

      final fromCatTrending = obj['pagesCategoryComponent']?['trendingVideoListProps']?['videoThumbProps'];
      if (fromCatTrending is List && fromCatTrending.isNotEmpty) return fromCatTrending;

      final fromCatList = obj['pagesCategoryComponent']?['videoListProps']?['videoThumbProps'];
      if (fromCatList is List && fromCatList.isNotEmpty) return fromCatList;

      final fromSearch = obj['searchResult']?['videoThumbProps'];
      if (fromSearch is List && fromSearch.isNotEmpty) return fromSearch;

      final fromSearchDirect = obj['search']?['videoThumbProps'];
      if (fromSearchDirect is List && fromSearchDirect.isNotEmpty) return fromSearchDirect;

      // 2. Fallback: Search all entries
      for (final entry in obj.entries) {
        if (entry.key == 'videoThumbProps' && entry.value is List && (entry.value as List).isNotEmpty) {
          return entry.value as List<dynamic>;
        }
        final found = _findVideoThumbProps(entry.value);
        if (found != null && found.isNotEmpty) return found;
      }
    } else if (obj is List) {
      for (final item in obj) {
        final found = _findVideoThumbProps(item);
        if (found != null && found.isNotEmpty) return found;
      }
    }
    return null;
  }

  /// Recursively find pagination total pages in initials data
  static int _findTotalPages(dynamic obj, int requestPage) {
    if (obj is Map<String, dynamic>) {
      // Check known pagination locations
      final candidates = [
        obj['layoutPage']?['paginationProps'],
        obj['pagesCategoryComponent']?['paginationProps'],
        obj['searchResult']?['paginationProps'],
      ];
      for (final p in candidates) {
        if (p is Map<String, dynamic>) {
          if (p['lastPageNumber'] is int) return p['lastPageNumber'] as int;
          if (p['totalPages'] is int) return p['totalPages'] as int;
        }
      }
      for (final entry in obj.entries) {
        if (entry.key == 'paginationProps' && entry.value is Map<String, dynamic>) {
          final p = entry.value as Map<String, dynamic>;
          if (p['lastPageNumber'] is int) return p['lastPageNumber'] as int;
          if (p['totalPages'] is int) return p['totalPages'] as int;
        }
        final t = _findTotalPages(entry.value, requestPage);
        if (t != requestPage) return t;
      }
    } else if (obj is List) {
      for (final item in obj) {
        final t = _findTotalPages(item, requestPage);
        if (t != requestPage) return t;
      }
    }
    return requestPage;
  }
}
