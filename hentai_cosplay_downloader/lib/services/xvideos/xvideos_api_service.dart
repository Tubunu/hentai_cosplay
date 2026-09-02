import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';

/// Top-level mode when browsing all categories
enum XVideosMainMode {
  latest('最新发布'),
  best('最佳影片');

  final String label;
  const XVideosMainMode(this.label);
}

/// Category types on XVideos
enum XVideosCategoryType {
  canonical, // Type 1: /c/{path} (e.g. Asian_Woman-32)
  searchTag, // Type 2: /?k={path}&top (e.g. cosplay)
}

/// Sub-sorting modes when a category, search, or author profile is active
enum XVideosSubSort {
  none('默认', ''),
  latest('最新', 'uploaddate'),
  rating('评级', 'rating'),
  views('观看次数', 'views'),
  random('随机', 'random');

  final String label;
  final String code;
  const XVideosSubSort(this.label, this.code);
}

class XVideosCategoryItem {
  final String id;
  final String name;
  final String path; // e.g. "Asian_Woman-32" or "cosplay"
  final XVideosCategoryType type;
  final String? icon;

  const XVideosCategoryItem({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    this.icon,
  });

  bool get isAll => id.isEmpty || id == 'all';
}

class XVideosApiResponse {
  final List<VideoItem> items;
  final int page;
  final int totalPages;
  final int total;

  XVideosApiResponse({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

class XVideosApiService {
  static const String kBaseUrl = 'https://www.xvideos.com';

  static String? _configuredProxy;
  static Dio _dio = _createDio();

  /// Available categories verified with canonical IDs (Type 1) or reliable search tags (Type 2)
  static const List<XVideosCategoryItem> defaultCategories = [
    XVideosCategoryItem(
      id: 'all',
      name: '全部分类',
      path: '',
      type: XVideosCategoryType.canonical,
      icon: '🔥',
    ),
    // --- Type 1: Canonical Channel Categories (/c/...) ---
    XVideosCategoryItem(
      id: 'asian',
      name: '亚洲 (Asian Woman)',
      path: 'Asian_Woman-32',
      type: XVideosCategoryType.canonical,
      icon: '🌸',
    ),

    // --- Type 2: Tag & Topic Categories (100% Reliable via /?k=...&top) ---
    XVideosCategoryItem(
      id: 'cosplay',
      name: 'Cosplay (角色扮演)',
      path: 'cosplay',
      type: XVideosCategoryType.searchTag,
      icon: '🎭',
    ),
    XVideosCategoryItem(
      id: 'hentai',
      name: '动漫 / 里番 (Hentai)',
      path: 'hentai',
      type: XVideosCategoryType.searchTag,
      icon: '🎨',
    ),
    XVideosCategoryItem(
      id: 'japanese',
      name: '日本 (Japanese)',
      path: 'japanese',
      type: XVideosCategoryType.searchTag,
      icon: '🗾',
    ),
    XVideosCategoryItem(
      id: 'chinese',
      name: '中国 / 华语 (Chinese)',
      path: 'chinese',
      type: XVideosCategoryType.searchTag,
      icon: '🇨🇳',
    ),
    XVideosCategoryItem(
      id: 'korean',
      name: '韩国精选 (Korean)',
      path: 'korean',
      type: XVideosCategoryType.searchTag,
      icon: '🇰🇷',
    ),
    XVideosCategoryItem(
      id: 'amateur',
      name: '业余自拍 (Amateur)',
      path: 'amateur',
      type: XVideosCategoryType.searchTag,
      icon: '📱',
    ),
    XVideosCategoryItem(
      id: 'milf',
      name: '熟女人妻 (MILF)',
      path: 'milf',
      type: XVideosCategoryType.searchTag,
      icon: '💄',
    ),
    XVideosCategoryItem(
      id: 'teens',
      name: '少女年轻 (Teens 18+)',
      path: 'teens 18',
      type: XVideosCategoryType.searchTag,
      icon: '✨',
    ),
    XVideosCategoryItem(
      id: 'lesbian',
      name: '女同 (Lesbian)',
      path: 'lesbian',
      type: XVideosCategoryType.searchTag,
      icon: '👭',
    ),
    XVideosCategoryItem(
      id: 'blowjob',
      name: '口交 (Blowjob)',
      path: 'blowjob',
      type: XVideosCategoryType.searchTag,
      icon: '👄',
    ),
    XVideosCategoryItem(
      id: 'big-tits',
      name: '巨乳 (Big Tits)',
      path: 'big tits',
      type: XVideosCategoryType.searchTag,
      icon: '🍈',
    ),
    XVideosCategoryItem(
      id: 'big-ass',
      name: '美臀 (Big Ass)',
      path: 'big ass',
      type: XVideosCategoryType.searchTag,
      icon: '🍑',
    ),
    XVideosCategoryItem(
      id: 'pov',
      name: '第一视角 (POV)',
      path: 'pov',
      type: XVideosCategoryType.searchTag,
      icon: '👀',
    ),
    XVideosCategoryItem(
      id: 'hardcore',
      name: '硬核激情 (Hardcore)',
      path: 'hardcore',
      type: XVideosCategoryType.searchTag,
      icon: '⚡',
    ),
    XVideosCategoryItem(
      id: 'blonde',
      name: '金发女郎 (Blonde)',
      path: 'blonde',
      type: XVideosCategoryType.searchTag,
      icon: '👱‍♀️',
    ),
    XVideosCategoryItem(
      id: 'brunette',
      name: '黑发美女 (Brunette)',
      path: 'brunette',
      type: XVideosCategoryType.searchTag,
      icon: '👩',
    ),
    XVideosCategoryItem(
      id: 'redhead',
      name: '红发女郎 (Redhead)',
      path: 'redhead',
      type: XVideosCategoryType.searchTag,
      icon: '👩‍🦰',
    ),
    XVideosCategoryItem(
      id: 'pornstar',
      name: '明星名优 (Pornstar)',
      path: 'pornstar',
      type: XVideosCategoryType.searchTag,
      icon: '⭐',
    ),
    XVideosCategoryItem(
      id: 'massage',
      name: '精油按摩 (Massage)',
      path: 'massage',
      type: XVideosCategoryType.searchTag,
      icon: '💆',
    ),
    XVideosCategoryItem(
      id: 'public',
      name: '户外露出 (Public)',
      path: 'public',
      type: XVideosCategoryType.searchTag,
      icon: '🌲',
    ),
    XVideosCategoryItem(
      id: 'uniform',
      name: '制服诱惑 (Uniform)',
      path: 'uniform',
      type: XVideosCategoryType.searchTag,
      icon: '👗',
    ),
    XVideosCategoryItem(
      id: 'feet',
      name: '丝袜美腿 / 恋足 (Feet)',
      path: 'feet',
      type: XVideosCategoryType.searchTag,
      icon: '👠',
    ),
    XVideosCategoryItem(
      id: 'pantyhose',
      name: '连裤袜 (Pantyhose)',
      path: 'pantyhose',
      type: XVideosCategoryType.searchTag,
      icon: '🧦',
    ),
    XVideosCategoryItem(
      id: 'voyeur',
      name: '偷窥探秘 (Voyeur)',
      path: 'voyeur',
      type: XVideosCategoryType.searchTag,
      icon: '🔍',
    ),
    XVideosCategoryItem(
      id: 'squirt',
      name: '潮吹喷水 (Squirt)',
      path: 'squirt',
      type: XVideosCategoryType.searchTag,
      icon: '💦',
    ),
    XVideosCategoryItem(
      id: 'creampie',
      name: '内射泡芙 (Creampie)',
      path: 'creampie',
      type: XVideosCategoryType.searchTag,
      icon: '🥧',
    ),
    XVideosCategoryItem(
      id: 'bdsm',
      name: 'BDSM / 调教 (BDSM)',
      path: 'bdsm',
      type: XVideosCategoryType.searchTag,
      icon: '⛓️',
    ),
    XVideosCategoryItem(
      id: 'threesome',
      name: '三人行 (Threesome)',
      path: 'threesome',
      type: XVideosCategoryType.searchTag,
      icon: '👥',
    ),
    XVideosCategoryItem(
      id: 'female-masturbation',
      name: '自慰 (Solo Female)',
      path: 'female masturbation',
      type: XVideosCategoryType.searchTag,
      icon: '🖐️',
    ),
    XVideosCategoryItem(
      id: 'vr',
      name: 'VR 虚拟现实 (VR)',
      path: 'vr',
      type: XVideosCategoryType.searchTag,
      icon: '🥽',
    ),
    XVideosCategoryItem(
      id: 'sfm',
      name: '3D 动漫 / SFM',
      path: 'sfm',
      type: XVideosCategoryType.searchTag,
      icon: '🎮',
    ),
  ];

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

  /// Default month for Best Videos
  static String getDefaultBestMonth() {
    final months = getAvailableBestMonths(count: 2);
    return months.length > 1 ? months[1] : months.first;
  }

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
    _dio = _createDio();
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
          'Referer': '$kBaseUrl/',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
          'Cookie': 'hasVisited=1; age_verified=1;',
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
        client.findProxy = HttpClient.findProxyFromEnvironment;
      }
      return client;
    };
    dio.httpClientAdapter = adapter;

    return dio;
  }

  /// Build request URL based on XVideos exact specifications:
  /// 1. Home Latest: / and /new/{page-1}
  /// 2. Home Best: /best/{YYYY-MM} and /best/{YYYY-MM}/{page-1}
  /// 3. Category Type 1: /c/{path} or /c/s:{sort}/{path} and .../{page-1}
  /// 4. Category Type 2 & Search: /?k={kw}&top or /?k={kw}&sort={sort}&p={page-1}
  static String buildUrl({
    int page = 1,
    XVideosMainMode mainMode = XVideosMainMode.latest,
    String? selectedMonth,
    XVideosCategoryItem? category,
    XVideosSubSort subSort = XVideosSubSort.none,
    String? keyword,
  }) {
    final pageOffset = page > 1 ? page - 1 : 0;

    // 1. Keyword search
    if (keyword != null && keyword.trim().isNotEmpty) {
      final encodedKw = Uri.encodeComponent(keyword.trim());
      var url = '$kBaseUrl/?k=$encodedKw';
      if (subSort != XVideosSubSort.none && subSort.code.isNotEmpty) {
        url += '&sort=${subSort.code}';
      } else {
        url += '&top';
      }
      if (pageOffset > 0) {
        url += '&p=$pageOffset';
      }
      return url;
    }

    // 2. Specific Category is selected
    final isCategorySelected = category != null && !category.isAll;
    if (isCategorySelected) {
      if (category.type == XVideosCategoryType.canonical) {
        // Type 1: /c/...
        var sortSegment = '';
        if (subSort != XVideosSubSort.none && subSort != XVideosSubSort.random && subSort.code.isNotEmpty) {
          sortSegment = 's:${subSort.code}/';
        }
        if (pageOffset > 0) {
          return '$kBaseUrl/c/$sortSegment${category.path}/$pageOffset';
        }
        return '$kBaseUrl/c/$sortSegment${category.path}';
      } else {
        // Type 2: /?k={path}&...
        final encodedKw = Uri.encodeComponent(category.path);
        var url = '$kBaseUrl/?k=$encodedKw';
        if (subSort != XVideosSubSort.none && subSort.code.isNotEmpty) {
          url += '&sort=${subSort.code}';
        } else {
          url += '&top';
        }
        if (pageOffset > 0) {
          url += '&p=$pageOffset';
        }
        return url;
      }
    }

    // 3. Home / All Categories ("全部分类")
    if (mainMode == XVideosMainMode.best) {
      final month = (selectedMonth != null && selectedMonth.isNotEmpty)
          ? selectedMonth
          : getDefaultBestMonth();
      if (pageOffset > 0) {
        return '$kBaseUrl/best/$month/$pageOffset';
      }
      return '$kBaseUrl/best/$month';
    }

    // Latest (最新发布)
    if (pageOffset > 0) {
      return '$kBaseUrl/new/$pageOffset';
    }
    return '$kBaseUrl/';
  }

  /// Fetch page data from www.xvideos.com with automatic fallback
  static Future<XVideosApiResponse?> fetchPageData({
    int page = 1,
    XVideosMainMode mainMode = XVideosMainMode.latest,
    String? selectedMonth,
    XVideosCategoryItem? category,
    XVideosSubSort subSort = XVideosSubSort.none,
    String? keyword,
  }) async {
    try {
      final url = buildUrl(
        page: page,
        mainMode: mainMode,
        selectedMonth: selectedMonth,
        category: category,
        subSort: subSort,
        keyword: keyword,
      );
      debugPrint('[XVideosApiService] Fetching URL: $url');

      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final parsed = _parseListPageHtml(response.data!, page);
        if (parsed.items.isNotEmpty) {
          return parsed;
        }
      }

      // If category canonical URL returned 404 or 0 items, fallback to search tag
      if (category != null && !category.isAll && category.type == XVideosCategoryType.canonical) {
        debugPrint('[XVideosApiService] Canonical category empty or failed, trying fallback search for: ${category.path}');
        final fallbackUrl = buildUrl(
          page: page,
          category: XVideosCategoryItem(
            id: category.id,
            name: category.name,
            path: category.path.split('-').first.replaceAll('_', ' '),
            type: XVideosCategoryType.searchTag,
          ),
          subSort: subSort,
        );
        debugPrint('[XVideosApiService] Fallback URL: $fallbackUrl');
        final fbResponse = await _dio.get<String>(
          fallbackUrl,
          options: Options(
            responseType: ResponseType.plain,
            followRedirects: true,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        if (fbResponse.statusCode == 200 && fbResponse.data != null) {
          return _parseListPageHtml(fbResponse.data!, page);
        }
      }
    } catch (e) {
      debugPrint('[XVideosApiService] Error fetching page $page: $e');
    }
    return null;
  }

  /// Fetch videos from a specific author / channel / profile with fallback
  static Future<XVideosApiResponse?> fetchAuthorVideos({
    required String authorName,
    String? authorUrl,
    int page = 1,
    XVideosSubSort subSort = XVideosSubSort.none,
  }) async {
    try {
      final pageOffset = page > 1 ? page - 1 : 0;

      // 1. If authorUrl is a profile/channel link, try direct endpoint
      if (authorUrl != null && authorUrl.isNotEmpty && (authorUrl.contains('/channels/') || authorUrl.contains('/profiles/') || authorUrl.contains('/model/'))) {
        final cleanUrl = authorUrl.replaceAll(RegExp(r'/videos.*$'), '');
        String targetUrl;
        if (subSort == XVideosSubSort.views || subSort == XVideosSubSort.rating) {
          targetUrl = pageOffset > 0 ? '$cleanUrl/videos/best/$pageOffset' : '$cleanUrl/videos/best';
        } else {
          targetUrl = pageOffset > 0 ? '$cleanUrl/videos/new/$pageOffset' : '$cleanUrl/videos/new';
        }

        debugPrint('[XVideosApiService] Fetching Author direct URL: $targetUrl');
        final response = await _dio.get<String>(
          targetUrl,
          options: Options(
            responseType: ResponseType.plain,
            followRedirects: true,
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final parsed = _parseListPageHtml(response.data!, page);
          if (parsed.items.isNotEmpty) {
            return parsed;
          }
        }
      }

      // 2. Direct / Fallback Author Search
      debugPrint('[XVideosApiService] Fetching Author via keyword search: $authorName, sort: $subSort, page: $page');
      final searchUrl = buildUrl(
        page: page,
        keyword: authorName,
        subSort: subSort,
      );
      final response = await _dio.get<String>(
        searchUrl,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return _parseListPageHtml(response.data!, page);
      }
    } catch (e) {
      debugPrint('[XVideosApiService] Error fetching author videos: $e');
    }
    return null;
  }

  /// Parse HTML video items list with accurate full titles and details
  static XVideosApiResponse _parseListPageHtml(String html, int requestedPage) {
    final document = html_parser.parse(html);
    final List<VideoItem> items = [];
    final seenSlugs = <String>{};

    // XVideos thumb blocks: div.thumb-block, div.mozaique > div, div[id^="video_"], .thumb-block, div.video-block
    final videoElements = document.querySelectorAll(
      'div.thumb-block, div.mozaique > div, div[id^="video_"], .thumb-block, div.video-block',
    );

    for (final elem in videoElements) {
      try {
        // 1. Extract accurate Title and detail link from .thumb-under or p.title
        var title = '';
        var href = '';

        final titleAnchor = elem.querySelector(
          '.thumb-under p.title a, p.title a, .thumb-under a.title, .thumb-under a[href*="/video"], p.title',
        );

        if (titleAnchor != null) {
          title = titleAnchor.attributes['title']?.trim() ??
              titleAnchor.attributes['_title']?.trim() ??
              titleAnchor.text.trim();
          href = titleAnchor.attributes['href'] ?? '';
        }

        // Fallback to any video anchor in the card if href or title is missing
        if (href.isEmpty || href == '#') {
          final anyVideoAnchor = elem.querySelector('a[href*="/video"]');
          href = anyVideoAnchor?.attributes['href'] ?? '';
          if (title.isEmpty) {
            title = anyVideoAnchor?.attributes['title']?.trim() ??
                anyVideoAnchor?.attributes['_title']?.trim() ??
                '';
          }
        }

        if (href.isEmpty || href == '#' || !href.contains('/video')) continue;

        if (!href.startsWith('http')) {
          if (!href.startsWith('/')) href = '/$href';
          href = '$kBaseUrl$href';
        }

        // Extract Video ID / Slug
        final idMatch = RegExp(r'/video[._]?([a-zA-Z0-9_-]+)/?').firstMatch(href);
        final rawId = idMatch?.group(1) ??
            elem.attributes['data-id'] ??
            elem.attributes['id']?.replaceFirst('video_', '') ??
            '';
        final slug = rawId.isNotEmpty
            ? 'xvideos_$rawId'
            : href.split('/').where((s) => s.isNotEmpty).last;

        if (!seenSlugs.add(slug)) continue;

        // Clean and fallback title
        if (title.isEmpty || RegExp(r'^\d+\s*min$', caseSensitive: false).hasMatch(title)) {
          final pTitle = elem.querySelector('p.title, .thumb-under p.title, .title');
          title = pTitle?.attributes['title']?.trim() ?? pTitle?.text.trim() ?? '';
        }

        if (title.isEmpty || RegExp(r'^\d+\s*min$', caseSensitive: false).hasMatch(title)) {
          final match = RegExp(r'/video[._]?[a-zA-Z0-9_-]+/([^/?#]+)').firstMatch(href);
          if (match != null) {
            title = Uri.decodeComponent(match.group(1)!.replaceAll('_', ' '));
          } else {
            title = 'XVideos $rawId';
          }
        }

        // Thumbnail / Cover image
        final imgElem = elem.querySelector('img');
        var coverUrl = imgElem?.attributes['data-src'] ??
            imgElem?.attributes['data-srcset'] ??
            imgElem?.attributes['data-thumb-url'] ??
            imgElem?.attributes['src'] ??
            '';

        if (coverUrl.contains('blank.gif') || coverUrl.contains('data:image')) {
          coverUrl = imgElem?.attributes['data-src'] ?? imgElem?.attributes['data-thumb-url'] ?? '';
        }

        if (coverUrl.startsWith('//')) {
          coverUrl = 'https:$coverUrl';
        } else if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = '$kBaseUrl$coverUrl';
        }

        // Duration
        final durationElem = elem.querySelector('span.duration, var.duration, .duration, span.bg .duration');
        final duration = durationElem?.text.trim() ?? '';

        // Views & Rating from metadata
        final metadataElem = elem.querySelector('p.metadata, .metadata, span.bg');
        var views = '';
        if (metadataElem != null) {
          final text = metadataElem.text.replaceAll(RegExp(r'\s+'), ' ').trim();
          views = text;
        }
        if (views.isEmpty) {
          views = 'XVideos HD';
        }

        // Author / Channel / Uploader
        final authorElem = elem.querySelector('p.metadata .name a, .name a, .uploader-tag a, .metadata a, .name, .profile-name');
        final author = authorElem?.text.trim().isNotEmpty == true
            ? authorElem!.text.trim()
            : 'XVideos';
        var authorHref = authorElem?.attributes['href'] ?? '';
        if (authorHref.isNotEmpty && !authorHref.startsWith('http')) {
          if (!authorHref.startsWith('/')) authorHref = '/$authorHref';
          authorHref = '$kBaseUrl$authorHref';
        }

        items.add(
          VideoItem(
            title: title,
            slug: slug,
            detailUrl: href,
            coverUrl: coverUrl.isNotEmpty ? coverUrl : null,
            duration: duration,
            author: author,
            views: views,
            date: '今日热门',
            tags: ['XVideos', '1080P/HD', author],
            videoUrl: null,
            isDetailLoaded: false,
            rawData: {
              'videoId': rawId,
              'detailUrl': href,
              if (authorHref.isNotEmpty) 'authorUrl': authorHref,
            },
          ),
        );
      } catch (e) {
        debugPrint('[XVideosApiService] Error parsing video element: $e');
      }
    }

    // Estimate total pages from pagination controls
    int totalPages = requestedPage;
    final pageLinks = document.querySelectorAll(
      'div.pagination ul li a, .pagination a, .page-number, .page_next, a[href*="p="], a[href*="/new/"], a[href*="/best/"]',
    );
    for (final pl in pageLinks) {
      final pageNum = int.tryParse(pl.text.trim());
      if (pageNum != null && pageNum > totalPages) {
        totalPages = pageNum;
      }
      final href = pl.attributes['href'] ?? '';
      final pageMatch = RegExp(r'[pP]=(\d+)').firstMatch(href) ??
          RegExp(r'/new/(\d+)').firstMatch(href) ??
          RegExp(r'/best/(?:\d{4}-\d{2}|month|year)/(\d+)').firstMatch(href) ??
          RegExp(r'/c/(?:[^/]+/)*(\d+)').firstMatch(href);
      if (pageMatch != null) {
        final p = int.tryParse(pageMatch.group(1)!);
        if (p != null && (p + 1) > totalPages) totalPages = p + 1;
      }
    }

    if (totalPages <= requestedPage && items.isNotEmpty) {
      totalPages = requestedPage + 1;
    }

    return XVideosApiResponse(
      items: items,
      page: requestedPage,
      totalPages: totalPages,
      total: items.length * totalPages,
    );
  }

  /// Resolve direct video stream from video page HTML
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    if (item.isDetailLoaded &&
        item.videoUrl != null &&
        item.videoUrl!.isNotEmpty &&
        item.videoUrl != item.detailUrl) {
      return item;
    }

    try {
      debugPrint('[XVideosApiService] Resolving video detail: ${item.detailUrl}');
      final response = await _dio.get<String>(
        item.detailUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        final rawHtml = response.data!;
        final document = html_parser.parse(rawHtml);

        String? directVideoUrl;
        String? hlsUrl;
        String? highMp4Url;
        String? lowMp4Url;

        // 1. Extract HTML5 Player parameters from JavaScript
        // html5player.setVideoHLS('https://...');
        final hlsMatch = RegExp(r"html5player\.setVideoHLS\s*\(\s*['" '"' r"]([^'" '"' r"]+)['" '"' r"]\s*\)").firstMatch(rawHtml);
        if (hlsMatch != null) {
          hlsUrl = hlsMatch.group(1);
        }

        // html5player.setVideoUrlHigh('https://...');
        final highMatch = RegExp(r"html5player\.setVideoUrlHigh\s*\(\s*['" '"' r"]([^'" '"' r"]+)['" '"' r"]\s*\)").firstMatch(rawHtml);
        if (highMatch != null) {
          highMp4Url = highMatch.group(1);
        }

        // html5player.setVideoUrlLow('https://...');
        final lowMatch = RegExp(r"html5player\.setVideoUrlLow\s*\(\s*['" '"' r"]([^'" '"' r"]+)['" '"' r"]\s*\)").firstMatch(rawHtml);
        if (lowMatch != null) {
          lowMp4Url = lowMatch.group(1);
        }

        // Choose highest quality stream available (prefer HLS master playlist or High MP4)
        directVideoUrl = hlsUrl ?? highMp4Url ?? lowMp4Url;

        // 2. Fallback regex for .m3u8 or .mp4 URLs in rawHtml
        if (directVideoUrl == null || directVideoUrl.isEmpty) {
          final m3u8Match = RegExp(r'(https?://[^\s"<>&]+?\.m3u8[^\s"<>&]*)').firstMatch(rawHtml);
          if (m3u8Match != null) {
            directVideoUrl = m3u8Match.group(1);
          }
        }

        if (directVideoUrl == null || directVideoUrl.isEmpty) {
          final mp4Match = RegExp(r'(https?://[^\s"<>&]+?\.mp4[^\s"<>&]*)').firstMatch(rawHtml);
          if (mp4Match != null) {
            directVideoUrl = mp4Match.group(1);
          }
        }

        // 3. Extract high quality poster cover if available
        var cover = item.coverUrl;
        final thumb169Match = RegExp(r"html5player\.setThumbUrl169\s*\(\s*['" '"' r"]([^'" '"' r"]+)['" '"' r"]\s*\)").firstMatch(rawHtml);
        if (thumb169Match != null && thumb169Match.group(1)!.isNotEmpty) {
          cover = thumb169Match.group(1);
        } else {
          final thumbMatch = RegExp(r"html5player\.setThumbUrl\s*\(\s*['" '"' r"]([^'" '"' r"]+)['" '"' r"]\s*\)").firstMatch(rawHtml);
          if (thumbMatch != null && thumbMatch.group(1)!.isNotEmpty) {
            cover = thumbMatch.group(1);
          }
        }

        // 4. Extract author & profile link
        final authorElem = document.querySelector('.main-uploader .name a, .uploader-tag a, a[href*="/channels/"], a[href*="/profiles/"], a[href*="/model/"]');
        final author = authorElem?.text.trim().isNotEmpty == true ? authorElem!.text.trim() : item.author;
        var authorHref = authorElem?.attributes['href'] ?? '';
        if (authorHref.isNotEmpty && !authorHref.startsWith('http')) {
          if (!authorHref.startsWith('/')) authorHref = '/$authorHref';
          authorHref = '$kBaseUrl$authorHref';
        }

        // 5. Extract tags
        final tags = <String>['XVideos'];
        final tagElements = document.querySelectorAll(
          '.video-tags a, .tags-list a, .video-metadata .tags a, a[href*="/tags/"], a[href*="/c/"], a[href*="/pornstars/"], a[href*="/channels/"]',
        );
        for (final t in tagElements) {
          final text = t.text.trim();
          if (text.isNotEmpty && !tags.contains(text) && text.length < 25 && !text.contains('Edit')) {
            tags.add(text);
          }
        }

        // Validate stream URL format
        if (directVideoUrl != null &&
            (!directVideoUrl.startsWith('http') ||
                directVideoUrl.isEmpty ||
                (!directVideoUrl.contains('.mp4') && !directVideoUrl.contains('.m3u8')))) {
          directVideoUrl = null;
        }

        final updatedRawData = Map<String, dynamic>.from(item.rawData);
        if (authorHref.isNotEmpty) {
          updatedRawData['authorUrl'] = authorHref;
        }

        return item.copyWith(
          author: author,
          coverUrl: cover,
          videoUrl: directVideoUrl ?? item.detailUrl,
          tags: tags.isNotEmpty ? tags : item.tags,
          isDetailLoaded: true,
          rawData: updatedRawData,
        );
      }
    } catch (e) {
      debugPrint('[XVideosApiService] Error resolving video detail: $e');
    }

    return item;
  }
}
