import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
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
        final clean = _configuredProxy!.replaceAll('http://', '').replaceAll('https://', '');
        client.findProxy = (uri) => 'PROXY $clean; DIRECT';
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

  /// Parse video items from HTML
  static List<VideoItem> parseVideoList(String html) {
    final List<VideoItem> items = [];
    final seen = <String>{};

    // 1. Identify distinct card blocks (li data-grid-item / board-item / video-list-item)
    var cardBlockMatches = RegExp(
      r'<li[^>]*data-(?:grid-item|select-item)[^>]*>[\s\S]*?</li>',
      caseSensitive: false,
    ).allMatches(html);

    if (cardBlockMatches.isEmpty) {
      cardBlockMatches = RegExp(
        r'<(?:div|li)[^>]*class=["\x27][^"\x27]*(?:board-item|video-list-item|post-item|image-list-item|card)[^"\x27]*["\x27][\s\S]*?</(?:div|li)>',
        caseSensitive: false,
      ).allMatches(html);
    }

    if (cardBlockMatches.isNotEmpty) {
      for (final cardMatch in cardBlockMatches) {
        final cardHtml = cardMatch.group(0) ?? '';

        // Extract detail href (must be a /video/ or /post/ link)
        final hrefMatch = RegExp(
          r'<a\s+[^>]*href=["\x27]([^"\x27]*(?:/video/|/post/)[^"\x27]+)["\x27]',
          caseSensitive: false,
        ).firstMatch(cardHtml);
        final rawHref = hrefMatch?.group(1)?.trim() ?? '';
        if (rawHref.isEmpty) continue;

        final fullDetailUrl = rawHref.startsWith('http') ? rawHref : '$kBaseUrl$rawHref';
        final slugMatch = RegExp(r'/(?:video|post)/([^/]+)/').firstMatch(fullDetailUrl);
        final slug = slugMatch?.group(1) ?? fullDetailUrl.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

        if (seen.contains(slug)) continue;

        // Extract cover image
        final imgMatch = RegExp(r'<img\s+[^>]*src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(cardHtml);
        final rawImg = imgMatch?.group(1)?.trim() ?? '';
        final fullCoverUrl = rawImg.isEmpty
            ? ''
            : (rawImg.startsWith('http') ? rawImg : '$kBaseUrl$rawImg');

        // Extract title: from h1/h2/h3/h4/p/span with class title/name/value OR img alt
        final titleMatch = RegExp(
          r'<(?:h1|h2|h3|h4|p|span)[^>]*class=["\x27][^"\x27]*(?:title|name|value)[^"\x27]*["\x27][^>]*>[\s\S]*?([^<>]+)(?:</h3>|</h2>|</h1>|</p>|</span>|</a>)',
          caseSensitive: false,
        ).firstMatch(cardHtml);
        var title = titleMatch?.group(1)?.trim() ?? '';
        if (title.isEmpty) {
          final altMatch = RegExp(r'<img\s+[^>]*alt=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(cardHtml);
          title = altMatch?.group(1)?.trim() ?? '';
        }
        if (title.isEmpty) {
          title = slug;
        }

        // Extract tags
        final tagMatches = RegExp(r'<a\s+[^>]*href=["\x27][^"\x27]*/search/tag/[^"\x27]+["\x27][^>]*>([^<]+)</a>', caseSensitive: false).allMatches(cardHtml);
        final tags = <String>[];
        for (final tm in tagMatches) {
          final tagText = tm.group(1)?.trim() ?? '';
          if (tagText.isNotEmpty && !tags.contains(tagText)) {
            tags.add(tagText);
          }
        }

        // Extract duration
        final durMatch = RegExp(r'<(?:span|div|p)[^>]*class=["\x27][^"\x27]*(?:duration|time)[^"\x27]*["\x27][^>]*>([^<]+)</', caseSensitive: false).firstMatch(cardHtml);
        final duration = durMatch?.group(1)?.trim() ?? '';

        // Extract date
        final dateMatch = RegExp(r'<(?:span|div|p)[^>]*class=["\x27][^"\x27]*(?:regist-date|date)[^"\x27]*["\x27][^>]*>([^<]+)</', caseSensitive: false).firstMatch(cardHtml);
        final date = dateMatch?.group(1)?.trim() ?? '';

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
    }

    return items;
  }

  /// Parse total pages from pagination
  static int parseTotalPages(String html, int currentPage, int fallbackItemCount) {
    // 1. wp-pagenavi last page link
    final lastPageMatch = RegExp(r'<a\s+class=["\x27]last["\x27][^>]*href=["\x27][^"\x27]*/page/([0-9]+)/["\x27]').firstMatch(html);
    if (lastPageMatch != null) {
      final p = int.tryParse(lastPageMatch.group(1) ?? '');
      if (p != null && p > 0) return p;
    }

    // 2. All /page/N/ matches
    final allPageMatches = RegExp(r'/page/([0-9]+)/').allMatches(html);
    int maxPage = currentPage;
    for (final m in allPageMatches) {
      final p = int.tryParse(m.group(1) ?? '');
      if (p != null && p > maxPage) {
        maxPage = p;
      }
    }

    // 3. Check for next page link in paginator-container (navigate_next / arrow_forward_ios)
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

    // 1. Extract from JSON-LD Schema VideoObject (Most reliable)
    final jsonLdMatch = RegExp(
      r'"contentUrl"\s*:\s*"(https?:\\?/\\?/[^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);

    if (jsonLdMatch != null) {
      directVideoUrl = jsonLdMatch.group(1)?.replaceAll(r'\/', '/').trim();
    }

    // 2. Try to find <source src="..." type="application/x-mpegURL"> or <source src="...">
    if (directVideoUrl == null || directVideoUrl.isEmpty) {
      final sourceMatch = RegExp(
        r'<(?:source|video)[^>]*src=["\x27]([^"\x27]+\.(?:m3u8|mp4|webm|mov)[^"\x27]*)["\x27]',
        caseSensitive: false,
      ).firstMatch(html);

      if (sourceMatch != null) {
        directVideoUrl = sourceMatch.group(1)?.trim();
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
      final downloadMatch = RegExp(
        r'<a[^>]*href=["\x27]([^"\x27]+\.(?:mp4|m3u8|webm)[^"\x27]*)["\x27][^>]*>(?:下载|Download|High Quality)',
        caseSensitive: false,
      ).firstMatch(html);
      if (downloadMatch != null) {
        directVideoUrl = downloadMatch.group(1)?.trim();
      }
    }

    // 5. Extract video poster
    final posterMatch = RegExp(r'<video[^>]*poster=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(html);
    if (posterMatch != null) {
      cover = posterMatch.group(1)?.trim() ?? cover;
    } else {
      final jsonThumbMatch = RegExp(r'"thumbnailUrl"\s*:\s*"(https?:\\?/\\?/[^"]+)"').firstMatch(html);
      if (jsonThumbMatch != null) {
        cover = jsonThumbMatch.group(1)?.replaceAll(r'\/', '/').trim() ?? cover;
      }
    }

    // 6. Extract tags
    final tagMatches = RegExp(r'<a\s+[^>]*href=["\x27][^"\x27]*/search/tag/([^/]+)/["\x27][^>]*>([^<]+)</a>', caseSensitive: false).allMatches(html);
    for (final tm in tagMatches) {
      final t = tm.group(2)?.trim();
      if (t != null && t.isNotEmpty && !tags.contains(t)) {
        tags.add(t);
      }
    }

    // 7. Extract duration if present
    final durationMatch = RegExp(r'(?:时长|Duration|Time)[:：\s]*([0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?)', caseSensitive: false).firstMatch(html);
    if (durationMatch != null) {
      duration = durationMatch.group(1) ?? duration;
    }

    return item.copyWith(
      coverUrl: cover.isNotEmpty ? cover : item.coverUrl,
      videoUrl: directVideoUrl,
      tags: tags.isNotEmpty ? tags : item.tags,
      duration: duration.isNotEmpty ? duration : item.duration,
      isDetailLoaded: true,
    );
  }

  /// Parse video tags from /tag-list/all/
  static List<RankingTagItem> parseVideoTags(String html) {
    final List<RankingTagItem> items = [];
    final seen = <String>{};

    final tagRegex = RegExp(
      r'<a\s+[^>]*href=["\x27]([^"\x27]*(?:/search/tag/|/tag/)[^"\x27]+)["\x27][^>]*>([\s\S]*?)</a>(?:[\s\S]*?(?:<span>\s*\(?\s*([0-9,]+)\s*\)?\s*</span>|\(\s*([0-9,]+)\s*\)))?',
      caseSensitive: false,
    );

    final matches = tagRegex.allMatches(html);
    for (final m in matches) {
      final rawHref = m.group(1)?.trim() ?? '';
      var rawName = m.group(2)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '';
      final count = (m.group(3) ?? m.group(4) ?? '').replaceAll(',', '').trim();

      if (rawName.isEmpty || rawName == '首页' || rawName == '下一页' || rawName == '上一页') {
        continue;
      }
      rawName = rawName.replaceAll(RegExp(r'\s*\([0-9,]+\)\s*$'), '').trim();
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
