import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../../models/album_item.dart';

class CoomerCreator {
  final String id;
  final String name;
  final String service; // 'onlyfans', 'fansly', 'patreon', 'candfans', etc.
  final int count;
  final int favorited;
  final String indexed;
  final String updated;

  String get avatarUrl => CoomerApiService.resolveAvatarUrl(service, id);

  CoomerCreator({
    required this.id,
    required this.name,
    required this.service,
    required this.count,
    this.favorited = 0,
    required this.indexed,
    required this.updated,
  });

  factory CoomerCreator.fromJson(Map<String, dynamic> json) {
    return CoomerCreator(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '未知创作者',
      service: json['service']?.toString() ?? 'onlyfans',
      count: json['count'] is int ? json['count'] : (int.tryParse(json['count']?.toString() ?? '0') ?? 0),
      favorited: json['favorited'] is int ? json['favorited'] : (int.tryParse(json['favorited']?.toString() ?? '0') ?? 0),
      indexed: json['indexed']?.toString() ?? '',
      updated: json['updated']?.toString() ?? '',
    );
  }
}

class CoomerApiResponse {
  final List<AlbumItem> items;
  final int offset;
  final int limit;
  final bool hasMore;
  final int total;

  CoomerApiResponse({
    required this.items,
    required this.offset,
    required this.limit,
    required this.hasMore,
    required this.total,
  });
}

class CoomerApiService {
  static const List<String> kDomains = [
    'https://coomer.st',
  ];

  static String kBaseUrl = kDomains.first;
  static String kImgBaseUrl = 'https://img.coomer.st';
  static String kMediaBaseUrl = 'https://coomer.st';

  static String? _configuredProxy;
  static Dio _dio = _createDio();

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
    _dio = _createDio();
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: kBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Referer': '$kBaseUrl/',
          'Origin': kBaseUrl,
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
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

  /// Resolve full media URL
  static String resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    var cleanPath = path.startsWith('/') ? path : '/$path';
    if (!cleanPath.startsWith('/data/')) {
      cleanPath = '/data$cleanPath';
    }
    if (cleanPath.endsWith('.mp4') || cleanPath.endsWith('.m4v') || cleanPath.endsWith('.mov')) {
      return 'https://c1.coomer.st$cleanPath';
    }
    return '$kImgBaseUrl/thumbnail$cleanPath';
  }

  /// Resolve thumbnail URL
  static String resolveThumbnailUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    var cleanPath = path.startsWith('/') ? path : '/$path';
    if (!cleanPath.startsWith('/data/')) {
      cleanPath = '/data$cleanPath';
    }
    return '$kImgBaseUrl/thumbnail$cleanPath';
  }

  /// Resolve avatar URL for creator
  static String resolveAvatarUrl(String service, String id) {
    return '$kImgBaseUrl/icons/$service/$id';
  }

  /// Fetch recent posts across platforms with pagination and search
  static Future<CoomerApiResponse?> fetchRecentPosts({
    int offset = 0,
    int limit = 40,
    String? service,
    String? query,
  }) async {
    final queryParams = <String, dynamic>{
      'o': offset,
    };
    if (query != null && query.trim().isNotEmpty) {
      queryParams['q'] = query.trim();
    }

    final targetService = (service != null && service.isNotEmpty && service != 'all') ? service.toLowerCase() : null;

    for (final domain in kDomains) {
      try {
        kBaseUrl = domain;
        _dio.options.baseUrl = domain;
        debugPrint('[CoomerApiService] Fetching posts from $domain: /api/v1/posts $queryParams (filter: $targetService)');
        final response = await _dio.get(
          '/api/v1/posts',
          queryParameters: queryParams,
        );

        if (response.statusCode == 200 && response.data != null) {
          dynamic rawData = response.data;
          if (rawData is String) {
            try {
              rawData = jsonDecode(rawData);
            } catch (_) {}
          }
          final List<dynamic> list = rawData is List
              ? rawData
              : (rawData is Map ? (rawData['posts'] as List? ?? rawData['results'] as List? ?? []) : []);
          final List<AlbumItem> items = [];

          for (final json in list) {
            if (json is Map<String, dynamic>) {
              final postService = json['service']?.toString().toLowerCase() ?? '';
              if (targetService != null && postService != targetService) {
                continue;
              }
              final item = _parsePostToAlbumItem(json);
              if (item != null) {
                items.add(item);
              }
            }
          }

          return CoomerApiResponse(
            items: items,
            offset: offset,
            limit: limit,
            hasMore: list.length >= 20,
            total: offset + items.length + (list.length >= 20 ? limit : 0),
          );
        }
      } catch (e) {
        debugPrint('[CoomerApiService] Error fetching posts from $domain: $e');
      }
    }
    return null;
  }

  /// Fetch posts for a specific creator
  static Future<CoomerApiResponse?> fetchCreatorPosts({
    required String service,
    required String creatorId,
    int offset = 0,
    int limit = 40,
  }) async {
    final path = '/api/v1/$service/user/$creatorId/posts';
    final queryParams = {'o': offset};

    for (final domain in kDomains) {
      try {
        kBaseUrl = domain;
        _dio.options.baseUrl = domain;
        debugPrint('[CoomerApiService] Fetching creator posts from $domain: $path $queryParams');
        final response = await _dio.get(
          path,
          queryParameters: queryParams,
        );

        if (response.statusCode == 200 && response.data != null) {
          final List<dynamic> list = response.data is List
              ? response.data as List
              : (response.data['posts'] as List? ?? response.data['results'] as List? ?? []);
          final List<AlbumItem> items = [];

          for (final json in list) {
            if (json is Map<String, dynamic>) {
              final item = _parsePostToAlbumItem(json);
              if (item != null) {
                items.add(item);
              }
            }
          }

          return CoomerApiResponse(
            items: items,
            offset: offset,
            limit: limit,
            hasMore: items.length >= limit,
            total: offset + items.length + (items.length >= limit ? limit : 0),
          );
        }
      } catch (e) {
        debugPrint('[CoomerApiService] Error fetching creator posts from $domain: $e');
      }
    }
    return null;
  }

  /// Fetch creators list
  static Future<List<CoomerCreator>> fetchCreators({
    String? service,
    String? query,
  }) async {
    for (final domain in kDomains) {
      try {
        kBaseUrl = domain;
        _dio.options.baseUrl = domain;
        debugPrint('[CoomerApiService] Fetching creators from $domain');
        final response = await _dio.get('/api/v1/creators');

        if (response.statusCode == 200 && response.data != null) {
          final List<dynamic> list = response.data is List
              ? response.data as List
              : (response.data['creators'] as List? ?? response.data['results'] as List? ?? []);
          final List<CoomerCreator> creators = [];

          for (final json in list) {
            if (json is Map<String, dynamic>) {
              final creator = CoomerCreator.fromJson(json);

              if (service != null && service.isNotEmpty && service != 'all') {
                if (creator.service.toLowerCase() != service.toLowerCase()) {
                  continue;
                }
              }

              if (query != null && query.trim().isNotEmpty) {
                if (!creator.name.toLowerCase().contains(query.trim().toLowerCase())) {
                  continue;
                }
              }

              creators.add(creator);
            }
          }

          return creators;
        }
      } catch (e) {
        debugPrint('[CoomerApiService] Error fetching creators from $domain: $e');
      }
    }
    return [];
  }

  /// Fetch post detail with all attachments
  static Future<AlbumItem?> fetchPostDetail(dynamic itemOrService, [String? creatorId, String? postId]) async {
    String service;
    String creator;
    String id;

    if (itemOrService is AlbumItem) {
      final parts = itemOrService.slug.split('/');
      if (parts.length >= 3) {
        service = parts[0];
        creator = parts[1];
        id = parts[2];
      } else {
        return itemOrService;
      }
    } else {
      service = itemOrService.toString();
      creator = creatorId ?? '';
      id = postId ?? '';
    }

    final path = '/api/v1/$service/user/$creator/post/$id';

    for (final domain in kDomains) {
      try {
        kBaseUrl = domain;
        _dio.options.baseUrl = domain;
        debugPrint('[CoomerApiService] Fetching post detail from $domain: $path');
        final response = await _dio.get(path);

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : (response.data is List && (response.data as List).isNotEmpty
                  ? (response.data as List).first as Map<String, dynamic>
                  : null);

          if (data != null) {
            return _parsePostToAlbumItem(data);
          }
        }
      } catch (e) {
        debugPrint('[CoomerApiService] Error fetching post detail from $domain: $e');
      }
    }
    return null;
  }

  /// Parse a post JSON object into our uniform AlbumItem
  static AlbumItem? _parsePostToAlbumItem(Map<String, dynamic> json) {
    try {
      final id = json['id']?.toString() ?? '';
      final user = json['user']?.toString() ?? '';
      final service = json['service']?.toString() ?? 'onlyfans';
      var title = json['title']?.toString() ?? '';
      final content = json['content']?.toString() ?? json['substring']?.toString() ?? '';
      final published = json['published']?.toString() ?? json['added']?.toString() ?? '';

      if (title.isEmpty) {
        if (content.isNotEmpty) {
          final cleanContent = content.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
          title = cleanContent.length > 50 ? '${cleanContent.substring(0, 50)}...' : cleanContent;
        }
        if (title.isEmpty) {
          title = 'Post #$id';
        }
      }

      final List<String> imageUrls = [];
      String? coverUrl;

      // Check main file
      if (json['file'] is Map<String, dynamic>) {
        final fileMap = json['file'] as Map<String, dynamic>;
        final path = fileMap['path']?.toString() ?? '';
        if (path.isNotEmpty) {
          final fullUrl = resolveMediaUrl(path);
          imageUrls.add(fullUrl);
          coverUrl = resolveThumbnailUrl(path);
        }
      }

      // Check attachments
      if (json['attachments'] is List) {
        for (final att in json['attachments']) {
          if (att is Map<String, dynamic>) {
            final path = att['path']?.toString() ?? '';
            if (path.isNotEmpty) {
              final fullUrl = resolveMediaUrl(path);
              if (!imageUrls.contains(fullUrl)) {
                imageUrls.add(fullUrl);
              }
              coverUrl ??= resolveThumbnailUrl(path);
            }
          }
        }
      }

      if (imageUrls.isEmpty) {
        return null;
      }

      coverUrl ??= imageUrls.first;

      return AlbumItem(
        title: title,
        slug: '$service/$user/$id',
        detailUrl: '$kBaseUrl/$service/user/$user/post/$id',
        coverUrl: coverUrl,
        date: published.isNotEmpty ? published.split('T').first : '今日',
        author: user.isNotEmpty ? user : 'Coomer',
        tags: [service.toUpperCase()],
        sourceType: MediaSourceType.coomer,
        imageUrls: imageUrls,
        previewUrls: imageUrls.take(6).toList(),
        isDetailLoaded: true,
      );
    } catch (e) {
      debugPrint('[CoomerApiService] Error parsing post: $e');
      return null;
    }
  }
}
