import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/album_item.dart';

enum CosvaultCategory {
  latest('全部画廊', '/posts/'),
  models('模特专区', '/models/');

  final String label;
  final String path;
  const CosvaultCategory(this.label, this.path);
}

class CosvaultModelItem {
  final String name;
  final String slug;
  final String count;
  final String? avatarUrl;

  CosvaultModelItem({
    required this.name,
    required this.slug,
    required this.count,
    this.avatarUrl,
  });
}

class CosvaultApiResponse {
  final List<AlbumItem> items;
  final int page;
  final int totalPages;
  final int total;

  CosvaultApiResponse({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

class CosvaultApiService {
  static const String kBaseUrl = 'https://cosvault.top';

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
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': '$kBaseUrl/',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      ),
    );

    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();
      if (_configuredProxy != null && _configuredProxy!.isNotEmpty) {
        client.badCertificateCallback = (cert, host, port) => true;
      }
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

  static final Map<String, String> _tagAliases = {
    '原神': 'genshin-impact',
    'genshin': 'genshin-impact',
    'genshin impact': 'genshin-impact',
    '星穹铁道': 'honkai-star-rail',
    '崩坏星穹铁道': 'honkai-star-rail',
    '崩铁': 'honkai-star-rail',
    'star rail': 'honkai-star-rail',
    'honkai': 'honkai-impact-3rd',
    '崩坏': 'honkai-impact-3rd',
    '碧蓝航线': 'azur-lane',
    'azur': 'azur-lane',
    'azur lane': 'azur-lane',
    '绝区零': 'zenless-zone-zero',
    'zzz': 'zenless-zone-zero',
    'zenless': 'zenless-zone-zero',
    'zenless zone zero': 'zenless-zone-zero',
    '火影': 'naruto',
    '火影忍者': 'naruto',
    '初音': 'hatsune-miku',
    '初音未来': 'hatsune-miku',
    'miku': 'hatsune-miku',
    '电锯人': 'chainsaw-man',
    'chainsaw': 'chainsaw-man',
    'chainsaw man': 'chainsaw-man',
    '明日方舟': 'arknights',
    '方舟': 'arknights',
    '碧蓝档案': 'blue-archive',
    '蔚蓝档案': 'blue-archive',
    'ba': 'blue-archive',
    'blue archive': 'blue-archive',
    '胜利女神': 'goddess-of-victory-nikke',
    'nikke': 'goddess-of-victory-nikke',
    'fate': 'fate-grand-order',
    'fgo': 'fate-grand-order',
    '英雄联盟': 'league-of-legends',
    'lol': 'league-of-legends',
    'league of legends': 'league-of-legends',
    '守望先锋': 'overwatch',
    'ow': 'overwatch',
    'overwatch': 'overwatch',
    '尼尔': 'nier-automata',
    'nier': 'nier-automata',
    '鸣潮': 'wuthering-waves',
    '死神': 'bleach',
    '鬼灭之刃': 'demon-slayer',
    '鬼灭': 'demon-slayer',
    '咒术回战': 'jujutsu-kaisen',
    '咒术': 'jujutsu-kaisen',
    '间谍过家家': 'spy-x-family',
    '2.5次元': '2-5-dimensional-seduction',
  };

  static String resolveTagSlug(String keyword) {
    final lower = keyword.trim().toLowerCase();
    if (_tagAliases.containsKey(lower)) {
      return _tagAliases[lower]!;
    }
    return lower.replaceAll(' ', '-');
  }

  /// Build request URL
  static String buildUrl({
    int page = 1,
    CosvaultCategory category = CosvaultCategory.latest,
    String? keyword,
    String? modelSlug,
  }) {
    if (modelSlug != null && modelSlug.trim().isNotEmpty) {
      final cleanSlug = modelSlug.trim().replaceAll('/models/', '').replaceAll('/', '');
      if (page > 1) {
        return '$kBaseUrl/models/$cleanSlug/page/$page/';
      }
      return '$kBaseUrl/models/$cleanSlug/';
    }

    if (keyword != null && keyword.trim().isNotEmpty) {
      final cleanKw = resolveTagSlug(keyword);
      // If user typed a specific tag or model name
      if (page > 1) {
        return '$kBaseUrl/tags/$cleanKw/page/$page/';
      }
      return '$kBaseUrl/tags/$cleanKw/';
    }

    if (page > 1) {
      return '$kBaseUrl/posts/page/$page/';
    }
    return '$kBaseUrl/posts/';
  }

  /// Fetch models list from https://cosvault.top/models/
  static Future<List<CosvaultModelItem>> fetchModels() async {
    try {
      final url = '$kBaseUrl/models/';
      debugPrint('[CosvaultApiService] Fetching models: $url');
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      if (response.statusCode == 200 && response.data != null) {
        final document = html_parser.parse(response.data!);
        final List<CosvaultModelItem> models = [];
        final cards = document.querySelectorAll('a.cosvault-model-card, a[href*="/models/"]');
        for (final card in cards) {
          final href = card.attributes['href'] ?? '';
          if (href.isEmpty || href == '/models/' || href == 'https://cosvault.top/models/') continue;
          final cleanSlug = href.replaceAll('/models/', '').replaceAll('/', '').trim();
          if (cleanSlug.isEmpty) continue;

          final nameEl = card.querySelector('h2, h3, .name, span.font-bold') ?? card.querySelector('div.text-center');
          final rawName = nameEl?.text.trim() ?? cleanSlug;
          final name = rawName.replaceAll(RegExp(r'\s*\(\d+\s*albums?\)', caseSensitive: false), '').trim();

          final countEl = card.querySelector('span.album-count, span.text-sm, span.text-neutral-400');
          final albumCount = countEl?.text.trim();

          final imgEl = card.querySelector('img');
          final avatarUrl = imgEl?.attributes['src'] ?? imgEl?.attributes['data-src'];

          if (!models.any((m) => m.slug == cleanSlug)) {
            models.add(CosvaultModelItem(
              name: name.isNotEmpty ? name : cleanSlug,
              slug: cleanSlug,
              avatarUrl: avatarUrl,
              count: albumCount ?? '',
            ));
          }
        }
        return models;
      }
    } catch (e) {
      debugPrint('[CosvaultApiService] Error fetching models: $e');
    }
    return [];
  }

  /// Fetch page data
  static Future<CosvaultApiResponse?> fetchPageData({
    int page = 1,
    CosvaultCategory category = CosvaultCategory.latest,
    String? keyword,
    String? modelSlug,
  }) async {
    try {
      final url = buildUrl(page: page, category: category, keyword: keyword, modelSlug: modelSlug);
      debugPrint('[CosvaultApiService] Fetching URL: $url');

      Response<String>? response;
      try {
        response = await _dio.get<String>(
          url,
          options: Options(responseType: ResponseType.plain),
        );
      } catch (e) {
        // If keyword search on /tags/ fails with 404, fallback to /models/
        if (keyword != null && keyword.trim().isNotEmpty) {
          final cleanKw = resolveTagSlug(keyword);
          final modelUrl = page > 1 ? '$kBaseUrl/models/$cleanKw/page/$page/' : '$kBaseUrl/models/$cleanKw/';
          debugPrint('[CosvaultApiService] Retrying with model URL: $modelUrl');
          try {
            response = await _dio.get<String>(
              modelUrl,
              options: Options(responseType: ResponseType.plain),
            );
          } catch (_) {
            return CosvaultApiResponse(items: [], page: page, totalPages: 0, total: 0);
          }
        } else {
          rethrow;
        }
      }

      final html = response.data;
      if (html != null && html.isNotEmpty) {
        return _parseListPageHtml(html, page, keyword);
      }
    } catch (e) {
      debugPrint('[CosvaultApiService] Error fetching page $page: $e');
    }
    return null;
  }

  /// Parse list page HTML
  static CosvaultApiResponse _parseListPageHtml(String html, int requestedPage, String? keyword) {
    final document = html_parser.parse(html);
    final List<AlbumItem> items = [];
    final seenUrls = <String>{};

    final articles = document.querySelectorAll('article.article-link--card, article');

    for (final article in articles) {
      try {
        final linkElem = article.querySelector('header a, h2 a, a[href*="/p/"]');
        if (linkElem == null) continue;

        var href = linkElem.attributes['href'] ?? '';
        if (href.isEmpty || href == '#') continue;
        if (!href.startsWith('http')) {
          href = '$kBaseUrl$href';
        }

        if (!seenUrls.add(href)) continue;

        var title = article.querySelector('header h2, h2')?.text.trim() ?? linkElem.text.trim();
        if (title.isEmpty) {
          title = 'CosVault 图集';
        }

        final imgElem = article.querySelector('img');
        var coverUrl = imgElem?.attributes['src'] ?? imgElem?.attributes['data-src'] ?? '';
        if (coverUrl.startsWith('//')) {
          coverUrl = 'https:$coverUrl';
        } else if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = '$kBaseUrl$coverUrl';
        }

        final modelElem = article.querySelector('a[href*="/models/"]');
        final author = modelElem?.text.trim() ?? AlbumItem.inferAuthor(title);

        final dateElem = article.querySelector('time');
        final date = dateElem?.text.trim() ?? '';

        final tagElements = article.querySelectorAll('a[href*="/tags/"], a[href*="/models/"]');
        final tags = tagElements.map((t) => t.text.trim()).where((t) => t.isNotEmpty).toSet().toList();
        if (tags.isEmpty) tags.add('CosVault');

        final slugMatch = RegExp(r'/p/([^/]+)').firstMatch(href);
        final slug = slugMatch?.group(1) ?? href.hashCode.abs().toString();

        items.add(
          AlbumItem(
            title: title,
            slug: 'cv_$slug',
            detailUrl: href,
            coverUrl: coverUrl.isNotEmpty ? coverUrl : null,
            date: date,
            author: author,
            tags: tags,
            imageUrls: [],
            previewUrls: [],
            isDetailLoaded: false,
            sourceType: MediaSourceType.cosvault,
            rawData: {'detailUrl': href, 'slug': slug},
          ),
        );
      } catch (e) {
        debugPrint('[CosvaultApiService] Error parsing card: $e');
      }
    }

    int totalPages = requestedPage;
    final pageLinks = document.querySelectorAll('a[href*="/page/"], .pagination a');
    for (final pl in pageLinks) {
      final href = pl.attributes['href'] ?? '';
      final match = RegExp(r'/page/(\d+)').firstMatch(href);
      if (match != null) {
        final pageNum = int.tryParse(match.group(1)!);
        if (pageNum != null && pageNum > totalPages) {
          totalPages = pageNum;
        }
      }
      final pageNumText = int.tryParse(pl.text.trim());
      if (pageNumText != null && pageNumText > totalPages) {
        totalPages = pageNumText;
      }
    }

    if (totalPages <= requestedPage && items.length >= 20) {
      totalPages = requestedPage + 1;
    }

    return CosvaultApiResponse(
      items: items,
      page: requestedPage,
      totalPages: totalPages,
      total: items.length * totalPages,
    );
  }

  /// Fetch full album detail & all original images
  static Future<AlbumItem?> fetchAlbumDetail(AlbumItem item) async {
    try {
      debugPrint('[CosvaultApiService] Fetching detail: ${item.detailUrl}');
      final response = await _dio.get<String>(
        item.detailUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data!;
        final document = html_parser.parse(html);

        final List<String> imageUrls = [];
        final List<String> previewUrls = [];

        // 1. Grid items on CosVault: <a class=cosvault-grid-item href="...">
        final gridLinks = document.querySelectorAll('.cosvault-grid a, a.cosvault-grid-item');
        for (final a in gridLinks) {
          var src = a.attributes['href'] ?? '';
          if (src.isEmpty) {
            final img = a.querySelector('img');
            src = img?.attributes['src'] ?? '';
          }
          if (src.isNotEmpty && !src.contains('avatar') && !src.contains('logo')) {
            if (!src.startsWith('http')) {
              src = '$kBaseUrl$src';
            }
            if (!imageUrls.contains(src)) {
              imageUrls.add(src);
              previewUrls.add(src);
            }
          }
        }

        // 2. Fallback: regex search for all static.galleryepic.xyz images
        if (imageUrls.isEmpty) {
          final matches = RegExp(r'https://static\.galleryepic\.xyz/image/[a-f0-9\-]+').allMatches(html);
          for (final m in matches) {
            final src = m.group(0)!;
            if (!imageUrls.contains(src)) {
              imageUrls.add(src);
              previewUrls.add(src);
            }
          }
        }

        // 3. Fallback: query all article images
        if (imageUrls.isEmpty) {
          final contentImgs = document.querySelectorAll('article img');
          for (final img in contentImgs) {
            var src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
            if (src.isNotEmpty && !src.contains('avatar') && !src.contains('logo')) {
              if (!src.startsWith('http')) {
                src = '$kBaseUrl$src';
              }
              if (!imageUrls.contains(src)) {
                imageUrls.add(src);
                previewUrls.add(src);
              }
            }
          }
        }

        final tags = List<String>.from(item.tags);
        final metaListItems = document.querySelectorAll('article li');
        for (final li in metaListItems) {
          final text = li.text.trim();
          if (text.startsWith('Model:') || text.startsWith('Character:') || text.startsWith('Parody:')) {
            final val = text.split(':').last.trim();
            if (val.isNotEmpty && !tags.contains(val)) {
              tags.add(val);
            }
          }
        }

        return item.copyWith(
          imageUrls: imageUrls,
          previewUrls: previewUrls,
          tags: tags,
          isDetailLoaded: true,
        );
      }
    } catch (e) {
      debugPrint('[CosvaultApiService] Error fetching detail: $e');
    }

    return item;
  }
}
