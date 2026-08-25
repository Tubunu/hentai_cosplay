import 'dart:convert';
import 'package:html/parser.dart' show parse;
import 'package:dio/dio.dart';
import '../../../models/jable_video_item.dart';
import '../api_client.dart';
import '../cf_cookie_harvester.dart';
import '../persistent_chromium_tunnel.dart';
import '../js_unpacker.dart';
import 'base_scraper.dart';

class SupJavScraper extends BaseScraper {
  @override
  String get siteName => 'SupJav';

  @override
  String get urlRoot => "https://${ApiClient().getActiveHost(siteName)}";

  static const List<Map<String, String>> categories = [
    {'name': '最新影片', 'url_path': '/zh/'},
    {'name': '热门影片', 'url_path': '/zh/popular'},
    {'name': '中文字幕', 'url_path': '/zh/category/chinese-subtitles'},
    {'name': '高清有码', 'url_path': '/zh/category/censored-jav'},
    {'name': '高清无码', 'url_path': '/zh/category/uncensored-jav'},
    {'name': '素人自拍', 'url_path': '/zh/category/amateur'},
    {'name': '无码破解', 'url_path': '/zh/category/reducing-mosaic'},
    {'name': '独家首发', 'url_path': '/zh/category/exclusive'},
    {'name': 'VR专区', 'url_path': '/zh/category/vr-censored'},
  ];

  @override
  Future<List<CategoryModel>> fetchCategories() async {
    final List<CategoryModel> cats = [];
    final root = urlRoot.replaceAll(RegExp(r'/+$'), '');
    
    for (final cat in categories) {
      String path = cat['url_path']!;
      String url = "$root$path";
      cats.add(CategoryModel(
        name: cat['name']!,
        url: url,
      ));
    }
    return cats;
  }

  @override
  Future<List<VideoCardModel>> fetchPage(String url) async {
    final List<VideoCardModel> videos = [];
    final root = urlRoot.replaceAll(RegExp(r'/+$'), '');
    try {
      final htmlText = await ApiClient().fetchHtml(siteName, url);
      final document = parse(htmlText);
      
      final posts = document.querySelectorAll('div.post, article.post, div.post-item, div.item, .posts .post, div.card, .post-list-item');
      final Set<String> seen = {};
      
      for (final post in posts) {
        final a = post.querySelector('a[href*=".html"]') ?? 
                  post.querySelector('a[href*="/4"]') ?? 
                  post.querySelector('a[href*="/5"]') ?? 
                  post.querySelector('a[href*="/6"]') ?? 
                  post.querySelector('a[href*="/7"]') ?? 
                  post.querySelector('a[href*="/8"]') ?? 
                  post.querySelector('a[href*="/9"]') ?? 
                  post.querySelector('h2 a') ?? 
                  post.querySelector('h3 a') ?? 
                  post.querySelector('.post-title a') ?? 
                  post.querySelector('a');
        if (a == null) continue;
        
        var videoUrl = a.attributes['href'] ?? '';
        if (videoUrl.isEmpty || videoUrl == '#' || videoUrl.contains('javascript:')) continue;
        if (!videoUrl.startsWith('http')) {
          videoUrl = "$root${videoUrl.startsWith('/') ? '' : '/'}$videoUrl";
        }
        
        if (seen.contains(videoUrl)) continue;
        seen.add(videoUrl);
        
        final title = a.attributes['title'] ?? a.text.trim();
        if (title.isEmpty) continue;
        
        final img = post.querySelector('img');
        var thumbnail = img?.attributes['data-original'] ?? 
                        img?.attributes['data-src'] ?? 
                        img?.attributes['data-lazy-src'] ?? 
                        '';
        if (thumbnail.isEmpty && img != null) {
          final src = img.attributes['src'] ?? '';
          if (!src.startsWith('data:')) {
            thumbnail = src;
          }
        }
        if (thumbnail.isNotEmpty && !thumbnail.startsWith('http')) {
          thumbnail = "$root${thumbnail.startsWith('/') ? '' : '/'}$thumbnail";
        }
        
        final meta = post.querySelector('div.meta, .post-meta, .date, span.time');
        final metaText = meta?.text.trim() ?? '';
        final dateMatch = RegExp(r'(?<!\d)(20\d{2}[/\-]\d{1,2}[/\-]\d{1,2})(?!\d)').firstMatch(metaText);
        final date = dateMatch != null ? dateMatch.group(1)! : "";
        
        videos.add(VideoCardModel(
          url: videoUrl,
          title: title,
          thumbnail: thumbnail,
          duration: "",
          date: date,
          siteName: siteName,
        ));
      }

      if (videos.isEmpty) {
        final regexMatches = RegExp(r'<a[^>]+href=["\x27](https?://[^"\x27]*supjav\.com/[^"\x27]*\.html)["\x27][^>]*>(.*?)</a>', caseSensitive: false).allMatches(htmlText);
        for (final m in regexMatches) {
          final vUrl = m.group(1)!;
          if (!seen.contains(vUrl)) {
            seen.add(vUrl);
            final inner = m.group(2)!;
            final tMatch = RegExp(r'title=["\x27]([^"\x27]+)["\x27]').firstMatch(m.group(0)!);
            final title = tMatch?.group(1) ?? inner.replaceAll(RegExp(r'<[^>]*>'), '').trim();
            if (title.isNotEmpty) {
              videos.add(VideoCardModel(url: vUrl, title: title, thumbnail: "", duration: "", date: "", siteName: siteName));
            }
          }
        }
      }
    } catch (_) {}
    return videos;
  }

  @override
  Future<List<VideoCardModel>> search(String query) async {
    final root = urlRoot.replaceAll(RegExp(r'/+$'), '');
    final encodedQuery = Uri.encodeComponent(query);
    final searchUrl = "$root/zh/?s=$encodedQuery";
    return fetchPage(searchUrl);
  }

  @override
  String buildPageUrl(String baseUrl, int page) {
    if (page <= 1) return baseUrl;
    
    final uri = Uri.parse(baseUrl);
    var path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (path.isEmpty) path = "/zh";
    
    path = path.replaceAll(RegExp(r'/page/\d+'), '');
    final newPath = "$path/page/$page";
    
    final newUri = uri.replace(path: newPath);
    return newUri.toString();
  }

  static bool _isValidUrl(String? url) {
    if (url == null || url.length < 10 || !url.startsWith('http')) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty && uri.host.contains('.');
  }

  @override
  Future<VideoDetailModel> parseVideoDetail(String videoUrl) async {
    String htmlText = "";
    try {
      htmlText = await ApiClient().fetchHtml(siteName, videoUrl, isDetailPage: true);
    } catch (e) {
      htmlText = await CfCookieHarvester.fetchContentViaWebView(videoUrl, siteName: siteName);
    }

    var detail = await _tryExtractDetailFromHtml(htmlText, videoUrl);
    if (detail != null && _isValidUrl(detail.m3u8Url)) {
      return detail;
    }

    final webViewHtml = await CfCookieHarvester.fetchContentViaWebView(videoUrl, siteName: siteName);
    if (webViewHtml.isNotEmpty && webViewHtml != htmlText) {
      detail = await _tryExtractDetailFromHtml(webViewHtml, videoUrl);
      if (detail != null && _isValidUrl(detail.m3u8Url)) {
        return detail;
      }
    }

    throw Exception("[$siteName] 无法解析视频播放源 (M3U8)，可能该视频已被删除或服务器受限。");
  }

  Future<VideoDetailModel?> _tryExtractDetailFromHtml(String htmlText, String videoUrl) async {
    final document = parse(htmlText);
    
    // 1. Get title
    final title = document.querySelector('h1')?.text.trim() ??
                  document.querySelector('meta[property="og:title"]')?.attributes['content'] ??
                  document.querySelector('title')?.text.trim() ??
                  "";
    
    // 2. Get thumbnail
    var thumbnail = document.querySelector('meta[property="og:image"]')?.attributes['content'] ??
                    document.querySelector('meta[name="twitter:image"]')?.attributes['content'] ??
                    document.querySelector('div.post img')?.attributes['data-original'] ??
                    document.querySelector('div.post img')?.attributes['data-src'] ??
                    document.querySelector('div.post img')?.attributes['data-lazy-src'] ??
                    document.querySelector('div.post img')?.attributes['src'] ??
                    "";
    if (thumbnail.startsWith('//')) thumbnail = "https:$thumbnail";

    // 3. Extract stream servers
    final Map<String, String> servers = {};
    final buttons = document.querySelectorAll('a.btn-server, button.btn-server, a[data-link]');
    for (final btn in buttons) {
      final name = btn.text.trim().toUpperCase();
      final link = btn.attributes['data-link'] ?? '';
      if (name.isNotEmpty && link.isNotEmpty) {
        servers[name] = link;
      }
    }

    if (servers.isEmpty) {
      final btnMatches = RegExp(r'class=["\x27][^"\x27]*btn-server[^"\x27]*["\x27][^>]+data-link=["\x27]([^"\x27]+)["\x27][^>]*>(.*?)<', caseSensitive: false).allMatches(htmlText);
      for (final m in btnMatches) {
        final link = m.group(1) ?? "";
        final name = (m.group(2) ?? "SERVER").trim().toUpperCase();
        if (link.isNotEmpty) servers[name] = link;
      }
    }

    if (servers.isEmpty) {
      final dataLinks = RegExp(r'data-link=["\x27]([^"\x27]+)["\x27]').allMatches(htmlText);
      int counter = 1;
      for (final m in dataLinks) {
        final link = m.group(1) ?? "";
        if (link.isNotEmpty) {
          servers['SERVER_$counter'] = link;
          counter++;
        }
      }
    }

    String reverseString(String s) {
      return s.split('').reversed.join('');
    }

    final orderedKeys = <String>[];
    for (final pref in ['TV', 'STREAM', 'FST', 'FAST', 'VOE', 'ST', 'DS', 'SSB', 'DIRECT']) {
      final match = servers.keys.firstWhere((k) => k.contains(pref), orElse: () => '');
      if (match.isNotEmpty && !orderedKeys.contains(match)) {
        orderedKeys.add(match);
      }
    }
    for (final k in servers.keys) {
      if (!orderedKeys.contains(k)) orderedKeys.add(k);
    }

    final dio = ApiClient().dio;
    VideoDetailModel? firstExtractedFallback;

    for (final srvName in orderedKeys) {
      final rawLink = servers[srvName]!;
      String supremeJavUrl = "";
      if (rawLink.startsWith('http://') || rawLink.startsWith('https://')) {
        supremeJavUrl = rawLink;
      } else if (rawLink.startsWith('//')) {
        supremeJavUrl = "https:$rawLink";
      } else {
        try {
          final b64 = utf8.decode(base64.decode(base64.normalize(rawLink.trim())));
          if (b64.startsWith('http')) {
            supremeJavUrl = b64;
          }
        } catch (_) {}

        if (supremeJavUrl.isEmpty) {
          final reversedLink = reverseString(rawLink);
          if (reversedLink.startsWith('http')) {
            supremeJavUrl = reversedLink;
          } else if (reversedLink.startsWith('//')) {
            supremeJavUrl = "https:$reversedLink";
          } else if (reversedLink.contains('supremejav.com') || reversedLink.contains('supjav.com')) {
            supremeJavUrl = "https://${reversedLink.replaceAll(RegExp(r'^/+'), '')}";
          } else {
            supremeJavUrl = 'https://lk1.supremejav.com/supjav.php?c=$reversedLink';
          }
        }
      }

      String responseText = "";
      String realReferer = "https://supjav.com/";

      try {
        final response = await dio.get(
          supremeJavUrl,
          options: Options(
            headers: {
              'Referer': 'https://supjav.com/',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
            },
            followRedirects: true,
          ),
        );
        responseText = response.data?.toString() ?? "";
        realReferer = response.realUri.toString();
      } catch (_) {
        try {
          final jsText = await PersistentChromiumTunnel.fetchText(
            supremeJavUrl,
            siteName: siteName,
            headers: {'Referer': 'https://supjav.com/'},
          );
          if (jsText != null && jsText.isNotEmpty) {
            responseText = jsText;
            realReferer = supremeJavUrl;
          } else {
            final fbText = await CfCookieHarvester.fetchTextViaJs(
              supremeJavUrl,
              siteName: siteName,
              headers: {'Referer': 'https://supjav.com/'},
            );
            if (fbText.isNotEmpty) {
              responseText = fbText;
              realReferer = supremeJavUrl;
            }
          }
        } catch (_) {}
      }

      if (responseText.isEmpty) continue;

      String m3u8Url = _extractPackedM3u8(responseText) ?? 
                       _extractVoeM3u8(responseText) ?? 
                       _extractDirectM3u8(responseText) ?? 
                       _extractStreamTapeMp4(responseText) ??
                       _extractDoodStream(responseText) ?? 
                       "";

      if (m3u8Url.isEmpty) {
        final iframeMatch = RegExp(r'<iframe[^>]+(?:src|data-src)=["\x27](https?://[^"\x27]+)["\x27]').firstMatch(responseText);
        if (iframeMatch != null) {
          final iframeSrc = iframeMatch.group(1)!;
          try {
            final ifrResp = await dio.get(
              iframeSrc,
              options: Options(
                headers: {
                  'Referer': supremeJavUrl,
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
                },
                followRedirects: true,
              ),
            );
            final ifrText = ifrResp.data?.toString() ?? "";
            m3u8Url = _extractPackedM3u8(ifrText) ?? 
                      _extractVoeM3u8(ifrText) ?? 
                      _extractDirectM3u8(ifrText) ?? 
                      _extractStreamTapeMp4(ifrText) ??
                      _extractDoodStream(ifrText) ?? 
                      "";
            if (m3u8Url.isNotEmpty) {
              realReferer = ifrResp.realUri.toString();
            }
          } catch (_) {}
        }
      }

      if (m3u8Url.isNotEmpty) {
        if (m3u8Url.startsWith('//')) {
          m3u8Url = "https:$m3u8Url";
        } else if (m3u8Url.startsWith('/')) {
          final refUri = Uri.tryParse(realReferer);
          if (refUri != null && refUri.hasScheme) {
            m3u8Url = "${refUri.scheme}://${refUri.host}$m3u8Url";
          }
        }

        if (_isValidUrl(m3u8Url)) {
          final cleanRef = realReferer.split('#').first;
          final cleanUri = Uri.tryParse(cleanRef);
          final cleanOrigin = cleanUri != null && cleanUri.hasScheme ? cleanUri.origin : "https://supjav.com";

          final workingHeaders = await _probeM3u8(m3u8Url, realReferer);
          if (workingHeaders != null) {
            return VideoDetailModel(
              title: title,
              imageUrl: thumbnail,
              m3u8Url: m3u8Url,
              headers: workingHeaders,
              siteName: siteName,
              webPlayerUrl: supremeJavUrl.isNotEmpty ? supremeJavUrl : videoUrl,
            );
          } else {
            firstExtractedFallback ??= VideoDetailModel(
              title: title,
              imageUrl: thumbnail,
              m3u8Url: m3u8Url,
              headers: {
                'Referer': cleanRef,
                'Origin': cleanOrigin,
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
              },
              siteName: siteName,
              webPlayerUrl: supremeJavUrl.isNotEmpty ? supremeJavUrl : videoUrl,
            );
          }
        }
      }
    }

    if (firstExtractedFallback != null && _isValidUrl(firstExtractedFallback.m3u8Url)) {
      return firstExtractedFallback;
    }

    if (servers.isNotEmpty) {
      final firstRaw = servers.values.first;
      return VideoDetailModel(
        title: title,
        imageUrl: thumbnail,
        m3u8Url: firstRaw.startsWith('http') ? firstRaw : videoUrl,
        headers: {
          'Referer': 'https://supjav.com/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        },
        siteName: siteName,
        webPlayerUrl: firstRaw.startsWith('http') ? firstRaw : videoUrl,
      );
    }
    return null;
  }

  static bool _isRealM3u8(String text) {
    if (!text.contains('#EXTM3U')) return false;
    final lower = text.toLowerCase();
    if (lower.contains('deleted') || lower.contains('not found') || lower.contains('404')) return false;
    return text.contains('#EXTINF') || text.contains('#EXT-X-STREAM-INF') || text.contains('#EXT-X-TARGETDURATION');
  }

  Future<Map<String, String>?> _probeM3u8(String m3u8Url, String baseReferer) async {
    final dio = ApiClient().dio;
    final cleanRef = baseReferer.split('#').first;
    final uri = Uri.tryParse(cleanRef);
    final origin = uri != null && uri.hasScheme ? uri.origin : "https://supjav.com";
    final rootRef = "$origin/";
    
    final candidates = <Map<String, String>>[
      {
        'Referer': cleanRef,
        'Origin': origin,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Accept': '*/*',
      },
      {
        'Referer': rootRef,
        'Origin': origin,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Accept': '*/*',
      },
      {
        'Referer': 'https://supjav.com/',
        'Origin': 'https://supjav.com',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Accept': '*/*',
      },
    ];

    for (final headers in candidates) {
      try {
        final resp = await dio.get(
          m3u8Url,
          options: Options(
            headers: headers,
            responseType: ResponseType.plain,
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
          ),
        );
        if ((resp.statusCode == 200 || resp.statusCode == 206) && resp.data != null) {
          final text = resp.data.toString();
          if (_isRealM3u8(text) || (m3u8Url.contains('.mp4') && text.length > 50) || m3u8Url.contains('get_video')) {
            return headers;
          }
        }
      } catch (_) {}
    }
    
    try {
      final jsText = await PersistentChromiumTunnel.fetchText(m3u8Url, siteName: siteName, headers: {'Referer': cleanRef});
      if (jsText != null && _isRealM3u8(jsText)) {
        return {
          'Referer': cleanRef,
          'Origin': origin,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          'Accept': '*/*',
        };
      }
    } catch (_) {}

    return null;
  }

  String? _extractPackedM3u8(String htmlText) {
    final scriptReg = RegExp(r'<script[^>]*>(.*?)</script>', dotAll: true);
    final matches = scriptReg.allMatches(htmlText);
    
    for (final m in matches) {
      final scriptText = m.group(1)!;
      if (scriptText.contains('eval(function') || scriptText.contains('eval(')) {
        final unpacked = JsUnpacker.unpack(scriptText);
        if (unpacked != null && unpacked.isNotEmpty) {
          final m3u8 = _extractDirectM3u8(unpacked) ?? _extractVoeM3u8(unpacked);
          if (m3u8 != null && _isValidUrl(m3u8)) {
            return m3u8;
          }
        }
      }
    }
    return null;
  }

  String? _extractVoeM3u8(String text) {
    final voeMatch = RegExp(r'["\x27]hls["\x27]\s*:\s*["\x27](https?://[^"\x27]+)["\x27]').firstMatch(text);
    if (voeMatch != null && _isValidUrl(voeMatch.group(1))) return voeMatch.group(1);

    final b64Match = RegExp(r'(?:let|var|const)\s+(?:hls|node|streamUrl)\s*=\s*["\x27]([A-Za-z0-9+/=]{20,})["\x27]').firstMatch(text);
    if (b64Match != null) {
      try {
        final decoded = utf8.decode(base64.decode(base64.normalize(b64Match.group(1)!.trim())));
        if (_isValidUrl(decoded)) {
          return decoded;
        }
      } catch (_) {}
    }
    return null;
  }

  String? _extractDirectM3u8(String text) {
    final sourcesMatch = RegExp(r'sources\s*:\s*\[\s*\{[^}]*file\s*:\s*["\x27](https?://[^"\x27]+\.m3u8[^"\x27]*)["\x27]', caseSensitive: false).firstMatch(text);
    if (sourcesMatch != null && _isValidUrl(sourcesMatch.group(1))) return sourcesMatch.group(1);

    final fileMatch = RegExp(r'file\s*:\s*["\x27](https?://[^"\x27]+\.m3u8[^"\x27]*)["\x27]', caseSensitive: false).firstMatch(text);
    if (fileMatch != null && _isValidUrl(fileMatch.group(1))) return fileMatch.group(1);

    final urlPlayMatch = RegExp(r'urlPlay[\s=:\x27\x22]+(?<u>https?://[^\s\x27\x22\\]+\.m3u8[^\s\x27\x22\\]*)', caseSensitive: false).firstMatch(text.replaceAll(r'\/', '/'));
    if (urlPlayMatch != null && _isValidUrl(urlPlayMatch.group(1))) return urlPlayMatch.group(1);

    final hlsUrlMatch = RegExp(r'(?:hlsUrl|hls_url|videoUrl|video_url)\s*=\s*["\x27](https?://[^"\x27]+\.m3u8[^"\x27]*)["\x27]', caseSensitive: false).firstMatch(text);
    if (hlsUrlMatch != null && _isValidUrl(hlsUrlMatch.group(1))) return hlsUrlMatch.group(1);

    final genericMatch = RegExp(r'https?://[^\s\x27\x22\\]+\.m3u8[^\s\x27\x22\\]*').firstMatch(text);
    if (genericMatch != null && _isValidUrl(genericMatch.group(0))) return genericMatch.group(0);

    return null;
  }

  String? _extractStreamTapeMp4(String text) {
    final getVidMatch = RegExp(r'["\x27](https?://[^"\x27]*streamtape\.com/get_video\?[^"\x27]+)["\x27]').firstMatch(text);
    if (getVidMatch != null && _isValidUrl(getVidMatch.group(1))) return getVidMatch.group(1);

    final tapeLink = RegExp(r'["\x27](https?://(?:streamtape|streamta|streamtape\.net|strcloud)[^"\x27]*/(?:v|e)/[^"\x27]+)["\x27]').firstMatch(text);
    if (tapeLink != null && _isValidUrl(tapeLink.group(1))) return tapeLink.group(1);

    return null;
  }

  String? _extractDoodStream(String text) {
    final doodMatch = RegExp(r'["\x27](https?://(?:dood|ds2play|doodstream)[^"\x27]*/pass_md5/[^"\x27]+)["\x27]').firstMatch(text);
    if (doodMatch != null && _isValidUrl(doodMatch.group(1))) {
      return doodMatch.group(1);
    }
    return null;
  }
}
