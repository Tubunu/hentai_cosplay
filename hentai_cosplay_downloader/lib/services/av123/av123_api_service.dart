import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';
import '../network_client.dart';

enum Av123Category {
  newest('最新发布', '/cn/new'),
  hot('热门推荐', '/cn/hot'),
  recent('最近更新', '/cn/recent'),
  today('今日热门', '/cn/all?sort=today'),
  week('本周热门', '/cn/all?sort=week'),
  month('本月热门', '/cn/all?sort=month'),
  censored('日本有码', '/cn/censored'),
  uncensored('日本无码', '/cn/uncensored'),
  uncensoredLeaked('无码流出', '/cn/uncensored-leaked');

  final String label;
  final String path;
  const Av123Category(this.label, this.path);
}

class Av123PageData {
  final List<VideoItem> items;
  final int currentPage;
  final int totalPages;

  const Av123PageData({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });
}

class Av123DetailData {
  final VideoItem item;
  final List<String> embedUrls;
  final List<String> tags;
  final List<String> actresses;
  final String? releaseDate;

  const Av123DetailData({
    required this.item,
    required this.embedUrls,
    required this.tags,
    required this.actresses,
    this.releaseDate,
  });
}

class Av123ApiService {
  static const String kBaseUrl = 'https://123av.com';
  static String? _configuredProxy;

  static void setProxy(String? proxy) {
    _configuredProxy = proxy;
  }

  static Dio _createDio() {
    return NetworkClient.createDio(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 45),
      specificProxy: _configuredProxy,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        'Referer': 'https://123av.com/cn',
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

  static String buildUrl({
    int page = 1,
    Av123Category category = Av123Category.newest,
    String? keyword,
  }) {
    final cleanKw = keyword?.trim();
    if (cleanKw != null && cleanKw.isNotEmpty) {
      final encoded = Uri.encodeComponent(cleanKw);
      return '$kBaseUrl/cn/search?keyword=$encoded&page=$page';
    }

    if (category.path.contains('?')) {
      return '$kBaseUrl${category.path}&page=$page';
    }

    if (page > 1) {
      return '$kBaseUrl${category.path}?page=$page';
    }
    return '$kBaseUrl${category.path}';
  }

  static Future<Av123PageData> fetchVideos({
    int page = 1,
    Av123Category category = Av123Category.newest,
    String? keyword,
  }) async {
    final dio = _createDio();
    final url = buildUrl(page: page, category: category, keyword: keyword);
    debugPrint('[Av123ApiService] Fetching URL: $url');

    final response = await dio.get<String>(url);
    final html = response.data ?? '';
    return parseHtml(html, currentPage: page);
  }

  static Av123PageData parseHtml(String html, {int currentPage = 1}) {
    final doc = html_parser.parse(html);
    final List<VideoItem> items = [];
    final seenSlugs = <String>{};

    final cardElements = doc.querySelectorAll('.card, div[class*="video-item"]');

    for (final card in cardElements) {
      final aTag = card.querySelector('a[href*="/v/"]') ?? card.querySelector('a');
      if (aTag == null) continue;

      var href = aTag.attributes['href'] ?? '';
      if (href.isEmpty || href == '#' || !href.contains('/v/')) continue;
      if (!href.startsWith('http')) {
        href = '$kBaseUrl$href';
      }

      final imgTag = card.querySelector('img');
      var thumb = imgTag?.attributes['data-src'] ??
          imgTag?.attributes['src'] ??
          '';

      final titleEl = card.querySelector('.card__title') ??
          card.querySelector('a.card__link') ??
          card.querySelector('h3') ??
          card.querySelector('.card-title') ??
          card.querySelector('.title');
      var title = titleEl?.text.trim() ?? '';
      if (title.isEmpty) {
        title = aTag.attributes['title'] ?? imgTag?.attributes['alt'] ?? '';
      }
      if (title.isEmpty) {
        final parts = href.split('/').where((s) => s.isNotEmpty).toList();
        title = parts.isNotEmpty ? parts.last.toUpperCase() : '123AV Video';
      }

      // Extract duration badge if present
      final durTag = card.querySelector('.card__dur') ??
          card.querySelector('.duration') ??
          card.querySelector('.label') ??
          card.querySelector('span[class*="dur"]');
      var duration = durTag?.text.trim() ?? '';
      if (duration == '0:00' || duration == '00:00' || duration == '0') {
        duration = '';
      }

      final slug = href;
      if (seenSlugs.contains(slug)) continue;
      seenSlugs.add(slug);

      items.add(VideoItem(
        title: title,
        slug: slug,
        detailUrl: href,
        coverUrl: thumb,
        duration: duration,
        views: '',
        date: '',
        author: '',
      ));
    }

    // Pagination
    int totalPages = currentPage;
    final pageLinks = doc.querySelectorAll('.pagination a, a[href*="page="]');
    for (final pl in pageLinks) {
      final text = pl.text.trim();
      final num = int.tryParse(text);
      if (num != null && num > totalPages) {
        totalPages = num;
      }
      final href = pl.attributes['href'] ?? '';
      final pageMatch = RegExp(r'page=(\d+)').firstMatch(href);
      if (pageMatch != null) {
        final p = int.tryParse(pageMatch.group(1) ?? '');
        if (p != null && p > totalPages) {
          totalPages = p;
        }
      }
    }

    if (items.isNotEmpty && totalPages <= currentPage) {
      totalPages = currentPage + 1;
    }

    return Av123PageData(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages,
    );
  }

  static Future<Av123DetailData> fetchDetail(VideoItem item) async {
    final dio = _createDio();
    final response = await dio.get<String>(
      item.detailUrl,
      options: Options(headers: {'Referer': 'https://123av.com/cn'}),
    );
    final html = response.data ?? '';
    final doc = html_parser.parse(html);

    // Title
    final titleEl = doc.querySelector('h1.title') ?? doc.querySelector('h1');
    final title = titleEl?.text.trim() ?? item.title;

    // Cover: preserve item.coverUrl if valid, or check player style / og:image
    var cover = (item.coverUrl != null && item.coverUrl!.isNotEmpty) ? item.coverUrl : '';
    final coverEl = doc.querySelector('.player');
    final styleAttr = coverEl?.attributes['style'] ?? '';
    final styleMatch = RegExp(r"url\(['\x22]?([^'\x22\)]+)['\x22]?\)").firstMatch(styleAttr);
    if (styleMatch != null && (styleMatch.group(1)?.isNotEmpty ?? false)) {
      cover = styleMatch.group(1);
    } else {
      final ogImage = doc.querySelector('meta[property="og:image"]')?.attributes['content'];
      if (ogImage != null && ogImage.isNotEmpty && !ogImage.contains('logo')) {
        cover = ogImage;
      }
    }
    if (cover == null || cover.isEmpty) {
      cover = item.coverUrl;
    }

    // Extract episodes / embed URLs from player(JSON.parse('...'))
    final List<String> embedUrls = [];
    final jsonMatch = RegExp(r"player\(JSON\.parse\(('(.*?)')\)").firstMatch(html);
    if (jsonMatch != null) {
      try {
        var rawQuoted = jsonMatch.group(1)!;
        // Unescape single quotes wrapper
        if (rawQuoted.startsWith("'") && rawQuoted.endsWith("'")) {
          rawQuoted = rawQuoted.substring(1, rawQuoted.length - 1);
        }
        // Handle JS string escape sequences
        rawQuoted = rawQuoted.replaceAll(r'\"', '"').replaceAll(r'\/', '/');
        final decoded = jsonDecode(rawQuoted);
        if (decoded is List) {
          for (final ep in decoded) {
            if (ep is Map && ep['url'] != null) {
              final u = ep['url'].toString();
              if (u.startsWith('http') && !embedUrls.contains(u)) {
                embedUrls.add(u);
              }
              // Extract HD poster if present in the player URL
              final posterMatch = RegExp(r'poster=([^&]+)').firstMatch(u);
              if (posterMatch != null) {
                final rawPoster = Uri.decodeComponent(posterMatch.group(1)!);
                if (rawPoster.startsWith('http')) {
                  cover = rawPoster;
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[Av123ApiService] Failed to parse player JSON: $e');
      }
    }

    // Secondary search for iframe
    final iframes = doc.querySelectorAll('iframe');
    for (final ifr in iframes) {
      final src = ifr.attributes['src'] ?? '';
      if (src.startsWith('http') && !embedUrls.contains(src)) {
        embedUrls.add(src);
      }
    }

    // Parse tags, actresses, date
    final List<String> tags = [];
    final List<String> actresses = [];
    String? releaseDate;

    for (final a in doc.querySelectorAll('a[href*="/tag/"], a[href*="/genres/"]')) {
      final t = a.text.trim();
      if (t.isNotEmpty && !tags.contains(t)) {
        tags.add(t);
      }
    }

    for (final a in doc.querySelectorAll('a[href*="/actress/"], a[href*="/actor/"]')) {
      final act = a.text.trim();
      if (act.isNotEmpty && !actresses.contains(act)) {
        actresses.add(act);
      }
    }

    final dateEl = doc.querySelector('.date, time');
    if (dateEl != null) {
      releaseDate = dateEl.text.trim();
    }

    final updatedItem = item.copyWith(
      title: title,
      coverUrl: cover,
      author: actresses.isNotEmpty ? actresses.join(', ') : item.author,
      tags: tags,
    );

    return Av123DetailData(
      item: updatedItem,
      embedUrls: embedUrls,
      tags: tags,
      actresses: actresses,
      releaseDate: releaseDate,
    );
  }

  /// Resolves an episode player URL (e.g. https://javplayer.cc/e/{id}) to a direct .m3u8 stream URL
  static Future<String?> resolveStreamUrl(String embedOrDetailUrl) async {
    if (embedOrDetailUrl.endsWith('.m3u8') || embedOrDetailUrl.endsWith('.mp4')) {
      return embedOrDetailUrl;
    }

    final hashMatch = RegExp(r'/e/([a-zA-Z0-9_]+)').firstMatch(embedOrDetailUrl);
    if (hashMatch == null) return null;
    final hashId = hashMatch.group(1)!;

    try {
      final dio = _createDio();
      final resp = await dio.get<Map<String, dynamic>>(
        'https://javplayer.cc/stream?id=$hashId',
        options: Options(headers: {
          'Referer': 'https://javplayer.cc/e/$hashId',
          'Accept': 'application/json, text/plain, */*',
        }),
      );
      final data = resp.data;
      if (data != null && data['status'] == 'ok') {
        final stream = data['media']?['stream']?.toString();
        if (stream != null && stream.isNotEmpty) {
          return stream;
        }
      }
    } catch (e) {
      debugPrint('[Av123ApiService] resolveStreamUrl error: $e');
    }
    return null;
  }
}
