import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/album_item.dart';

enum GalleryEpicCategory {
  cosplay('Cosplay 套图', '/zh/cosplays/'),
  albums('写真相册', '/zh/albums/');

  final String label;
  final String path;
  const GalleryEpicCategory(this.label, this.path);
}

enum GalleryEpicMainCategory {
  cosplay('Cosplay'),
  album('Album');

  final String label;
  const GalleryEpicMainCategory(this.label);
}

enum GalleryEpicSubCategory {
  lists('Lists'),
  cosers('Cosers'),
  parodies('Parodies'),
  models('Models');

  final String label;
  const GalleryEpicSubCategory(this.label);
}

class GalleryEpicCreatorItem {
  final String name;
  final String detailPath;
  final String? avatarUrl;

  GalleryEpicCreatorItem({
    required this.name,
    required this.detailPath,
    this.avatarUrl,
  });
}

class GalleryEpicParodyItem {
  final String name;
  final String detailPath;

  GalleryEpicParodyItem({
    required this.name,
    required this.detailPath,
  });
}

class GalleryEpicCharacterItem {
  final String name;
  final String detailPath;

  GalleryEpicCharacterItem({
    required this.name,
    required this.detailPath,
  });
}

class GalleryEpicCreatorsResponse {
  final List<GalleryEpicCreatorItem> items;
  final int page;
  final int totalPages;

  GalleryEpicCreatorsResponse({
    required this.items,
    required this.page,
    required this.totalPages,
  });
}

class GalleryEpicApiResponse {
  final List<AlbumItem> items;
  final int page;
  final int totalPages;
  final int total;

  GalleryEpicApiResponse({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

class GalleryepicApiService {
  static const String kBaseUrl = 'https://galleryepic.xyz';
  static const String kImageCdn = 'https://static.galleryepic.xyz/image';

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
          'Referer': '$kBaseUrl/zh',
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

  /// Build request URL
  static String buildUrl({
    int page = 1,
    GalleryEpicCategory category = GalleryEpicCategory.cosplay,
    String? keyword,
    String? customPath,
  }) {
    if (customPath != null && customPath.isNotEmpty) {
      final clean = customPath.replaceAll(RegExp(r'/\d+$'), '');
      if (page > 1) {
        return '$kBaseUrl$clean/$page';
      }
      return '$kBaseUrl$customPath';
    }

    if (keyword != null && keyword.trim().isNotEmpty) {
      final encodedKw = Uri.encodeComponent(keyword.trim());
      return '$kBaseUrl${category.path}$page?q=$encodedKw';
    }
    return '$kBaseUrl${category.path}$page';
  }

  /// Fetch single page data
  static Future<GalleryEpicApiResponse?> _fetchSinglePage(
    int page,
    GalleryEpicCategory category,
    String? keyword,
    String? customPath,
  ) async {
    final url = buildUrl(page: page, category: category, keyword: keyword, customPath: customPath);
    debugPrint('[GalleryepicApiService] Fetching URL: $url');

    final response = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );

    if (response.statusCode == 200 && response.data != null) {
      return _parseListPageHtml(response.data!, page, category, keyword);
    }
    return null;
  }

  /// Fetch page data with multi-page keyword scanning
  static Future<GalleryEpicApiResponse?> fetchPageData({
    int page = 1,
    GalleryEpicCategory category = GalleryEpicCategory.cosplay,
    String? keyword,
    String? customPath,
  }) async {
    try {
      final cleanKw = keyword?.trim();
      if (cleanKw != null && cleanKw.isNotEmpty && (customPath == null || customPath.isEmpty)) {
        // Multi-page search scanning across the first 4 pages
        final futures = [1, 2, 3, 4].map((p) => _fetchSinglePage(p, category, null, customPath));
        final responses = await Future.wait(futures);
        final allItems = <AlbumItem>[];
        final seen = <String>{};
        for (final resp in responses) {
          if (resp != null) {
            for (final it in resp.items) {
              if (seen.add(it.detailUrl)) {
                allItems.add(it);
              }
            }
          }
        }
        final lower = cleanKw.toLowerCase();
        final filtered = allItems.where((it) {
          return it.title.toLowerCase().contains(lower) ||
              it.author.toLowerCase().contains(lower) ||
              it.tags.any((t) => t.toLowerCase().contains(lower));
        }).toList();

        return GalleryEpicApiResponse(
          items: filtered,
          page: 1,
          totalPages: 1,
          total: filtered.length,
        );
      }

      return await _fetchSinglePage(page, category, keyword, customPath);
    } catch (e) {
      debugPrint('[GalleryepicApiService] Error fetching page $page: $e');
    }
    return null;
  }

  /// Fetch Cosers list from https://galleryepic.xyz/zh/cosers/{page}
  static Future<GalleryEpicCreatorsResponse?> fetchCosers({int page = 1}) async {
    try {
      final url = '$kBaseUrl/zh/cosers/$page';
      debugPrint('[GalleryepicApiService] Fetching cosers: $url');
      final response = await _dio.get<String>(url, options: Options(responseType: ResponseType.plain));
      if (response.statusCode == 200 && response.data != null) {
        final document = html_parser.parse(response.data!);
        final List<GalleryEpicCreatorItem> items = [];
        for (final a in document.querySelectorAll('a[href*="/zh/coser/"]')) {
          final href = a.attributes['href'] ?? '';
          if (href.isEmpty) continue;
          final img = a.querySelector('img');
          var avatar = img?.attributes['src'] ?? '';
          if (avatar.startsWith('//')) avatar = 'https:$avatar';
          final name = a.text.trim();
          if (name.isNotEmpty && !items.any((it) => it.detailPath == href)) {
            items.add(GalleryEpicCreatorItem(name: name, detailPath: href, avatarUrl: avatar.isNotEmpty ? avatar : null));
          }
        }
        int totalPages = page;
        final pageMatches = RegExp(r'/zh/cosers/(\d+)').allMatches(response.data!);
        for (final m in pageMatches) {
          final p = int.tryParse(m.group(1)!);
          if (p != null && p > totalPages) totalPages = p;
        }
        return GalleryEpicCreatorsResponse(items: items, page: page, totalPages: totalPages);
      }
    } catch (e) {
      debugPrint('[GalleryepicApiService] Error fetching cosers: $e');
    }
    return null;
  }

  /// Fetch Models list from https://galleryepic.xyz/zh/models/{page}
  static Future<GalleryEpicCreatorsResponse?> fetchModels({int page = 1}) async {
    try {
      final url = '$kBaseUrl/zh/models/$page';
      debugPrint('[GalleryepicApiService] Fetching models: $url');
      final response = await _dio.get<String>(url, options: Options(responseType: ResponseType.plain));
      if (response.statusCode == 200 && response.data != null) {
        final document = html_parser.parse(response.data!);
        final List<GalleryEpicCreatorItem> items = [];
        for (final a in document.querySelectorAll('a[href*="/zh/model/"]')) {
          final href = a.attributes['href'] ?? '';
          if (href.isEmpty) continue;
          final img = a.querySelector('img');
          var avatar = img?.attributes['src'] ?? '';
          if (avatar.startsWith('//')) avatar = 'https:$avatar';
          final name = a.text.trim();
          if (name.isNotEmpty && !items.any((it) => it.detailPath == href)) {
            items.add(GalleryEpicCreatorItem(name: name, detailPath: href, avatarUrl: avatar.isNotEmpty ? avatar : null));
          }
        }
        int totalPages = page;
        final pageMatches = RegExp(r'/zh/models/(\d+)').allMatches(response.data!);
        for (final m in pageMatches) {
          final p = int.tryParse(m.group(1)!);
          if (p != null && p > totalPages) totalPages = p;
        }
        return GalleryEpicCreatorsResponse(items: items, page: page, totalPages: totalPages);
      }
    } catch (e) {
      debugPrint('[GalleryepicApiService] Error fetching models: $e');
    }
    return null;
  }

  /// Fetch Parodies list from https://galleryepic.xyz/zh/parodies
  static Future<List<GalleryEpicParodyItem>> fetchParodies() async {
    try {
      final url = '$kBaseUrl/zh/parodies';
      debugPrint('[GalleryepicApiService] Fetching parodies: $url');
      final response = await _dio.get<String>(url, options: Options(responseType: ResponseType.plain));
      if (response.statusCode == 200 && response.data != null) {
        final document = html_parser.parse(response.data!);
        final List<GalleryEpicParodyItem> items = [];
        for (final a in document.querySelectorAll('a[href*="/zh/parody/"]')) {
          final href = a.attributes['href'] ?? '';
          if (href.isEmpty) continue;
          final name = a.text.trim();
          if (name.isNotEmpty && !items.any((it) => it.detailPath == href || it.name == name)) {
            items.add(GalleryEpicParodyItem(name: name, detailPath: href));
          }
        }
        return items;
      }
    } catch (e) {
      debugPrint('[GalleryepicApiService] Error fetching parodies: $e');
    }
    return [];
  }

  /// Fetch Characters under a Parody from https://galleryepic.xyz{parodyPath}
  static Future<List<GalleryEpicCharacterItem>> fetchParodyCharacters(String parodyPath) async {
    try {
      final url = parodyPath.startsWith('http') ? parodyPath : '$kBaseUrl$parodyPath';
      debugPrint('[GalleryepicApiService] Fetching parody characters: $url');
      final response = await _dio.get<String>(url, options: Options(responseType: ResponseType.plain));
      if (response.statusCode == 200 && response.data != null) {
        final document = html_parser.parse(response.data!);
        final List<GalleryEpicCharacterItem> items = [];
        for (final a in document.querySelectorAll('a[href*="/zh/character/"]')) {
          final href = a.attributes['href'] ?? '';
          if (href.isEmpty) continue;
          final name = a.text.trim();
          if (name.isNotEmpty && !items.any((it) => it.detailPath == href)) {
            items.add(GalleryEpicCharacterItem(name: name, detailPath: href));
          }
        }
        return items;
      }
    } catch (e) {
      debugPrint('[GalleryepicApiService] Error fetching parody characters: $e');
    }
    return [];
  }

  /// Parse list page HTML
  static GalleryEpicApiResponse _parseListPageHtml(
    String html,
    int requestedPage,
    GalleryEpicCategory category,
    String? keyword,
  ) {
    final document = html_parser.parse(html);
    final List<AlbumItem> items = [];
    final seenUrls = <String>{};

    final cardElements = document.querySelectorAll('div.relative.flex.flex-col.gap-3');

    for (final card in cardElements) {
      try {
        final linkElem = card.querySelector('a.space-y-3, a[href*="/cosplay/"], a[href*="/album/"]');
        if (linkElem == null) continue;

        var href = linkElem.attributes['href'] ?? '';
        if (href.isEmpty || href == '#') continue;
        if (!href.startsWith('http')) {
          href = '$kBaseUrl$href';
        }

        if (!seenUrls.add(href)) continue;

        final imgElem = card.querySelector('img');
        var coverUrl = imgElem?.attributes['src'] ?? '';
        if (coverUrl.startsWith('//')) {
          coverUrl = 'https:$coverUrl';
        } else if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = '$kBaseUrl$coverUrl';
        }

        final countText = card.querySelector('p.text-xs.text-white')?.text.trim().replaceAll(RegExp(r'<!--.*?-->'), '') ?? '';

        final titleElem = card.querySelector('h3.truncate.font-medium, h3.truncate');
        var title = titleElem?.text.trim() ?? '';

        final parodyElem = card.querySelector('p.truncate.text-muted-foreground');
        final parody = parodyElem?.text.trim() ?? '';

        final authorElem = card.querySelector('a[href*="/coser/"] h3, a[href*="/model/"] h3, a[href*="/coser/"], a[href*="/model/"]');
        var author = authorElem?.text.trim() ?? '';

        // If title is just a character name and parody is given, format title nicely: [Author] Character (Parody)
        if (author.isNotEmpty && title.isNotEmpty && parody.isNotEmpty && parody != '-') {
          title = '$title ($parody)';
        } else if (title.isEmpty) {
          title = parody.isNotEmpty && parody != '-' ? parody : 'GalleryEpic 图集';
        }

        if (author.isEmpty) {
          author = AlbumItem.inferAuthor(title);
        }

        final tags = <String>[];
        if (category == GalleryEpicCategory.cosplay) {
          tags.add('Cosplay');
        } else {
          tags.add('写真');
        }
        if (countText.isNotEmpty) tags.add(countText);
        if (parody.isNotEmpty && parody != '-') tags.add(parody);

        final idMatch = RegExp(r'/(cosplay|album)/(\d+)').firstMatch(href);
        final id = idMatch?.group(2) ?? href.hashCode.abs().toString();
        final typePrefix = idMatch?.group(1) ?? 'cosplay';

        items.add(
          AlbumItem(
            title: title,
            slug: 'ge_${typePrefix}_$id',
            detailUrl: href,
            coverUrl: coverUrl.isNotEmpty ? coverUrl : null,
            date: countText,
            author: author,
            tags: tags,
            imageUrls: [],
            previewUrls: [],
            isDetailLoaded: false,
            sourceType: MediaSourceType.galleryepic,
            rawData: {'detailUrl': href, 'id': id, 'type': typePrefix},
          ),
        );
      } catch (e) {
        debugPrint('[GalleryepicApiService] Error parsing card: $e');
      }
    }

    // Parse pagination
    int totalPages = requestedPage;
    final pagePattern = RegExp(r'/zh/(?:cosplays|albums|coser/\d+|model/\d+|parody/\d+)/(\d+)');
    final allPageMatches = pagePattern.allMatches(html);
    for (final m in allPageMatches) {
      final pNum = int.tryParse(m.group(1)!);
      if (pNum != null && pNum > totalPages) {
        totalPages = pNum;
      }
    }

    if (totalPages <= requestedPage && items.length >= 15) {
      totalPages = requestedPage + 1;
    }

    return GalleryEpicApiResponse(
      items: items,
      page: requestedPage,
      totalPages: totalPages,
      total: items.length * totalPages,
    );
  }

  /// Fetch full album detail & all original images
  static Future<AlbumItem?> fetchAlbumDetail(AlbumItem item) async {
    try {
      debugPrint('[GalleryepicApiService] Fetching detail: ${item.detailUrl}');
      final response = await _dio.get<String>(
        item.detailUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data!;
        final List<String> imageUrls = [];

        // 1. Precise match: JSON array of UUIDs preceding activityStatId or similar metadata
        final arrayMatch = RegExp(r'(\[([a-f0-9\-",\s\\]+)\])[^\]]*activityStatId').firstMatch(html);
        if (arrayMatch != null) {
          try {
            final raw = arrayMatch.group(1)!.replaceAll(r'\"', '"');
            final dynamic decoded = jsonDecode(raw);
            if (decoded is List) {
              for (final uuid in decoded) {
                final u = uuid.toString().trim();
                if (RegExp(r'^[a-f0-9\-]{36}$').hasMatch(u)) {
                  final url = '$kImageCdn/$u';
                  if (!imageUrls.contains(url)) {
                    imageUrls.add(url);
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('[GalleryepicApiService] Error parsing JSON UUID array: $e');
          }
        }

        // 2. Fallback: match any static.galleryepic.xyz image UUIDs
        if (imageUrls.isEmpty) {
          final imgMatches = RegExp(r'https://static\.galleryepic\.xyz/image/([a-f0-9\-]{36})').allMatches(html);
          for (final m in imgMatches) {
            final u = m.group(1)!;
            final url = '$kImageCdn/$u';
            if (!imageUrls.contains(url)) {
              imageUrls.add(url);
            }
          }
        }

        // 3. Fallback: match any UUIDs in array pattern
        if (imageUrls.isEmpty) {
          final allUuids = RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}').allMatches(html);
          for (final m in allUuids) {
            final u = m.group(0)!;
            final url = '$kImageCdn/$u';
            if (!imageUrls.contains(url)) {
              imageUrls.add(url);
            }
          }
        }

        // Extract detailed title if present
        final document = html_parser.parse(html);
        String? detailedTitle;
        final titleTag = document.querySelector('title')?.text.trim();
        if (titleTag != null && titleTag.isNotEmpty && titleTag != '404') {
          detailedTitle = titleTag.replaceAll(RegExp(r'\s*\|\s*Gallery\s*Epic.*', caseSensitive: false), '').trim();
        }
        if (detailedTitle == null || detailedTitle.isEmpty || detailedTitle == 'Cosplay' || detailedTitle == 'Album') {
          for (final h2 in document.querySelectorAll('h2')) {
            final text = h2.text.trim();
            if (text.isNotEmpty && text != 'Cosplay' && text != 'Album') {
              detailedTitle = text;
              break;
            }
          }
        }

        final finalTitle = (detailedTitle != null &&
                detailedTitle.isNotEmpty &&
                detailedTitle != 'Cosplay' &&
                detailedTitle != 'Album')
            ? detailedTitle
            : item.title;

        return item.copyWith(
          title: finalTitle,
          imageUrls: imageUrls,
          previewUrls: imageUrls,
          isDetailLoaded: true,
        );
      }
    } catch (e) {
      debugPrint('[GalleryepicApiService] Error fetching detail: $e');
    }

    return item;
  }
}
