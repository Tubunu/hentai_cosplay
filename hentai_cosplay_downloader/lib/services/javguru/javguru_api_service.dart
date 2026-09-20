import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/video_item.dart';
import '../network_client.dart';

enum JavguruCategory {
  all('最新影片', ''),
  jav('JAV 精选', '/category/jav/'),
  decensored('无码破解', '/category/decensored/'),
  amateur('业余自拍', '/category/amateur/'),
  idol('偶像写真', '/category/idol/'),
  resolution4k('4K 超清', '/category/4k/'),
  subbed('字幕版', '/category/english-subbed/');

  final String label;
  final String path;
  const JavguruCategory(this.label, this.path);
}

class JavguruPageData {
  final List<VideoItem> items;
  final int currentPage;
  final int totalPages;

  const JavguruPageData({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });
}

class JavguruDetailData {
  final VideoItem item;
  final List<String> embedUrls;
  final List<String> tags;
  final List<String> actresses;
  final String? studio;

  const JavguruDetailData({
    required this.item,
    required this.embedUrls,
    required this.tags,
    required this.actresses,
    this.studio,
  });
}

class JavguruApiService {
  static const String kBaseUrl = 'https://jav.guru';
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
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        'Referer': 'https://jav.guru/',
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
    JavguruCategory category = JavguruCategory.all,
    String? keyword,
  }) {
    final cleanKw = keyword?.trim();
    if (cleanKw != null && cleanKw.isNotEmpty) {
      final encoded = Uri.encodeComponent(cleanKw);
      if (page > 1) {
        return '$kBaseUrl/page/$page/?s=$encoded';
      }
      return '$kBaseUrl/?s=$encoded';
    }

    if (category == JavguruCategory.all) {
      if (page > 1) {
        return '$kBaseUrl/page/$page/';
      }
      return '$kBaseUrl/';
    }

    if (page > 1) {
      return '$kBaseUrl${category.path}page/$page/';
    }
    return '$kBaseUrl${category.path}';
  }

  static Future<JavguruPageData> fetchVideos({
    int page = 1,
    JavguruCategory category = JavguruCategory.all,
    String? keyword,
  }) async {
    final dio = _dio;
    final url = buildUrl(page: page, category: category, keyword: keyword);
    debugPrint('[JavguruApiService] Fetching URL: $url');

    final response = await dio.get<String>(url);
    final html = response.data ?? '';
    return parseHtml(html, currentPage: page);
  }

  static JavguruPageData parseHtml(String html, {int currentPage = 1}) {
    final doc = html_parser.parse(html);
    final List<VideoItem> items = [];
    final seenSlugs = <String>{};

    final cardElements = doc.querySelectorAll('.inside-article, article.post');

    for (final card in cardElements) {
      final aTag = card.querySelector('.imgg a') ??
          card.querySelector('a[href*="jav.guru/"]') ??
          card.querySelector('.entry-title a') ??
          card.querySelector('a');
      if (aTag == null) continue;

      var href = aTag.attributes['href'] ?? '';
      if (href.isEmpty || href == '#' || !href.contains('jav.guru/')) continue;
      if (!href.startsWith('http')) {
        href = '$kBaseUrl$href';
      }

      if (href.contains('/category/') ||
          href.contains('/tag/') ||
          href.contains('/author/')) {
        continue;
      }

      final imgTag = card.querySelector('.imgg img') ?? card.querySelector('img');
      var thumb = imgTag?.attributes['src'] ??
          imgTag?.attributes['data-src'] ??
          imgTag?.attributes['data-lazy-src'] ??
          '';

      var title = imgTag?.attributes['alt'] ??
          card.querySelector('.entry-title')?.text.trim() ??
          aTag.attributes['title'] ??
          aTag.text.trim();

      if (title.isEmpty) {
        title = 'JAV Video';
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

    if (items.isEmpty) {
      final postLinks = doc.querySelectorAll('a[href*="jav.guru/"]');
      final postRegex = RegExp(r'jav\.guru/\d+/');
      for (final a in postLinks) {
        final href = a.attributes['href'] ?? '';
        if (!postRegex.hasMatch(href)) continue;
        if (seenSlugs.contains(href)) continue;
        seenSlugs.add(href);

        final img = a.querySelector('img');
        final thumb = img?.attributes['src'] ??
            img?.attributes['data-src'] ??
            img?.attributes['data-lazy-src'] ??
            '';
        final title = img?.attributes['alt'] ?? a.text.trim();
        if (title.isNotEmpty) {
          items.add(VideoItem(
            title: title,
            slug: href,
            detailUrl: href,
            coverUrl: thumb,
            duration: '',
            views: '',
            date: '',
            author: '',
          ));
        }
      }
    }

    int totalPages = currentPage;
    final pageLinks = doc.querySelectorAll('.page-numbers, .pagination a, .nav-links a');
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

    return JavguruPageData(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages,
    );
  }

  static Future<JavguruDetailData> fetchDetail(VideoItem item) async {
    final dio = _dio;
    final response = await dio.get<String>(
      item.detailUrl,
      options: Options(headers: {'Referer': 'https://jav.guru/'}),
    );
    final html = response.data ?? '';
    final doc = html_parser.parse(html);

    final titleEl = doc.querySelector('h1.entry-title') ?? doc.querySelector('h1');
    final title = titleEl?.text.trim() ?? item.title;

    final imgEl = doc.querySelector('.large-screenshot img') ??
        doc.querySelector('.entry-content img') ??
        doc.querySelector('.imgg img');
    final cover = imgEl?.attributes['src'] ??
        imgEl?.attributes['data-src'] ??
        imgEl?.attributes['data-lazy-src'] ??
        item.coverUrl;

    final List<String> embedUrls = [];
    final varMatches = RegExp(r'var\s+([a-zA-Z0-9]+)\s*=\s*(\{.*?"iframe_url".*?\});')
        .allMatches(html);

    for (final m in varMatches) {
      try {
        final jsonStr = m.group(2);
        if (jsonStr != null) {
          final map = jsonDecode(jsonStr);
          final b64 = map['iframe_url'] as String?;
          if (b64 != null && b64.isNotEmpty) {
            final decodedBytes = base64.decode(b64);
            final decodedUrl = utf8.decode(decodedBytes, allowMalformed: true);
            if (decodedUrl.startsWith('http')) {
              embedUrls.add(decodedUrl);
            }
          }
        }
      } catch (e) {
        debugPrint('[JavguruApiService] Failed to decode iframe var: $e');
      }
    }

    final iframes = doc.querySelectorAll('iframe');
    for (final ifr in iframes) {
      final src = ifr.attributes['src'] ?? ifr.attributes['data-src'] ?? '';
      if (src.startsWith('http') &&
          !src.contains('mayzaent') &&
          !embedUrls.contains(src)) {
        embedUrls.add(src);
      }
    }

    final List<String> tags = [];
    final List<String> actresses = [];
    String? studio;

    for (final a in doc.querySelectorAll('.entry-content a, .tags-links a, a[rel="tag"]')) {
      final href = a.attributes['href'] ?? '';
      final text = a.text.trim();
      if (text.isEmpty) continue;

      if (href.contains('/actress/') || href.contains('/actor/')) {
        if (!actresses.contains(text)) actresses.add(text);
      } else if (href.contains('/studio/') || href.contains('/maker/')) {
        studio ??= text;
      } else if (href.contains('/tag/') || href.contains('/category/')) {
        if (!tags.contains(text)) tags.add(text);
      }
    }

    final updatedItem = item.copyWith(
      title: title,
      coverUrl: cover,
      author: studio ?? (actresses.isNotEmpty ? actresses.first : item.author),
      tags: tags,
    );

    return JavguruDetailData(
      item: updatedItem,
      embedUrls: embedUrls,
      tags: tags,
      actresses: actresses,
      studio: studio,
    );
  }

  /// Unpack Dean Edwards packed JavaScript code (p, a, c, k, e, d)
  static String? unpackDeanEdwards(String packed) {
    final match = RegExp(
      r"}\('(.*)',\s*(\d+),\s*(\d+),\s*'(.*?)'\.split\('\|'\)",
      dotAll: true,
    ).firstMatch(packed);
    if (match == null) return null;

    final p = match.group(1)!;
    final a = int.parse(match.group(2)!);
    final c = int.parse(match.group(3)!);
    final k = match.group(4)!.split('|');

    const chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    String baseN(int num, int radix) {
      if (num == 0) return '0';
      var res = '';
      var n = num;
      while (n > 0) {
        res = chars[n % radix] + res;
        n ~/= radix;
      }
      return res;
    }

    final map = <String, String>{};
    for (int i = 0; i < c; i++) {
      final key = baseN(i, a);
      final val = (i < k.length && k[i].isNotEmpty) ? k[i] : key;
      map[key] = val;
    }

    return p.replaceAllMapped(RegExp(r'\b\w+\b'), (m) {
      final word = m.group(0)!;
      return map[word] ?? word;
    });
  }

  /// Resolves a JavGuru searcho embed URL to a direct .m3u8 master stream URL
  static Future<String?> resolveStreamUrl(String searchoUrl) async {
    if (searchoUrl.endsWith('.m3u8') || searchoUrl.endsWith('.mp4')) {
      return searchoUrl;
    }

    try {
      final uri = Uri.parse(searchoUrl);
      String? token;
      String? rtype;
      for (final key in uri.queryParameters.keys) {
        if (key.endsWith('d') && key.length == 2) {
          token = uri.queryParameters[key];
          rtype = key[0];
          break;
        }
      }
      if (token == null || rtype == null) return null;

      final revToken = token.split('').reversed.join('');
      final realSrc = 'https://jav.guru/searcho/?${rtype}r=$revToken';

      final dio = _dio;
      final resp = await dio.get<String>(
        realSrc,
        options: Options(headers: {'Referer': 'https://jav.guru/'}),
      );
      final html = resp.data ?? '';
      final evalMatch = RegExp(
        r"eval\(function\(p,a,c,k,e,d\).*?\.split\('\|'\)\)\)",
        dotAll: true,
      ).firstMatch(html);
      if (evalMatch == null) return null;

      final unpacked = unpackDeanEdwards(evalMatch.group(0)!);
      if (unpacked == null) return null;

      final m3u8Match = RegExp(r'https?://[^\s"<>\x27]+\.m3u8[^\s"<>\x27]*').firstMatch(unpacked);
      return m3u8Match?.group(0);
    } catch (e) {
      debugPrint('[JavguruApiService] resolveStreamUrl error: $e');
    }
    return null;
  }
}
