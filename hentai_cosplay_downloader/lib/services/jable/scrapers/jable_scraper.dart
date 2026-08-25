import 'package:html/parser.dart' show parse;
import '../../../models/jable_video_item.dart';
import '../api_client.dart';
import '../cf_cookie_harvester.dart';
import '../js_unpacker.dart';
import 'base_scraper.dart';

class JableScraper extends BaseScraper {
  @override
  String get siteName => 'JableTV';

  @override
  String get urlRoot => "https://${ApiClient().getActiveHost(siteName)}";

  static const List<Map<String, String>> homepageSections = [
    {'name': '最近更新', 'url_path': '/latest-updates/'},
    {'name': '热门影片', 'url_path': '/hot/'},
    {'name': '新片上架', 'url_path': '/new-release/'},
  ];

  @override
  Future<List<CategoryModel>> fetchCategories() async {
    final List<CategoryModel> cats = [];
    final root = urlRoot;
    
    // 1. Add static default homepage sections
    for (final sec in homepageSections) {
      cats.add(CategoryModel(
        name: sec['name']!,
        url: "$root${sec['url_path']}",
      ));
    }

    try {
      final htmlText = await ApiClient().fetchHtml(siteName, "$root/categories/");
      final document = parse(htmlText);
      final links = document.querySelectorAll('a[href*="/categories/"]');
      
      for (final a in links) {
        final href = a.attributes['href'] ?? '';
        final text = a.text.trim();
        
        if (href.contains('/categories/') && href != "$root/categories/" && text.isNotEmpty) {
          final countReg = RegExp(r'(\d[\d,]*)\s*(?:部影片|videos?)', caseSensitive: false);
          final countMatch = countReg.firstMatch(text);
          int count = 0;
          if (countMatch != null) {
            count = int.parse(countMatch.group(1)!.replaceAll(',', ''));
          }
          
          final cleanName = text.replaceAll(RegExp(r'\d[\d,]*\s*(?:部影片|videos?)', caseSensitive: false), '').trim();
          final slug = href.replaceAll(RegExp(r'/$'), '').split('/').last;
          
          String absoluteUrl = href;
          if (!href.startsWith('http')) {
            absoluteUrl = "$root$href";
          }
          
          cats.add(CategoryModel(
            name: cleanName,
            url: absoluteUrl,
            slug: slug,
            count: count,
          ));
        }
      }
    } catch (_) {}
    return cats;
  }

  @override
  Future<List<VideoCardModel>> fetchPage(String url) async {
    final List<VideoCardModel> videos = [];
    try {
      final htmlText = await ApiClient().fetchHtml(siteName, url);
      final document = parse(htmlText);
      
      final cards = document.querySelectorAll('div.video-img-box');
      for (final card in cards) {
        final detail = card.querySelector('div.detail');
        if (detail == null) continue;
        
        final tagA = detail.querySelector('h6 a');
        if (tagA == null) continue;
        
        final videoUrl = tagA.attributes['href'] ?? '';
        final title = tagA.text.trim();
        
        final img = card.querySelector('img');
        final thumbnail = img?.attributes['data-src'] ?? img?.attributes['src'] ?? '';
        
        final durationSpan = card.querySelector('span.label');
        final duration = durationSpan?.text.trim() ?? '';
        
        videos.add(VideoCardModel(
          url: videoUrl,
          title: title,
          thumbnail: thumbnail,
          duration: duration,
          siteName: siteName,
        ));
      }
    } catch (_) {}
    return videos;
  }

  @override
  Future<List<VideoCardModel>> search(String query) async {
    final root = urlRoot;
    final encodedQuery = Uri.encodeComponent(query);
    final searchUrl = "$root/search/$encodedQuery/";
    return fetchPage(searchUrl);
  }

  @override
  String buildPageUrl(String baseUrl, int page) {
    if (page <= 1) return baseUrl;
    final uri = Uri.parse(baseUrl);
    final params = Map<String, String>.from(uri.queryParameters);
    final pageStr = page < 10 ? "0$page" : "$page";
    params['from'] = pageStr;
    return uri.replace(queryParameters: params).toString();
  }

  @override
  Future<VideoDetailModel> parseVideoDetail(String videoUrl) async {
    String htmlText = "";
    try {
      htmlText = await ApiClient().fetchHtml(siteName, videoUrl, isDetailPage: true);
    } catch (e) {
      htmlText = await CfCookieHarvester.fetchContentViaWebView(videoUrl, siteName: siteName);
    }

    VideoDetailModel? detail = _extractDetailFromHtml(htmlText, videoUrl);
    
    // If not found in initial HTML, fallback to full Headless WebView
    if (detail == null || detail.m3u8Url.isEmpty) {
      final webViewHtml = await CfCookieHarvester.fetchContentViaWebView(videoUrl, siteName: siteName);
      if (webViewHtml.isNotEmpty) {
        detail = _extractDetailFromHtml(webViewHtml, videoUrl);
      }
    }

    if (detail == null || detail.m3u8Url.isEmpty) {
      if (htmlText.contains('eval(function(p,a,c,k,e,d)')) {
        final unpacked = JsUnpacker.unpack(htmlText);
        if (unpacked != null && unpacked.isNotEmpty) {
          detail = _extractDetailFromHtml(unpacked, videoUrl);
        }
      }
    }

    if (detail == null || detail.m3u8Url.isEmpty) {
      throw Exception("[$siteName] 无法解析视频详情与播放源: $videoUrl");
    }

    return detail;
  }

  VideoDetailModel? _extractDetailFromHtml(String htmlText, String videoUrl) {
    if (htmlText.isEmpty) return null;

    final document = parse(htmlText);

    // 1. Extract Title
    String title = "";
    final ogTitle = document.querySelector('meta[property="og:title"], meta[name="og:title"], meta[name="twitter:title"]');
    if (ogTitle != null && (ogTitle.attributes['content']?.isNotEmpty ?? false)) {
      title = ogTitle.attributes['content']!.trim();
    }
    if (title.isEmpty) {
      final header = document.querySelector('div.header h4, .video-header h4, h4, h1');
      if (header != null && header.text.trim().isNotEmpty) {
        title = header.text.trim();
      }
    }
    if (title.isEmpty) {
      final titleTag = document.querySelector('title');
      if (titleTag != null && titleTag.text.trim().isNotEmpty) {
        title = titleTag.text.trim().replaceAll(RegExp(r'\s*-\s*(?:Jable\.TV|fs1\.app|Jable).*$', caseSensitive: false), '').trim();
      }
    }
    if (title.isEmpty) {
      try {
        final uri = Uri.parse(videoUrl);
        final last = uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => "");
        title = last.toUpperCase();
      } catch (_) {}
    }

    // 2. Extract Thumbnail
    String imageUrl = "";
    final ogImage = document.querySelector('meta[property="og:image"], meta[name="og:image"], meta[name="twitter:image"]');
    if (ogImage != null && (ogImage.attributes['content']?.isNotEmpty ?? false)) {
      imageUrl = ogImage.attributes['content']!.trim();
    }
    if (imageUrl.isEmpty) {
      final videoElem = document.querySelector('video[poster]');
      if (videoElem != null && (videoElem.attributes['poster']?.isNotEmpty ?? false)) {
        imageUrl = videoElem.attributes['poster']!.trim();
      }
    }
    if (imageUrl.isEmpty) {
      final img = document.querySelector('#player img, .player img, img.preview');
      if (img != null) {
        imageUrl = img.attributes['data-src'] ?? img.attributes['src'] ?? '';
      }
    }

    // 3. Extract M3U8 URL
    String m3u8Url = "";
    
    // Pattern A: var hlsUrl = 'https://...m3u8';
    final hlsVarMatch = RegExp(r'''(?:var\s+)?(?:hlsUrl|hls_url|videoUrl|video_url)\s*=\s*['"](https?://[^'"]+\.m3u8[^'"]*)['"]''', caseSensitive: false).firstMatch(htmlText);
    if (hlsVarMatch != null) {
      m3u8Url = hlsVarMatch.group(1)!;
    }

    // Pattern B: Any https://*.m3u8 URL
    if (m3u8Url.isEmpty) {
      final m3u8DirectMatch = RegExp(r'''https?://[^\s\x22\x27\<\>\"\'\`\\]+\.m3u8[^\s\x22\x27\<\>\"\'\`\\]*''').firstMatch(htmlText);
      if (m3u8DirectMatch != null) {
        m3u8Url = m3u8DirectMatch.group(0)!;
      }
    }

    // Pattern C: <source src="...m3u8">
    if (m3u8Url.isEmpty) {
      final source = document.querySelector('source[src*=".m3u8"], video[src*=".m3u8"]');
      if (source != null) {
        m3u8Url = source.attributes['src'] ?? '';
      }
    }

    if (m3u8Url.isEmpty) {
      return null;
    }

    final headers = ApiClient().getHeadersForSite(siteName, videoUrl);

    return VideoDetailModel(
      title: title.isNotEmpty ? title : "JableTV Video",
      imageUrl: imageUrl,
      m3u8Url: m3u8Url,
      headers: headers,
      siteName: siteName,
    );
  }
}
