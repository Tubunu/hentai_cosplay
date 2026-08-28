import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';
import '../../models/hanime1_category.dart';

import '../jable/api_client.dart';

class Hanime1ApiResponse {
  final List<VideoItem> items;
  final int page;
  final int totalPages;
  final int total;

  Hanime1ApiResponse({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

class Hanime1ApiService {
  static const String kBaseUrl = 'https://hanime1.me';

  static String? _configuredProxy;
  static Dio _dio = _createDio();

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
    _dio = _createDio();
  }

  static Dio _createDio([bool direct = false]) {
    final dio = Dio(
      BaseOptions(
        baseUrl: kBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': '$kBaseUrl/',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-TW,zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      ),
    );

    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      if (!direct && _configuredProxy != null && _configuredProxy!.isNotEmpty) {
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

  /// Build list / search / ranking URL
  static String buildUrl({
    int page = 1,
    Hanime1Category category = Hanime1Category.latest,
    String? keyword,
    String? genre,
    String? tag,
    String? broadcaster,
    String? year,
    String? month,
  }) {
    if (keyword != null && keyword.trim().isNotEmpty) {
      final q = Uri.encodeComponent(keyword.trim());
      if (page > 1) {
        return '$kBaseUrl/search?query=$q&page=$page';
      }
      return '$kBaseUrl/search?query=$q';
    }

    if (tag != null && tag.trim().isNotEmpty) {
      final t = Uri.encodeComponent(tag.trim());
      if (page > 1) {
        return '$kBaseUrl/search?tags=$t&page=$page';
      }
      return '$kBaseUrl/search?tags=$t';
    }

    if (broadcaster != null && broadcaster.trim().isNotEmpty) {
      final b = Uri.encodeComponent(broadcaster.trim());
      if (page > 1) {
        return '$kBaseUrl/search?broadcaster=$b&page=$page';
      }
      return '$kBaseUrl/search?broadcaster=$b';
    }

    if (genre != null && genre.trim().isNotEmpty) {
      final g = Uri.encodeComponent(genre.trim());
      if (page > 1) {
        return '$kBaseUrl/search?genre=$g&page=$page';
      }
      return '$kBaseUrl/search?genre=$g';
    }

    final catPath = category.path;
    if (catPath.contains('?')) {
      if (page > 1) {
        return '$kBaseUrl$catPath&page=$page';
      }
      return '$kBaseUrl$catPath';
    }

    if (page > 1) {
      return '$kBaseUrl$catPath?page=$page';
    }
    return '$kBaseUrl$catPath';
  }

  /// Fetch videos list from Hanime1
  static Future<Hanime1ApiResponse?> fetchPageData({
    int page = 1,
    Hanime1Category category = Hanime1Category.latest,
    String? keyword,
    String? genre,
    String? tag,
    String? broadcaster,
    String? year,
    String? month,
  }) async {
    final url = buildUrl(
      page: page,
      category: category,
      keyword: keyword,
      genre: genre,
      tag: tag,
      broadcaster: broadcaster,
      year: year,
      month: month,
    );
    debugPrint('[Hanime1ApiService] Fetching list: $url');

    // 1. Primary: Use ApiClient with Cloudflare Harvester
    try {
      final html = await ApiClient().fetchHtml('Hanime1', url);
      if (html.isNotEmpty) {
        final parsed = _parseListPageHtml(html, page);
        if (parsed.items.isNotEmpty) {
          return parsed;
        }
      }
    } catch (e) {
      debugPrint('[Hanime1ApiService] ApiClient fetchHtml exception: $e');
    }

    // 2. Secondary fallback: Dio
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        return _parseListPageHtml(response.data!, page);
      }
    } catch (e) {
      debugPrint('[Hanime1ApiService] Error fetching page data: $e. Retrying direct...');
      try {
        final directDio = _createDio(true);
        final response = await directDio.get<String>(
          url,
          options: Options(responseType: ResponseType.plain),
        );
        if (response.statusCode == 200 && response.data != null) {
          return _parseListPageHtml(response.data!, page);
        }
      } catch (e2) {
        debugPrint('[Hanime1ApiService] Direct fallback error: $e2');
      }
    }
    return null;
  }

  /// Fetch and resolve full video detail and direct stream URLs for Hanime1 item
  static Future<VideoItem> fetchVideoDetail(VideoItem item) => resolveVideoDetail(item);

  /// Resolve watch page to extract MP4 video sources (1080p, 720p), tags, studio, and episodes
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    if (item.isDetailLoaded &&
        item.videoUrl != null &&
        item.videoUrl!.isNotEmpty &&
        (item.videoUrl!.contains('.mp4') || item.videoUrl!.contains('.m3u8'))) {
      return item;
    }

    String? directVideoUrl = item.videoUrl;
    String? title = item.title;
    String? author = item.author;
    String? duration = item.duration;
    String? views = item.views;
    String? date = item.date;
    String? coverUrl = item.coverUrl;
    final List<String> tags = List<String>.from(item.tags);
    final Map<String, dynamic> rawData = Map<String, dynamic>.from(item.rawData);
    final List<Map<String, dynamic>> episodes = [];
    final Map<String, String> qualities = {};

    try {
      debugPrint('[Hanime1ApiService] Resolving video detail HTML: ${item.detailUrl}');
      String? html;
      try {
        html = await ApiClient().fetchHtml('Hanime1', item.detailUrl, isDetailPage: true);
      } catch (e) {
        debugPrint('[Hanime1ApiService] ApiClient fetchHtml detail error: $e');
        try {
          final response = await _dio.get<String>(
            item.detailUrl,
            options: Options(responseType: ResponseType.plain),
          );
          if (response.statusCode == 200) {
            html = response.data;
          }
        } catch (e2) {
          final directDio = _createDio(true);
          final response = await directDio.get<String>(
            item.detailUrl,
            options: Options(responseType: ResponseType.plain),
          );
          if (response.statusCode == 200) {
            html = response.data;
          }
        }
      }

      if (html != null && html.isNotEmpty) {
        final document = html_parser.parse(html);

        // 1. Title
        final titleElem = document.querySelector('h1#shareBtn-title') ??
            document.querySelector('h1') ??
            document.querySelector('.video-title');
        if (titleElem != null) {
          final t = titleElem.text.trim();
          if (t.isNotEmpty) title = t;
        }

        // 2. Video tag & source elements
        final sourceElems = document.querySelectorAll('video source, source');
        for (final s in sourceElems) {
          final src = s.attributes['src'];
          final size = s.attributes['size'] ?? s.attributes['title'] ?? s.attributes['type'] ?? '720p';
          if (src != null && src.isNotEmpty && (src.contains('.mp4') || src.contains('.m3u8'))) {
            final qKey = size.contains('1080')
                ? '1080p'
                : (size.contains('720')
                    ? '720p'
                    : (size.contains('480') ? '480p' : size));
            qualities[qKey] = src;
            if (directVideoUrl == null || directVideoUrl.isEmpty || qKey == '1080p') {
              directVideoUrl = src;
            }
          }
        }

        // 3. Poster / Cover image
        final videoElem = document.querySelector('video#player') ?? document.querySelector('video');
        final poster = videoElem?.attributes['poster'];
        if (poster != null && poster.isNotEmpty) {
          coverUrl = poster.startsWith('http') ? poster : '$kBaseUrl$poster';
        }

        // 4. Studio / Broadcaster & Director / Artist
        final broadcasterElem = document.querySelector('a[href*="broadcaster="]');
        if (broadcasterElem != null && broadcasterElem.text.trim().isNotEmpty) {
          author = broadcasterElem.text.trim();
        }

        // 5. Release Date & Views & Duration from video details area
        final detailsArea = document.querySelector('.video-details-wrapper') ?? document.querySelector('.video-info');
        if (detailsArea != null) {
          final dText = detailsArea.text;
          final viewMatch = RegExp(r'(\d+[\d,]*\s*次觀看|\d+[\d,]*\s*次播放)').firstMatch(dText);
          if (viewMatch != null) {
            views = viewMatch.group(1)!.trim();
          }
          final dateMatch = RegExp(r'(\d{4}[-/]\d{2}[-/]\d{2})').firstMatch(dText);
          if (dateMatch != null) {
            date = dateMatch.group(1)!.trim();
          }
        }

        // 6. Tags
        final tagElements = document.querySelectorAll('.single-video-tag, .video-tag, a[href*="genre="], a[href*="tags="]');
        for (final tagElem in tagElements) {
          final tagText = tagElem.text.trim();
          if (tagText.isNotEmpty && !tags.contains(tagText)) {
            tags.add(tagText);
          }
        }

        // 7. Related Playlist / Episodes
        final relatedLinks = document.querySelectorAll('.related-watch-wrap a[href*="watch?v="], .home-rows-videos-div a[href*="watch?v="], a[href*="watch?v="]');
        final seenEpUrls = <String>{};
        for (final a in relatedLinks) {
          final href = a.attributes['href'];
          if (href != null && href.contains('watch?v=') && href != item.detailUrl) {
            final fullEpUrl = href.startsWith('http') ? href : '$kBaseUrl$href';
            if (seenEpUrls.add(fullEpUrl)) {
              final epTitle = a.querySelector('.home-rows-videos-title, .video-title, h5, h4')?.text.trim() ??
                  a.attributes['title'] ??
                  '';
              final epImg = a.querySelector('img');
              final epCover = epImg?.attributes['src'] ?? epImg?.attributes['data-src'] ?? '';
              episodes.add({
                'title': epTitle.isNotEmpty ? epTitle : '播放集数',
                'url': fullEpUrl,
                'cover': epCover,
              });
            }
          }
        }

        rawData['qualities'] = qualities;
        rawData['episodes'] = episodes;
      }
    } catch (e) {
      debugPrint('[Hanime1ApiService] Error resolving video detail HTML: $e');
    }

    return item.copyWith(
      title: title,
      author: author,
      duration: duration,
      views: views,
      date: date,
      coverUrl: coverUrl,
      videoUrl: directVideoUrl,
      tags: tags,
      isDetailLoaded: directVideoUrl != null && directVideoUrl.isNotEmpty,
      rawData: rawData,
    );
  }

  /// Parse HTML string into Hanime1ApiResponse
  static Hanime1ApiResponse _parseListPageHtml(String html, int requestedPage) {
    final document = html_parser.parse(html);
    final List<VideoItem> items = [];
    final seenUrls = <String>{};

    // Cards patterns in search / ranking / home
    final cardElements = document.querySelectorAll('.search-result-div, .home-rows-videos-div, .video-card, .col-video, a[href*="watch?v="]');

    for (final card in cardElements) {
      try {
        final linkElem = card.localName == 'a' ? card : card.querySelector('a[href*="watch?v="]');
        if (linkElem == null) continue;

        var detailHref = linkElem.attributes['href'] ?? '';
        if (detailHref.isEmpty || !detailHref.contains('watch?v=')) continue;
        if (!detailHref.startsWith('http')) {
          detailHref = '$kBaseUrl$detailHref';
        }

        if (!seenUrls.add(detailHref)) continue;

        final vMatch = RegExp(r'watch\?v=(\d+)').firstMatch(detailHref);
        final slug = vMatch != null ? 'hanime1_${vMatch.group(1)}' : detailHref.hashCode.toString();

        // Title
        final titleElem = card.querySelector('.search-result-title, .home-rows-videos-title, .video-title, h5, h4') ?? linkElem;
        var title = titleElem.text.trim();
        if (title.isEmpty) {
          title = linkElem.attributes['title']?.trim() ?? 'Hanime1 动漫 #$slug';
        }

        // Cover
        final imgElem = card.querySelector('img');
        var coverUrl = imgElem?.attributes['data-src'] ?? imgElem?.attributes['src'] ?? '';
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = '$kBaseUrl$coverUrl';
        }

        // Duration & Views
        final durElem = card.querySelector('.video-duration-span, .duration, .badge-duration');
        final duration = durElem?.text.trim() ?? '';

        final viewsElem = card.querySelector('.video-views-span, .views, .play-count');
        final views = viewsElem?.text.trim() ?? '';

        // Broadcaster / Author
        final authorElem = card.querySelector('.home-rows-videos-uploader, .video-artist-span, .broadcaster, .author');
        final author = authorElem?.text.trim() ?? 'Hanime1';

        items.add(
          VideoItem(
            title: title,
            slug: slug,
            detailUrl: detailHref,
            coverUrl: coverUrl.isNotEmpty ? coverUrl : null,
            duration: duration,
            author: author,
            views: views,
            date: '最新动漫',
            tags: const ['Hanime1', '裏番'],
            rawData: {
              'isAnime': true,
              'source': 'hanime1',
            },
          ),
        );
      } catch (e) {
        debugPrint('[Hanime1ApiService] Error parsing video card: $e');
      }
    }

    // Pagination
    int totalPages = requestedPage;
    final paginationLinks = document.querySelectorAll('.pagination a, .page-item a, ul.pagination li a');
    for (final pl in paginationLinks) {
      final pText = pl.text.trim();
      final num = int.tryParse(pText);
      if (num != null && num > totalPages) {
        totalPages = num;
      }
      final href = pl.attributes['href'] ?? '';
      final m = RegExp(r'page=(\d+)').firstMatch(href);
      if (m != null) {
        final pNum = int.tryParse(m.group(1)!);
        if (pNum != null && pNum > totalPages) {
          totalPages = pNum;
        }
      }
    }

    return Hanime1ApiResponse(
      items: items,
      page: requestedPage,
      totalPages: totalPages > requestedPage ? totalPages : requestedPage + 1,
      total: items.length * totalPages,
    );
  }
}
