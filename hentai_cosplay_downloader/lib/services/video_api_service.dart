import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/album_item.dart';
import '../models/video_item.dart';
import 'hc_api_service.dart';

class VideoApiResponse {
  final List<VideoItem> items;
  final int total;
  final int pageSize;
  final int page;
  final int totalPages;

  VideoApiResponse({
    required this.items,
    required this.total,
    required this.pageSize,
    required this.page,
    required this.totalPages,
  });
}

class VideoApiService {
  static const String kBaseUrl = 'https://porn-video-xxx.com';

  static String? _configuredProxy;

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
    _recreateDio();
  }

  static late Dio _dio;

  static void _recreateDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Referer': '$kBaseUrl/',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8,ja;q=0.7',
          'Connection': 'keep-alive',
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
        client.findProxy = (uri) => 'DIRECT';
      }
      return client;
    };

    dio.httpClientAdapter = adapter;
    _dio = dio;
  }

  static final bool _initialized = () {
    _recreateDio();
    return true;
  }();

  /// Build online video URL supporting categories, keywords, and tags
  static String buildBrowseUrl({
    VideoCategory category = VideoCategory.latest,
    String? keyword,
    String? tag,
    int page = 1,
  }) {
    if (!_initialized) _recreateDio();

    final cleanKeyword = keyword?.trim() ?? '';
    if (cleanKeyword.isNotEmpty) {
      final encoded = Uri.encodeComponent(cleanKeyword);
      if (page <= 1) {
        return '$kBaseUrl/search/keyword/$encoded/';
      } else {
        return '$kBaseUrl/search/keyword/$encoded/page/$page/';
      }
    }

    final cleanTag = tag?.trim() ?? '';
    if (cleanTag.isNotEmpty) {
      final encoded = Uri.encodeComponent(cleanTag);
      if (page <= 1) {
        return '$kBaseUrl/search/tag/$encoded/';
      } else {
        return '$kBaseUrl/search/tag/$encoded/page/$page/';
      }
    }

    // Category URL
    final cleanPath = category.path.replaceAll(RegExp(r'^/|/$'), '');
    if (page <= 1) {
      return '$kBaseUrl/$cleanPath/';
    } else {
      return '$kBaseUrl/$cleanPath/page/$page/';
    }
  }

  /// Build video tags URL
  static String buildTagsUrl({int page = 1}) {
    if (!_initialized) _recreateDio();
    if (page <= 1) {
      return '$kBaseUrl/tag-list/all/';
    } else {
      return '$kBaseUrl/tag-list/all/page/$page/';
    }
  }

  /// Parse video items from HTML using DOM parser
  static List<VideoItem> parseVideoList(String html) {
    final List<VideoItem> items = [];
    final seen = <String>{};
    final doc = html_parser.parse(html);

    // Identify distinct card elements
    var cardElements = doc.querySelectorAll('li[data-grid-item], li[data-select-item], .board-item, .video-list-item, .post-item, .image-list-item, .card');
    if (cardElements.isEmpty) {
      cardElements = doc.querySelectorAll('li, .item');
    }

    for (final card in cardElements) {
      final hrefEl = card.querySelector('a[href*="/video/"], a[href*="/post/"]') ?? card.querySelector('a');
      final rawHref = hrefEl?.attributes['href']?.trim() ?? '';
      if (rawHref.isEmpty || (!rawHref.contains('/video/') && !rawHref.contains('/post/'))) {
        continue;
      }

      final fullDetailUrl = rawHref.startsWith('http') ? rawHref : '$kBaseUrl$rawHref';
      final slugMatch = RegExp(r'/(?:video|post)/([^/]+)/').firstMatch(fullDetailUrl);
      final slug = slugMatch?.group(1) ?? fullDetailUrl.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      if (seen.contains(slug)) continue;

      final imgEl = card.querySelector('img');
      final rawImg = imgEl?.attributes['src']?.trim() ?? imgEl?.attributes['data-src']?.trim() ?? '';
      final fullCoverUrl = rawImg.isEmpty
          ? ''
          : (rawImg.startsWith('http') ? rawImg : '$kBaseUrl$rawImg');

      final titleEl = card.querySelector('.title, .name, .value, h1, h2, h3, h4, p.title');
      var title = titleEl?.text.trim() ?? imgEl?.attributes['alt']?.trim() ?? '';
      if (title.isEmpty) {
        title = slug;
      }

      final tagElements = card.querySelectorAll('a[href*="/search/tag/"], a[href*="/tag/"]');
      final tags = <String>[];
      for (final tm in tagElements) {
        final t = tm.text.trim();
        if (t.isNotEmpty && !tags.contains(t)) {
          tags.add(t);
        }
      }

      final durEl = card.querySelector('.duration, .time, span.duration');
      final duration = durEl?.text.trim() ?? '';

      final dateEl = card.querySelector('.regist-date, .date, span.date');
      final date = dateEl?.text.trim() ?? '';

      final author = VideoItem.inferAuthor(title);
      seen.add(slug);

      items.add(
        VideoItem(
          title: title,
          slug: slug,
          detailUrl: fullDetailUrl,
          coverUrl: fullCoverUrl.isNotEmpty ? fullCoverUrl : null,
          duration: duration,
          date: date,
          author: author,
          tags: tags,
        ),
      );
    }

    return items;
  }

  /// Parse total pages from pagination using DOM parser
  static int parseTotalPages(String html, int currentPage, int fallbackItemCount) {
    final doc = html_parser.parse(html);

    // 1. wp-pagenavi last page link
    final lastLink = doc.querySelector('.wp-pagenavi a.last, a.last');
    if (lastLink != null) {
      final href = lastLink.attributes['href'] ?? '';
      final match = RegExp(r'/page/(\d+)/?').firstMatch(href);
      if (match != null) {
        final p = int.tryParse(match.group(1) ?? '');
        if (p != null && p > 0) return p;
      }
    }

    // 2. All pagination page numbers
    final pageLinks = doc.querySelectorAll('.wp-pagenavi a, .pagination a');
    int maxPage = currentPage;
    for (final l in pageLinks) {
      final p = int.tryParse(l.text.trim());
      if (p != null && p > maxPage) {
        maxPage = p;
      }
    }

    // 3. Check for next page link in paginator-container
    final hasNext = html.contains('navigate_next') ||
        html.contains('arrow_forward_ios') ||
        html.contains('/page/${currentPage + 1}/');

    if (hasNext && maxPage <= currentPage) {
      maxPage = currentPage + 1;
    }

    return maxPage > 0 ? maxPage : 1;
  }

  /// Check if next page exists
  static bool parseHasNextPage(String html, int currentPage) {
    return html.contains('navigate_next') ||
        html.contains('arrow_forward_ios') ||
        html.contains('/page/${currentPage + 1}/');
  }

  /// Parse video detail page to extract real video file URL (m3u8/mp4), poster, tags, duration
  static VideoItem parseVideoDetail(String html, VideoItem item) {
    String? directVideoUrl;
    String cover = item.coverUrl ?? '';
    List<String> tags = [];
    String duration = item.duration;
    final doc = html_parser.parse(html);

    // 1. Extract from JSON-LD Schema VideoObject (Most reliable)
    final jsonLdScripts = doc.querySelectorAll('script[type="application/ld+json"]');
    for (final script in jsonLdScripts) {
      final jsonText = script.text.trim();
      final contentUrlMatch = RegExp(r'"contentUrl"\s*:\s*"(https?:\\?/\\?/[^"]+)"', caseSensitive: false).firstMatch(jsonText);
      if (contentUrlMatch != null) {
        directVideoUrl = contentUrlMatch.group(1)?.replaceAll(r'\/', '/').trim();
      }
      final thumbMatch = RegExp(r'"thumbnailUrl"\s*:\s*"(https?:\\?/\\?/[^"]+)"', caseSensitive: false).firstMatch(jsonText);
      if (thumbMatch != null) {
        cover = thumbMatch.group(1)?.replaceAll(r'\/', '/').trim() ?? cover;
      }
      if (directVideoUrl != null && directVideoUrl.isNotEmpty) break;
    }

    // 2. Try to find <source src="..." type="application/x-mpegURL"> or <video src="...">
    if (directVideoUrl == null || directVideoUrl.isEmpty) {
      final sourceEl = doc.querySelector('video source[src], video[src], source[src]');
      final src = sourceEl?.attributes['src']?.trim();
      if (src != null && src.isNotEmpty) {
        directVideoUrl = src.startsWith('http') ? src : '$kBaseUrl$src';
      }
    }

    // 3. Try to find JavaScript player variable video_url / file / source
    if (directVideoUrl == null || directVideoUrl.isEmpty) {
      final jsMatch = RegExp(
        r'(?:video_url|videoUrl|file|source|src)\s*[:=]\s*["\x27](https?:\\?/\\?/[^"\x27]+\.(?:m3u8|mp4|webm)[^"\x27]*)["\x27]',
        caseSensitive: false,
      ).firstMatch(html);
      if (jsMatch != null) {
        directVideoUrl = jsMatch.group(1)?.replaceAll(r'\/', '/').trim();
      }
    }

    // 4. Try to find direct download link
    if (directVideoUrl == null || directVideoUrl.isEmpty) {
      final downloadEl = doc.querySelector('a[href*=".mp4"], a[href*=".m3u8"], a[href*=".webm"]');
      final href = downloadEl?.attributes['href']?.trim();
      if (href != null && href.isNotEmpty) {
        directVideoUrl = href.startsWith('http') ? href : '$kBaseUrl$href';
      }
    }

    // 5. Extract video poster
    final videoEl = doc.querySelector('video[poster]');
    final poster = videoEl?.attributes['poster']?.trim();
    if (poster != null && poster.isNotEmpty) {
      cover = poster.startsWith('http') ? poster : '$kBaseUrl$poster';
    }

    // 6. Extract tags
    final tagElements = doc.querySelectorAll('a[href*="/search/tag/"], a[href*="/tag/"]');
    for (final el in tagElements) {
      final t = el.text.trim();
      if (t.isNotEmpty && !tags.contains(t)) {
        tags.add(t);
      }
    }

    // 7. Extract duration if present
    final durEl = doc.querySelector('.duration, .time, span.duration');
    if (durEl != null && durEl.text.trim().isNotEmpty) {
      duration = durEl.text.trim();
    } else {
      final durationMatch = RegExp(r'(?:时长|Duration|Time)[:：\s]*([0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?)', caseSensitive: false).firstMatch(html);
      if (durationMatch != null) {
        duration = durationMatch.group(1) ?? duration;
      }
    }

    return item.copyWith(
      coverUrl: cover.isNotEmpty ? cover : item.coverUrl,
      videoUrl: directVideoUrl,
      tags: tags.isNotEmpty ? tags : item.tags,
      duration: duration.isNotEmpty ? duration : item.duration,
      isDetailLoaded: true,
    );
  }

  /// Parse video tags from /tag-list/all/ using DOM parser
  static List<RankingTagItem> parseVideoTags(String html) {
    final List<RankingTagItem> items = [];
    final seen = <String>{};
    final doc = html_parser.parse(html);

    final tagLinks = doc.querySelectorAll('a[href*="/search/tag/"], a[href*="/tag/"]');
    for (final el in tagLinks) {
      final rawHref = el.attributes['href']?.trim() ?? '';
      var rawName = el.text.trim();

      if (rawName.isEmpty || rawName == '首页' || rawName == '下一页' || rawName == '上一页') {
        continue;
      }

      // Extract optional count e.g. (1234)
      String count = '';
      final countSpan = el.parent?.querySelector('span') ?? el.querySelector('span');
      if (countSpan != null) {
        count = countSpan.text.replaceAll(RegExp(r'[(),\s]'), '');
      } else {
        final match = RegExp(r'\(([\d,]+)\)').firstMatch(el.parent?.text ?? '');
        if (match != null) {
          count = match.group(1)?.replaceAll(',', '') ?? '';
        }
      }

      rawName = rawName.replaceAll(RegExp(r'\s*\([\d,]+\)\s*$'), '').trim();
      final fullUrl = rawHref.startsWith('http') ? rawHref : '$kBaseUrl$rawHref';

      if (!seen.contains(rawName) && rawName.isNotEmpty) {
        seen.add(rawName);
        items.add(
          RankingTagItem(
            name: rawName,
            count: count,
            targetUrl: fullUrl,
            isTag: true,
          ),
        );
      }
    }

    return items;
  }

  /// Fetch online video page data
  static Future<VideoApiResponse?> fetchVideoPageData({
    VideoCategory category = VideoCategory.latest,
    String? keyword,
    String? tag,
    required int page,
    int retryCount = 3,
  }) async {
    if (!_initialized) _recreateDio();

    final url = buildBrowseUrl(
      category: category,
      keyword: keyword,
      tag: tag,
      page: page,
    );

    for (int i = 0; i < retryCount; i++) {
      try {
        final response = await _dio.get(
          url,
          options: Options(
            responseType: ResponseType.plain,
            headers: {
              'Referer': '$kBaseUrl/',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final html = response.data.toString();
          final items = parseVideoList(html);
          final totalPages = parseTotalPages(html, page, items.length);
          final totalItems = totalPages * 24;

          return VideoApiResponse(
            items: items,
            total: totalItems,
            pageSize: 24,
            page: page,
            totalPages: totalPages > 0 ? totalPages : 1,
          );
        }
      } catch (e) {
        if (i < retryCount - 1) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }
    }
    return null;
  }

  /// Fetch video detail
  static Future<VideoItem?> fetchVideoDetail(
    VideoItem item, {
    int retryCount = 3,
  }) async {
    if (!_initialized) _recreateDio();

    for (int i = 0; i < retryCount; i++) {
      try {
        final response = await _dio.get(
          item.detailUrl,
          options: Options(
            responseType: ResponseType.plain,
            headers: {
              'Referer': '$kBaseUrl/',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final html = response.data.toString();
          return parseVideoDetail(html, item);
        }
      } catch (e) {
        if (i < retryCount - 1) {
          await Future.delayed(const Duration(milliseconds: 1200));
        }
      }
    }
    return item;
  }

  /// Fetch video tags with pagination
  static Future<RankingTagsResponse?> fetchVideoTags({
    required int page,
    int retryCount = 3,
  }) async {
    if (!_initialized) _recreateDio();

    final url = buildTagsUrl(page: page);

    for (int i = 0; i < retryCount; i++) {
      try {
        final response = await _dio.get(
          url,
          options: Options(
            responseType: ResponseType.plain,
            headers: {
              'Referer': '$kBaseUrl/',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final html = response.data.toString();
          final items = parseVideoTags(html);
          final totalPages = parseTotalPages(html, page, items.length);

          return RankingTagsResponse(
            items: items,
            page: page,
            totalPages: totalPages > 0 ? totalPages : 1,
          );
        }
      } catch (e) {
        if (i < retryCount - 1) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }
    }
    return null;
  }
}
