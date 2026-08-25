import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'api_client.dart';

class PersistentChromiumTunnel {
  static HeadlessInAppWebView? _headless;
  static InAppWebViewController? _controller;
  static Completer<void>? _readyCompleter;
  static bool _isRunning = false;
  static int _activeRefCount = 0;
  static Timer? _idleTimer;

  /// Ensures a single background headless Chromium instance is running and warmed up.
  static Future<void> ensureStarted(String siteName, {String? refererUrl}) async {
    _idleTimer?.cancel();
    if (_isRunning && _controller != null) return;
    if (_readyCompleter != null) {
      await _readyCompleter!.future;
      return;
    }

    final completer = Completer<void>();
    _readyCompleter = completer;
    final activeHost = ApiClient().getActiveHost(siteName);
    final referer = refererUrl ?? "https://$activeHost/";

    _headless = HeadlessInAppWebView(
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
        _controller = controller;
      },
      onLoadStop: (controller, url) {
        _isRunning = true;
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    try {
      await _headless!.run();
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      _isRunning = false;
      _controller = null;
      _readyCompleter = null;
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      try {
        _headless?.dispose();
      } catch (_) {}
      _headless = null;
      rethrow;
    }
  }

  /// Retains reference count for an active download session
  static void retain() {
    _idleTimer?.cancel();
    _activeRefCount++;
  }

  /// Fetches binary data (TS segments, AES keys) through the warm persistent Chromium instance
  static Future<Uint8List?> fetchBytes(String url, {required String siteName, Map<String, String>? headers}) async {
    final activeHost = ApiClient().getActiveHost(siteName);
    final referer = headers?['Referer'] ?? "https://$activeHost/";
    final origin = headers?['Origin'] ?? referer.replaceAll(RegExp(r'/+$'), '');

    try {
      await ensureStarted(siteName, refererUrl: referer);
      if (_controller == null) return null;

      final jsResult = await _controller!.callAsyncJavaScript(
        functionBody: """
          try {
            const response = await fetch('$url', {
              headers: {
                'Referer': '$referer',
                'Origin': '$origin',
                'Accept': '*/*'
              }
            });
            if (!response.ok) return null;
            const blob = await response.blob();
            return await new Promise((resolve) => {
              const reader = new FileReader();
              reader.onloadend = () => {
                const res = reader.result;
                resolve(res ? res.split(',')[1] : null);
              };
              reader.readAsDataURL(blob);
            });
          } catch (e) {
            return null;
          }
        """,
      );

      final b64 = jsResult?.value as String?;
      if (b64 != null && b64.isNotEmpty) {
        return base64Decode(b64);
      }
    } catch (e) {
      debugPrint('ChromiumTunnel fetchBytes error: $e');
    } finally {
      _scheduleIdleShutdown();
    }
    return null;
  }

  /// Fetches text content (M3U8 playlists) through the warm persistent Chromium instance
  static Future<String?> fetchText(String url, {required String siteName, Map<String, String>? headers}) async {
    final activeHost = ApiClient().getActiveHost(siteName);
    final rawReferer = headers?['Referer'] ?? "https://$activeHost/";
    final referer = rawReferer.split('#').first;
    final rawOrigin = headers?['Origin'] ?? referer.replaceAll(RegExp(r'/+$'), '');
    final origin = rawOrigin.split('#').first;

    try {
      await ensureStarted(siteName, refererUrl: referer);
      if (_controller == null) return null;

      final jsResult = await _controller!.callAsyncJavaScript(
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
              if (text) return text;
            }
          } catch (e) {}

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
                  resolve(xhr.responseText);
                } else {
                  resolve(null);
                }
              };
              xhr.onerror = function() { resolve(null); };
              xhr.send();
            } catch (e2) {
              resolve(null);
            }
          });
        """,
      );

      final str = jsResult?.value as String?;
      if (str != null && str.isNotEmpty) {
        return str;
      }
    } catch (e) {
      debugPrint('ChromiumTunnel fetchText error: $e');
    } finally {
      _scheduleIdleShutdown();
    }
    return null;
  }

  static void _scheduleIdleShutdown() {
    _idleTimer?.cancel();
    if (_activeRefCount <= 0 && _isRunning) {
      _idleTimer = Timer(const Duration(seconds: 45), () {
        if (_activeRefCount <= 0) {
          _disposeTunnel();
        }
      });
    }
  }

  static void _disposeTunnel() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _activeRefCount = 0;
    _isRunning = false;
    _controller = null;
    _readyCompleter = null;
    try {
      _headless?.dispose();
    } catch (_) {}
    _headless = null;
  }

  /// Releases reference count and disposes the persistent Chromium instance when all tasks are complete
  static void release() {
    _activeRefCount--;
    if (_activeRefCount <= 0) {
      _disposeTunnel();
    }
  }
}
