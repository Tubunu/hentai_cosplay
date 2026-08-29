import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';

enum PornhubSortOrder {
  hottest('热门推荐', 'ht'),
  mostViewed('最多播放', 'mv'),
  topRated('最高好评', 'tr'),
  newest('最新发布', 'mr'),
  longest('超长精选', 'lg');

  final String label;
  final String orderCode;
  const PornhubSortOrder(this.label, this.orderCode);
}

class PornhubCategoryItem {
  final String id;
  final String name;
  final String slug;
  final String? icon;
  final bool isSearch;

  const PornhubCategoryItem({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.isSearch = false,
  });
}

class PornhubApiResponse {
  final List<VideoItem> items;
  final int page;
  final int totalPages;
  final int total;

  PornhubApiResponse({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

class PornhubApiService {
  static const String kBaseUrl = 'https://cn.pornhub.com';

  static String? _configuredProxy;
  static Dio _dio = _createDio();

  /// Built-in rich predefined categories from Pornhub with Chinese translations & canonical category slugs
  static const List<PornhubCategoryItem> defaultCategories = [
    PornhubCategoryItem(id: '', name: '全部分类', slug: 'all', icon: '🔥'),
    PornhubCategoryItem(id: '241', name: 'Cosplay (角色扮演)', slug: 'cosplay', icon: '🎭', isSearch: true),
    PornhubCategoryItem(id: '36', name: '动漫 / 里番 (Hentai)', slug: 'hentai', icon: '🎨'),
    PornhubCategoryItem(id: '1', name: '亚洲 (Asian)', slug: 'asian', icon: '🌸'),
    PornhubCategoryItem(id: '111', name: '日本 (Japanese)', slug: 'japanese', icon: '🗾'),
    PornhubCategoryItem(id: '115', name: '中国 / 华语 (Chinese)', slug: 'chinese', icon: '🇨🇳', isSearch: true),
    PornhubCategoryItem(id: '3', name: '业余自拍 (Amateur)', slug: 'amateur', icon: '📱'),
    PornhubCategoryItem(id: '13', name: '少女年轻 (Teen 18+)', slug: 'teen', icon: '✨'),
    PornhubCategoryItem(id: '8', name: '熟女人妻 (MILF)', slug: 'milf', icon: '💄'),
    PornhubCategoryItem(id: '7', name: '巨乳 (Big Tits)', slug: 'big-tits', icon: '🍈'),
    PornhubCategoryItem(id: '6', name: '美臀 (Big Ass)', slug: 'big-ass', icon: '🍑'),
    PornhubCategoryItem(id: '14', name: '口交 (Blowjob)', slug: 'blowjob', icon: '👄'),
    PornhubCategoryItem(id: '43', name: '第一视角 (POV)', slug: 'pov', icon: '👀'),
    PornhubCategoryItem(id: '104', name: 'VR 虚拟现实 (VR)', slug: 'vr', icon: '🥽'),
    PornhubCategoryItem(id: '28', name: '女同 (Lesbian)', slug: 'lesbian', icon: '👭'),
    PornhubCategoryItem(id: '19', name: '自慰 (Solo Female)', slug: 'solo-female', icon: '🖐️'),
    PornhubCategoryItem(id: '65', name: '三人行 (Threesome)', slug: 'threesome', icon: '👥'),
    PornhubCategoryItem(id: '18', name: '硬核激情 (Hardcore)', slug: 'hardcore', icon: '⚡'),
    PornhubCategoryItem(id: '9', name: '金发女郎 (Blonde)', slug: 'blonde', icon: '👱‍♀️'),
    PornhubCategoryItem(id: '10', name: '黑发美女 (Brunette)', slug: 'brunette', icon: '👩'),
    PornhubCategoryItem(id: '11', name: '红发女郎 (Redhead)', slug: 'redhead', icon: '👩‍🦰'),
    PornhubCategoryItem(id: '15', name: '明星网黄 (Pornstar)', slug: 'pornstar', icon: '⭐'),
    PornhubCategoryItem(id: '79', name: '精油按摩 (Massage)', slug: 'massage', icon: '💆'),
    PornhubCategoryItem(id: '23', name: '户外露出 (Public)', slug: 'public', icon: '🌲'),
    PornhubCategoryItem(id: '138', name: '真实情侣 (Verified Couples)', slug: 'verified-couples', icon: '💑'),
    PornhubCategoryItem(id: '84', name: '制服诱惑 (Roleplay)', slug: 'roleplay', icon: '👗'),
    PornhubCategoryItem(id: '95', name: '丝袜美腿 / 恋足 (Feet)', slug: 'feet', icon: '👠'),
    PornhubCategoryItem(id: '102', name: '连裤袜 (Pantyhose)', slug: 'pantyhose', icon: '🧦'),
    PornhubCategoryItem(id: '41', name: '偷窥探秘 (Voyeur)', slug: 'voyeur', icon: '🔍'),
    PornhubCategoryItem(id: '78', name: '高潮喷射 (Female Orgasm)', slug: 'female-orgasm', icon: '🌊'),
    PornhubCategoryItem(id: '75', name: '深喉 (Deepthroat)', slug: 'deepthroat', icon: '🔥'),
    PornhubCategoryItem(id: '16', name: '颜射 (Cumshot)', slug: 'cumshot', icon: '💥'),
    PornhubCategoryItem(id: '20', name: '手交 (Handjob)', slug: 'handjob', icon: '✋'),
    PornhubCategoryItem(id: '125', name: '街头采访 (Interviews)', slug: 'interviews', icon: '🎤'),
    PornhubCategoryItem(id: '5', name: 'BDSM / 调教 (BDSM)', slug: 'bdsm', icon: '⛓️'),
    PornhubCategoryItem(id: '201', name: '3D 动漫 / SFM', slug: 'sfm', icon: '🎮', isSearch: true),
    PornhubCategoryItem(id: '30', name: '复古经典 (Vintage)', slug: 'vintage', icon: '📼'),
    PornhubCategoryItem(id: '73', name: '大学生 (College 18+)', slug: 'college-18', icon: '🎓'),
    PornhubCategoryItem(id: '103', name: '粗暴激情 (Rough Sex)', slug: 'rough-sex', icon: '💥'),
    PornhubCategoryItem(id: '4', name: '黑人美女 (Ebony)', slug: 'ebony', icon: '🍫'),
    PornhubCategoryItem(id: '2', name: '拉丁风情 (Latina)', slug: 'latina', icon: '💃'),
    PornhubCategoryItem(id: '37', name: '潮吹喷水 (Squirt)', slug: 'squirt', icon: '💦'),
    PornhubCategoryItem(id: '35', name: '肛交探秘 (Anal)', slug: 'anal', icon: '🍑'),
    PornhubCategoryItem(id: '21', name: '内射泡芙 (Creampie)', slug: 'creampie', icon: '🥧'),
    PornhubCategoryItem(id: '80', name: '群交派对 (Gangbang)', slug: 'gangbang', icon: '🎉'),
    PornhubCategoryItem(id: '89', name: '保姆女仆 (Babysitter)', slug: 'babysitter', icon: '🧹'),
    PornhubCategoryItem(id: '33', name: '脱衣诱惑 (Striptease)', slug: 'striptease', icon: '👙'),
    PornhubCategoryItem(id: '90', name: '男士自慰 (Solo Male)', slug: 'solo-male', icon: '🙋‍♂️'),
    PornhubCategoryItem(id: '100', name: '完整原盘 (Uncut / Full)', slug: 'uncut', icon: '🎬'),
    PornhubCategoryItem(id: '112', name: '韩国精选 (Korean)', slug: 'korean', icon: '🇰🇷', isSearch: true),
    PornhubCategoryItem(id: '82', name: '微乳贫乳 (Small Tits)', slug: 'small-tits', icon: '🍒'),
    PornhubCategoryItem(id: '86', name: '幕后花絮 (Behind the Scenes)', slug: 'behind-the-scenes', icon: '🎥', isSearch: true),
  ];

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
          'Cookie':
              'age_verified=1; platform=pc; accessAgeDisclaimerPH=1; cookie_preferences=%7B%221%22%3A1%2C%222%22%3A1%2C%223%22%3A1%2C%224%22%3A1%7D; hasVisited=1;',
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

  /// Build request URL using canonical category paths or search routes
  static String buildUrl({
    int page = 1,
    PornhubSortOrder sortOrder = PornhubSortOrder.hottest,
    PornhubCategoryItem? category,
    String? categoryId,
    String? categorySlug,
    String? keyword,
  }) {
    if (keyword != null && keyword.trim().isNotEmpty) {
      final encodedKw = Uri.encodeComponent(keyword.trim());
      var url = '$kBaseUrl/video/search?search=$encodedKw';
      if (sortOrder.orderCode.isNotEmpty && sortOrder.orderCode != 'ht') {
        url += '&o=${sortOrder.orderCode}';
      }
      if (page > 1) {
        url += '&page=$page';
      }
      return url;
    }

    if (category != null && category.isSearch) {
      final encodedKw = Uri.encodeComponent(category.slug);
      var url = '$kBaseUrl/video/search?search=$encodedKw';
      if (sortOrder.orderCode.isNotEmpty && sortOrder.orderCode != 'ht') {
        url += '&o=${sortOrder.orderCode}';
      }
      if (page > 1) {
        url += '&page=$page';
      }
      return url;
    }

    final slug = category?.slug ?? categorySlug;
    final id = category?.id ?? categoryId;

    String path;
    if (slug != null && slug.isNotEmpty && slug != 'all') {
      path = '/categories/$slug';
    } else {
      path = '/video';
    }

    final queryParams = <String>[];

    if (path == '/video' && id != null && id.isNotEmpty && id != 'all' && (slug == null || slug.isEmpty || slug == 'all')) {
      queryParams.add('c=$id');
    }

    if (page > 1) {
      queryParams.add('page=$page');
    }

    // Only append order parameter if not default hottest
    if (sortOrder.orderCode.isNotEmpty && sortOrder.orderCode != 'ht') {
      queryParams.add('o=${sortOrder.orderCode}');
    }

    if (queryParams.isNotEmpty) {
      return '$kBaseUrl$path?${queryParams.join('&')}';
    }
    return '$kBaseUrl$path';
  }

  /// Fetch page data from cn.pornhub.com
  static Future<PornhubApiResponse?> fetchPageData({
    int page = 1,
    PornhubSortOrder sortOrder = PornhubSortOrder.hottest,
    PornhubCategoryItem? category,
    String? categoryId,
    String? keyword,
  }) async {
    try {
      final url = buildUrl(
        page: page,
        sortOrder: sortOrder,
        category: category,
        categoryId: categoryId,
        keyword: keyword,
      );
      debugPrint('[PornhubApiService] Fetching URL: $url');

      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final parsed = _parseListPageHtml(response.data!, page);
        if (parsed.items.isNotEmpty) {
          return parsed;
        }

        // If category returned 0 items, fallback to search query
        if (category != null && category.slug != 'all' && !category.isSearch) {
          debugPrint('[PornhubApiService] Category page empty, trying search fallback for: ${category.slug}');
          final searchUrl = buildUrl(
            page: page,
            sortOrder: sortOrder,
            keyword: category.slug,
          );
          final searchResp = await _dio.get<String>(
            searchUrl,
            options: Options(responseType: ResponseType.plain, followRedirects: true),
          );
          if (searchResp.statusCode == 200 && searchResp.data != null) {
            return _parseListPageHtml(searchResp.data!, page);
          }
        }

        return parsed;
      }
    } catch (e) {
      debugPrint('[PornhubApiService] Error fetching page $page: $e');
    }
    return null;
  }

  /// Parse HTML list
  static PornhubApiResponse _parseListPageHtml(String html, int requestedPage) {
    final document = html_parser.parse(html);
    final List<VideoItem> items = [];
    final seenSlugs = <String>{};

    // Pornhub cards: li.pcVideoListItem, li.videoBlock, div.ph-video-wrap, li[data-video-vkey], li.videoblock_item, .videoList .videoBox, ul.videos li
    final videoElements = document.querySelectorAll(
      'li.pcVideoListItem, li.videoBlock, div.ph-video-wrap, [data-video-vkey], li[data-entry-id], li.videoblock_item, .videoList .videoBox, ul.videos > li',
    );

    for (final elem in videoElements) {
      try {
        final linkElem = elem.querySelector('a[href*="view_video.php"], a.linkVideoThumb, a[data-title], a');
        if (linkElem == null) continue;

        var href = linkElem.attributes['href'] ?? '';
        if (href.isEmpty || href == '#' || !href.contains('view_video.php')) continue;

        if (!href.startsWith('http')) {
          if (!href.startsWith('/')) href = '/$href';
          href = '$kBaseUrl$href';
        }

        // Extract vkey
        final vkeyMatch = RegExp(r'viewkey=([a-zA-Z0-9_-]+)').firstMatch(href);
        final vkey = vkeyMatch?.group(1) ?? elem.attributes['data-video-vkey'] ?? '';
        final slug = vkey.isNotEmpty ? 'pornhub_$vkey' : href.split('/').last;

        if (!seenSlugs.add(slug)) continue;

        // Title
        var title = linkElem.attributes['title'] ??
            linkElem.attributes['data-title'] ??
            elem.querySelector('.title a, .title, span.title, h5 a, .ph-title')?.text.trim() ??
            linkElem.text.trim();
        if (title.isEmpty) {
          title = 'Pornhub Video $vkey';
        }

        // Thumbnail / Cover image
        final imgElem = elem.querySelector('img');
        var coverUrl = imgElem?.attributes['data-thumb_url'] ??
            imgElem?.attributes['data-mediumthumb'] ??
            imgElem?.attributes['data-src'] ??
            imgElem?.attributes['src'] ??
            '';

        if (coverUrl.contains('blank.gif') || coverUrl.contains('data:image')) {
          coverUrl = imgElem?.attributes['data-thumb_url'] ?? imgElem?.attributes['data-src'] ?? '';
        }

        if (coverUrl.startsWith('//')) {
          coverUrl = 'https:$coverUrl';
        } else if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = '$kBaseUrl$coverUrl';
        }

        // Duration
        final durationElem = elem.querySelector('var.duration, span.duration, .duration, .time, var');
        final duration = durationElem?.text.trim() ?? '';

        // Views
        final viewsElem = elem.querySelector('.views, span.views, .viewCount, .videoDetailsBlock .views');
        var views = viewsElem?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? 'Pornhub HD';

        // Rating
        final ratingElem = elem.querySelector('.value, .rating-container .value, .rating');
        final rating = ratingElem?.text.trim() ?? '';
        if (rating.isNotEmpty && !views.contains('%')) {
          views = '$views · ★ $rating';
        }

        // Uploader / Author
        final authorElem = elem.querySelector('.usernameWrap a, .videoUploader a, .username, .author');
        final author = authorElem?.text.trim().isNotEmpty == true
            ? authorElem!.text.trim()
            : 'Pornhub';

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
            tags: ['Pornhub', '1080P/HD', author],
            videoUrl: null,
            isDetailLoaded: false,
            rawData: {'vkey': vkey, 'detailUrl': href},
          ),
        );
      } catch (e) {
        debugPrint('[PornhubApiService] Error parsing video element: $e');
      }
    }

    // Estimate total pages
    int totalPages = requestedPage;
    final pageLinks = document.querySelectorAll(
      '.pagination a, .page-number, .page_next, li.pageitem a, .pagination_block a, .page_current, ul.pagination li a, .page-link, li.pageitem.page_next a, li.pageitem.page_last a, a[href*="page="]',
    );
    for (final pl in pageLinks) {
      final pageNum = int.tryParse(pl.text.trim());
      if (pageNum != null && pageNum > totalPages) {
        totalPages = pageNum;
      }
      final href = pl.attributes['href'] ?? '';
      final pageMatch = RegExp(r'page=(\d+)').firstMatch(href);
      if (pageMatch != null) {
        final p = int.tryParse(pageMatch.group(1)!);
        if (p != null && p > totalPages) totalPages = p;
      }
    }

    if (totalPages <= requestedPage && items.isNotEmpty) {
      totalPages = requestedPage + 1;
    }

    return PornhubApiResponse(
      items: items,
      page: requestedPage,
      totalPages: totalPages,
      total: items.length * totalPages,
    );
  }

  /// Resolve direct video stream
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    if (item.isDetailLoaded &&
        item.videoUrl != null &&
        item.videoUrl!.isNotEmpty &&
        item.videoUrl != item.detailUrl) {
      return item;
    }

    try {
      debugPrint('[PornhubApiService] Resolving video detail: ${item.detailUrl}');
      final response = await _dio.get<String>(
        item.detailUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        final rawHtml = response.data!;
        final cleanHtml = rawHtml.replaceAll(r'\/', '/');
        final document = html_parser.parse(rawHtml);

        String? directVideoUrl;

        // 1. Try to find mediaDefinitions in scripts (Standard Pornhub FlashVars / JSON)
        final flashvarsMatch = RegExp(r'var\s+flashvars_\d+\s*=\s*(\{.+?\});', dotAll: true).firstMatch(rawHtml) ??
            RegExp(r'mediaDefinitions\s*:\s*(\[\{.+?\}\])', dotAll: true).firstMatch(rawHtml) ??
            RegExp(r'mediaDefinitions\s*=\s*(\[\{.+?\}\])', dotAll: true).firstMatch(rawHtml);

        if (flashvarsMatch != null) {
          try {
            final rawJson = flashvarsMatch.group(1)!.replaceAll(r'\/', '/');
            dynamic data = jsonDecode(rawJson);
            List mediaList = [];
            if (data is Map && data['mediaDefinitions'] is List) {
              mediaList = data['mediaDefinitions'];
            } else if (data is List) {
              mediaList = data;
            }

            // Find highest quality direct URL (prefer 4K/1080p/Master HLS over low res MP4)
            int bestQualityScore = -1;
            String? bestStreamUrl;

            for (final m in mediaList) {
              if (m is! Map) continue;
              final format = m['format']?.toString().toLowerCase();
              final rawVUrl = m['videoUrl']?.toString().trim();
              if (rawVUrl == null || rawVUrl.isEmpty || !rawVUrl.startsWith('http')) continue;

              var vUrl = rawVUrl;
              if (vUrl.startsWith('//')) {
                vUrl = 'https:$vUrl';
              }

              // Compute resolution / quality score
              int score = 0;
              final qStr = (m['quality']?.toString() ?? '').toLowerCase();
              final qMatch = RegExp(r'(\d+)').firstMatch(qStr);
              if (qMatch != null) {
                score = int.tryParse(qMatch.group(1)!) ?? 0;
              } else if (qStr.contains('4k') || qStr.contains('2160')) {
                score = 2160;
              } else if (qStr.contains('2k') || qStr.contains('1440')) {
                score = 1440;
              } else if (format == 'hls' || vUrl.contains('.m3u8')) {
                score = 1080; // Master HLS carries 1080p+ adaptive stream
              } else {
                score = 720;
              }

              if (score > bestQualityScore || bestStreamUrl == null) {
                bestQualityScore = score;
                bestStreamUrl = vUrl;
              }
            }

            directVideoUrl = bestStreamUrl;
          } catch (e) {
            debugPrint('[PornhubApiService] Error parsing mediaDefinitions: $e');
          }
        }

        // 2. Search for master m3u8 or mp4 via regex in cleanHtml
        if (directVideoUrl == null || directVideoUrl.isEmpty) {
          final m3u8Match = RegExp(r'(https?://[^\s"<>&]+?\.m3u8[^\s"<>&]*)').firstMatch(cleanHtml);
          if (m3u8Match != null) {
            directVideoUrl = m3u8Match.group(1);
          }
        }

        if (directVideoUrl == null || directVideoUrl.isEmpty) {
          final mp4Match = RegExp(r'(https?://[^\s"<>&]+?\.mp4[^\s"<>&]*)').firstMatch(cleanHtml);
          if (mp4Match != null) {
            directVideoUrl = mp4Match.group(1);
          }
        }

        // 3. Extract Tags
        final tags = <String>['Pornhub'];
        final tagElements = document.querySelectorAll('.tagsWrapper a, .categoriesWrapper a, a[href*="/video?c="]');
        for (final t in tagElements) {
          final text = t.text.trim();
          if (text.isNotEmpty && !tags.contains(text) && text.length < 20) {
            tags.add(text);
          }
        }

        // 4. Extract full cover if possible
        var cover = item.coverUrl;
        final posterElem = document.querySelector('video[poster], meta[property="og:image"]');
        if (posterElem != null) {
          final p = posterElem.attributes['poster'] ?? posterElem.attributes['content'];
          if (p != null && p.isNotEmpty && p.startsWith('http')) {
            cover = p;
          }
        }

        // Validate directVideoUrl format
        if (directVideoUrl != null &&
            (!directVideoUrl.startsWith('http') ||
                directVideoUrl.isEmpty ||
                (!directVideoUrl.contains('.mp4') && !directVideoUrl.contains('.m3u8')))) {
          directVideoUrl = null;
        }

        return item.copyWith(
          coverUrl: cover,
          videoUrl: directVideoUrl ?? item.detailUrl,
          tags: tags.isNotEmpty ? tags : item.tags,
          isDetailLoaded: true,
        );
      }
    } catch (e) {
      debugPrint('[PornhubApiService] Error resolving video: $e');
    }

    return item;
  }
}
