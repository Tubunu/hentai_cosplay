import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/rule34video_category.dart';
import '../../models/video_item.dart';
import '../config_service.dart';
import '../jable/cf_cookie_harvester.dart';

class Rule34VideoPageData {
  final List<VideoItem> items;
  final int currentPage;
  final int totalPages;

  const Rule34VideoPageData({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });
}

class Rule34VideoApiService {
  static const String kBaseUrl = 'https://rule34video.com';

  static String? _configuredProxy;

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Referer': 'https://rule34video.com/',
        },
      ),
    );

    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      final effectiveProxy = _configuredProxy ?? ConfigService.loadConfig().customProxy;
      if (effectiveProxy.isNotEmpty) {
        final clean = effectiveProxy.replaceAll(RegExp(r'https?://|socks5?://'), '');
        client.findProxy = (uri) => 'PROXY $clean';
      }
      return client;
    };
    dio.httpClientAdapter = adapter;
    return dio;
  }

  /// Internal HTML fetcher with multi-tier fallback (curl on desktop, Dio on mobile)
  static Future<String> _fetchHtml(String url) async {
    final cfg = ConfigService.loadConfig();
    final proxy = _configuredProxy ?? (cfg.customProxy.isNotEmpty ? cfg.customProxy : null);

    // Desktop tier: curl
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      try {
        final List<String> args = [
          '-s',
          '-L',
          '--compressed',
          '-A',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          '-H',
          'Referer: https://rule34video.com/',
          '-H',
          'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        ];
        if (proxy != null && proxy.isNotEmpty) {
          final p = proxy.startsWith('http') ? proxy : 'http://$proxy';
          args.addAll(['-x', p]);
        }
        args.add(url);

        final result = await Process.run('curl', args, runInShell: true);
        if (result.exitCode == 0 && (result.stdout as String).isNotEmpty) {
          return result.stdout as String;
        }
      } catch (e) {
        debugPrint('[Rule34VideoApiService] Desktop curl failed, falling back to Dio: $e');
      }
    }

    // Mobile / Standard tier: Dio
    try {
      final dio = _createDio();
      final res = await dio.get(url);
      return res.data.toString();
    } catch (e) {
      debugPrint('[Rule34VideoApiService] Dio get failed, trying cf Harvester: $e');
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final res = await CfCookieHarvester.fetchContentViaWebView(url, siteName: 'Rule34Video');
        if (res.isNotEmpty) return res;
      }
      rethrow;
    }
  }

  /// Build request URL based on filters
  static String buildUrl({
    int page = 1,
    Rule34VideoCategory category = Rule34VideoCategory.latest,
    String? searchKeyword,
    String? selectedTag,
    String? selectedArtist,
  }) {
    if (searchKeyword != null && searchKeyword.trim().isNotEmpty) {
      final kw = Uri.encodeComponent(searchKeyword.trim());
      return page <= 1 ? '$kBaseUrl/search/$kw/' : '$kBaseUrl/search/$kw/$page/';
    }

    if (selectedTag != null && selectedTag.trim().isNotEmpty) {
      final tag = Uri.encodeComponent(selectedTag.trim());
      return page <= 1 ? '$kBaseUrl/tags/$tag/' : '$kBaseUrl/tags/$tag/$page/';
    }

    if (selectedArtist != null && selectedArtist.trim().isNotEmpty) {
      final artist = Uri.encodeComponent(selectedArtist.trim());
      return page <= 1 ? '$kBaseUrl/models/$artist/' : '$kBaseUrl/models/$artist/$page/';
    }

    if (category == Rule34VideoCategory.trending) {
      return page <= 1 ? '$kBaseUrl/' : '$kBaseUrl/?page=$page';
    }

    final catPath = category.path.endsWith('/') ? category.path : '${category.path}/';
    return page <= 1 ? '$kBaseUrl$catPath' : '$kBaseUrl$catPath$page/';
  }

  /// Fetch paginated videos from Rule34Video
  static Future<Rule34VideoPageData> fetchPageData({
    int page = 1,
    Rule34VideoCategory category = Rule34VideoCategory.latest,
    String? searchKeyword,
    String? selectedTag,
    String? selectedArtist,
  }) async {
    final url = buildUrl(
      page: page,
      category: category,
      searchKeyword: searchKeyword,
      selectedTag: selectedTag,
      selectedArtist: selectedArtist,
    );

    debugPrint('[Rule34VideoApiService] Fetching videos: $url');
    final html = await _fetchHtml(url);
    final document = html_parser.parse(html);

    final List<VideoItem> items = [];
    final cardElements = document.querySelectorAll('div.item.thumb, div.item[data-video-card-id]');

    for (final card in cardElements) {
      final videoId = card.attributes['data-video-card-id'] ?? '';
      final linkEl = card.querySelector('a.th, a[href*="/video/"]');
      if (linkEl == null) continue;

      final href = linkEl.attributes['href'] ?? '';
      if (!href.contains('/video/')) continue;

      final fullDetailUrl = href.startsWith('http') ? href : '$kBaseUrl$href';

      // Title
      String title = (linkEl.attributes['title'] ?? '').trim();
      if (title.isEmpty) {
        final titleEl = card.querySelector('.thumb_title, .title');
        title = (titleEl?.text ?? 'Rule34 Video').trim();
      }

      // Cover image
      final imgEl = card.querySelector('img.thumb, img');
      String? coverUrl = imgEl?.attributes['data-original'] ??
          imgEl?.attributes['data-webp'] ??
          imgEl?.attributes['data-src'] ??
          imgEl?.attributes['src'];
      if (coverUrl != null && !coverUrl.startsWith('http') && !coverUrl.startsWith('data:')) {
        coverUrl = '$kBaseUrl$coverUrl';
      }

      // Animated Preview MP4
      final imgWrap = card.querySelector('div.img.wrap_image');
      final previewMp4 = imgWrap?.attributes['data-preview'];

      // Duration
      final durationEl = card.querySelector('.time, .duration');
      final duration = durationEl?.text.trim() ?? '';

      // Date / Added
      final dateEl = card.querySelector('.added, .video-card-meta__date');
      final date = dateEl?.text.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';

      // Rating / Thumbs up
      final ratingEl = card.querySelector('.rating, .video-card-meta__rating');
      final rating = ratingEl?.text.trim() ?? '';

      // Slug
      final slug = videoId.isNotEmpty ? 'r34_$videoId' : 'r34_${href.hashCode}';

      items.add(
        VideoItem(
          title: title,
          slug: slug,
          detailUrl: fullDetailUrl,
          coverUrl: coverUrl,
          date: date,
          author: 'Rule34Video',
          tags: const [],
          rawData: {
            'id': videoId,
            'duration': duration,
            'previewMp4': previewMp4,
            'rating': rating,
            'source': 'rule34video',
          },
        ),
      );
    }

    // Parse pagination
    int totalPages = page;
    final paginationLinks = document.querySelectorAll('.pagination a, .paging a, ul.pagination li a');
    for (final p in paginationLinks) {
      final pNum = int.tryParse(p.text.trim());
      if (pNum != null && pNum > totalPages) {
        totalPages = pNum;
      }
    }
    if (totalPages < page) totalPages = page;
    if (items.isNotEmpty && totalPages == page) {
      totalPages = page + 1; // enable next page if items exist
    }

    return Rule34VideoPageData(
      items: items,
      currentPage: page,
      totalPages: totalPages,
    );
  }

  /// Resolve full video details and streaming quality links
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    final detailUrl = item.detailUrl;
    debugPrint('[Rule34VideoApiService] Resolving detail: $detailUrl');

    final html = await _fetchHtml(detailUrl);
    final document = html_parser.parse(html);

    final Map<String, dynamic> qualities = {};

    // 1. Check explicit download tags: <a class="tag_item tag_item_download" href="...">MP4 1080p</a>
    final downloadLinks = document.querySelectorAll('a.tag_item_download, a[href*="/get_file/"]');
    for (final dl in downloadLinks) {
      final href = dl.attributes['href'];
      final text = dl.text.trim().toLowerCase();
      if (href == null || href.isEmpty) continue;

      final fullHref = href.startsWith('http') ? href : '$kBaseUrl$href';
      if (text.contains('1080') || href.contains('1080p')) {
        qualities['1080p'] = fullHref;
      } else if (text.contains('720') || href.contains('720p')) {
        qualities['720p'] = fullHref;
      } else if (text.contains('480') || href.contains('480p')) {
        qualities['480p'] = fullHref;
      } else if (text.contains('360') || href.contains('360')) {
        qualities['360p'] = fullHref;
      } else {
        qualities[text.replaceAll('mp4', '').trim()] = fullHref;
      }
    }

    // 2. Check HTML5 flashvars in scripts if download tags not found
    if (qualities.isEmpty) {
      final scriptElements = document.querySelectorAll('script');
      for (final script in scriptElements) {
        final content = script.text;
        if (content.contains('video_url') || content.contains('video_alt_url')) {
          final videoUrlMatch = RegExp(r"video_url:\s*'([^']+)'").firstMatch(content);
          final altUrlMatch = RegExp(r"video_alt_url:\s*'([^']+)'").firstMatch(content);
          final alt2UrlMatch = RegExp(r"video_alt_url2:\s*'([^']+)'").firstMatch(content);
          final alt3UrlMatch = RegExp(r"video_alt_url3:\s*'([^']+)'").firstMatch(content);

          if (videoUrlMatch != null) qualities['1080p'] = videoUrlMatch.group(1);
          if (altUrlMatch != null) qualities['720p'] = altUrlMatch.group(1);
          if (alt2UrlMatch != null) qualities['480p'] = alt2UrlMatch.group(1);
          if (alt3UrlMatch != null) qualities['360p'] = alt3UrlMatch.group(1);
          break;
        }
      }
    }

    // Pick highest quality stream
    String? bestStreamUrl;
    for (final q in ['1080p', '720p', '480p', '360p']) {
      if (qualities.containsKey(q)) {
        bestStreamUrl = qualities[q]?.toString();
        break;
      }
    }
    bestStreamUrl ??= qualities.values.isNotEmpty ? qualities.values.first.toString() : null;

    // Extract tags & artists
    final List<String> tags = [];
    final tagElements = document.querySelectorAll('a[href*="/tags/"], a[href*="/categories/"]');
    for (final t in tagElements) {
      final name = t.text.trim();
      if (name.isNotEmpty && !tags.contains(name) && !name.contains('Tags') && !name.contains('Categories')) {
        tags.add(name);
      }
    }

    // Extract artist/model
    String author = item.author;
    final modelEl = document.querySelector('a[href*="/models/"]');
    if (modelEl != null && modelEl.text.trim().isNotEmpty) {
      author = modelEl.text.trim();
    }

    // Extract Title
    final h1El = document.querySelector('h1.title, h1');
    final title = (h1El?.text ?? item.title).trim();

    final updatedRawData = Map<String, dynamic>.from(item.rawData);
    updatedRawData['qualities'] = qualities;
    updatedRawData['source'] = 'rule34video';

    return VideoItem(
      title: title.isNotEmpty ? title : item.title,
      slug: item.slug,
      detailUrl: item.detailUrl,
      coverUrl: item.coverUrl,
      videoUrl: bestStreamUrl ?? item.videoUrl,
      date: item.date,
      author: author,
      tags: tags.isNotEmpty ? tags : item.tags,
      rawData: updatedRawData,
    );
  }

  /// Backward-compatible wrapper
  static Future<VideoItem> fetchVideoDetail(VideoItem item) => resolveVideoDetail(item);
}
