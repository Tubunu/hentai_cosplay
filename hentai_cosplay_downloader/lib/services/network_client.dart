import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Centralized network client manager for creating and configuring Dio instances,
/// proxies (HTTP & SOCKS5), and connection parameters across all API services.
class NetworkClient {
  static String _currentProxy = '';
  static bool _allowInsecureCertificates = false;
  static final List<void Function(String proxy)> _proxyListeners = [];

  static String get currentProxy => _currentProxy;
  static bool get allowInsecureCertificates => _allowInsecureCertificates;

  /// Global insecure certificates setter
  static void setAllowInsecureCertificates(bool allow) {
    _allowInsecureCertificates = allow;
  }

  /// Global proxy setter, notifies all listeners of changes
  static void setProxy(String? proxy) {
    _currentProxy = proxy?.trim() ?? '';
    for (final listener in List.of(_proxyListeners)) {
      try {
        listener(_currentProxy);
      } catch (_) {}
    }
  }

  /// Register listener for proxy changes
  static void addProxyListener(void Function(String proxy) listener) {
    _proxyListeners.add(listener);
  }

  /// Remove listener for proxy changes
  static void removeProxyListener(void Function(String proxy) listener) {
    _proxyListeners.remove(listener);
  }

  /// Creates a pre-configured Dio instance with standardized proxy handling and certificate validation
  static Dio createDio({
    String? baseUrl,
    Map<String, dynamic>? headers,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 25),
    Duration sendTimeout = const Duration(seconds: 15),
    bool? allowBadCertificates,
    String? specificProxy,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        headers: headers,
      ),
    );

    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();
      final effectiveProxy = specificProxy ?? _currentProxy;
      final effectiveAllowBadCert = (allowBadCertificates ?? _allowInsecureCertificates) && effectiveProxy.isNotEmpty;
      // 仅在明确开启且配置了代理时绕过 SSL 验证（如 Charles / Proxyman 抓包调试）
      if (effectiveAllowBadCert) {
        client.badCertificateCallback = (cert, host, port) => true;
      }
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
}
