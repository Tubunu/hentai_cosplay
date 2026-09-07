import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';
import '../network_client.dart';

enum JavmostCategory {
  all('全部影片', '/category/all/'),
  censor('有码 JAV', '/category/censor/'),
  uncensor('无码 JAV', '/category/uncensor/'),
  topDaily('每日最热', '/topdaily/'),
  topView('实时热门', '/topview/');

  final String label;
  final String path;
  const JavmostCategory(this.label, this.path);
}

class JavmostPageData {
  final List<VideoItem> items;
  final int currentPage;
  final int totalPages;

  const JavmostPageData({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });
}

class JavmostDetailData {
  final VideoItem item;
  final List<String> embedUrls;
  final List<String> tags;
  final List<String> actresses;
  final String? releaseDate;
  final String? studio;

  const JavmostDetailData({
    required this.item,
    required this.embedUrls,
    required this.tags,
    required this.actresses,
    this.releaseDate,
    this.studio,
  });
}

class JavmostApiService {
  static const String kBaseUrl = 'https://www.javmost.ws';
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
        'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7,ja;q=0.6',
        'Referer': 'https://www.javmost.ws/',
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
    JavmostCategory category = JavmostCategory.all,
    String? keyword,
  }) {
    final cleanKw = keyword?.trim();
    if (cleanKw != null && cleanKw.isNotEmpty) {
      final encoded = Uri.encodeComponent(cleanKw);
      if (page > 1) {
        return '$kBaseUrl/search/$encoded/page/$page/';
      }
      return '$kBaseUrl/search/$encoded/';
    }

    if (page > 1) {
      return '$kBaseUrl${category.path}page/$page/';
    }
    return '$kBaseUrl${category.path}';
  }

  static Future<JavmostPageData> fetchVideos({
    int page = 1,
    JavmostCategory category = JavmostCategory.all,
    String? keyword,
  }) async {
    final dio = _createDio();
    final url = buildUrl(page: page, category: category, keyword: keyword);
    debugPrint('[JavmostApiService] Fetching URL: $url');

    final response = await dio.get<String>(url);
    final html = response.data ?? '';
    return parseHtml(html, currentPage: page);
  }

  static JavmostPageData parseHtml(String html, {int currentPage = 1}) {
    final doc = html_parser.parse(html);
    final List<VideoItem> items = [];
    final seenSlugs = <String>{};

    final cardElements = doc.querySelectorAll('.card, .card-body, .item');

    for (final card in cardElements) {
      final aTag = card.querySelector('a[href^="https://www.javmost.ws/"]') ??
          card.querySelector('a[href^="/"]');
      if (aTag == null) continue;

      var href = aTag.attributes['href'] ?? '';
      if (href.isEmpty ||
          href == '#' ||
          href == '/' ||
          href.contains('/category/') ||
          href.contains('/pornstar/') ||
          href.contains('/search/')) {
        continue;
      }

      if (!href.startsWith('http')) {
        href = '$kBaseUrl$href';
      }

      final sourceTag = card.querySelector('source');
      final imgTag = card.querySelector('img');
      var thumb = sourceTag?.attributes['data-srcset'] ??
          sourceTag?.attributes['srcset'] ??
          imgTag?.attributes['data-src'] ??
          imgTag?.attributes['src'] ??
          '';

      if (thumb.startsWith('data:image') || thumb.isEmpty) {
        final parts = href.split('/').where((s) => s.isNotEmpty).toList();
        if (parts.isNotEmpty) {
          thumb = 'https://img2.javmost.ws/file_image/${parts.last}.jpg';
        }
      } else if (thumb.startsWith('//')) {
        thumb = 'https:$thumb';
      }

      var title = card.querySelector('h4, h5, .title')?.text.trim() ??
          aTag.attributes['title'] ??
          imgTag?.attributes['alt'] ??
          aTag.text.trim();

      if (title.isEmpty) {
        // Fallback: extract code from URL e.g. /SNOS-363/
        final parts = href.split('/').where((s) => s.isNotEmpty).toList();
        if (parts.isNotEmpty) {
          title = parts.last;
        } else {
          title = 'JAV Most Video';
        }
      }

      final slug = href;
      if (seenSlugs.contains(slug)) continue;
      seenSlugs.add(slug);

      items.add(VideoItem(
        title: title,
        slug: slug,
        detailUrl: href,
        coverUrl: thumb,
        duration: '',
        views: '',
        date: '',
        author: '',
      ));
    }

    // Pagination
    int totalPages = currentPage;
    final pageLinks = doc.querySelectorAll('.pagination a, a[href*="/page/"]');
    for (final pl in pageLinks) {
      final text = pl.text.trim();
      final num = int.tryParse(text);
      if (num != null && num > totalPages) {
        totalPages = num;
      }
      final href = pl.attributes['href'] ?? '';
      final pageMatch = RegExp(r'/page/(\d+)').firstMatch(href);
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

    return JavmostPageData(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages,
    );
  }

  static Future<JavmostDetailData> fetchDetail(VideoItem item) async {
    final dio = _createDio();
    final response = await dio.get<String>(
      item.detailUrl,
      options: Options(headers: {'Referer': 'https://www.javmost.ws/'}),
    );
    final html = response.data ?? '';
    final doc = html_parser.parse(html);

    // Title
    final titleEl = doc.querySelector('h1, h2, h3.title, .page-header');
    final title = titleEl?.text.trim() ?? item.title;

    // Cover
    var cover = item.coverUrl;
    final ogImg = doc.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImg != null && ogImg.isNotEmpty && !ogImg.startsWith('data:image')) {
      cover = ogImg;
    } else if (cover == null || cover.isEmpty || cover.startsWith('data:image')) {
      final parts = item.detailUrl.split('/').where((s) => s.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        cover = 'https://img2.javmost.ws/file_image/${parts.last}.jpg';
      }
    }

    // Embed player URLs or direct web page URL
    final List<String> embedUrls = [];
    final iframes = doc.querySelectorAll('iframe');
    for (final ifr in iframes) {
      final src = ifr.attributes['src'] ?? '';
      if (src.startsWith('http') && !embedUrls.contains(src)) {
        embedUrls.add(src);
      }
    }

    // If no direct iframe found in static HTML, the page itself is the web player
    if (embedUrls.isEmpty) {
      embedUrls.add(item.detailUrl);
    }

    // Parse metadata
    final List<String> tags = [];
    final List<String> actresses = [];
    String? releaseDate;
    String? studio;

    for (final a in doc.querySelectorAll('a[href*="/category/"], a[href*="/tag/"]')) {
      final t = a.text.trim();
      if (t.isNotEmpty && !tags.contains(t)) {
        tags.add(t);
      }
    }

    for (final a in doc.querySelectorAll('a[href*="/pornstar/"], a[href*="/actor/"]')) {
      final act = a.text.trim();
      if (act.isNotEmpty && !actresses.contains(act)) {
        actresses.add(act);
      }
    }

    for (final p in doc.querySelectorAll('p, div.meta')) {
      final text = p.text;
      if (text.contains('Release Date:') || text.contains('Date:')) {
        releaseDate = text.replaceAll('Release Date:', '').replaceAll('Date:', '').trim();
      }
      if (text.contains('Studio:') || text.contains('Maker:')) {
        studio = text.replaceAll('Studio:', '').replaceAll('Maker:', '').trim();
      }
    }

    final updatedItem = item.copyWith(
      title: title,
      coverUrl: cover,
      author: studio ?? (actresses.isNotEmpty ? actresses.join(', ') : item.author),
      tags: tags,
    );

    return JavmostDetailData(
      item: updatedItem,
      embedUrls: embedUrls,
      tags: tags,
      actresses: actresses,
      releaseDate: releaseDate,
      studio: studio,
    );
  }

  /// Resolves JavMost video stream via server AJAX and player gateway
  static Future<String?> resolveStreamUrl(String detailUrl) async {
    if (detailUrl.endsWith('.m3u8') || detailUrl.endsWith('.mp4')) {
      return detailUrl;
    }

    try {
      final dio = _createDio();
      final detailResp = await dio.get<String>(
        detailUrl,
        options: Options(headers: {'Referer': 'https://www.javmost.ws/'}),
      );
      final html = detailResp.data ?? '';

      final valMatch = RegExp(r"var\s+YWRzMQo\s*=\s*'([^']+)'").firstMatch(html);
      final val = valMatch?.group(1) ?? '';

      final partMatch = RegExp(
        r"select_part\('([^']+)','([^']+)'.*?'parent','([^']+)','([^']+)','([^']*)'",
      ).firstMatch(html);
      if (partMatch == null) return null;

      final part = partMatch.group(1)!;
      final group = partMatch.group(2)!;
      final code = partMatch.group(3)!;
      final code2 = partMatch.group(4)!;
      final code3 = partMatch.group(5)!;

      final ajaxResp = await dio.post<Map<String, dynamic>>(
        'https://www.javmost.ws/ri3123o235r/',
        data: {
          'group': group,
          'part': part,
          'code': code,
          'code2': code2,
          'code3': code3,
          'value': val,
          'sound': 'av',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'X-Requested-With': 'XMLHttpRequest',
            'Origin': 'https://www.javmost.ws',
            'Referer': detailUrl,
          },
        ),
      );

      final embedList = (ajaxResp.data?['data'] as List?)?.cast<String>();
      if (embedList == null || embedList.isEmpty) return null;
      final embedUrl = embedList.first;

      if (embedUrl.endsWith('.m3u8') || embedUrl.endsWith('.mp4')) {
        return embedUrl;
      }

      if (embedUrl.contains('dooplayer.com')) {
        final dooDio = NetworkClient.createDio(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': 'https://www.javmost.ws/',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
            'sec-ch-ua':
                '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"Windows"',
            'sec-fetch-dest': 'iframe',
            'sec-fetch-mode': 'navigate',
            'sec-fetch-site': 'cross-site',
          },
        );

        final dooResp = await dooDio.get<String>(embedUrl);
        final dooHtml = dooResp.data ?? '';

        final token = RegExp(r'name=["\x27]?x-embed-token["\x27]?\s*content=["\x27]?([^"\x27>]+)').firstMatch(dooHtml)?.group(1) ??
            RegExp(r'content=["\x27]?([^"\x27>]+)["\x27]?\s*name=["\x27]?x-embed-token').firstMatch(dooHtml)?.group(1);
        final api = RegExp(r'name=["\x27]?x-embed-api["\x27]?\s*content=["\x27]?([^"\x27>]+)').firstMatch(dooHtml)?.group(1) ??
            RegExp(r'content=["\x27]?([^"\x27>]+)["\x27]?\s*name=["\x27]?x-embed-api').firstMatch(dooHtml)?.group(1);
        final et = RegExp(r'name=["\x27]?x-embed-et["\x27]?\s*content=["\x27]?([^"\x27>]+)').firstMatch(dooHtml)?.group(1) ??
            RegExp(r'content=["\x27]?([^"\x27>]+)["\x27]?\s*name=["\x27]?x-embed-et').firstMatch(dooHtml)?.group(1);
        final sig = RegExp(r'name=["\x27]?x-embed-sig["\x27]?\s*content=["\x27]?([^"\x27>]+)').firstMatch(dooHtml)?.group(1) ??
            RegExp(r'content=["\x27]?([^"\x27>]+)["\x27]?\s*name=["\x27]?x-embed-sig').firstMatch(dooHtml)?.group(1);

        if (token != null && api != null) {
          final streamApiUrl = '${api.replaceAll(RegExp(r'/+$'), '')}/${Uri.encodeComponent(token)}';
          final streamResp = await dooDio.post<Map<String, dynamic>>(
            streamApiUrl,
            data: jsonEncode({'ref': embedUrl}),
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'Referer': embedUrl,
                'Origin': 'https://www.dooplayer.com',
                'X-Embed-Auth': '1',
                'X-Embed-ET': et ?? '',
                'X-Embed-SIG': sig ?? '',
              },
            ),
          );

          final streamData = streamResp.data;
          if (streamData?['ok'] == true && streamData?['url'] != null) {
            return streamData!['url'].toString();
          }
        }
      }
    } catch (e) {
      debugPrint('[JavmostApiService] resolveStreamUrl error: $e');
    }
    return null;
  }
}
