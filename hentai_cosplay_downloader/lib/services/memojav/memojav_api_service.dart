import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';
import '../network_client.dart';

enum MemojavCategory {
  best('热门推荐', 'best/'),
  latest('最新影片', 'video/'),
  actress('女优分类', 'actress/'),
  studio('片商分类', 'studio/'),
  series('系列分类', 'series/'),
  categories('分类标签', 'categories/');

  final String label;
  final String path;
  const MemojavCategory(this.label, this.path);
}

class MemojavPageData {
  final List<VideoItem> items;
  final int currentPage;
  final int totalPages;

  const MemojavPageData({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });
}

class MemojavApiService {
  static const String kBaseUrl = 'https://memojav.org';
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
      allowBadCertificates: true,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        'Referer': 'https://memojav.org/',
        'sec-ch-ua':
            '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'document',
        'sec-fetch-mode': 'navigate',
        'sec-fetch-site': 'same-origin',
        'upgrade-insecure-requests': '1',
      },
    );
  }

  /// Builds catalog or video URL for MemoJAV
  static String buildUrl({
    int page = 1,
    MemojavCategory category = MemojavCategory.best,
    String? keyword,
  }) {
    if (keyword != null && keyword.trim().isNotEmpty) {
      final sanitized = keyword.trim().toUpperCase();
      return '$kBaseUrl/video/$sanitized';
    }

    final catPath = category.path.startsWith('/') ? category.path.substring(1) : category.path;
    if (page <= 1) {
      return '$kBaseUrl/$catPath';
    }
    // MemoJAV uses /best/page-2 or /video/page-2
    final cleanPath = catPath.endsWith('/') ? catPath : '$catPath/';
    return '$kBaseUrl/${cleanPath}page-$page';
  }

  /// Fetches a page of video items
  static Future<MemojavPageData> fetchVideos({
    int page = 1,
    MemojavCategory category = MemojavCategory.best,
    String? keyword,
  }) async {
    final dio = _dio;
    final url = buildUrl(page: page, category: category, keyword: keyword);
    debugPrint('[MemojavApiService] Fetching: $url');

    try {
      final response = await dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );

      final html = response.data ?? '';
      return _parseListPageHtml(html, page, requestedUrl: url);
    } catch (e) {
      debugPrint('[MemojavApiService] Error fetching $url: $e');
      rethrow;
    }
  }

  @visibleForTesting
  static MemojavPageData parseListPageHtmlForTest(String html, int requestPage) =>
      _parseListPageHtml(html, requestPage);

  static MemojavPageData _parseListPageHtml(
    String html,
    int requestPage, {
    String? requestedUrl,
  }) {
    final doc = html_parser.parse(html);

    // If this returned a single video detail page (from keyword search)
    if (doc.querySelector('#player-container') != null ||
        doc.querySelector('meta[property="og:type"][content*="video"]') != null) {
      final titleEl = doc.querySelector('h1#title') ?? doc.querySelector('h1');
      final title = titleEl?.text.trim() ?? '';
      final posterEl = doc.querySelector('meta[property="og:image"]');
      final coverUrl = posterEl?.attributes['content']?.trim() ?? '';
      final slugMatch = RegExp(r'/video/([^/?#]+)').firstMatch(requestedUrl ?? '');
      final slug = slugMatch?.group(1) ?? '';

      if (title.isNotEmpty && slug.isNotEmpty) {
        return MemojavPageData(
          items: [
            VideoItem(
              title: title,
              slug: slug,
              detailUrl: requestedUrl ?? '$kBaseUrl/video/$slug',
              coverUrl: coverUrl,
              duration: '',
              views: '',
              date: '',
              author: 'MemoJAV',
              rawData: {
                'slug': slug,
                'source': 'memojav',
                'embed_url': '$kBaseUrl/embed/$slug',
              },
            ),
          ],
          currentPage: 1,
          totalPages: 1,
        );
      }
    }

    final cardEls = doc.querySelectorAll('.video-item, a.video-item, #relative-video a');
    final items = <VideoItem>[];
    final seenSlugs = <String>{};

    for (final el in cardEls) {
      var href = el.attributes['href']?.trim() ?? '';
      if (href.isEmpty) {
        final aChild = el.querySelector('a[href*="/video/"]');
        href = aChild?.attributes['href']?.trim() ?? '';
      }
      if (href.isEmpty) continue;

      if (!href.startsWith('http')) {
        href = '$kBaseUrl${href.startsWith('/') ? href : '/$href'}';
      }

      final uri = Uri.tryParse(href);
      final segments = uri?.pathSegments ?? [];
      final slug = segments.isNotEmpty ? segments.last : href;
      if (slug.isEmpty || seenSlugs.contains(slug)) continue;
      seenSlugs.add(slug);

      // Title
      final titleEl = el.querySelector('.video-title') ?? el.querySelector('img[alt]');
      var title = titleEl?.text.trim() ?? '';
      if (title.isEmpty) {
        final imgEl = el.querySelector('img');
        title = imgEl?.attributes['alt']?.trim() ?? '';
      }
      if (title.isEmpty) {
        title = slug.toUpperCase();
      }

      // Cover image
      final imgEl = el.querySelector('img.video-poster') ?? el.querySelector('img');
      var coverUrl = imgEl?.attributes['src']?.trim() ??
          imgEl?.attributes['data-src']?.trim() ??
          '';
      if (coverUrl.startsWith('//')) {
        coverUrl = 'https:$coverUrl';
      } else if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
        coverUrl = '$kBaseUrl$coverUrl';
      }

      // Metadata (e.g. JUR-511 • MADONNA • Huziura Megu)
      final metaEl = el.querySelector('.video-metadata');
      final metadata = metaEl?.text.trim() ?? '';

      items.add(
        VideoItem(
          title: title,
          slug: slug,
          detailUrl: href,
          coverUrl: coverUrl,
          duration: '',
          views: '',
          date: '',
          author: 'MemoJAV',
          rawData: {
            'slug': slug,
            'source': 'memojav',
            'metadata': metadata,
            'embed_url': '$kBaseUrl/embed/$slug',
          },
        ),
      );
    }

    // Pagination
    int totalPages = requestPage;

    // 1. Try inputNumber_nav max attribute
    final inputNav = doc.querySelector('input.inputNumber_nav');
    final maxAttr = inputNav?.attributes['max'];
    if (maxAttr != null) {
      final maxVal = int.tryParse(maxAttr);
      if (maxVal != null && maxVal > totalPages) {
        totalPages = maxVal;
      }
    }

    // 2. Try pageNav-main links
    final pageLinks = doc.querySelectorAll('.pageNav-main .pageNav-page a, ul.pageNav-main a');
    for (final a in pageLinks) {
      final text = a.text.trim();
      final numVal = int.tryParse(text);
      if (numVal != null && numVal > totalPages) {
        totalPages = numVal;
      }
      final href = a.attributes['href'] ?? '';
      final pageMatch = RegExp(r'page-(\d+)').firstMatch(href);
      if (pageMatch != null) {
        final p = int.tryParse(pageMatch.group(1)!);
        if (p != null && p > totalPages) {
          totalPages = p;
        }
      }
    }

    return MemojavPageData(
      items: items,
      currentPage: requestPage,
      totalPages: totalPages < requestPage ? requestPage : totalPages,
    );
  }

  /// Resolves detailed video metadata
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    final dio = _dio;
    debugPrint('[MemojavApiService] Resolving detail: ${item.detailUrl}');

    final response = await dio.get<String>(
      item.detailUrl,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data ?? '';
    final doc = html_parser.parse(html);

    // Title
    final titleEl = doc.querySelector('h1#title') ?? doc.querySelector('h1');
    var fullTitle = titleEl?.text.trim() ?? '';
    if (fullTitle.isEmpty) {
      final metaTitle = doc.querySelector('meta[property="og:title"]');
      fullTitle = metaTitle?.attributes['content']?.trim() ?? item.title;
    }

    // Cover / Poster
    final posterEl = doc.querySelector('#poster') ??
        doc.querySelector('.image-item.image-full img') ??
        doc.querySelector('meta[property="og:image"]');
    var posterUrl = posterEl?.attributes['src']?.trim() ??
        posterEl?.attributes['content']?.trim() ??
        item.coverUrl;
    if (posterUrl != null && posterUrl.startsWith('//')) {
      posterUrl = 'https:$posterUrl';
    }

    // Duration (e.g. PT138M0S -> 138分钟)
    final durMeta = doc.querySelector('meta[itemprop="duration"]');
    var duration = durMeta?.attributes['content']?.trim() ?? '';
    if (duration.isNotEmpty) {
      final durMatch = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?').firstMatch(duration);
      if (durMatch != null) {
        final hours = int.tryParse(durMatch.group(1) ?? '0') ?? 0;
        final minutes = int.tryParse(durMatch.group(2) ?? '0') ?? 0;
        if (hours > 0) {
          duration = '$hours小时$minutes分';
        } else if (minutes > 0) {
          duration = '$minutes分钟';
        }
      }
    }

    // Tags & metadata
    final tags = <String>[];
    String? studio;
    String? actress;
    String? series;

    for (final a in doc.querySelectorAll('a[href*="/categories/"]')) {
      final t = a.text.trim();
      if (t.isNotEmpty && !tags.contains(t)) {
        tags.add(t);
      }
    }

    for (final a in doc.querySelectorAll('a[href*="/actress/"]')) {
      final t = a.text.trim();
      if (t.isNotEmpty) {
        actress = t;
        if (!tags.contains(t)) tags.insert(0, t);
      }
    }

    for (final a in doc.querySelectorAll('a[href*="/studio/"]')) {
      final t = a.text.trim();
      if (t.isNotEmpty) {
        studio = t;
        if (!tags.contains(t)) tags.add(t);
      }
    }

    for (final a in doc.querySelectorAll('a[href*="/series/"]')) {
      final t = a.text.trim();
      if (t.isNotEmpty) {
        series = t;
      }
    }

    // Release Date
    var date = item.date;
    final dateMeta = doc.querySelector('meta[itemprop="datePublished"]');
    if (dateMeta != null) {
      date = dateMeta.attributes['content']?.trim() ?? '';
      if (date.contains('T')) {
        date = date.split('T').first;
      }
    }
    if (date.isEmpty) {
      final dateMatch = RegExp(r'\b(20\d{2}[-/]\d{2}[-/]\d{2})\b').firstMatch(html);
      date = dateMatch?.group(1) ?? '';
    }

    // Preview MP4 Video (trailer)
    final previewEl = doc.querySelector('#preview-vid') ?? doc.querySelector('video[src*=".mp4"]');
    var previewVideo = previewEl?.attributes['src']?.trim() ?? '';

    // Embed player URL
    var embedUrl = '$kBaseUrl/embed/${item.slug}';
    final embedIframe = doc.querySelector('iframe.responsive-iframe');
    final iframeSrc = embedIframe?.attributes['src']?.trim();
    if (iframeSrc != null && iframeSrc.isNotEmpty) {
      embedUrl = iframeSrc.startsWith('http') ? iframeSrc : '$kBaseUrl$iframeSrc';
    }

    // Screenshots
    final screenshots = <String>[];
    for (final img in doc.querySelectorAll('#image-list img, .thumb-list img')) {
      var src = img.attributes['src']?.trim() ?? '';
      if (src.isNotEmpty && !screenshots.contains(src)) {
        if (src.startsWith('//')) src = 'https:$src';
        screenshots.add(src);
      }
    }

    final updatedRawData = Map<String, dynamic>.from(item.rawData);
    updatedRawData['source'] = 'memojav';
    updatedRawData['slug'] = item.slug;
    updatedRawData['preview_video'] = previewVideo;
    updatedRawData['embed_url'] = embedUrl;
    if (studio != null) updatedRawData['studio'] = studio;
    if (actress != null) updatedRawData['actress'] = actress;
    if (series != null) updatedRawData['series'] = series;
    if (screenshots.isNotEmpty) updatedRawData['screenshots'] = screenshots;

    return item.copyWith(
      title: fullTitle.isNotEmpty ? fullTitle : item.title,
      coverUrl: posterUrl,
      videoUrl: previewVideo.isNotEmpty ? previewVideo : embedUrl,
      duration: duration.isNotEmpty ? duration : item.duration,
      date: date.isNotEmpty ? date : item.date,
      tags: tags.isNotEmpty ? tags : item.tags,
      author: actress ?? (studio ?? 'MemoJAV'),
      isDetailLoaded: true,
      rawData: updatedRawData,
    );
  }
}
