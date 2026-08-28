import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/album_item.dart';

enum ExSourceServer {
  eHentai('E-Hentai (表站)', 'https://e-hentai.org'),
  exHentai('ExHentai (里站)', 'https://exhentai.org'),
  mirror810114('810114 镜像', 'https://ex.810114.xyz');

  final String label;
  final String baseUrl;
  const ExSourceServer(this.label, this.baseUrl);
}

enum ExCategory {
  all('全部', '', 0),
  doujinshi('同人志', 'doujinshi', 2),
  manga('漫画', 'manga', 4),
  artistCg('画师CG', 'artistcg', 8),
  gameCg('游戏CG', 'gamecg', 16),
  western('欧美', 'western', 512),
  nonH('非H', 'non-h', 256),
  imageSet('图集', 'imageset', 32),
  cosplay('Cosplay', 'cosplay', 64),
  asianPorn('亚洲写真', 'asianporn', 128),
  misc('杂项', 'misc', 1);

  final String label;
  final String path;
  final int bitmask;
  const ExCategory(this.label, this.path, this.bitmask);
}

class ExPageResult {
  final List<AlbumItem> items;
  final int currentPage;
  final int totalPages;
  final bool hasMore;
  final String? nextCursor;
  final String? prevCursor;

  const ExPageResult({
    required this.items,
    required this.currentPage,
    this.totalPages = 1,
    this.hasMore = true,
    this.nextCursor,
    this.prevCursor,
  });
}

class ExHentaiApiService {
  static const String kBaseUrl = 'https://e-hentai.org';
  static const String kFallbackUrl = 'https://ex.810114.xyz';

  static ExSourceServer _currentSource = ExSourceServer.eHentai;
  static String _customMirrorUrl = '';

  static ExSourceServer get currentSource => _currentSource;
  static String get customSourceUrl => _customMirrorUrl;
  static String get currentBaseUrl =>
      _customMirrorUrl.isNotEmpty ? _customMirrorUrl : _currentSource.baseUrl;

  static void setSource(ExSourceServer source, {String? customUrl}) {
    _currentSource = source;
    _customMirrorUrl = customUrl?.trim() ?? '';
    _dio = _createDio();
  }

  static String? _configuredProxy;
  static Dio _dio = _createDio();

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
    _dio = _createDio();
  }

  static Dio _createDio() {
    final baseUrl = currentBaseUrl;
    final isEx = baseUrl.contains('exhentai.org') || baseUrl.contains('810114');

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Referer': '$baseUrl/',
          'Accept': 'text/html,application/xhtml+xml,application/xml,application/json;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
          'Cookie': isEx ? 'nw=1; igneous=1' : 'nw=1',
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

  /// Build list page URL with canonical category routing, search parameter, and GID cursor
  static String buildUrl({
    int page = 1,
    ExCategory category = ExCategory.all,
    String? keyword,
    bool isPopular = false,
    String? cursor,
  }) {
    final baseUrl = currentBaseUrl;
    if (isPopular) {
      if (_currentSource == ExSourceServer.mirror810114) {
        return 'https://ex.810114.xyz/image/popular';
      }
      return '$baseUrl/popular';
    }

    final queryParams = <String, String>{};

    if (keyword != null && keyword.trim().isNotEmpty) {
      queryParams['f_search'] = keyword.trim();
    }

    if (cursor != null && cursor.isNotEmpty) {
      if (cursor.contains('=')) {
        final parts = cursor.split('=');
        queryParams[parts[0]] = parts[1];
      } else {
        queryParams['next'] = cursor;
      }
    }

    final pathSegment = category == ExCategory.all ? '' : category.path;
    var urlPath = '$baseUrl/$pathSegment';
    if (_currentSource == ExSourceServer.mirror810114 && !urlPath.contains('/image')) {
      urlPath = urlPath.replaceAll('https://ex.810114.xyz', 'https://ex.810114.xyz/image');
    }

    final uri = Uri.parse(urlPath).replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    return uri.toString();
  }

  /// Fetch page data from ExHentai / E-Hentai / Mirrors
  static Future<ExPageResult?> fetchPageData({
    int page = 1,
    ExCategory category = ExCategory.all,
    String? keyword,
    bool isPopular = false,
    String? cursor,
  }) async {
    try {
      final url = buildUrl(
        page: page,
        category: category,
        keyword: keyword,
        isPopular: isPopular,
        cursor: cursor,
      );
      debugPrint('[ExHentaiApiService] Fetching list from $currentBaseUrl: $url');

      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        return _parseListPageHtml(response.data!, page);
      }
    } catch (e) {
      debugPrint('[ExHentaiApiService] Error fetching page data from $currentBaseUrl: $e');
    }
    return null;
  }

  /// Parse list page HTML into List of AlbumItem with strict deduplication
  static ExPageResult _parseListPageHtml(String html, int requestedPage) {
    final document = html_parser.parse(html);
    final List<AlbumItem> items = [];
    final seenSlugs = <String>{};

    // 1. Check Grid format (.gl1t cards) or Table rows (.itg tr)
    final gridCards = document.querySelectorAll('table.itg tr, .gl1t, div.gl1e');
    for (final card in gridCards) {
      try {
        final linkElem = card.querySelector('a[href*="/g/"]');
        if (linkElem == null) continue;

        var detailHref = linkElem.attributes['href'] ?? '';
        if (detailHref.isEmpty || !detailHref.contains('/g/')) continue;
        if (!detailHref.startsWith('http')) {
          detailHref = '$currentBaseUrl$detailHref';
        }

        // Extract gid and token from href: /g/4146938/ff7d6eba08/
        final match = RegExp(r'/g/(\d+)/([a-z0-9]+)').firstMatch(detailHref);
        if (match == null) continue;
        final gid = match.group(1)!;
        final token = match.group(2)!;
        final slug = '${gid}_$token';

        if (!seenSlugs.add(gid)) continue;

        // Title (strictly query .glink to avoid tag concatenation from parent containers)
        final titleElem = card.querySelector('.glink') ?? card.querySelector('div.glink');
        var title = titleElem?.text.trim() ?? linkElem.attributes['title'] ?? 'ExHentai #$gid';

        // Cover image
        final imgElem = card.querySelector('.glthumb img, img');
        var coverUrl = imgElem?.attributes['data-src'] ??
            imgElem?.attributes['data-lazy-src'] ??
            imgElem?.attributes['src'] ??
            '';
        if (coverUrl.startsWith('data:image')) {
          coverUrl = imgElem?.attributes['data-src'] ?? imgElem?.attributes['data-lazy-src'] ?? '';
        }
        if (coverUrl.startsWith('//')) {
          coverUrl = 'https:$coverUrl';
        } else if (coverUrl.startsWith('/')) {
          coverUrl = '$currentBaseUrl$coverUrl';
        }

        // Category
        final catElem = card.querySelector('.cs, [class*="ct"], .cn');
        final category = catElem?.text.trim() ?? 'ExHentai';

        // Posted date
        final dateElem = card.querySelector('[id^="posted_"], td.gl2c');
        final date = dateElem?.text.trim() ?? '今日';

        // Rating
        final irElem = card.querySelector('.ir, [class*="ir"]');
        final ratingStyle = irElem?.attributes['style'] ?? '';
        var rating = '';
        final rMatch = RegExp(r'background-position:\s*(-?\d+)px\s+(-?\d+)px').firstMatch(ratingStyle);
        if (rMatch != null) {
          final posX = int.tryParse(rMatch.group(1) ?? '0') ?? 0;
          final calculated = (5.0 + (posX / 16.0)).clamp(0.0, 5.0);
          rating = calculated.toStringAsFixed(1);
        }

        // Pages / File count: strictly match leaf elements with "X pages" to avoid concatenating date minutes
        String? filecount;
        for (final el in card.querySelectorAll('div, td, span')) {
          final t = el.text.trim();
          final m = RegExp(r'^\s*(\d{1,5})\s*pages?\s*$', caseSensitive: false).firstMatch(t);
          if (m != null) {
            filecount = m.group(1);
            break;
          }
        }
        filecount ??= RegExp(r'(?:^|[^\d:])(\d{1,5})\s*pages?', caseSensitive: false).firstMatch(card.text)?.group(1);

        items.add(
          AlbumItem(
            title: title,
            slug: slug,
            detailUrl: detailHref,
            coverUrl: coverUrl.isNotEmpty ? coverUrl : null,
            date: date,
            author: category,
            tags: [category],
            sourceType: MediaSourceType.exhentai,
            rawData: {
              'gid': gid,
              'token': token,
              'category': category,
              if (rating.isNotEmpty) 'rating': rating,
              if (filecount != null) 'filecount': filecount,
            },
          ),
        );
      } catch (e) {
        debugPrint('[ExHentaiApiService] Error parsing card: $e');
      }
    }

    // Fallback: Search all /g/ links
    if (items.isEmpty) {
      final allLinks = document.querySelectorAll('a[href*="/g/"]');
      for (final a in allLinks) {
        var href = a.attributes['href'] ?? '';
        if (!href.contains('/g/')) continue;
        if (!href.startsWith('http')) {
          href = '$currentBaseUrl$href';
        }

        final match = RegExp(r'/g/(\d+)/([a-z0-9]+)').firstMatch(href);
        if (match == null) continue;
        final gid = match.group(1)!;
        final token = match.group(2)!;
        final slug = '${gid}_$token';

        if (!seenSlugs.add(gid)) continue;

        final title = a.attributes['title'] ?? a.text.trim();
        final img = a.querySelector('img');
        final cover = img?.attributes['src'] ?? img?.attributes['data-src'];

        if (title.isNotEmpty && title.length > 2) {
          items.add(
            AlbumItem(
              title: title,
              slug: slug,
              detailUrl: href,
              coverUrl: cover != null && cover.isNotEmpty ? (cover.startsWith('http') ? cover : '$currentBaseUrl$cover') : null,
              date: '今日',
              author: 'ExHentai',
              tags: const ['ExHentai'],
              sourceType: MediaSourceType.exhentai,
              rawData: {'gid': gid, 'token': token},
            ),
          );
        }
      }
    }

    // Extract next/prev cursor from HTML links or GID boundaries
    String? nextCursor;
    String? prevCursor;

    final nextMatch = RegExp(r'[?&]next=(\d+)').firstMatch(html);
    if (nextMatch != null) {
      nextCursor = nextMatch.group(1);
    } else if (seenSlugs.isNotEmpty) {
      final lastGid = int.tryParse(seenSlugs.last);
      if (lastGid != null && lastGid > 1) {
        nextCursor = (lastGid - 1).toString();
      }
    }

    final prevMatch = RegExp(r'[?&]prev=(\d+)').firstMatch(html);
    if (prevMatch != null) {
      prevCursor = prevMatch.group(1);
    } else if (seenSlugs.isNotEmpty) {
      final firstGid = int.tryParse(seenSlugs.first);
      if (firstGid != null) {
        prevCursor = (firstGid + 1).toString();
      }
    }

    // Parse Pagination
    int totalPages = requestedPage;
    final pageTable = document.querySelector('table.ptb');
    if (pageTable != null) {
      final pageLinks = pageTable.querySelectorAll('td a');
      for (final pl in pageLinks) {
        final pText = pl.text.trim();
        final num = int.tryParse(pText);
        if (num != null && num > totalPages) {
          totalPages = num;
        }
      }
    }

    return ExPageResult(
      items: items,
      currentPage: requestedPage,
      totalPages: totalPages > requestedPage ? totalPages : (nextCursor != null ? requestedPage + 1 : requestedPage),
      hasMore: items.isNotEmpty && nextCursor != null,
      nextCursor: nextCursor,
      prevCursor: prevCursor,
    );
  }

  /// Parse thumbnails and reader URLs from gallery HTML document
  static void _parseGdtThumbnails(dynamic document, List<String> previewThumbnails, List<String> pageUrls, [bool isMirror810114 = false]) {
    final gdtElems = document.querySelectorAll('#gdt .gdtm, #gdt .gdtl, #gdt a[href*="/s/"]');
    for (final g in gdtElems) {
      final aTag = g.querySelector('a') ?? (g.localName == 'a' ? g : null);
      var pageHref = aTag?.attributes['href'];
      if (pageHref != null && pageHref.contains('/s/')) {
        if (pageHref.startsWith('/')) {
          pageHref = isMirror810114 ? 'https://ex.810114.xyz/image$pageHref' : 'https://e-hentai.org$pageHref';
        } else if (isMirror810114) {
          pageHref = pageHref.replaceAll('https://e-hentai.org', 'https://ex.810114.xyz/image')
                             .replaceAll('https://exhentai.org', 'https://ex.810114.xyz/image');
        }
        if (!pageUrls.contains(pageHref)) {
          pageUrls.add(pageHref);
        }
      }

      final imgTag = g.querySelector('img');
      final thumbSrc = imgTag?.attributes['src'] ?? imgTag?.attributes['data-src'];
      if (thumbSrc != null && thumbSrc.isNotEmpty && thumbSrc.startsWith('http')) {
        if (!previewThumbnails.contains(thumbSrc)) {
          previewThumbnails.add(thumbSrc);
        }
      } else {
        final div = g.querySelector('div') ?? (g.localName == 'div' ? g : null);
        if (div != null) {
          final style = div.attributes['style'] ?? '';
          final urlMatch = RegExp(r'url\((["\x27]?)(.*?)\1\)').firstMatch(style);
          if (urlMatch != null && urlMatch.group(2)!.startsWith('http')) {
            final url = urlMatch.group(2)!;
            final posMatch = RegExp(r'(-?\d+)px\s+(-?\d+)px').firstMatch(style) ?? RegExp(r'(-?\d+)px\s+0').firstMatch(style);
            final wMatch = RegExp(r'width:\s*(\d+)px').firstMatch(style);
            final hMatch = RegExp(r'height:\s*(\d+)px').firstMatch(style);
            final offsetX = (double.tryParse(posMatch?.group(1) ?? '0') ?? 0).abs();
            final offsetY = posMatch != null && posMatch.groupCount >= 2 ? (double.tryParse(posMatch.group(2) ?? '0') ?? 0).abs() : 0.0;
            final w = double.tryParse(wMatch?.group(1) ?? '200') ?? 200.0;
            final h = double.tryParse(hMatch?.group(1) ?? '280') ?? 280.0;
            final spriteData = 'sprite:$url#$offsetX,$offsetY,$w,$h';
            if (!previewThumbnails.contains(spriteData)) {
              previewThumbnails.add(spriteData);
            }
          }
        }
      }
    }
  }

  /// Fetch full album detail via 810114 Mirror API without requiring VPN
  static Future<AlbumItem?> _fetchAlbumDetailViaMirrorApi(AlbumItem item) async {
    try {
      final match = RegExp(r'/g/(\d+)/([a-zA-Z0-9]+)').firstMatch(item.detailUrl);
      if (match != null) {
        final gid = int.tryParse(match.group(1)!) ?? 0;
        final token = match.group(2)!;

        final response = await _dio.post(
          'https://ex.810114.xyz/api.php',
          data: {
            'method': 'gdata',
            'gidlist': [
              [gid, token]
            ],
            'namespace': 1,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data is Map ? response.data as Map : {};
          final list = data['gmetadata'] as List?;
          if (list != null && list.isNotEmpty) {
            final meta = list.first as Map;
            final title = meta['title']?.toString() ?? item.title;
            final titleJpn = meta['title_jpn']?.toString() ?? '';
            final finalTitle = titleJpn.isNotEmpty ? titleJpn : title;
            final coverUrl = meta['thumb']?.toString() ?? item.coverUrl;
            final category = meta['category']?.toString() ?? item.author;
            final rating = meta['rating']?.toString() ?? '';
            final filecount = int.tryParse(meta['filecount']?.toString() ?? '1') ?? 1;
            final tags = meta['tags'] != null ? List<String>.from(meta['tags'] as List) : item.tags;

            final List<String> imageUrls = [];
            final List<String> previewUrls = [];

            if (coverUrl != null && coverUrl.isNotEmpty) {
              imageUrls.add(coverUrl);
              previewUrls.add(coverUrl);
            }

            return item.copyWith(
              title: finalTitle,
              coverUrl: coverUrl,
              author: category,
              tags: tags,
              previewUrls: previewUrls,
              imageUrls: imageUrls,
              isDetailLoaded: true,
              rawData: {
                ...item.rawData,
                'title_en': title,
                'title_jpn': titleJpn,
                'rating': rating,
                'filecount': filecount.toString(),
                'pageCount': filecount,
              },
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[ExHentaiApiService] Error fetching 810114 mirror detail: $e');
    }
    return item;
  }

  /// Fetch full album detail, tags, and all preview thumbnail page links across all gallery pages
  static Future<AlbumItem?> fetchAlbumDetail(AlbumItem item) async {
    final isMirror = currentSource == ExSourceServer.mirror810114 || item.detailUrl.contains('810114');
    
    // Extract gid & token
    final match = RegExp(r'/g/(\d+)/([a-zA-Z0-9]+)').firstMatch(item.detailUrl);
    final gid = match != null ? (int.tryParse(match.group(1)!) ?? 0) : 0;
    final token = match != null ? match.group(2)! : '';

    try {
      String fetchUrl;
      if (isMirror && gid > 0 && token.isNotEmpty) {
        fetchUrl = 'https://ex.810114.xyz/image/g/$gid/$token/';
      } else {
        fetchUrl = item.detailUrl.replaceAll('https://ex.810114.xyz', 'https://e-hentai.org');
      }

      debugPrint('[ExHentaiApiService] Fetching detail: $fetchUrl (original: ${item.detailUrl})');
      final response = await _dio.get<String>(
        fetchUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Referer': isMirror ? 'https://ex.810114.xyz/' : 'https://e-hentai.org/',
            'Cookie': 'nw=1; igneous=1',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data!;
        final document = html_parser.parse(html);

        // 1. Japanese / English Titles
        final gn = document.querySelector('#gn')?.text.trim();
        final gj = document.querySelector('#gj')?.text.trim();
        final finalTitle = (gj != null && gj.isNotEmpty) ? gj : (gn ?? item.title);

        // 2. Cover image
        final coverElem = document.querySelector('#gd1 div') ?? document.querySelector('#gd1 img');
        var coverUrl = item.coverUrl;
        if (coverElem != null) {
          final style = coverElem.attributes['style'] ?? '';
          final urlMatch = RegExp(r'url\((["\x27]?)(.*?)\1\)').firstMatch(style);
          if (urlMatch != null) {
            coverUrl = urlMatch.group(2);
          } else {
            coverUrl = coverElem.attributes['src'] ?? coverUrl;
          }
        }

        // 3. Tags
        final List<String> tags = [];
        final tagElems = document.querySelectorAll('#taglist tr');
        for (final tr in tagElems) {
          final namespace = tr.querySelector('.tc')?.text.trim().replaceAll(':', '') ?? '';
          final tLinks = tr.querySelectorAll('a');
          for (final a in tLinks) {
            final t = a.text.trim();
            if (t.isNotEmpty) {
              tags.add(namespace.isNotEmpty ? '$namespace:$t' : t);
            }
          }
        }

        // 4. Extract total pages & preview images across all subpages
        final List<String> previewThumbnails = [];
        final List<String> pageUrls = [];
        _parseGdtThumbnails(document, previewThumbnails, pageUrls, isMirror);

        // Check if there are subpages in gallery (e.g. ?p=1, ?p=2...)
        final ptbLinks = document.querySelectorAll('table.ptb td a');
        final subpageUrls = <String>[];
        for (final pl in ptbLinks) {
          var href = pl.attributes['href'];
          if (href != null && href.contains('?p=') && !subpageUrls.contains(href)) {
            if (!href.endsWith('?p=0') && !href.contains('?p=0&') && !href.contains('?p=0#')) {
              if (isMirror && gid > 0 && token.isNotEmpty) {
                final pMatch = RegExp(r'p=(\d+)').firstMatch(href);
                final pNum = pMatch?.group(1) ?? '1';
                subpageUrls.add('https://ex.810114.xyz/image/g/$gid/$token/?p=$pNum');
              } else {
                if (href.startsWith('/')) {
                  href = 'https://e-hentai.org$href';
                }
                subpageUrls.add(href);
              }
            }
          }
        }

        if (subpageUrls.isNotEmpty) {
          final pagesToFetch = subpageUrls.take(15).toList();
          final results = await Future.wait(
            pagesToFetch.map(
              (pUrl) => _dio.get<String>(
                pUrl,
                options: Options(
                  responseType: ResponseType.plain,
                  headers: {
                    'Referer': isMirror ? 'https://ex.810114.xyz/' : 'https://e-hentai.org/',
                    'Cookie': 'nw=1; igneous=1',
                  },
                ),
              ).catchError((_) => Response<String>(requestOptions: RequestOptions(), statusCode: 500)),
            ),
          );
          for (final res in results) {
            if (res.statusCode == 200 && res.data != null) {
              final subDoc = html_parser.parse(res.data!);
              _parseGdtThumbnails(subDoc, previewThumbnails, pageUrls, isMirror);
            }
          }
        }

        // 5. Rating & category & total pages from #gdd
        final ratingText = document.querySelector('#rating_label')?.text.trim() ?? '';
        final catText = document.querySelector('#gdc .cs')?.text.trim() ?? item.author;

        String? gddPageCount;
        for (final row in document.querySelectorAll('#gdd tr, #gdd td')) {
          if (row.text.contains('Length:')) {
            final m = RegExp(r'(\d+)\s*pages?', caseSensitive: false).firstMatch(row.text);
            if (m != null) {
              gddPageCount = m.group(1);
              break;
            }
          }
        }

        final finalPageCount = gddPageCount ??
            (pageUrls.isNotEmpty ? pageUrls.length.toString() : item.rawData['filecount']?.toString() ?? '1');

        return item.copyWith(
          title: finalTitle,
          coverUrl: coverUrl,
          author: catText,
          tags: tags.isNotEmpty ? tags : item.tags,
          previewUrls: previewThumbnails.isNotEmpty ? previewThumbnails : (coverUrl != null ? [coverUrl] : []),
          imageUrls: pageUrls.isNotEmpty ? pageUrls : (coverUrl != null ? [coverUrl] : []),
          isDetailLoaded: true,
          rawData: {
            ...item.rawData,
            'rating': ratingText,
            'filecount': finalPageCount,
            'pageCount': pageUrls.length,
          },
        );
      }
    } catch (e) {
      debugPrint('[ExHentaiApiService] Error fetching album detail HTML: $e');
    }

    return await _fetchAlbumDetailViaMirrorApi(item);
  }

  /// Resolve high resolution image URL from a reader page link (e.g. /s/token/gid-p)
  static Future<String?> resolveFullImageUrl(String pageUrl) async {
    if (pageUrl.startsWith('http') &&
        (pageUrl.endsWith('.jpg') ||
            pageUrl.endsWith('.png') ||
            pageUrl.endsWith('.webp') ||
            pageUrl.endsWith('.jpeg') ||
            pageUrl.contains('.hath.network') ||
            pageUrl.contains('ex.810114.xyz/image/s/'))) {
      return pageUrl;
    }

    if (currentSource == ExSourceServer.mirror810114 || pageUrl.contains('810114')) {
      if (pageUrl.contains('/s/')) {
        final clean = pageUrl.startsWith('http')
            ? pageUrl.replaceAll('https://e-hentai.org', 'https://ex.810114.xyz/image')
                     .replaceAll('https://exhentai.org', 'https://ex.810114.xyz/image')
            : 'https://ex.810114.xyz/image$pageUrl';
        return clean;
      }
      return pageUrl;
    }

    return await resolveDirectImageUrl(pageUrl);
  }

  /// Resolve direct original Hath Network image from e-hentai /s/ reader URL
  static Future<String?> resolveDirectImageUrl(String pageUrl) async {
    if (pageUrl.contains('.hath.network') ||
        pageUrl.endsWith('.jpg') ||
        pageUrl.endsWith('.png') ||
        pageUrl.endsWith('.webp')) {
      return pageUrl;
    }

    if (pageUrl.contains('ex.810114.xyz/image/s/')) {
      return pageUrl;
    }

    try {
      final response = await _dio.get<String>(
        pageUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Referer': 'https://e-hentai.org/',
            'Cookie': 'nw=1; igneous=1',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final document = html_parser.parse(response.data!);
        final img = document.querySelector('#img, #i3 img');
        final src = img?.attributes['src'];
        if (src != null && src.isNotEmpty && src.startsWith('http')) {
          return src;
        }
      }
    } catch (e) {
      debugPrint('[ExHentaiApiService] Error resolving direct image: $e');
    }
    return null;
  }

  /// Gallery detail alias
  static Future<AlbumItem?> fetchGalleryDetail(AlbumItem item) => fetchAlbumDetail(item);
}
