import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../app_logger.dart';
import '../config_service.dart';
import 'cf_cookie_harvester.dart';
import 'persistent_chromium_tunnel.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  final Dio _dio;
  String _proxyUrl = "";
  final Map<String, Map<String, String>> _siteHeaders = {}; // siteName -> headers Map
  final Map<String, Map<String, String>> _hostHeaders = {}; // host -> headers Map
  final Map<String, String> _activeHost = {
    'MissAV': 'missav.ws',
    'JableTV': 'jable.tv',
    'SupJav': 'supjav.com',
    'Hanime1': 'hanime1.me',
    '91PinSe': '91pinse.com',
  };

  ApiClient._internal() : _dio = Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 20);
    
    // Add default headers to resemble standard mobile browsers
    _dio.options.headers = {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      'Accept': '*/*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8,ja;q=0.7',
    };

    // Load initial proxy
    final cfg = ConfigService.loadConfig();
    if (cfg.customProxy.isNotEmpty) {
      setProxy(cfg.customProxy);
    }
  }

  Dio get dio => _dio;

  /// Configures HTTP/HTTPS proxies inside Dio.
  void setProxy(String proxyUrl) {
    _proxyUrl = proxyUrl.trim();
    if (_proxyUrl.isEmpty) {
      _dio.httpClientAdapter = IOHttpClientAdapter();
      return;
    }

    String formattedProxy = _proxyUrl;
    if (!_proxyUrl.startsWith('http://') && !_proxyUrl.startsWith('https://') && !_proxyUrl.startsWith('socks5://')) {
      formattedProxy = 'http://$_proxyUrl';
    }

    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (uri) {
          final cleaned = formattedProxy.replaceAll(RegExp(r'https?://|socks5?://'), '');
          if (formattedProxy.startsWith('socks')) {
            return "SOCKS5 $cleaned; DIRECT";
          } else {
            return "PROXY $cleaned; DIRECT";
          }
        };
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        return client;
      },
    );
  }

  /// Sets custom Cloudflare headers (cookies, user-agent) for a specific site and host.
  void setSiteHeaders(String siteName, Map<String, String> headers) {
    _siteHeaders[siteName] = headers;
    final host = headers['host'];
    if (host != null && host.isNotEmpty) {
      _hostHeaders[host] = headers;
      _activeHost[siteName] = host;
    }
  }

  /// Returns current active host for site
  String getActiveHost(String siteName) {
    return _activeHost[siteName] ?? 
        (siteName == 'MissAV' ? 'missav.ws' : (siteName == 'JableTV' ? 'jable.tv' : (siteName == 'Hanime1' ? 'hanime1.me' : (siteName == '91PinSe' ? '91pinse.com' : 'supjav.com'))));
  }

  /// Retrieves customized headers for a specific site, injecting bypass tokens if harvested.
  Map<String, String> getHeadersForSite(String siteName, String targetUrl) {
    final targetUri = Uri.tryParse(targetUrl) ?? Uri.parse(Uri.encodeFull(targetUrl));
    final targetHost = targetUri.host;
    
    final activeHost = getActiveHost(siteName);
    
    // Look for host-specific override first, then site fallback
    final custom = _hostHeaders[targetHost] ?? _siteHeaders[siteName] ?? {};
    
    final ua = custom['user-agent'] ?? 
        _dio.options.headers['User-Agent'] as String? ??
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

    final headers = <String, String>{
      'User-Agent': ua,
      'Accept': '*/*',
    };

    final bool isSiteDomain = targetHost.contains('missav') || 
                              targetHost.contains('jable') || 
                              targetHost.contains('fs1.app') || 
                              targetHost.contains('supjav') ||
                              targetHost.contains('hanime1') ||
                              targetHost.contains('91pinse');

    if (isSiteDomain) {
      headers['Referer'] = "https://$targetHost/";
      headers['Origin'] = "https://$targetHost";
      
      final hostCustom = _hostHeaders[targetHost] ?? custom;
      if (hostCustom['cookie'] != null && hostCustom['cookie']!.isNotEmpty) {
        headers['Cookie'] = hostCustom['cookie']!;
      }
    } else {
      headers['Referer'] = "https://$activeHost/";
      headers['Origin'] = "https://$activeHost";
    }

    return headers;
  }

  /// Performs a page fetch with automatic mirror rotation and CF bypass.
  Future<String> fetchHtml(String siteName, String url, {bool isDetailPage = false}) async {
    List<String> mirrors = [];
    if (siteName == 'MissAV') {
      mirrors = ['missav.ws', 'missav.ai', 'missav.live', 'missav123.com'];
    } else if (siteName == 'JableTV') {
      mirrors = ['jable.tv', 'fs1.app'];
    } else if (siteName == 'SupJav') {
      mirrors = ['supjav.com', 'supremejav.com'];
    } else if (siteName == 'Hanime1') {
      mirrors = ['hanime1.me'];
    } else if (siteName == '91PinSe') {
      mirrors = ['91pinse.com', 'www.91pinse.com'];
    }

    final targetUri = Uri.tryParse(url) ?? Uri.parse(Uri.encodeFull(url));
    final targetHost = targetUri.host;
    final activeHost = _activeHost[siteName];
    
    final hostsToTry = <String>[];
    if (isDetailPage) {
      hostsToTry.add(targetHost);
      for (final m in mirrors) {
        if (!hostsToTry.contains(m)) {
          hostsToTry.add(m);
        }
      }
    } else {
      if (activeHost != null && mirrors.contains(activeHost)) {
        hostsToTry.add(activeHost);
      }
      if (!hostsToTry.contains(targetHost)) {
        hostsToTry.add(targetHost);
      }
      for (final m in mirrors) {
        if (!hostsToTry.contains(m)) {
          hostsToTry.add(m);
        }
      }
    }

    dynamic lastError;
    for (final host in hostsToTry) {
      final swappedUrl = targetUri.replace(host: host).toString();
      try {
        final html = await _fetchSingleHtml(siteName, swappedUrl, isDetailPage: isDetailPage);
        if (html.isNotEmpty && CfCookieHarvester.isValidPage(siteName, html, isDetailPage: isDetailPage)) {
          _activeHost[siteName] = host;
          return html;
        }
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception("[$siteName] 所有镜像源均请求失败: $url");
  }

  Future<String> _fetchSingleHtml(String siteName, String url, {bool isDetailPage = false}) async {
    final headers = getHeadersForSite(siteName, url);
    
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      final html = response.data as String;
      
      final isCf = !CfCookieHarvester.isValidPage(siteName, html, isDetailPage: isDetailPage);
                   
      if (isCf) {
        final harvested = await CfCookieHarvester.harvest(url, siteName: siteName);
        setSiteHeaders(siteName, harvested);
        
        if (harvested['targetUrl'] == url && harvested['html'] != null && harvested['html']!.isNotEmpty && CfCookieHarvester.isValidPage(siteName, harvested['html']!, isDetailPage: isDetailPage)) {
          return harvested['html']!;
        }
        
        try {
          final freshHeaders = getHeadersForSite(siteName, url);
          final retryResp = await _dio.get(
            url,
            options: Options(
              headers: freshHeaders,
              responseType: ResponseType.plain,
              validateStatus: (status) => status != null && status < 400,
            ),
          );
          final retryHtml = retryResp.data as String;
          if (CfCookieHarvester.isValidPage(siteName, retryHtml, isDetailPage: isDetailPage)) {
            return retryHtml;
          }
        } catch (_) {}

        final webViewHtml = await CfCookieHarvester.fetchContentViaWebView(url, siteName: siteName);
        if (webViewHtml.isNotEmpty && CfCookieHarvester.isValidPage(siteName, webViewHtml, isDetailPage: isDetailPage)) {
          return webViewHtml;
        }
      }
      
      return html;
    } catch (e) {
      AppLogger.w('ApiClient', '网络请求失败 [$siteName] URL: $url ($e). 尝试 Chromium WebView 回退...');
      try {
        final webViewHtml = await CfCookieHarvester.fetchContentViaWebView(url, siteName: siteName);
        if (webViewHtml.isNotEmpty && CfCookieHarvester.isValidPage(siteName, webViewHtml, isDetailPage: isDetailPage)) {
          AppLogger.s('ApiClient', 'Chromium WebView 回退成功 [$siteName]');
          return webViewHtml;
        }
      } catch (e2) {
        AppLogger.w('ApiClient', 'Chromium WebView 回退异常: $e2');
      }

      try {
        final harvested = await CfCookieHarvester.harvest(url, siteName: siteName);
        setSiteHeaders(siteName, harvested);
        
        if (harvested['html'] != null && harvested['html']!.isNotEmpty && CfCookieHarvester.isValidPage(siteName, harvested['html']!, isDetailPage: isDetailPage)) {
          return harvested['html']!;
        }

        try {
          final freshHeaders = getHeadersForSite(siteName, url);
          final retryResp = await _dio.get(
            url,
            options: Options(
              headers: freshHeaders,
              responseType: ResponseType.plain,
              validateStatus: (status) => status != null && status < 400,
            ),
          );
          final retryHtml = retryResp.data as String;
          if (CfCookieHarvester.isValidPage(siteName, retryHtml, isDetailPage: isDetailPage)) {
            return retryHtml;
          }
        } catch (_) {}
      } catch (harvestErr) {
        AppLogger.e('ApiClient', 'Harvest 回退失败: $harvestErr');
      }
      rethrow;
    }
  }

  /// Downloads binary data with site-specific headers.
  Future<List<int>> downloadBytes(String siteName, String url, {Map<String, String>? extraHeaders}) async {
    final headers = getHeadersForSite(siteName, url);
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    final host = (Uri.tryParse(url) ?? Uri.parse(Uri.encodeFull(url))).host;
    final isCdn = !host.contains('missav') && !host.contains('jable') && !host.contains('fs1.app') && !host.contains('supjav');
    if (isCdn) {
      headers.remove('Cookie');
      headers.remove('cookie');
      headers['Accept'] = '*/*';
    }
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      if (response.data != null) {
        return response.data!;
      }
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Response body is null',
      );
    } catch (e) {
      try {
        final bytes = await PersistentChromiumTunnel.fetchBytes(url, siteName: siteName, headers: headers);
        if (bytes != null && bytes.isNotEmpty) return bytes;
      } catch (_) {}
      rethrow;
    }
  }
}
