import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../models/album_item.dart';

class MztApiResponse {
  final List<AlbumItem> items;
  final int total;
  final int pageSize;
  final int page;

  MztApiResponse({
    required this.items,
    required this.total,
    required this.pageSize,
    required this.page,
  });

  int get totalPages => pageSize > 0 ? (total + pageSize - 1) ~/ pageSize : 1;
}

class MztApiService {
  static const String kBaseApiUrl = 'https://mzt.111404.xyz/urls';

  static String? _configuredProxy;
  static Dio _dio = _createDio();

  static void setProxy(String? proxy) {
    _configuredProxy = proxy?.trim();
    _dio = _createDio();
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Referer': 'https://mzt.111404.xyz/',
          'Connection': 'keep-alive',
        },
      ),
    );

    if (_configuredProxy != null && _configuredProxy!.isNotEmpty) {
      final adapter = IOHttpClientAdapter();
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        final clean = _configuredProxy!.replaceAll(RegExp(r'https?://|socks5?://'), '');
        if (_configuredProxy!.startsWith('socks')) {
          client.findProxy = (uri) => 'SOCKS5 $clean; DIRECT';
        } else {
          client.findProxy = (uri) => 'PROXY $clean; DIRECT';
        }
        return client;
      };
      dio.httpClientAdapter = adapter;
    }
    return dio;
  }

  /// Fetch a page of MZT image packs
  static Future<MztApiResponse?> fetchPageData({
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
              .map((item) => AlbumItem.fromMztJson(item as Map<String, dynamic>))
              .toList();
          final total = (data['total'] as num?)?.toInt() ?? items.length;
          final actualPageSize = (data['pageSize'] as num?)?.toInt() ?? pageSize;

          return MztApiResponse(
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

  /// Test connectivity and latency of a proxy domain node (e.g. https://tgproxy.1258012.xyz)
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
      if (res.statusCode != null && res.statusCode! < 400) {
        return stopwatch.elapsedMilliseconds;
      }
    } catch (_) {}
    return null;
  }

  /// Test base API connectivity and latency
  static Future<int?> testBaseApiLatency() async {
    final stopwatch = Stopwatch()..start();
    try {
      final res = await _dio.get(
        kBaseApiUrl,
        queryParameters: {'page': 1, 'pageSize': 1},
        options: Options(
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      stopwatch.stop();
      if (res.statusCode == 200) {
        return stopwatch.elapsedMilliseconds;
      }
    } catch (_) {}
    return null;
  }
}
