import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';
import '../network_client.dart';

enum CosplayporntubeCategory {
  trending('热门', '/'),
  newest('最新', '/newest/'),
  popular('最受欢迎', '/popular/');

  final String label;
  final String path;
  const CosplayporntubeCategory(this.label, this.path);
}

class CosplayporntubePageData {
  final List<VideoItem> items;
  final int currentPage;
  final int totalPages;

  const CosplayporntubePageData({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });
}

class CosplayporntubeApiService {
  static const String kBaseUrl = 'https://cosplayporntube.com';

  static String? _configuredProxy;

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
  }

  static Dio _createDio() {
    return NetworkClient.createDio(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      specificProxy: _configuredProxy,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Referer': 'https://cosplayporntube.com/',
      },
    );
  }

  static String buildUrl({
    int page = 1,
    CosplayporntubeCategory category = CosplayporntubeCategory.trending,
    String? keyword,
  }) {
    final cleanKw = keyword?.trim();
    if (cleanKw != null && cleanKw.isNotEmpty) {
      if (page > 1) {
        return '$kBaseUrl/page/$page/?s=${Uri.encodeQueryComponent(cleanKw)}';
      }
      return '$kBaseUrl/?s=${Uri.encodeQueryComponent(cleanKw)}';
    }

    if (category == CosplayporntubeCategory.trending) {
      if (page > 1) {
        return '$kBaseUrl/page/$page/';
      }
      return '$kBaseUrl/';
    }

    final catPath = category.path.replaceAll(RegExp(r'^/|/$'), '');
    if (page > 1) {
      return '$kBaseUrl/$catPath/page/$page/';
    }
    return '$kBaseUrl/$catPath/';
  }

  /// Fetch list page data
  static Future<CosplayporntubePageData> fetchPageData({
    int page = 1,
    CosplayporntubeCategory category = CosplayporntubeCategory.trending,
    String? keyword,
  }) async {
    final dio = _createDio();
    final url = buildUrl(page: page, category: category, keyword: keyword);
    debugPrint('[CosplayporntubeApiService] Fetching list: $url');

    final response = await dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data ?? '';
    return _parseListPageHtml(html, page);
  }

  static CosplayporntubePageData _parseListPageHtml(String html, int requestPage) {
    final doc = html_parser.parse(html);
    final itemEls = doc.querySelectorAll('div.item');
    final items = <VideoItem>[];

    final bgRegex = RegExp(r'url\((.*?)\)');

    for (final it in itemEls) {
      final aLink = it.querySelector('a.clip-link') ?? it.querySelector('a.entry-title') ?? it.querySelector('a');
      if (aLink == null) continue;

      var href = aLink.attributes['href']?.trim() ?? '';
      if (href.isEmpty) continue;
      if (!href.startsWith('http')) {
        href = '$kBaseUrl${href.startsWith('/') ? '' : '/'}$href';
      }

      var title = aLink.text.trim();
      if (title.isEmpty) {
        title = aLink.attributes['title']?.trim() ?? '';
      }

      final thumbDiv = it.querySelector('.thumb');
      String? coverUrl;
      if (thumbDiv != null) {
        final style = thumbDiv.attributes['style'] ?? '';
        final m = bgRegex.firstMatch(style);
        if (m != null) {
          coverUrl = m.group(1)?.replaceAll('"', '').replaceAll("'", "").trim();
        }
      }

      final imgEl = it.querySelector('img');
      coverUrl ??= imgEl?.attributes['src']?.trim() ?? imgEl?.attributes['data-src']?.trim();
      if (coverUrl != null && !coverUrl.startsWith('http')) {
        coverUrl = '$kBaseUrl${coverUrl.startsWith('/') ? '' : '/'}$coverUrl';
      }

      final durationEl = it.querySelector('.video-info') ?? it.querySelector('.duration');
      final duration = durationEl?.text.trim() ?? '';

      final viewsEl = it.querySelector('.views');
      final views = viewsEl?.text.trim() ?? '';

      final postId = it.attributes['id']?.replaceAll('post-', '').trim() ?? '';
      final slug = Uri.parse(href).path.replaceAll(RegExp(r'^/|/$'), '');

      items.add(
        VideoItem(
          title: title.isNotEmpty ? title : 'Cosplay Video',
          slug: slug.isNotEmpty ? slug : postId,
          detailUrl: href,
          coverUrl: coverUrl,
          duration: duration,
          views: views,
          date: '',
          author: 'CosplayPornTube',
          rawData: {
            'duration': duration,
            'views': views,
            'post_id': postId,
            'source': 'cosplayporntube',
          },
        ),
      );
    }

    // Parse pagination
    int totalPages = requestPage;
    final pageLinks = doc.querySelectorAll('.pag-nav a, ul.pagination a, .pages a');
    for (final pl in pageLinks) {
      final t = pl.text.replaceAll(',', '').replaceAll(' ', '').trim();
      final pNum = int.tryParse(t);
      if (pNum != null && pNum > totalPages) {
        totalPages = pNum;
      }
      final href = pl.attributes['href'] ?? '';
      final m = RegExp(r'/page/(\d+)/').firstMatch(href);
      if (m != null) {
        final numFromHref = int.tryParse(m.group(1)!);
        if (numFromHref != null && numFromHref > totalPages) {
          totalPages = numFromHref;
        }
      }
    }

    return CosplayporntubePageData(
      items: items,
      currentPage: requestPage,
      totalPages: totalPages < requestPage ? requestPage : totalPages,
    );
  }

  /// Resolve full video details including MP4 streaming URLs
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    final dio = _createDio();
    debugPrint('[CosplayporntubeApiService] Resolving detail: ${item.detailUrl}');

    final response = await dio.get<String>(
      item.detailUrl,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data ?? '';
    final doc = html_parser.parse(html);

    var videoUrl = '';
    var posterUrl = item.coverUrl;

    final videoEl = doc.querySelector('video#video-player, video[id^="video-player"], video');
    if (videoEl != null) {
      final p = videoEl.attributes['poster'] ?? videoEl.attributes['data-poster'];
      if (p != null && p.isNotEmpty) {
        posterUrl = p.startsWith('http') ? p : '$kBaseUrl$p';
      }

      final directSrc = videoEl.attributes['src'];
      if (directSrc != null && directSrc.isNotEmpty) {
        videoUrl = directSrc.startsWith('http') ? directSrc : '$kBaseUrl$directSrc';
      }

      for (final srcEl in videoEl.querySelectorAll('source')) {
        final sUrl = srcEl.attributes['src']?.trim() ?? '';
        if (sUrl.isEmpty) continue;
        videoUrl = sUrl.startsWith('http') ? sUrl : '$kBaseUrl$sUrl';
        break;
      }
    }

    // Fallback regex search for MP4 in script tags
    if (videoUrl.isEmpty) {
      final mp4Match = RegExp(r'https?://[^\s"<>]+\.mp4(?:\?[^\s"<>]*)?').firstMatch(html);
      if (mp4Match != null) {
        videoUrl = mp4Match.group(0) ?? '';
      }
    }

    final tags = <String>[];
    for (final a in doc.querySelectorAll('a[href*="/category/"], a[href*="/tag/"], a[href*="/model/"]')) {
      final t = a.text.trim();
      if (t.isNotEmpty &&
          !t.startsWith('View all') &&
          !tags.contains(t) &&
          !['Trending', 'Newest', 'Most Popular'].contains(t)) {
        tags.add(t);
      }
    }

    final updatedRawData = Map<String, dynamic>.from(item.rawData);
    updatedRawData['source'] = 'cosplayporntube';
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
