import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import '../../models/album_item.dart';
import '../../models/video_item.dart';
import '../../models/ygjgl/ygjgl_post_item.dart';
import '../../models/ygjgl/ygjgl_vod_item.dart';
import '../app_logger.dart';
import '../network_client.dart';

class YgjglApiService {
  static const String kBaseUrl = 'https://ygjgl.one';
  static Dio _dio = _createDio();

  static Dio _createDio() {
    return NetworkClient.createDio(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        'Referer': '$kBaseUrl/',
      },
    );
  }

  static void resetClient() {
    try {
      _dio.close(force: true);
    } catch (_) {}
    _dio = _createDio();
  }

  // ==========================================
  // 1. 点播 (VOD) 接口
  // ==========================================

  /// 获取点播列表
  static Future<Map<String, dynamic>> fetchVodList({
    int page = 1,
    int size = 40,
    String? q,
    String? sort = 'pub_desc',
    String? tag,
    bool freeOnly = false,
    String? year,
    String? month,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'size': size,
        'sort': sort ?? 'pub_desc',
      };

      if (q != null && q.trim().isNotEmpty) {
        queryParams['q'] = q.trim();
        if (freeOnly) queryParams['free'] = '1';
      } else {
        queryParams['free'] = freeOnly ? '1' : '0';
      }

      if (tag != null && tag.isNotEmpty && tag != '全部' && tag != '免费区') {
        queryParams['tag'] = tag;
      }
      if (year != null && year.isNotEmpty) {
        queryParams['y'] = year;
      }
      if (month != null && month.isNotEmpty) {
        queryParams['m'] = month.padLeft(2, '0');
      }

      final response = await _dio.get('/api/list', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data : jsonDecode(response.data.toString());
        final total = (data['total'] is num) ? (data['total'] as num).toInt() : 0;
        final rawItems = data['items'] as List? ?? [];
        final items = rawItems
            .map((item) => YgjglVodItem.fromJson(item as Map<String, dynamic>))
            .toList();

        return {
          'items': items,
          'total': total,
        };
      }
    } catch (e, st) {
      AppLogger.e('YgjglApiService', 'fetchVodList 失败: $e', e, st);
    }
    return {'items': <YgjglVodItem>[], 'total': 0};
  }

  /// 获取点播详情
  static Future<YgjglVodItem?> fetchVodDetail(String id) async {
    try {
      final response = await _dio.get('/api/item', queryParameters: {'id': id});
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data : jsonDecode(response.data.toString());
        if (data['id'] != null) {
          final vod = YgjglVodItem.fromJson(data as Map<String, dynamic>);
          // Try resolving stream host as well
          final mp4 = await resolveVodStream(id);
          return vod.copyWith(mp4Url: mp4);
        }
      }
    } catch (e, st) {
      AppLogger.e('YgjglApiService', 'fetchVodDetail 失败 (id=$id): $e', e, st);
    }
    return null;
  }

  /// 获取点播直链 MP4 或备用播放地址
  static Future<String?> resolveVodStream(String id) async {
    try {
      final response = await _dio.get(
        '/api/srchosts',
        queryParameters: {'vid': id},
        options: Options(headers: {'Cache-Control': 'no-store'}),
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data : jsonDecode(response.data.toString());
        if (data['mp4'] != null && data['mp4'].toString().isNotEmpty) {
          return data['mp4'].toString();
        }
      }
    } catch (e) {
      AppLogger.w('YgjglApiService', 'resolveVodStream 获取直链失败 (vid=$id): $e');
    }
    return null;
  }

  /// 获取地区分类
  static Future<List<Map<String, dynamic>>> fetchRegions() async {
    try {
      final response = await _dio.get('/api/regions');
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data is List ? response.data : jsonDecode(response.data.toString());
        if (raw is List) {
          return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      AppLogger.w('YgjglApiService', 'fetchRegions 失败: $e');
    }
    return [
      {'tag': '国产', 'count': 0},
      {'tag': '日本', 'count': 0},
      {'tag': '免费区', 'count': 0, 'href': '/free'},
    ];
  }

  /// 获取年份和时间 Facets
  static Future<Map<String, dynamic>> fetchFacets() async {
    try {
      final response = await _dio.get('/api/facets');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data : jsonDecode(response.data.toString());
        return Map<String, dynamic>.from(data as Map);
      }
    } catch (e) {
      AppLogger.w('YgjglApiService', 'fetchFacets 失败: $e');
    }
    return {'years': <String>['2026', '2025', '2024', '2023'], 'months': []};
  }

  // ==========================================
  // 2. 写真 (Image) & 电台 (Audio) 接口
  // ==========================================

  /// 获取图集 / 电台列表
  static Future<Map<String, dynamic>> fetchPostList({
    required String kind, // 'image' | 'audio'
    int page = 1,
    int size = 24,
    String? q,
    String? tag,
    int? series,
    String? range = 'all',
    String? sort = 'new',
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'kind': kind,
        'page': page,
        'size': size,
        'range': range ?? 'all',
        'sort': sort ?? 'new',
        't': DateTime.now().millisecondsSinceEpoch,
      };

      if (q != null && q.trim().isNotEmpty) {
        queryParams['q'] = q.trim();
      }
      if (tag != null && tag.isNotEmpty) {
        queryParams['tag'] = tag;
      }
      if (series != null && series > 0) {
        queryParams['series'] = series;
      }

      final response = await _dio.get('/api/posts', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data : jsonDecode(response.data.toString());
        final total = (data['total'] is num) ? (data['total'] as num).toInt() : 0;
        final rawItems = data['items'] as List? ?? [];
        final items = rawItems
            .map((item) => YgjglPostItem.fromJson(item as Map<String, dynamic>, defaultKind: kind))
            .toList();

        return {
          'items': items,
          'total': total,
        };
      }
    } catch (e, st) {
      AppLogger.e('YgjglApiService', 'fetchPostList 失败 (kind=$kind): $e', e, st);
    }
    return {'items': <YgjglPostItem>[], 'total': 0};
  }

  /// 获取图集 / 电台详情
  static Future<YgjglPostItem?> fetchPostDetail(String id, {String defaultKind = 'image'}) async {
    try {
      final response = await _dio.get('/api/post', queryParameters: {'id': id});
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data : jsonDecode(response.data.toString());
        final postMap = data['post'] as Map<String, dynamic>?;
        if (postMap != null) {
          return YgjglPostItem.fromJson(postMap, defaultKind: defaultKind);
        }
      }
    } catch (e, st) {
      AppLogger.e('YgjglApiService', 'fetchPostDetail 失败 (id=$id): $e', e, st);
    }
    return null;
  }

  /// 获取标签列表
  static Future<List<Map<String, dynamic>>> fetchPostTags({required String kind}) async {
    try {
      final response = await _dio.get(
        '/api/posts/tags',
        queryParameters: {
          'kind': kind,
          't': DateTime.now().millisecondsSinceEpoch,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data : jsonDecode(response.data.toString());
        final items = data['items'] as List? ?? [];
        return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      AppLogger.w('YgjglApiService', 'fetchPostTags 失败 (kind=$kind): $e');
    }
    return [];
  }

  /// 获取合集系列列表
  static Future<List<Map<String, dynamic>>> fetchPostSeries({required String kind}) async {
    try {
      final response = await _dio.get(
        '/api/series',
        queryParameters: {
          'kind': kind,
          't': DateTime.now().millisecondsSinceEpoch,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data : jsonDecode(response.data.toString());
        final items = data['items'] as List? ?? [];
        return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      AppLogger.w('YgjglApiService', 'fetchPostSeries 失败: $e');
    }
    return [];
  }

  /// 获取排行榜
  static Future<List<YgjglPostItem>> fetchPostRank({
    required String kind,
    String window = 'week',
    int limit = 30,
  }) async {
    try {
      final response = await _dio.get(
        '/api/posts/rank',
        queryParameters: {
          'kind': kind,
          'window': window,
          'limit': limit,
          't': DateTime.now().millisecondsSinceEpoch,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data : jsonDecode(response.data.toString());
        final items = data['items'] as List? ?? [];
        return items
            .map((e) => YgjglPostItem.fromJson(e as Map<String, dynamic>, defaultKind: kind))
            .toList();
      }
    } catch (e) {
      AppLogger.w('YgjglApiService', 'fetchPostRank 失败 (kind=$kind): $e');
    }
    return [];
  }

  /// 随机获取一个 post ID
  static Future<String?> fetchRandomPostId({required String kind}) async {
    try {
      final response = await _dio.get(
        '/api/posts/random',
        queryParameters: {
          'kind': kind,
          't': DateTime.now().millisecondsSinceEpoch,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data : jsonDecode(response.data.toString());
        if (data['ok'] == true && data['id'] != null) {
          return data['id'].toString();
        }
      }
    } catch (e) {
      AppLogger.w('YgjglApiService', 'fetchRandomPostId 失败: $e');
    }
    return null;
  }

  /// 随机获取一个 VOD 视频
  static Future<YgjglVodItem?> fetchRandomVodItem({int totalCount = 11000}) async {
    try {
      final totalPages = max(1, (totalCount / 40).ceil());
      final randomPage = Random().nextInt(min(totalPages, 50)) + 1;
      final res = await fetchVodList(page: randomPage, size: 40);
      final list = res['items'] as List<YgjglVodItem>? ?? [];
      if (list.isNotEmpty) {
        final chosen = list[Random().nextInt(list.length)];
        return await fetchVodDetail(chosen.id) ?? chosen;
      }
    } catch (e) {
      AppLogger.w('YgjglApiService', 'fetchRandomVodItem 失败: $e');
    }
    return null;
  }

  // ==========================================
  // 3. 通用接入层方法 (用于 DownloadEngine / HistoryRouter)
  // ==========================================

  /// 为 DownloadEngine 解析图集详情 (AlbumItem)
  static Future<AlbumItem?> fetchAlbumDetail(AlbumItem item) async {
    final post = await fetchPostDetail(item.slug, defaultKind: 'image');
    if (post != null) {
      return post.toAlbumItem();
    }
    return null;
  }

  /// 为 DownloadEngine 解析视频直链 (VideoItem)
  static Future<VideoItem?> resolveVideoDetail(VideoItem video) async {
    // 检查是否已有直链
    if (video.videoUrl != null && video.videoUrl!.isNotEmpty && video.videoUrl!.contains('.mp4')) {
      return video;
    }

    final vid = video.slug;
    final mp4 = await resolveVodStream(vid);
    if (mp4 != null && mp4.isNotEmpty) {
      return video.copyWith(
        videoUrl: mp4,
        isDetailLoaded: true,
      );
    }
    return video;
  }
}
