import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';
import '../config_service.dart';
import 'twitter_site_config.dart';

class TwitterPageData {
  final List<VideoItem> items;
  final int currentPage;
  final int totalPages;
  final String? nextCursor;
  final bool hasMore;

  const TwitterPageData({
    required this.items,
    required this.currentPage,
    this.totalPages = 1,
    this.nextCursor,
    this.hasMore = true,
  });
}

class TwitterRankingApiService {
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12)
    ..idleTimeout = const Duration(seconds: 15)
    ..badCertificateCallback = (cert, host, port) => true;

  static String? _configuredProxy;

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
    _applyProxy(_client);
  }

  static void _applyProxy(HttpClient client) {
    client.badCertificateCallback = (cert, host, port) => true;
    final proxy = (_configuredProxy != null && _configuredProxy!.isNotEmpty)
        ? _configuredProxy!
        : ConfigService.loadConfig().customProxy;

    if (proxy.isNotEmpty) {
      final clean = proxy.replaceAll(RegExp(r'https?://|socks5?://'), '');
      if (proxy.startsWith('socks')) {
        client.findProxy = (uri) => 'SOCKS5 $clean; DIRECT';
      } else {
        client.findProxy = (uri) => 'PROXY $clean; DIRECT';
      }
    } else {
      client.findProxy = HttpClient.findProxyFromEnvironment;
    }
  }

  /// Main dispatcher to fetch video list from any supported Twitter ranking site
  static Future<TwitterPageData?> fetchPageData({
    required TwitterSiteConfig site,
    String? range,
    String? sort,
    int page = 1,
    String? cursor,
    String? keyword,
  }) async {
    _applyProxy(_client);

    final actualRange = range ?? site.rangeOptions.first.id;
    final actualSort = sort ?? site.sortOptions.first.id;

    try {
      switch (site.adapterType) {
        case TwitterAdapterType.pektino:
          return await _fetchPektino(site, actualRange, actualSort, page, cursor);
        case TwitterAdapterType.nextapi:
          return await _fetchNextApi(site, actualRange, actualSort, page, cursor);
        case TwitterAdapterType.twihub:
          return await _fetchTwiHub(site, actualRange, actualSort, page, cursor);
        case TwitterAdapterType.xhotvideo:
          return await _fetchXHotVideo(site, actualRange, actualSort, page);
        case TwitterAdapterType.monsnode:
          return await _fetchMonsnode(site, actualRange, actualSort, page, cursor);
        case TwitterAdapterType.htmlRanking:
          return await _fetchHtmlRanking(site, actualRange, actualSort, page, cursor);
      }
    } catch (e) {
      debugPrint('TwitterRankingApiService [${site.name}] fetch error: $e');
      rethrow;
    }
  }

  // ================= 1. Pektino Adapter =================
  static Future<TwitterPageData> _fetchPektino(
    TwitterSiteConfig site,
    String range,
    String sort,
    int page,
    String? cursor,
  ) async {
    final uri = Uri.parse('${site.baseUrl}/api/media').replace(queryParameters: {
      'page': cursor ?? page.toString(),
      'per_page': '20',
      'isAnimeOnly': site.isAnimeOnly ? '1' : '0',
      'range': range,
      'sort': sort,
    });

    final req = await _client.getUrl(uri);
    req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    req.headers.set('Accept', 'application/json');
    final res = await req.close();
    final body = await utf8.decodeStream(res);

    if (res.statusCode != 200) {
      throw Exception('Pektino API HTTP ${res.statusCode}');
    }

    final json = jsonDecode(body);
    final rawItems = json['items'] as List? ?? [];
    final currentPage = json['current_page'] as int? ?? page;
    final lastPage = json['last_page'] as int? ?? (page + (rawItems.length >= 20 ? 1 : 0));

    final List<VideoItem> items = [];
    for (final raw in rawItems) {
      final tweetId = (raw['url_cd'] ?? raw['id'] ?? '').toString();
      final title = (raw['anime_title'] ?? raw['tweet_title'] ?? raw['tweet_account'] ?? '推特精选视频').toString();
      final author = (raw['tweet_account'] ?? 'unknown').toString();
      final thumbnail = (raw['thumbnail'] ?? '').toString();
      final videoUrl = (raw['url'] ?? '').toString();
      final pv = raw['pv']?.toString() ?? '0';
      final fav = raw['favorite']?.toString() ?? '0';
      final duration = raw['duration']?.toString() ?? '';

      items.add(VideoItem(
        title: title.isNotEmpty ? title : '@$author 的推特视频',
        slug: 'twitter_${site.id}_$tweetId',
        detailUrl: (raw['original_url'] ?? 'https://x.com/$author/status/$tweetId').toString(),
        coverUrl: thumbnail,
        duration: duration.isNotEmpty ? '$duration秒' : '',
        views: '🔥 $pv 播放 · ❤️ $fav 喜欢',
        date: raw['created_at']?.toString().split('T').first ?? '今日热门',
        author: '@$author',
        videoUrl: videoUrl.isNotEmpty ? videoUrl : null,
        isDetailLoaded: videoUrl.isNotEmpty,
        rawData: raw is Map<String, dynamic> ? raw : {},
      ));
    }

    return TwitterPageData(
      items: items,
      currentPage: currentPage,
      totalPages: lastPage,
      hasMore: currentPage < lastPage,
    );
  }

  // ================= 2. Next.js App Router / SSR API Adapter (Twivideo / Pektino alt) =================
  static Future<TwitterPageData> _fetchNextApi(
    TwitterSiteConfig site,
    String range,
    String sort,
    int page,
    String? cursor,
  ) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'sort': sort,
      'range': range,
    };

    final uri = Uri.parse('${site.baseUrl}/api/posts').replace(queryParameters: queryParams);
    final req = await _client.getUrl(uri);
    req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    req.headers.set('Accept', 'application/json');
    req.headers.set('Referer', '${site.baseUrl}/');
    final res = await req.close();
    final body = await utf8.decodeStream(res);

    if (res.statusCode == 200) {
      final json = jsonDecode(body);
      final rawPosts = (json is List) ? json : (json['posts'] ?? json['data'] ?? json['items'] ?? []);
      final List<VideoItem> items = [];

      for (final raw in rawPosts) {
        final id = (raw['id'] ?? raw['tweet_id'] ?? '').toString();
        if (id.isEmpty) continue;

        final title = (raw['title'] ?? raw['text'] ?? raw['description'] ?? '推特精选视频').toString();
        final author = (raw['author'] ?? raw['username'] ?? raw['screen_name'] ?? 'Twitter').toString();
        final thumb = (raw['thumbnail'] ?? raw['poster'] ?? raw['cover'] ?? '').toString();
        final videoUrl = (raw['video_url'] ?? raw['media_url'] ?? raw['url'] ?? '').toString();
        final views = (raw['views'] ?? raw['likes'] ?? '').toString();

        items.add(VideoItem(
          title: title.isNotEmpty ? title : '@$author 的推特精选',
          slug: 'twitter_${site.id}_$id',
          detailUrl: 'https://x.com/$author/status/$id',
          coverUrl: thumb.isNotEmpty ? thumb : null,
          duration: '',
          views: views.isNotEmpty ? '🔥 $views' : '🔥 热门视频',
          date: '今日热门',
          author: '@$author',
          videoUrl: videoUrl.isNotEmpty ? videoUrl : null,
          isDetailLoaded: videoUrl.isNotEmpty,
          rawData: raw is Map<String, dynamic> ? raw : {},
        ));
      }

      return TwitterPageData(
        items: items,
        currentPage: page,
        totalPages: page + 1,
        hasMore: items.isNotEmpty,
      );
    }

    // Fallback to universal HTML parsing
    return _fetchHtmlRanking(site, range, sort, page, cursor);
  }

  // ================= 3. TwiHub Adapter =================
  static Future<TwitterPageData> _fetchTwiHub(
    TwitterSiteConfig site,
    String range,
    String sort,
    int page,
    String? cursor,
  ) async {
    final queryParams = <String, String>{
      'category': site.isAnimeOnly ? 'anime' : 'all',
      'sort': sort,
      'range': range,
      'limit': '24',
    };
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }

    final uri = Uri.parse('${site.baseUrl}/api/v1/posts').replace(queryParameters: queryParams);
    final req = await _client.getUrl(uri);
    req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    req.headers.set('Accept', 'application/json');
    req.headers.set('Referer', '${site.baseUrl}/');
    final res = await req.close();
    final body = await utf8.decodeStream(res);

    if (res.statusCode != 200) {
      throw Exception('TwiHub API error HTTP ${res.statusCode}');
    }

    final json = jsonDecode(body);
    final rawPosts = json['posts'] as List? ?? [];
    final nextCursor = json['nextCursor']?.toString();
    final hasMore = json['hasMore'] as bool? ?? (nextCursor != null && nextCursor.isNotEmpty);

    final List<VideoItem> items = [];
    for (final raw in rawPosts) {
      final postId = (raw['postId'] ?? '').toString();
      if (postId.isEmpty) continue;

      final thumbnail = (raw['thumbnailUrl'] ?? '').toString();
      final likesCount = raw['likesCount']?.toString() ?? '0';
      final durationSec = (raw['firstVideoDuration'] as num?)?.round() ?? 0;

      items.add(VideoItem(
        title: '推特精选视频 #$postId',
        slug: 'twitter_${site.id}_$postId',
        detailUrl: 'https://x.com/i/status/$postId',
        coverUrl: thumbnail,
        duration: _formatDuration(durationSec),
        views: '❤️ $likesCount 喜欢',
        date: '今日榜单',
        author: '@Twitter',
        videoUrl: null,
        isDetailLoaded: false,
        rawData: raw is Map<String, dynamic> ? raw : {},
      ));
    }

    return TwitterPageData(
      items: items,
      currentPage: page,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  // ================= 4. XHotVideo Adapter =================
  static Future<TwitterPageData> _fetchXHotVideo(
    TwitterSiteConfig site,
    String range,
    String sort,
    int page,
  ) async {
    String path = '/videos/period/$range/page/$page';
    if (sort == 'new') {
      path = '/videos/sort/new/page/$page';
    }

    final req = await _client.getUrl(Uri.parse('${site.baseUrl}$path'));
    req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
    req.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
    final res = await req.close();
    final body = await utf8.decodeStream(res);

    if (res.statusCode != 200) {
      throw Exception('XHotVideo HTTP error ${res.statusCode}');
    }

    final doc = html_parser.parse(body);
    final videoCards = doc.querySelectorAll('.video-card, .card, .col-6, .col-md-4, .video_item, [class*="video"], a[href*="/video/"]');
    final List<VideoItem> items = [];
    final seenIds = <String>{};

    for (final card in videoCards) {
      final linkEl = card.localName == 'a' ? card : (card.querySelector('a[href*="/video/"], a') ?? card);
      final href = linkEl.attributes['href'] ?? '';
      if (!href.contains('/video/')) continue;
      final videoId = href.split('/').where((s) => s.isNotEmpty).last;
      if (videoId.isEmpty || !seenIds.add(videoId)) continue;

      final imgEl = card.querySelector('img');
      final thumbnail = imgEl?.attributes['data-src'] ?? imgEl?.attributes['src'] ?? '';
      final durationEl = card.querySelector('.duration, .badge, .time');
      final duration = durationEl?.text.trim() ?? '';
      final titleEl = card.querySelector('.title, .card-title, h4, h5');
      final title = titleEl?.text.trim() ?? 'XHotVideo #$videoId';
      final metaEl = card.querySelector('.card-meta, .views');
      final views = metaEl?.text.trim() ?? '🔥 热门视频';

      items.add(VideoItem(
        title: title,
        slug: 'twitter_${site.id}_$videoId',
        detailUrl: href.startsWith('http') ? href : '${site.baseUrl}/video/$videoId',
        coverUrl: thumbnail.isNotEmpty ? (thumbnail.startsWith('http') ? thumbnail : '${site.baseUrl}$thumbnail') : null,
        duration: duration,
        views: views,
        date: '今日热门',
        author: 'XHotVideo',
        videoUrl: null,
        isDetailLoaded: false,
        rawData: {'videoId': videoId},
      ));
    }

    return TwitterPageData(
      items: items,
      currentPage: page,
      totalPages: page + (items.isNotEmpty ? 1 : 0),
      hasMore: items.isNotEmpty,
    );
  }

  // ================= 5. Monsnode Adapter =================
  static Future<TwitterPageData> _fetchMonsnode(
    TwitterSiteConfig site,
    String range,
    String sort,
    int page,
    String? cursor,
  ) async {
    final actualPage = cursor ?? (page - 1).toString();
    final ranking = sort == 'pv' ? '8' : '1';

    final uri = Uri.parse('${site.baseUrl}/').replace(queryParameters: {
      'page': actualPage,
      'period': range,
      'ranking': ranking,
    });

    final req = await _client.getUrl(uri);
    req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
    final res = await req.close();
    final body = await utf8.decodeStream(res);

    if (res.statusCode != 200) {
      throw Exception('Monsnode HTTP error ${res.statusCode}');
    }

    final doc = html_parser.parse(body);
    final listItems = doc.querySelectorAll('.listn, li, a[href*="redirect.php?v="], a[href*="/v"]');
    final List<VideoItem> items = [];
    final seenIds = <String>{};

    for (final item in listItems) {
      final aTag = item.localName == 'a' ? item : item.querySelector('a[href*="redirect.php?v="], a[href*="/v"]');
      final href = aTag?.attributes['href'] ?? '';
      final vMatch = RegExp(r'v=(\d+)').firstMatch(href) ?? RegExp(r'/v(\d+)').firstMatch(href);
      final videoId = vMatch?.group(1) ?? '';
      if (videoId.isEmpty || !seenIds.add(videoId)) continue;

      final imgTag = item.querySelector('img') ?? aTag?.querySelector('img');
      final thumbnail = imgTag?.attributes['src'] ?? imgTag?.attributes['data-src'] ?? '';
      final userTag = item.querySelector('.user a, .name a, .author');
      final author = userTag?.text.trim().replaceAll('@', '') ?? 'Monsnode';

      items.add(VideoItem(
        title: '@$author 的推特热门视频 #$videoId',
        slug: 'twitter_${site.id}_$videoId',
        detailUrl: '${site.baseUrl}/redirect.php?v=$videoId',
        coverUrl: thumbnail.isNotEmpty ? thumbnail : null,
        duration: '',
        views: '🔥 热门推荐',
        date: '今日热门',
        author: '@$author',
        videoUrl: null,
        isDetailLoaded: false,
        rawData: {'videoId': videoId},
      ));
    }

    final nextPage = (int.tryParse(actualPage) ?? 0) + 1;
    return TwitterPageData(
      items: items,
      currentPage: page,
      nextCursor: nextPage.toString(),
      hasMore: items.isNotEmpty,
    );
  }

  // ================= 6. Universal HTML Ranking Adapter (TwiDouga / JavTwi / Twiigle / Uraaka / TwiVideo) =================
  static Future<TwitterPageData> _fetchHtmlRanking(
    TwitterSiteConfig site,
    String range,
    String sort,
    int page,
    String? cursor,
  ) async {
    String requestUrl = '${site.baseUrl}/';

    if (site.id == 'twidouga') {
      if (range == 'weekly') {
        requestUrl = '${site.baseUrl}/jp/ranking_t1.php';
      } else {
        requestUrl = '${site.baseUrl}/realtime_t.php';
      }
    } else if (site.id == 'twiigle') {
      if (range == 'realtime') {
        requestUrl = '${site.baseUrl}/realtime/';
      } else if (range == 'weekly') {
        requestUrl = '${site.baseUrl}/weekly/';
      } else if (range == 'monthly') {
        requestUrl = '${site.baseUrl}/monthly/';
      } else {
        requestUrl = '${site.baseUrl}/';
      }
    } else if (site.id == 'javtwi') {
      if (range == 'weekly' || sort == 'favorite') {
        requestUrl = '${site.baseUrl}/favorite.html';
      } else {
        requestUrl = page > 1 ? '${site.baseUrl}/?page=$page' : '${site.baseUrl}/';
      }
    } else if (site.id == 'uraaka-times') {
      try {
        final uReq = await _client.getUrl(Uri.parse('${site.baseUrl}/'));
        uReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
        uReq.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
        final uRes = await uReq.close();
        final uHtml = await utf8.decodeStream(uRes);

        final scriptMatch = RegExp(r'<script[^>]*>\s*(\[\["ShallowReactive"[\s\S]*?\])\s*</script>').firstMatch(uHtml);
        if (scriptMatch != null) {
          final list = jsonDecode(scriptMatch.group(1)!) as List;

          dynamic resolve(dynamic val) {
            if (val is int && val >= 0 && val < list.length) {
              return list[val];
            }
            return val;
          }

          final videoObjs = list.where((e) => e is Map && e.containsKey('tweet_id') && e.containsKey('video')).toList();
          final List<VideoItem> uItems = [];

          for (final raw in videoObjs) {
            final obj = raw as Map;
            final tweetId = resolve(obj['tweet_id'])?.toString() ?? '${uItems.length + 1}';
            final tweetText = resolve(obj['posted_text'] ?? obj['tweet'])?.toString() ?? '推特精选视频 #$tweetId';
            final likes = resolve(obj['favorite'])?.toString() ?? '';
            final views = resolve(obj['views'])?.toString() ?? '';

            String author = 'UraakaTimes';
            final rawUser = resolve(obj['user']);
            if (rawUser is Map) {
              final name = resolve(rawUser['twitter_name'] ?? rawUser['name'] ?? rawUser['twitter_id'])?.toString();
              if (name != null && name.isNotEmpty) author = name;
            }

            String? videoUrl;
            String? thumbUrl;
            final rawVideo = resolve(obj['video']);
            if (rawVideo is List && rawVideo.isNotEmpty) {
              final firstV = resolve(rawVideo.first);
              if (firstV is Map) {
                videoUrl = resolve(firstV['video_link'] ?? firstV['video_url'] ?? firstV['url'])?.toString();
                thumbUrl = resolve(firstV['video_thumbnail'] ?? firstV['thumbnail_url'] ?? firstV['thumbnail'])?.toString();
              }
            } else if (rawVideo is Map) {
              videoUrl = resolve(rawVideo['video_link'] ?? rawVideo['video_url'] ?? rawVideo['url'])?.toString();
              thumbUrl = resolve(rawVideo['video_thumbnail'] ?? rawVideo['thumbnail_url'] ?? rawVideo['thumbnail'])?.toString();
            }

            if (videoUrl != null && videoUrl.isNotEmpty) {
              uItems.add(VideoItem(
                title: tweetText.length > 60 ? '${tweetText.substring(0, 60)}...' : tweetText,
                slug: 'twitter_${site.id}_$tweetId',
                detailUrl: '${site.baseUrl}/',
                coverUrl: thumbUrl,
                duration: '',
                views: views.isNotEmpty ? '🔥 $views 播放' : (likes.isNotEmpty ? '❤️ $likes 喜欢' : '🔥 今日热门'),
                date: '今日热门',
                author: '@$author',
                videoUrl: videoUrl,
                isDetailLoaded: true,
                rawData: {'videoUrl': videoUrl, 'thumb': thumbUrl, 'tweetId': tweetId},
              ));
            }
          }

          if (uItems.isNotEmpty) {
            return TwitterPageData(
              items: uItems,
              currentPage: page,
              totalPages: page + 1,
              hasMore: uItems.isNotEmpty,
            );
          }
        }
      } catch (e) {
        debugPrint('[TwitterRankingApiService] Uraaka Nuxt parsing error: $e');
      }
      requestUrl = '${site.baseUrl}/';
    }

    final req = await _client.getUrl(Uri.parse(requestUrl));
    req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
    req.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
    req.headers.set('Referer', '${site.baseUrl}/');
    final res = await req.close();
    final body = await utf8.decodeStream(res);

    if (res.statusCode != 200 && res.statusCode != 301 && res.statusCode != 302) {
      throw Exception('${site.name} HTTP error ${res.statusCode}');
    }

    final List<VideoItem> items = [];
    final doc = html_parser.parse(body);

    // 1. TwiDouga specific grid parser (.grid-item)
    if (site.id == 'twidouga') {
      final gridItems = doc.querySelectorAll('.grid-item');
      for (final g in gridItems) {
        final dataVideo = g.attributes['data-video'] ?? g.attributes['data-video-lq'] ?? '';
        final dataImage = g.attributes['data-image'] ?? '';
        final dataUrl = g.attributes['data-url'] ?? '';
        final dataId = g.attributes['data-id'] ?? '';

        if (dataVideo.isNotEmpty) {
          final authorMatch = RegExp(r'x\.com/([a-zA-Z0-9_]+)/status').firstMatch(dataUrl);
          final author = authorMatch?.group(1) ?? 'TwiDouga';

          items.add(VideoItem(
            title: '@$author 的推特精选视频',
            slug: 'twitter_${site.id}_$dataId',
            detailUrl: dataUrl.isNotEmpty ? dataUrl : 'https://x.com/i/status/$dataId',
            coverUrl: dataImage.isNotEmpty ? dataImage : null,
            duration: '',
            views: '🔥 今日精选',
            date: '今日热门',
            author: '@$author',
            videoUrl: dataVideo,
            isDetailLoaded: true,
            rawData: {'dataId': dataId, 'videoUrl': dataVideo},
          ));
        }
      }
    }

    // 2. Twiigle specific card parser (.art_li)
    if (site.id == 'twiigle' && items.isEmpty) {
      final artList = doc.querySelectorAll('.art_li');
      for (final art in artList) {
        final aTag = art.querySelector('.item_image a, a[href*="contents="]');
        final href = aTag?.attributes['href'] ?? '';
        final imgTag = art.querySelector('.item_image img, img');
        final thumb = imgTag?.attributes['src'] ?? imgTag?.attributes['data-src'] ?? '';
        final id = aTag?.attributes['data-id'] ?? '';

        String? mp4Url;
        final cMatch = RegExp(r'contents=(https?://[^\s&"]+\.mp4[^\s&"]*)').firstMatch(href);
        if (cMatch != null) {
          mp4Url = cMatch.group(1);
        }

        if (mp4Url != null && mp4Url.isNotEmpty) {
          items.add(VideoItem(
            title: 'Twiigle 推特热门视频 #${id.isNotEmpty ? id : items.length + 1}',
            slug: 'twitter_${site.id}_${id.isNotEmpty ? id : items.length + 1}',
            detailUrl: '${site.baseUrl}/',
            coverUrl: thumb.isNotEmpty ? thumb : null,
            duration: '',
            views: '🔥 热门推荐',
            date: '今日',
            author: '@Twiigle',
            videoUrl: mp4Url,
            isDetailLoaded: true,
            rawData: {'videoUrl': mp4Url, 'id': id},
          ));
        }
      }
    }

    // 3. JavTwi & Uraaka parsing
    if ((site.id == 'javtwi' || site.id == 'uraaka-times') && items.isEmpty) {
      final cardElements = doc.querySelectorAll('.card, .video-item, .item, .post, article, li, div');
      final seenVideos = <String>{};

      for (final c in cardElements) {
        final cHtml = c.outerHtml;
        final mp4Match = RegExp(r'https?://video\.twimg\.com/[^\s"<>\x27\\]+\.mp4[^\s"<>\x27\\]*').firstMatch(cHtml);
        if (mp4Match == null) continue;
        final mp4 = mp4Match.group(0)!;
        if (!seenVideos.add(mp4)) continue;

        final imgTag = c.querySelector('img');
        final thumb = imgTag?.attributes['data-src'] ?? imgTag?.attributes['src'] ?? '';
        final id = items.length + 1;

        items.add(VideoItem(
          title: '${site.name} 精选推特视频 #$id',
          slug: 'twitter_${site.id}_$id',
          detailUrl: '${site.baseUrl}/',
          coverUrl: thumb.isNotEmpty && !thumb.startsWith('data:') ? thumb : null,
          duration: '',
          views: '🔥 热门推荐',
          date: '今日热门',
          author: '@${site.name}',
          videoUrl: mp4,
          isDetailLoaded: true,
          rawData: {'videoUrl': mp4, 'thumb': thumb},
        ));
      }

      // Regex stream fallback if cardElements didn't catch all
      if (items.length < 5) {
        final mp4Matches = RegExp(r'https?://video\.twimg\.com/[^\s"<>\x27\\]+\.mp4[^\s"<>\x27\\]*').allMatches(body);
        final thumbMatches = RegExp(r'https?://pbs\.twimg\.com/[^\s"<>\x27\\]+(?:\.jpg|\.png|\.webp)').allMatches(body).map((m) => m.group(0)!).toList();

        int tIdx = 0;
        for (final m in mp4Matches) {
          final mp4 = m.group(0)!;
          if (!seenVideos.add(mp4)) continue;

          final thumb = tIdx < thumbMatches.length ? thumbMatches[tIdx] : null;
          final id = items.length + 1;

          items.add(VideoItem(
            title: '${site.name} 精选推特视频 #$id',
            slug: 'twitter_${site.id}_$id',
            detailUrl: '${site.baseUrl}/',
            coverUrl: thumb,
            duration: '',
            views: '🔥 热门推荐',
            date: '今日热门',
            author: '@${site.name}',
            videoUrl: mp4,
            isDetailLoaded: true,
            rawData: {'videoUrl': mp4, 'thumb': thumb},
          ));
          tIdx++;
        }
      }
    }

    // 4. Fallback card parsing with STRICT per-card isolation
    if (items.isEmpty) {
      final cards = doc.querySelectorAll('.card, .video-item, .item, .ranking-item, article, li');
      final seenVideos = <String>{};

      for (final card in cards) {
        final cardHtml = card.outerHtml;
        final mp4Match = RegExp(r'https?://video\.twimg\.com/[^\s"<>\x27\\]+\.mp4[^\s"<>\x27\\]*').firstMatch(cardHtml);
        if (mp4Match == null) continue;
        final mp4 = mp4Match.group(0)!;
        if (!seenVideos.add(mp4)) continue;

        final imgTag = card.querySelector('img');
        final thumb = imgTag?.attributes['data-src'] ?? imgTag?.attributes['src'] ?? '';
        final linkTag = card.querySelector('a[href*="status/"], a');
        final href = linkTag?.attributes['href'] ?? '';
        final authorMatch = RegExp(r'(?:twitter|x)\.com/([a-zA-Z0-9_]+)/status').firstMatch(href);
        final author = authorMatch?.group(1) ?? site.name;
        final id = items.length + 1;

        items.add(VideoItem(
          title: '@$author 的精选推特视频 #$id',
          slug: 'twitter_${site.id}_$id',
          detailUrl: href.startsWith('http') ? href : '${site.baseUrl}/',
          coverUrl: thumb.isNotEmpty && !thumb.startsWith('data:') ? thumb : null,
          duration: '',
          views: '🔥 热门视频',
          date: '今日榜单',
          author: '@$author',
          videoUrl: mp4,
          isDetailLoaded: true,
          rawData: {'videoUrl': mp4},
        ));
      }
    }

    return TwitterPageData(
      items: items,
      currentPage: page,
      totalPages: page + 1,
      hasMore: items.isNotEmpty,
    );
  }

  /// Resolve real MP4 stream URL for sites that require on-demand extraction
  static Future<VideoItem> resolveVideoDetail(TwitterSiteConfig site, VideoItem item) async {
    if (item.videoUrl != null && item.videoUrl!.isNotEmpty) {
      return item;
    }

    _applyProxy(_client);

    try {
      if (site.id == 'monsnode') {
        final videoId = item.rawData['videoId']?.toString() ?? item.slug.split('_').last;
        final redirectUrl = '${site.baseUrl}/twjn.php?v=$videoId';
        debugPrint('[TwitterRankingApiService] Resolving Monsnode video via: $redirectUrl');

        final req = await _client.getUrl(Uri.parse(redirectUrl));
        req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
        final res = await req.close();
        final body = await utf8.decodeStream(res);

        // Find base64 encoded stream in atob('...')
        final b64Matches = RegExp(r"atob\(\s*['\x22]([A-Za-z0-9+/=]+)['\x22]\s*\)").allMatches(body);
        for (final m in b64Matches) {
          try {
            final b64 = m.group(1);
            if (b64 != null && b64.isNotEmpty) {
              final decoded = utf8.decode(base64.decode(b64));
              if (decoded.contains('video.twimg.com') && decoded.contains('.mp4')) {
                debugPrint('[TwitterRankingApiService] Successfully decoded Monsnode MP4: $decoded');
                return item.copyWith(
                  videoUrl: decoded,
                  isDetailLoaded: true,
                );
              }
            }
          } catch (_) {}
        }
      } else if (site.adapterType == TwitterAdapterType.twihub) {
        final postId = item.rawData['postId']?.toString() ?? item.slug.split('_').last;
        final req = await _client.getUrl(Uri.parse('${site.baseUrl}/posts/$postId'));
        req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
        final res = await req.close();
        final html = await utf8.decodeStream(res);

        final doc = html_parser.parse(html);
        final videoLink = doc.getElementById('video-link');
        final videoPath = videoLink?.attributes['href'];

        if (videoPath != null && videoPath.isNotEmpty) {
          final fullVideoUrl = videoPath.startsWith('http') ? videoPath : '${site.baseUrl}$videoPath';
          return item.copyWith(
            videoUrl: fullVideoUrl,
            isDetailLoaded: true,
          );
        }
      } else if (site.adapterType == TwitterAdapterType.xhotvideo) {
        final videoId = item.rawData['videoId']?.toString() ?? item.slug.split('_').last;
        final req = await _client.getUrl(Uri.parse('${site.baseUrl}/video/$videoId'));
        req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
        final res = await req.close();
        final html = await utf8.decodeStream(res);

        final doc = html_parser.parse(html);
        final source = doc.querySelector('video source');
        final videoSrc = source?.attributes['src'];

        if (videoSrc != null && videoSrc.isNotEmpty) {
          final fullVideoUrl = videoSrc.startsWith('http') ? videoSrc : '${site.baseUrl}$videoSrc';
          return item.copyWith(
            videoUrl: fullVideoUrl,
            isDetailLoaded: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error resolving video detail for ${item.title}: $e');
    }

    return item;
  }

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
