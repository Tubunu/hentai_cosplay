import 'dart:async';
import 'package:dio/dio.dart';
import '../models/pack_item.dart';

class ApiResponse {
  final List<PackItem> items;
  final int total;
  final int pageSize;
  final int page;

  ApiResponse({
    required this.items,
    required this.total,
    required this.pageSize,
    required this.page,
  });

  int get totalPages => pageSize > 0 ? (total + pageSize - 1) ~/ pageSize : 1;
}

class ApiService {
  static const String kBaseApiUrl = 'https://mzt.111404.xyz/urls';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://mzt.111404.xyz/',
        'Connection': 'keep-alive',
      },
    ),
  );

  /// Fetch a page of image packs
  static Future<ApiResponse?> fetchPageData({
    required int page,
    int pageSize = 12,
    int retryCount = 3,
  }) async {
    for (int i = 0; i < retryCount; i++) {
      try {
        final response = await _dio.get(
          kBaseApiUrl,
          queryParameters: {
            'page': page,
            'pageSize': pageSize,
          },
        );

        if (response.statusCode == 200 && response.data is Map) {
          final data = response.data as Map<String, dynamic>;
          final itemsRaw = (data['items'] as List<dynamic>?) ?? [];
          final items = itemsRaw
              .map((item) => PackItem.fromJson(item as Map<String, dynamic>))
              .toList();
          final total = (data['total'] as num?)?.toInt() ?? items.length;
          final actualPageSize = (data['pageSize'] as num?)?.toInt() ?? pageSize;

          return ApiResponse(
            items: items,
            total: total,
            pageSize: actualPageSize,
            page: page,
          );
        }
      } catch (e) {
        if (i < retryCount - 1) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }
    }
    return null;
  }

  /// Test connectivity and latency of a proxy domain (e.g. https://tgproxy.1258012.xyz)
  static Future<int?> testProxyLatency(String proxyDomain) async {
    final stopwatch = Stopwatch()..start();
    try {
      final cleanDomain = proxyDomain.trim().replaceAll(RegExp(r'/+$'), '');
      final res = await _dio.get(
        cleanDomain,
        options: Options(
          validateStatus: (status) => true,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      stopwatch.stop();
      if (res.statusCode != null) {
        return stopwatch.elapsedMilliseconds;
      }
    } catch (_) {}
    return null;
  }
}
