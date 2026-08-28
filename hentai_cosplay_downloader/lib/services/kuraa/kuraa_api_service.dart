import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/album_item.dart';

class KuraaStorageLocation {
  final String id;
  final String name;
  final String anonymousAccess;
  final bool hasPassword;

  const KuraaStorageLocation({
    required this.id,
    required this.name,
    required this.anonymousAccess,
    required this.hasPassword,
  });

  factory KuraaStorageLocation.fromJson(Map<String, dynamic> json) {
    return KuraaStorageLocation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      anonymousAccess: json['anonymousAccess']?.toString() ?? 'read',
      hasPassword: json['hasPassword'] == true,
    );
  }
}

class KuraaFileItem {
  final String id;
  final String storageLocationId;
  final String? parentId;
  final String name;
  final String type; // 'folder' or 'file'
  final int size;
  final String? mimeType;
  final String? extension;
  final String? contentToken;
  final String createdAt;
  final String updatedAt;
  final bool hasThumbnail;
  final List<String> tags;

  const KuraaFileItem({
    required this.id,
    required this.storageLocationId,
    this.parentId,
    required this.name,
    required this.type,
    required this.size,
    this.mimeType,
    this.extension,
    this.contentToken,
    required this.createdAt,
    required this.updatedAt,
    required this.hasThumbnail,
    required this.tags,
  });

  bool get isFolder => type == 'folder';
  bool get isImage =>
      type == 'file' &&
      ((mimeType?.startsWith('image/') ?? false) ||
          ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp']
              .contains((extension ?? '').toLowerCase()));
  bool get isVideo =>
      type == 'file' &&
      ((mimeType?.startsWith('video/') ?? false) ||
          ['mp4', 'mov', 'mkv', 'webm', 'm4v', 'flv', 'avi']
              .contains((extension ?? '').toLowerCase()));

  String get thumbnailUrl {
    if (contentToken != null && contentToken!.isNotEmpty) {
      return 'https://p.kuraa.cc/api/files/content/$contentToken/thumbnail';
    }
    return '';
  }

  String get previewUrl {
    if (contentToken != null && contentToken!.isNotEmpty) {
      return 'https://p.kuraa.cc/api/files/content/$contentToken/preview';
    }
    return '';
  }

  String get downloadUrl {
    if (contentToken != null && contentToken!.isNotEmpty) {
      return 'https://p.kuraa.cc/api/files/content/$contentToken/download';
    }
    return '';
  }

  factory KuraaFileItem.fromJson(Map<String, dynamic> json) {
    int parsedSize = 0;
    if (json['size'] != null) {
      parsedSize = int.tryParse(json['size'].toString()) ?? 0;
    }

    final tagsList = <String>[];
    if (json['tags'] is List) {
      for (final t in json['tags']) {
        if (t != null) tagsList.add(t.toString());
      }
    }

    return KuraaFileItem(
      id: json['id']?.toString() ?? '',
      storageLocationId: json['storageLocationId']?.toString() ?? '',
      parentId: json['parentId']?.toString(),
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'file',
      size: parsedSize,
      mimeType: json['mimeType']?.toString(),
      extension: json['extension']?.toString(),
      contentToken: json['contentToken']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
      hasThumbnail: json['hasThumbnail'] == true,
      tags: tagsList,
    );
  }
}

class KuraaFolderNav {
  final String? id;
  final String name;

  const KuraaFolderNav({required this.id, required this.name});
}

class KuraaPageResult {
  final List<KuraaFileItem> items;
  final int offset;
  final int limit;
  final int total;
  final bool hasMore;

  const KuraaPageResult({
    required this.items,
    required this.offset,
    required this.limit,
    required this.total,
    required this.hasMore,
  });
}

class KuraaApiService {
  static const String baseUrl = 'https://p.kuraa.cc';
  static const String defaultInnerPassword = 'kuraa.cc';

  static String? _configuredProxy;
  static final HttpClient _client = _createHttpClient();

  static HttpClient _createHttpClient() {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    _applyProxy(client);
    return client;
  }

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
    _applyProxy(_client);
  }

  static void _applyProxy(HttpClient client) {
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
  }

  static Future<dynamic> _getJson(String path, {Map<String, String>? headers}) async {
    final uri = Uri.parse(path.startsWith('http') ? path : '$baseUrl$path');
    final req = await _client.getUrl(uri);
    req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    headers?.forEach((k, v) => req.headers.set(k, v));
    final res = await req.close();
    final body = await utf8.decodeStream(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(body);
    }
    throw Exception('API请求失败 (HTTP ${res.statusCode}): $body');
  }

  static Future<dynamic> _postJson(String path, Map<String, dynamic> data, {Map<String, String>? headers}) async {
    final uri = Uri.parse(path.startsWith('http') ? path : '$baseUrl$path');
    final req = await _client.postUrl(uri);
    req.headers.contentType = ContentType.json;
    req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    headers?.forEach((k, v) => req.headers.set(k, v));
    req.write(jsonEncode(data));
    final res = await req.close();
    final body = await utf8.decodeStream(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(body);
    }
    throw Exception('API请求失败 (HTTP ${res.statusCode}): $body');
  }

  /// 获取存储位置列表 (公开浏览、内板等)
  static Future<List<KuraaStorageLocation>> fetchStorageLocations() async {
    try {
      final json = await _getJson('/api/storage-locations');
      final list = json['data'] as List? ?? [];
      return list
          .map((loc) => KuraaStorageLocation.fromJson(loc as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Kuraa fetchStorageLocations error: $e');
      return [];
    }
  }

  /// 解锁带密码的存储位置并返回 token
  static Future<String?> unlockStorageLocation(String locationId, String password) async {
    try {
      final json = await _postJson(
        '/api/storage-locations/$locationId/unlock',
        {'password': password},
      );
      if (json['data'] != null && json['data']['token'] != null) {
        return json['data']['token'].toString();
      }
    } catch (e) {
      debugPrint('Kuraa unlockStorageLocation error: $e');
      rethrow;
    }
    return null;
  }

  /// 获取指定目录下的文件与文件夹列表
  static Future<KuraaPageResult> fetchFiles({
    required String storageLocationId,
    String? parentId,
    int offset = 0,
    int limit = 50,
    String sortBy = 'updatedAt',
    String sortOrder = 'desc',
    String? token,
  }) async {
    try {
      final queryParams = {
        'storageLocationId': storageLocationId,
        'offset': '$offset',
        'limit': '$limit',
        'sortBy': sortBy,
        'sortOrder': sortOrder,
      };
      if (parentId != null && parentId.isNotEmpty) {
        queryParams['parentId'] = parentId;
      }

      final uri = Uri.parse('$baseUrl/api/files').replace(queryParameters: queryParams);
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['x-storage-tokens'] = jsonEncode({storageLocationId: token});
      }

      final json = await _getJson(uri.toString(), headers: headers);
      final rawList = json['data'] as List? ?? [];
      final items = rawList
          .map((item) => KuraaFileItem.fromJson(item as Map<String, dynamic>))
          .toList();

      final pagination = json['pagination'] as Map<String, dynamic>? ?? {};
      final total = int.tryParse(pagination['total']?.toString() ?? '0') ?? items.length;
      final hasMore = pagination['hasMore'] == true;

      return KuraaPageResult(
        items: items,
        offset: offset,
        limit: limit,
        total: total,
        hasMore: hasMore,
      );
    } catch (e) {
      debugPrint('Kuraa fetchFiles error: $e');
      rethrow;
    }
  }

  /// 获取某个文件夹的封面图片（取文件夹内第一张图片的缩略图或预览图）
  static Future<String?> fetchFolderCover(
    KuraaFileItem folderItem, {
    String? token,
  }) async {
    try {
      final res = await fetchFiles(
        storageLocationId: folderItem.storageLocationId,
        parentId: folderItem.id,
        offset: 0,
        limit: 8,
        token: token,
      );
      for (final item in res.items) {
        if (item.isImage) {
          if (item.thumbnailUrl.isNotEmpty) return item.thumbnailUrl;
          if (item.previewUrl.isNotEmpty) return item.previewUrl;
        }
      }
      // If direct children have subfolders, try one level deeper
      for (final sub in res.items) {
        if (sub.isFolder) {
          final subRes = await fetchFiles(
            storageLocationId: sub.storageLocationId,
            parentId: sub.id,
            offset: 0,
            limit: 3,
            token: token,
          );
          for (final subItem in subRes.items) {
            if (subItem.isImage) {
              if (subItem.thumbnailUrl.isNotEmpty) return subItem.thumbnailUrl;
              if (subItem.previewUrl.isNotEmpty) return subItem.previewUrl;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching folder cover for ${folderItem.name}: $e');
    }
    return null;
  }

  /// 全局关键词搜索
  static Future<KuraaPageResult> searchFiles({
    required String storageLocationId,
    required String query,
    int offset = 0,
    int limit = 50,
    String? token,
  }) async {
    try {
      final queryParams = {
        'storageLocationId': storageLocationId,
        'q': query,
        'offset': '$offset',
        'limit': '$limit',
      };

      final uri = Uri.parse('$baseUrl/api/files/search').replace(queryParameters: queryParams);
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['x-storage-tokens'] = jsonEncode({storageLocationId: token});
      }

      final json = await _getJson(uri.toString(), headers: headers);
      final rawList = json['data'] as List? ?? [];
      final items = rawList
          .map((item) => KuraaFileItem.fromJson(item as Map<String, dynamic>))
          .toList();

      final pagination = json['pagination'] as Map<String, dynamic>? ?? {};
      final total = int.tryParse(pagination['total']?.toString() ?? '0') ?? items.length;
      final hasMore = pagination['hasMore'] == true;

      return KuraaPageResult(
        items: items,
        offset: offset,
        limit: limit,
        total: total,
        hasMore: hasMore,
      );
    } catch (e) {
      debugPrint('Kuraa searchFiles error: $e');
      rethrow;
    }
  }

  /// 获取某相册/文件夹内的全部图片并转换为 AlbumItem
  static Future<AlbumItem?> fetchAlbumDetail(
    KuraaFileItem folderItem, {
    String? token,
  }) async {
    try {
      if (!folderItem.isFolder) {
        final imgUrl = folderItem.downloadUrl.isNotEmpty
            ? folderItem.downloadUrl
            : folderItem.previewUrl;
        return AlbumItem(
          title: folderItem.name,
          slug: 'kuraa_${folderItem.id}',
          detailUrl: '$baseUrl/file/${folderItem.id}',
          coverUrl: imgUrl,
          date: folderItem.updatedAt.split('T').first,
          author: 'Kuraa',
          tags: ['Kuraa', ...folderItem.tags],
          sourceType: MediaSourceType.kuraa,
          imageUrls: imgUrl.isNotEmpty ? [imgUrl] : [],
          previewUrls: imgUrl.isNotEmpty ? [imgUrl] : [],
          isDetailLoaded: true,
        );
      }

      final allImages = <KuraaFileItem>[];
      int offset = 0;
      const limit = 100;
      bool hasMore = true;

      while (hasMore) {
        final res = await fetchFiles(
          storageLocationId: folderItem.storageLocationId,
          parentId: folderItem.id,
          offset: offset,
          limit: limit,
          sortBy: 'name',
          sortOrder: 'asc',
          token: token,
        );

        for (final item in res.items) {
          if (item.isImage) {
            allImages.add(item);
          }
        }

        hasMore = res.hasMore && res.items.isNotEmpty;
        offset += limit;
      }

      final imageUrls = allImages.map((img) => img.downloadUrl).toList();
      final previewUrls = allImages
          .map((img) => img.previewUrl.isNotEmpty
              ? img.previewUrl
              : (img.thumbnailUrl.isNotEmpty ? img.thumbnailUrl : img.downloadUrl))
          .toList();
      final coverUrl = allImages.isNotEmpty
          ? (allImages.first.thumbnailUrl.isNotEmpty
              ? allImages.first.thumbnailUrl
              : allImages.first.previewUrl)
          : null;

      return AlbumItem(
        title: folderItem.name,
        slug: 'kuraa_${folderItem.id}',
        detailUrl: '$baseUrl/folder/${folderItem.id}',
        coverUrl: coverUrl,
        date: folderItem.updatedAt.split('T').first,
        author: 'Kuraa',
        tags: ['Kuraa', ...folderItem.tags],
        sourceType: MediaSourceType.kuraa,
        imageUrls: imageUrls,
        previewUrls: previewUrls,
        isDetailLoaded: true,
      );
    } catch (e) {
      debugPrint('Kuraa fetchAlbumDetail error: $e');
      rethrow;
    }
  }
}
