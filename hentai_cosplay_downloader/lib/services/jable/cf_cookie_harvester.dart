import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'api_client.dart';
import 'navigator_service.dart';

class CfCookieHarvester {
  static final Map<String, Future<Map<String, String>>> _activeHarvestFutures = {};

  /// Helper to check if the loaded HTML is a valid target page or a Cloudflare block page.
  static bool isValidPage(String siteName, String html, {bool isDetailPage = false}) {
    if (html.isEmpty) return false;
    final lower = html.toLowerCase();
    
    // Check page title for Cloudflare Interstitial markers
    final titleMatch = RegExp(r'<title>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(html);
    final pageTitle = titleMatch?.group(1)?.trim().toLowerCase() ?? "";
    if (pageTitle.contains('just a moment') ||
        pageTitle.contains('attention required') ||
        pageTitle.contains('security check') ||
        pageTitle.contains('cloudflare') ||
        pageTitle.contains('moment...')) {
      return false;
    }
    
    // Explicit block markers on raw response
    if (lower.contains('attention required! | cloudflare') ||
        (lower.contains('cloudflare') && lower.contains('ray id') && !lower.contains('eval(function') && !lower.contains('og:title'))) {
      return false;
    }
    
    // Positive content matching
    if (siteName == 'MissAV') {
      if (isDetailPage) {
        return (lower.contains('og:title') || lower.contains('twitter:title') || lower.contains('eval(function')) &&
               (lower.contains('eval(function') || lower.contains('.m3u8') || lower.contains('surrit.com') || lower.contains('sixyik.com'));
      }
      return lower.contains('og:title') ||
             lower.contains('eval(function') ||
             lower.contains('.m3u8') ||
             lower.contains('thumbnail') || 
             lower.contains('video-item') ||
             lower.contains('truncate') ||
             lower.contains('my-2 text-nord');
    } else if (siteName == 'JableTV') {
      return lower.contains('og:title') ||
             lower.contains('video-img-box') || 
             lower.contains('list_videos') ||
             lower.contains('.m3u8') ||
             lower.contains('navbar');
    } else if (siteName == 'SupJav') {
      return lower.contains('og:title') ||
             lower.contains('post') || 
             lower.contains('board') ||
             lower.contains('btn-server') ||
             lower.contains('navbar');
    }
    
    return lower.contains('navbar') || lower.contains('logo') || lower.contains('footer') || lower.contains('og:title');
  }

  /// Loads the target URL in a WebView to bypass Cloudflare security challenges.
  static Future<Map<String, String>> harvest(String url, {String? siteName}) async {
    final hostKey = Uri.tryParse(url)?.host ?? siteName ?? 'default';
    if (_activeHarvestFutures.containsKey(hostKey)) {
      return await _activeHarvestFutures[hostKey]!;
    }
    
    final future = _doHarvest(url, siteName: siteName);
    _activeHarvestFutures[hostKey] = future;
    try {
      final result = await future;
      return result;
    } finally {
      _activeHarvestFutures.remove(hostKey);
    }
  }

  /// Fetches text content using JavaScript fetch inside Chromium native stack
  static Future<String> fetchTextViaJs(String url, {String? siteName, Map<String, String>? headers}) async {
    final completer = Completer<String>();
    HeadlessInAppWebView? headless;
    Timer? timeoutTimer;
    
    final activeHost = ApiClient().getActiveHost(siteName ?? 'MissAV');
    final rawReferer = headers?['Referer'] ?? "https://$activeHost/";
    final referer = rawReferer.split('#').first;
    final rawOrigin = headers?['Origin'] ?? referer.replaceAll(RegExp(r'/+$'), '');
    final origin = rawOrigin.split('#').first;
    bool hasAttemptedDirectLoad = false;

    headless = HeadlessInAppWebView(
      initialData: InAppWebViewInitialData(
        data: "<!DOCTYPE html><html><head></head><body>ready</body></html>",
        baseUrl: WebUri(referer),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        allowUniversalAccessFromFileURLs: true,
        allowFileAccessFromFileURLs: true,
        allowContentAccess: true,
        allowFileAccess: true,
        useShouldOverrideUrlLoading: true,
      ),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: 'onJsFetchResult',
          callback: (args) {
            final res = args.isNotEmpty ? args[0] : null;
            if (res != null && res is String && res.isNotEmpty) {
              if (!completer.isCompleted) completer.complete(res);
            }
          },
        );
      },
      onLoadStop: (controller, currentUrl) async {
        try {
          if (currentUrl != null && currentUrl.toString().contains('.m3u8')) {
            final directHtml = await controller.evaluateJavascript(
              source: "document.querySelector('pre')?.innerText || document.body?.innerText || document.documentElement?.outerHTML"
            ) as String? ?? "";
            if (directHtml.contains('#EXTM3U') && !completer.isCompleted) {
              completer.complete(directHtml);
              return;
            }
          }

          final jsResult = await controller.callAsyncJavaScript(
            functionBody: """
              try {
                const response = await fetch('$url', {
                  headers: {
                    'Referer': '$referer',
                    'Origin': '$origin',
                    'Accept': '*/*'
                  }
                });
                if (response.ok) {
                  const text = await response.text();
                  if (text && text.includes('#EXTM3U')) {
                    window.flutter_inappwebview.callHandler('onJsFetchResult', text);
                    return text;
                  }
                }
              } catch (err) {}
              
              // Fallback to XMLHttpRequest
              return await new Promise((resolve) => {
                try {
                  const xhr = new XMLHttpRequest();
                  xhr.open('GET', '$url', true);
                  xhr.setRequestHeader('Referer', '$referer');
                  xhr.setRequestHeader('Origin', '$origin');
                  xhr.setRequestHeader('Accept', '*/*');
                  xhr.onload = function() {
                    if (xhr.status >= 200 && xhr.status < 300) {
                      window.flutter_inappwebview.callHandler('onJsFetchResult', xhr.responseText);
                      resolve(xhr.responseText);
                    } else {
                      resolve('HTTP_ERROR:' + xhr.status);
                    }
                  };
                  xhr.onerror = function() {
                    resolve('JS_ERROR:XHR_FAILED');
                  };
                  xhr.send();
                } catch (e2) {
                  resolve('JS_ERROR:' + e2.message);
                }
              });
            """,
          );
          
          final result = jsResult?.value?.toString() ?? "";
          
          if (result.contains('#EXTM3U')) {
            if (!completer.isCompleted) completer.complete(result);
            return;
          }
          
          if (result.startsWith('HTTP_ERROR:') || result.startsWith('JS_ERROR:') || result.isEmpty) {
            if (!hasAttemptedDirectLoad) {
              hasAttemptedDirectLoad = true;
              try {
                await controller.loadUrl(
                  urlRequest: URLRequest(
                    url: WebUri(url),
                    headers: {
                      'Referer': referer,
                      'Origin': origin,
                      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
                    },
                  ),
                );
              } catch (e) {
                if (!completer.isCompleted) completer.completeError(result.isNotEmpty ? result : e);
              }
            }
          } else {
            if (!completer.isCompleted) completer.complete(result);
          }
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
    );
    
    await headless.run();
    timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) completer.completeError("JS Fetch timeout for: $url");
    });
    
    try {
      final res = await completer.future;
      timeoutTimer.cancel();
      await headless.dispose();
      return res;
    } catch (e) {
      timeoutTimer.cancel();
      await headless.dispose();
      rethrow;
    }
  }

  /// Fetches binary data via Chromium native stack
  static Future<List<int>> fetchBytesViaJs(String url, {String? siteName, Map<String, String>? headers}) async {
    final completer = Completer<List<int>>();
    HeadlessInAppWebView? headless;
    Timer? timeoutTimer;
    
    final activeHost = ApiClient().getActiveHost(siteName ?? 'MissAV');
    final referer = headers?['Referer'] ?? "https://$activeHost/";
    final origin = headers?['Origin'] ?? referer.replaceAll(RegExp(r'/+$'), '');
    
    headless = HeadlessInAppWebView(
      initialData: InAppWebViewInitialData(
        data: "<!DOCTYPE html><html><head></head><body>ready</body></html>",
        baseUrl: WebUri(referer),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        allowUniversalAccessFromFileURLs: true,
        allowFileAccessFromFileURLs: true,
        allowContentAccess: true,
        allowFileAccess: true,
      ),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: 'onJsBytesResult',
          callback: (args) {
            if (args.isNotEmpty && args[0] is String) {
              final b64 = args[0] as String;
              if (b64.isNotEmpty && !completer.isCompleted) {
                completer.complete(base64Decode(b64));
              }
            }
          },
        );
      },
      onLoadStop: (controller, currentUrl) async {
        try {
          final jsResult = await controller.callAsyncJavaScript(
            functionBody: """
              try {
                const response = await fetch('$url', {
                  headers: {
                    'Referer': '$referer',
                    'Origin': '$origin',
                    'Accept': '*/*'
                  }
                });
                if (!response.ok) return '';
                const blob = await response.blob();
                return await new Promise((resolve) => {
                  const reader = new FileReader();
                  reader.onloadend = () => {
                    const res = reader.result;
                    const b64 = res ? res.split(',')[1] : '';
                    window.flutter_inappwebview.callHandler('onJsBytesResult', b64);
                    resolve(b64);
                  };
                  reader.readAsDataURL(blob);
                });
              } catch (err) {
                return '';
              }
            """,
          );
          
          final val = jsResult?.value;
          if (val is String && val.isNotEmpty && !completer.isCompleted) {
            completer.complete(base64Decode(val));
          }
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
    );
    
    await headless.run();
    timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) completer.completeError("JS Bytes Fetch timeout for $url");
    });
    
    try {
      final res = await completer.future;
      timeoutTimer.cancel();
      await headless.dispose();
      return res;
    } catch (e) {
      timeoutTimer.cancel();
      await headless.dispose();
      rethrow;
    }
  }

  /// Fetches content via Headless Chromium WebView
  static Future<String> fetchContentViaWebView(String url, {String? siteName}) async {
    try {
      return await fetchTextViaJs(url, siteName: siteName);
    } catch (_) {
      final completer = Completer<String>();
      HeadlessInAppWebView? headless;
      Timer? timeoutTimer;
      final activeHost = ApiClient().getActiveHost(siteName ?? 'MissAV');
      
      headless = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(url),
          headers: {
            'Referer': 'https://$activeHost/',
            'Origin': 'https://$activeHost',
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
          },
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          useShouldOverrideUrlLoading: true,
        ),
        onLoadStop: (controller, currentUrl) async {
          try {
            final text = await controller.evaluateJavascript(
              source: "document.body.innerText || document.documentElement.outerHTML"
            ) as String? ?? "";
            if (text.isNotEmpty && !completer.isCompleted) {
              completer.complete(text);
            }
          } catch (_) {}
        },
      );
      
      await headless.run();
      timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!completer.isCompleted) completer.completeError("WebView fetch timeout for: $url");
      });
      
      try {
        final res = await completer.future;
        timeoutTimer.cancel();
        await headless.dispose();
        return res;
      } catch (e) {
        timeoutTimer.cancel();
        await headless.dispose();
        rethrow;
      }
    }
  }

  static Future<Map<String, String>> _doHarvest(String url, {String? siteName}) async {
    String finalSiteName = siteName ?? "JableTV";
    if (url.contains("missav")) {
      finalSiteName = "MissAV";
    } else if (url.contains("supjav")) {
      finalSiteName = "SupJav";
    }

    // 1. First attempt headless background harvesting without showing any UI modal
    try {
      final headlessResult = await _harvestHeadless(finalSiteName, url);
      if (headlessResult.isNotEmpty && headlessResult['cookie'] != null && headlessResult['cookie']!.isNotEmpty) {
        return headlessResult;
      }
    } catch (_) {}

    // 2. If headless fails, check if an interactive context is available
    final context = navigatorKey.currentContext;
    if (context == null) {
      return _harvestHeadless(finalSiteName, url);
    }

    final completer = Completer<Map<String, String>>();
    bool resolved = false;

    // Show a modal bottom sheet containing the WebView
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        final isDark = Theme.of(modalContext).brightness == Brightness.dark;
        return PopScope(
          canPop: false,
          child: Container(
            height: MediaQuery.of(modalContext).size.height * 0.65,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '正在进行 Cloudflare 安全验证...',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                const Text(
                  '若有验证码或“确认您是人类”选项，请在下方点击。',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(url)),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                        databaseEnabled: true,
                        useShouldOverrideUrlLoading: true,
                      ),
                      shouldOverrideUrlLoading: (controller, navigationAction) async {
                        return NavigationActionPolicy.ALLOW;
                      },
                      onWebViewCreated: (controller) {
                        bool reloadTriggered = false;
                        Timer.periodic(const Duration(milliseconds: 800), (timer) async {
                          if (resolved || completer.isCompleted) {
                            timer.cancel();
                            return;
                          }
                          try {
                            final currentUrl = await controller.getUrl();
                            if (currentUrl == null) return;
                            final cookies = await CookieManager.instance().getCookies(url: currentUrl);
                            final hasClearance = cookies.any((c) => c.name == 'cf_clearance' && c.value.isNotEmpty);
                            final html = await controller.getHtml() ?? "";
                            final pageValid = isValidPage(finalSiteName, html);
                            
                            if (pageValid) {
                              timer.cancel();
                              final cookieString = cookies.map((c) => "${c.name}=${c.value}").join("; ");
                              final userAgent = await controller.evaluateJavascript(
                                source: "navigator.userAgent"
                              ) as String? ?? "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36";
                              
                              resolved = true;
                              if (modalContext.mounted && Navigator.canPop(modalContext)) {
                                Navigator.pop(modalContext);
                                if (!completer.isCompleted) {
                                  completer.complete({
                                    'targetUrl': url,
                                    'html': html,
                                    'cookie': cookieString,
                                    'user-agent': userAgent,
                                    'host': currentUrl.host,
                                    'origin': "${currentUrl.scheme}://${currentUrl.host}",
                                    'referer': "${currentUrl.scheme}://${currentUrl.host}/",
                                  });
                                }
                              }
                            } else if (hasClearance && !reloadTriggered) {
                              reloadTriggered = true;
                              await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
                            }
                          } catch (_) {}
                        });
                      },
                      onLoadStop: (controller, currentUrl) async {
                        try {
                          if (currentUrl == null) return;
                          final cookies = await CookieManager.instance().getCookies(url: currentUrl);
                          final html = await controller.getHtml() ?? "";
                          final pageValid = isValidPage(finalSiteName, html);
                          
                          if (pageValid) {
                            final cookieString = cookies.map((c) => "${c.name}=${c.value}").join("; ");
                            final userAgent = await controller.evaluateJavascript(
                              source: "navigator.userAgent"
                            ) as String? ?? "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36";
                            
                            resolved = true;
                            if (modalContext.mounted && Navigator.canPop(modalContext)) {
                              Navigator.pop(modalContext);
                            }
                            if (!completer.isCompleted) {
                              completer.complete({
                                'html': html,
                                'cookie': cookieString,
                                'user-agent': userAgent,
                                'host': currentUrl.host,
                                'origin': "${currentUrl.scheme}://${currentUrl.host}",
                                'referer': "${currentUrl.scheme}://${currentUrl.host}/",
                              });
                            }
                          }
                        } catch (_) {}
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    resolved = true;
                    Navigator.pop(modalContext);
                    completer.completeError("用户取消了 Cloudflare 验证");
                  },
                  child: const Text('取消并返回', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (!resolved && !completer.isCompleted) {
        completer.completeError("Cloudflare 验证窗口被关闭");
      }
    });

    try {
      return await completer.future.timeout(const Duration(seconds: 45));
    } catch (e) {
      rethrow;
    }
  }

  /// Headless mode fallback
  static Future<Map<String, String>> _harvestHeadless(String siteName, String url) async {
    final completer = Completer<Map<String, String>>();
    Timer? pollTimer;
    
    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        useShouldOverrideUrlLoading: true,
      ),
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        return NavigationActionPolicy.ALLOW;
      },
      onWebViewCreated: (controller) {
        pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
          if (completer.isCompleted) {
            timer.cancel();
            return;
          }
          try {
            final currentUrl = await controller.getUrl();
            if (currentUrl == null) return;
            final cookies = await CookieManager.instance().getCookies(url: currentUrl);
            final hasClearance = cookies.any((c) => c.name == 'cf_clearance' && c.value.isNotEmpty);
            final html = await controller.getHtml() ?? "";
            
            if (isValidPage(siteName, html) || hasClearance) {
              pollTimer?.cancel();
              final cookieString = cookies.map((c) => "${c.name}=${c.value}").join("; ");
              final userAgent = await controller.evaluateJavascript(source: "navigator.userAgent") as String? ?? "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36";
              if (!completer.isCompleted) {
                completer.complete({
                  'targetUrl': url,
                  'html': html,
                  'cookie': cookieString,
                  'user-agent': userAgent,
                  'host': currentUrl.host,
                  'origin': "${currentUrl.scheme}://${currentUrl.host}",
                  'referer': "${currentUrl.scheme}://${currentUrl.host}/",
                });
              }
            }
          } catch (_) {}
        });
      },
      onLoadStop: (controller, currentUrl) async {
        try {
          if (currentUrl == null) return;
          final cookies = await CookieManager.instance().getCookies(url: currentUrl);
          final hasClearance = cookies.any((c) => c.name == 'cf_clearance' && c.value.isNotEmpty);
          final html = await controller.getHtml() ?? "";
          if (isValidPage(siteName, html) || hasClearance) {
            pollTimer?.cancel();
            final cookieString = cookies.map((c) => "${c.name}=${c.value}").join("; ");
            final userAgent = await controller.evaluateJavascript(source: "navigator.userAgent") as String? ?? "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36";
            if (!completer.isCompleted) {
              completer.complete({
                'targetUrl': url,
                'html': html,
                'cookie': cookieString,
                'user-agent': userAgent,
                'host': currentUrl.host,
                'origin': "${currentUrl.scheme}://${currentUrl.host}",
                'referer': "${currentUrl.scheme}://${currentUrl.host}/",
              });
            }
          }
        } catch (_) {}
      },
    );

    await headless.run();
    try {
      final result = await completer.future.timeout(const Duration(seconds: 20));
      return result;
    } finally {
      pollTimer?.cancel();
      try {
        await headless.dispose();
      } catch (_) {}
    }
  }
}
