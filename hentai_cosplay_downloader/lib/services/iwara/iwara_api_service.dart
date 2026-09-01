import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../../models/iwara_category.dart';
import '../../models/video_item.dart';
import '../config_service.dart';
import '../jable/cf_cookie_harvester.dart';

class IwaraPageData {
  final List<VideoItem> items;
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final int limit;

  const IwaraPageData({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    required this.limit,
  });
}

class IwaraApiService {
  static const String kBaseUrl = 'https://www.iwara.tv';
  static const String kApiBaseUrl = 'https://api.iwara.tv';
  static const String kImageBaseUrl = 'https://i.iwara.tv';

  static String? _configuredProxy;

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Referer': 'https://www.iwara.tv/',
          'Origin': 'https://www.iwara.tv',
        },
      ),
    );

    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      final effectiveProxy = _configuredProxy ?? ConfigService.loadConfig().customProxy;
      if (effectiveProxy.isNotEmpty) {
        final clean = effectiveProxy.replaceAll(RegExp(r'https?://|socks5?://'), '');
        if (effectiveProxy.startsWith('socks')) {
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

  /// Internal JSON fetcher with multi-tier fallback (curl on desktop, WebView/Dio on mobile)
  static Future<String> _fetchJson(String url) async {
    final effectiveProxy = _configuredProxy ?? ConfigService.loadConfig().customProxy;

    // 1. Desktop tier: curl (Windows, macOS, Linux) with real browser TLS fingerprint
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      try {
        final args = <String>[
          '-s',
          '-L',
          '--compressed',
          if (effectiveProxy.isNotEmpty) ...[
            '-x',
            effectiveProxy.startsWith('http') || effectiveProxy.startsWith('socks')
                ? effectiveProxy
                : 'http://$effectiveProxy',
          ],
          '-A',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          '-H',
          'Referer: https://www.iwara.tv/',
          '-H',
          'Origin: https://www.iwara.tv',
          '-H',
          'Accept: application/json, text/plain, */*',
          '--max-time',
          '15',
          url,
        ];

        final result = await Process.run('curl', args, stdoutEncoding: utf8);
        if (result.exitCode == 0 && (result.stdout as String).isNotEmpty) {
          final stdout = (result.stdout as String).trim();
          if (stdout.startsWith('{') || stdout.startsWith('[')) {
            return stdout;
          }
        }
      } catch (e) {
        debugPrint('[IwaraApiService] Desktop curl failed: $e');
      }
    }

    // 2. Mobile Tier: Chromium WebView Engine
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final res = await CfCookieHarvester.fetchContentViaWebView(url, siteName: 'Iwara');
        if (res.isNotEmpty) {
          String cleanJson = res.trim();
          if (cleanJson.contains('<pre') && cleanJson.contains('</pre>')) {
            final match = RegExp(r'<pre[^>]*>([\s\S]*?)</pre>').firstMatch(cleanJson);
            if (match != null) {
              cleanJson = match.group(1)!.trim();
            }
          }
          if (cleanJson.startsWith('{') || cleanJson.startsWith('[')) {
            return cleanJson;
          }
        }
      } catch (e) {
        debugPrint('[IwaraApiService] Mobile WebView fetch error: $e');
      }
    }

    // 3. Fallback: Dio HTTP Client
    try {
      final dio = _createDio();
      final res = await dio.get(url);
      if (res.data is String) {
        return res.data as String;
      }
      return jsonEncode(res.data);
    } catch (e) {
      debugPrint('[IwaraApiService] Dio get failed: $e');
      rethrow;
    }
  }

  /// Fetch paginated videos from Iwara API
  static Future<IwaraPageData> fetchPageData({
    int page = 1,
    IwaraCategory category = IwaraCategory.latest,
    String? searchKeyword,
    String? selectedTag,
    String? selectedUserId,
    int limit = 32,
  }) async {
    final queryParams = <String, String>{
      'page': (page > 0 ? page - 1 : 0).toString(),
      'limit': limit.toString(),
      'sort': category.sort,
    };

    if (category.rating != null) {
      queryParams['rating'] = category.rating!;
    }

    if (searchKeyword != null && searchKeyword.trim().isNotEmpty) {
      queryParams['query'] = searchKeyword.trim();
    }

    if (selectedTag != null && selectedTag.trim().isNotEmpty) {
      queryParams['tags'] = selectedTag.trim();
    }

    if (selectedUserId != null && selectedUserId.trim().isNotEmpty) {
      queryParams['user'] = selectedUserId.trim();
    }

    final uri = Uri.https('api.iwara.tv', '/videos', queryParams);
    debugPrint('[IwaraApiService] Fetching videos: $uri');

    final jsonStr = await _fetchJson(uri.toString());
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    final count = data['count'] as int? ?? 0;
    final results = data['results'] as List? ?? [];
    final totalPages = (count / limit).ceil().clamp(1, 9999);

    final List<VideoItem> items = [];
    for (final raw in results) {
      if (raw is! Map<String, dynamic>) continue;
      final item = _parseVideoJson(raw);
      if (item != null) {
        items.add(item);
      }
    }

    return IwaraPageData(
      items: items,
      currentPage: page,
      totalPages: totalPages,
      totalCount: count,
      limit: limit,
    );
  }

  /// Parse a video JSON item into a VideoItem model
  static VideoItem? _parseVideoJson(Map<String, dynamic> raw) {
    final id = raw['id']?.toString() ?? '';
    if (id.isEmpty) return null;

    final title = (raw['title']?.toString() ?? 'Iwara Video').trim();
    final slug = 'iwara_$id';
    final detailUrl = 'https://www.iwara.tv/video/$id';

    // Generate cover thumbnail URL
    String? coverUrl;
    final customThumbnail = raw['customThumbnail'] as Map<String, dynamic>?;
    final file = raw['file'] as Map<String, dynamic>?;

    if (customThumbnail != null && customThumbnail['id'] != null && customThumbnail['name'] != null) {
      coverUrl = '$kImageBaseUrl/image/thumbnail/${customThumbnail['id']}/${customThumbnail['name']}';
    } else if (file != null && file['id'] != null) {
      final thumbIdx = (raw['thumbnail'] as num?)?.toInt() ?? 0;
      final thumbPad = thumbIdx.toString().padLeft(2, '0');
      coverUrl = '$kImageBaseUrl/image/thumbnail/${file['id']}/thumbnail-$thumbPad.jpg';
    }

    // Author
    final user = raw['user'] as Map<String, dynamic>?;
    final author = user?['name']?.toString() ?? user?['username']?.toString() ?? 'Iwara';

    // Date
    final dateStr = raw['createdAt']?.toString() ?? '';
    String date = '';
    if (dateStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(dateStr).toLocal();
        date = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {
        date = dateStr.split('T').first;
      }
    }

    // Tags
    final rawTags = raw['tags'] as List? ?? [];
    final List<String> tags = [];
    for (final t in rawTags) {
      if (t is Map && t['id'] != null) {
        tags.add(t['id'].toString());
      }
    }

    // Duration formatting
    final durationSec = (file?['duration'] as num?)?.toInt() ?? 0;
    final minutes = durationSec ~/ 60;
    final seconds = durationSec % 60;
    final durationFormatted = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return VideoItem(
      title: title,
      slug: slug,
      detailUrl: detailUrl,
      coverUrl: coverUrl,
      date: date,
      author: author,
      tags: tags,
      rawData: {
        'id': id,
        'numViews': raw['numViews'] ?? 0,
        'numLikes': raw['numLikes'] ?? 0,
        'numComments': raw['numComments'] ?? 0,
        'duration': durationSec,
        'durationFormatted': durationFormatted,
        'rating': raw['rating'] ?? 'general',
        'user': user,
        'file': file,
        'body': raw['body'],
        'source': 'iwara',
      },
    );
  }

  /// Resolve full video details and streaming quality links
  static Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    String id = item.rawData['id']?.toString() ?? '';
    if (id.isEmpty) {
      final uri = Uri.tryParse(item.detailUrl);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        id = uri.pathSegments.last;
      }
    }
    if (id.isEmpty) return item;

    final detailApiUrl = '$kApiBaseUrl/video/$id';
    debugPrint('[IwaraApiService] Resolving detail: $detailApiUrl');

    final jsonStr = await _fetchJson(detailApiUrl);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    final fileUrl = data['fileUrl']?.toString();
    final Map<String, dynamic> qualities = {};
    String? bestStreamUrl;

    if (fileUrl != null && fileUrl.isNotEmpty) {
      try {
        final streamJsonStr = await _fetchJson(fileUrl);
        final streamList = jsonDecode(streamJsonStr) as List? ?? [];
        for (final s in streamList) {
          if (s is! Map<String, dynamic>) continue;
          final qName = s['name']?.toString() ?? 'Source';
          final src = s['src'] as Map<String, dynamic>?;
          final viewUrl = src?['view']?.toString() ?? src?['download']?.toString();
          if (viewUrl != null && viewUrl.isNotEmpty) {
            final fullUrl = viewUrl.startsWith('//') ? 'https:$viewUrl' : viewUrl;
            qualities[qName] = fullUrl;
          }
        }
      } catch (e) {
        debugPrint('[IwaraApiService] Failed to resolve fileUrl streams: $e');
      }
    }

    // Select highest quality stream
    for (final q in ['Source', '1080', '1080p', '720', '720p', '540', '360', 'preview']) {
      if (qualities.containsKey(q)) {
        bestStreamUrl = qualities[q]?.toString();
        break;
      }
    }
    bestStreamUrl ??= qualities.values.isNotEmpty ? qualities.values.first.toString() : null;

    final updatedRawData = Map<String, dynamic>.from(item.rawData);
    updatedRawData['qualities'] = qualities;
    if (data['body'] != null) {
      updatedRawData['body'] = data['body'];
    }

    return VideoItem(
      title: (data['title']?.toString() ?? item.title).trim(),
      slug: item.slug,
      detailUrl: item.detailUrl,
      coverUrl: item.coverUrl,
      videoUrl: bestStreamUrl ?? item.videoUrl,
      date: item.date,
      author: item.author,
      tags: item.tags,
      rawData: updatedRawData,
    );
  }

  /// Backward-compatible wrapper
  static Future<VideoItem> fetchVideoDetail(VideoItem item) => resolveVideoDetail(item);
}
