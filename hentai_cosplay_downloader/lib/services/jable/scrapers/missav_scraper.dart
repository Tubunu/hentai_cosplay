import 'package:html/parser.dart' show parse;
import '../../../models/jable_video_item.dart';
import '../api_client.dart';
import '../cf_cookie_harvester.dart';
import '../js_unpacker.dart';
import 'base_scraper.dart';

class MissAVScraper extends BaseScraper {
  @override
  String get siteName => 'MissAV';

  @override
  String get urlRoot {
    final active = ApiClient().getActiveHost(siteName);
    return "https://$active";
  }

  static const List<Map<String, String>> categories = [
    {'name': '今日热门', 'url_path': '/dm298/today-hot'},
    {'name': '本周热门', 'url_path': '/dm170/weekly-hot'},
    {'name': '本月热门', 'url_path': '/dm270/monthly-hot'},
    {'name': '中文字幕', 'url_path': '/dm278/chinese-subtitle'},
    {'name': '最近更新', 'url_path': '/dm539/new'},
    {'name': '新作上市', 'url_path': '/dm634/release'},
    {'name': '无码流出', 'url_path': '/dm817/uncensored-leak'},
    {'name': 'SIRO', 'url_path': '/dm36/siro'},
    {'name': 'FC2', 'url_path': '/dm541/fc2'},
    {'name': '麻豆传媒', 'url_path': '/dm63/madou'},
    {'name': '东京热', 'url_path': '/dm42/tokyohot'},
    {'name': '一本道', 'url_path': '/dm4854130/1pondo'},
  ];

  @override
  Future<List<CategoryModel>> fetchCategories() async {
    final List<CategoryModel> cats = [];
    final root = urlRoot;
    
    for (final cat in categories) {
      cats.add(CategoryModel(
        name: cat['name']!,
        url: "$root${cat['url_path']}",
      ));
    }
    return cats;
  }

  @override
  Future<List<VideoCardModel>> fetchPage(String url) async {
    final List<VideoCardModel> videos = [];
    try {
      final htmlText = await ApiClient().fetchHtml(siteName, url);
      final document = parse(htmlText);
      
      final cards = document.querySelectorAll('div.thumbnail, div.group, article.video-item, div[class*="grid"] > div');
      for (final card in cards) {
        final link = card.querySelector('a[href]');
        if (link == null) continue;
        
        var videoUrl = link.attributes['href'] ?? '';
        if (videoUrl.contains('/search/')) continue;
        
        if (!videoUrl.startsWith('http')) {
          videoUrl = "$urlRoot$videoUrl";
        }
        
        final uri = Uri.parse(videoUrl);
        final lastSeg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
        if (!RegExp(r'\d').hasMatch(lastSeg)) {
          continue;
        }
        
        final img = card.querySelector('img');
        if (img == null) continue;
        final thumbnail = img.attributes['data-src'] ?? img.attributes['src'] ?? '';
        var title = img.attributes['alt']?.trim() ?? '';
        
        final titleA = card.querySelector('div.my-2 a, div.truncate a');
        if (titleA != null && titleA.text.trim().isNotEmpty) {
          title = titleA.text.trim();
        }
        
        final durationSpan = card.querySelector('span.absolute.bottom-1.right-1');
        final duration = durationSpan?.text.trim() ?? '';
        
        if (!videos.any((v) => v.url == videoUrl)) {
          videos.add(VideoCardModel(
            url: videoUrl,
            title: title,
            thumbnail: thumbnail,
            duration: duration,
            siteName: siteName,
          ));
        }
      }
    } catch (_) {}
    return videos;
  }

  @override
  Future<List<VideoCardModel>> search(String query) async {
    final root = urlRoot;
    final encodedQuery = Uri.encodeComponent(query);
    final searchUrl = "$root/search/$encodedQuery";
    return fetchPage(searchUrl);
  }

  @override
  String buildPageUrl(String baseUrl, int page) {
    if (page <= 1) return baseUrl;
    final uri = Uri.parse(baseUrl);
    final params = Map<String, String>.from(uri.queryParameters);
    params['page'] = page.toString();
    return uri.replace(queryParameters: params).toString();
  }

  @override
  Future<VideoDetailModel> parseVideoDetail(String videoUrl) async {
    final htmlText = await ApiClient().fetchHtml(siteName, videoUrl, isDetailPage: true);
    final document = parse(htmlText);
    
    // 1. Get title
    var title = "";
    final ogTitle = document.querySelector('meta[property="og:title"]');
    if (ogTitle != null) {
      title = ogTitle.attributes['content'] ?? "";
    } else {
      final h1 = document.querySelector('h1');
      title = h1?.text.trim() ?? document.querySelector('title')?.text.trim() ?? "";
    }
    
    // 2. Get thumbnail
    var thumbnail = "";
    final ogImage = document.querySelector('meta[property="og:image"]');
    if (ogImage != null) {
      thumbnail = ogImage.attributes['content'] ?? "";
    }
    
    // 3. Extract M3U8 from packed eval block or scripts
    var m3u8Url = "";
    final scripts = document.querySelectorAll('script');
    
    for (final script in scripts) {
      final scriptText = script.innerHtml.isNotEmpty ? script.innerHtml : script.text;
      if (scriptText.contains('eval(function') || scriptText.contains('m3u8')) {
        final unpacked = JsUnpacker.unpack(scriptText);
        final textsToInspect = [if (unpacked != null) unpacked, scriptText];
        
        for (final text in textsToInspect) {
          final mainMatch = RegExp(r"source\s*=\s*[\\'\x22]*(https?://[^'\\;\s\x22\n\r]+\.m3u8)").firstMatch(text);
          if (mainMatch != null) {
            m3u8Url = mainMatch.group(1)!;
            break;
          }
          final uuidMatch = RegExp(r"(https?://[a-zA-Z0-9.\-_]+/[0-9a-fA-F\-]{16,}/playlist\.m3u8)").firstMatch(text);
          if (uuidMatch != null) {
            m3u8Url = uuidMatch.group(1)!;
            break;
          }
          final fallbackMatch = RegExp(r"(https?://[^\x27\x22\\;\s\n\r<>]+\.m3u8[^\x27\x22\\;\s\n\r<>]*)").firstMatch(text);
          if (fallbackMatch != null) {
            m3u8Url = fallbackMatch.group(1)!;
            break;
          }
        }
        if (m3u8Url.isNotEmpty) break;
      }
    }
    
    if (m3u8Url.isEmpty) {
      final directMatch = RegExp(r"(https?://[^\x27\x22\\;\s\n\r<>]+\.m3u8[^\x27\x22\\;\s\n\r<>]*)").firstMatch(htmlText);
      if (directMatch != null) {
        m3u8Url = directMatch.group(1)!;
      }
    }

    if (m3u8Url.isEmpty) {
      try {
        final webViewHtml = await CfCookieHarvester.fetchContentViaWebView(videoUrl, siteName: siteName);
        if (webViewHtml.isNotEmpty) {
          final doc2 = parse(webViewHtml);
          final scripts2 = doc2.querySelectorAll('script');
          for (final script in scripts2) {
            final scriptText = script.innerHtml.isNotEmpty ? script.innerHtml : script.text;
            if (scriptText.contains('eval(function') || scriptText.contains('.m3u8')) {
              final unpacked = JsUnpacker.unpack(scriptText);
              if (unpacked != null) {
                final match = RegExp(r"source\s*=\s*[\\'\x22]*(https?://[^'\\;\s\x22]+\.m3u8)").firstMatch(unpacked);
                if (match != null) {
                  m3u8Url = match.group(1)!;
                  break;
                }
                final match2 = RegExp(r"(https?://[^\x27\x22\\;\s\n\r]+\.m3u8)").firstMatch(unpacked);
                if (match2 != null) {
                  m3u8Url = match2.group(1)!;
                  break;
                }
              }
            }
          }
          if (m3u8Url.isEmpty) {
            final directMatch2 = RegExp(r"(https?://[^\x27\x22\\;\s\n\r<>]+\.m3u8[^\x27\x22\\;\s\n\r<>]*)").firstMatch(webViewHtml);
            if (directMatch2 != null) {
              m3u8Url = directMatch2.group(1)!;
            }
          }
        }
      } catch (_) {}
    }
    
    if (m3u8Url.isEmpty) {
      throw Exception("[$siteName] 未能解析到有效 M3U8 流地址: $videoUrl");
    }
    
    final videoUri = Uri.parse(videoUrl);
    final pageHost = videoUri.host.isNotEmpty ? videoUri.host : ApiClient().getActiveHost(siteName);
    final headers = ApiClient().getHeadersForSite(siteName, "https://$pageHost/");
    headers['Referer'] = "https://$pageHost/";
    headers['Origin'] = "https://$pageHost";

    return VideoDetailModel(
      title: title,
      imageUrl: thumbnail,
      m3u8Url: m3u8Url,
      headers: headers,
      siteName: siteName,
    );
  }
}
