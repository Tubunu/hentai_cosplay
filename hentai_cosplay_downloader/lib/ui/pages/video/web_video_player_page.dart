import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import 'video_player_page.dart';

class WebVideoPlayerPage extends StatefulWidget {
  final String url;
  final String title;

  const WebVideoPlayerPage({
    super.key,
    required this.url,
    required this.title,
  });

  static void open(BuildContext context, {required String url, required String title}) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => WebVideoPlayerPage(url: url, title: title),
      ),
    );
  }

  @override
  State<WebVideoPlayerPage> createState() => _WebVideoPlayerPageState();
}

class _WebVideoPlayerPageState extends State<WebVideoPlayerPage> {
  InAppWebViewController? _webViewController;
  double _progress = 0.0;
  bool _isLoading = true;
  bool _isLandscape = false;
  String? _detectedVideoUrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    try {
      _webViewController?.stopLoading();
      _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')));
    } catch (_) {}
    _webViewController = null;
    super.dispose();
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
    });
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _openInNativePlayer(String videoUrl) {
    VideoPlayerPage.openRemote(
      context,
      url: videoUrl,
      title: widget.title,
      webPlayerUrl: widget.url,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            top: true,
            left: true,
            right: true,
            bottom: !_isLandscape,
            child: Column(
              children: [
                // Top Navigation Bar
                Container(
                  color: isDark ? const Color(0xFF141416) : const Color(0xFF242426),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      BouncingButton(
                        onTap: () {
                          if (_isLandscape) {
                            _toggleOrientation();
                          }
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white12,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.chevron_back, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      // Optional Built-in Player switch button if video src detected
                      if (_detectedVideoUrl != null && _detectedVideoUrl!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        BouncingButton(
                          onTap: () => _openInNativePlayer(_detectedVideoUrl!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: IosTheme.primaryPink.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: IosTheme.primaryPink, width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.play_arrow_solid, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  '内置播放',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),

                      // Copy URL Button
                      BouncingButton(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已复制网页链接'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white12,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.link, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Refresh Button
                      BouncingButton(
                        onTap: () {
                          setState(() {
                            _errorMessage = null;
                            _isLoading = true;
                            _progress = 0.0;
                          });
                          _webViewController?.reload();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white12,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.refresh, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Fullscreen / Rotate Button
                      BouncingButton(
                        onTap: _toggleOrientation,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _isLandscape ? IosTheme.primaryPink : Colors.white12,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isLandscape ? CupertinoIcons.fullscreen_exit : CupertinoIcons.fullscreen,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Linear Progress Indicator
                if (_isLoading)
                  LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 2.5,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(IosTheme.primaryPink),
                  ),

                // WebView Body
                Expanded(
                  child: Stack(
                    children: [
                      InAppWebView(
                        initialUrlRequest: URLRequest(
                          url: WebUri(widget.url),
                          headers: {
                            'User-Agent':
                                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
                            'Accept':
                                'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
                            'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
                          },
                        ),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          domStorageEnabled: true,
                          databaseEnabled: true,
                          mediaPlaybackRequiresUserGesture: false,
                          allowsInlineMediaPlayback: true,
                          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                          useHybridComposition: true,
                          allowsBackForwardNavigationGestures: true,
                          useWideViewPort: true,
                          loadWithOverviewMode: true,
                          supportZoom: true,
                          builtInZoomControls: true,
                          displayZoomControls: false,
                          transparentBackground: true,
                          allowFileAccess: true,
                          allowContentAccess: true,
                          javaScriptCanOpenWindowsAutomatically: true,
                          supportMultipleWindows: false,
                          preferredContentMode: UserPreferredContentMode.RECOMMENDED,
                          userAgent:
                              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
                        ),
                        onWebViewCreated: (controller) {
                          _webViewController = controller;
                        },
                        shouldOverrideUrlLoading: (controller, navigationAction) async {
                          final uri = navigationAction.request.url;
                          if (uri == null) return NavigationActionPolicy.ALLOW;
                          final scheme = uri.scheme.toLowerCase();
                          if (scheme == 'http' || scheme == 'https' || scheme == 'about') {
                            return NavigationActionPolicy.ALLOW;
                          }
                          debugPrint('[WebVideoPlayer] Blocked non-http scheme: $scheme ($uri)');
                          return NavigationActionPolicy.CANCEL;
                        },
                        onReceivedServerTrustAuthRequest: (controller, challenge) async {
                          return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
                        },
                        onLoadStart: (controller, url) {
                          if (mounted) {
                            setState(() {
                              _isLoading = true;
                              _errorMessage = null;
                            });
                          }
                        },
                        onProgressChanged: (controller, progress) {
                          if (mounted) {
                            setState(() {
                              _progress = progress / 100;
                              _isLoading = progress < 100;
                              if (progress > 60 && _errorMessage != null) {
                                _errorMessage = null;
                              }
                            });
                          }
                        },
                        onReceivedError: (controller, request, error) {
                          final isMain = request.isForMainFrame ?? true;
                          if (isMain && mounted) {
                            debugPrint('[WebVideoPlayer] Main frame load error: ${error.description}');
                            setState(() {
                              _errorMessage = error.description;
                              _isLoading = false;
                            });
                          }
                        },
                        onReceivedHttpError: (controller, request, errorResponse) {
                          final isMain = request.isForMainFrame ?? true;
                          if (isMain && (errorResponse.statusCode ?? 200) >= 400 && mounted) {
                            debugPrint('[WebVideoPlayer] HTTP error: ${errorResponse.statusCode} ${errorResponse.reasonPhrase}');
                          }
                        },
                        onLoadResource: (controller, resource) {
                          final resUrl = resource.url?.toString() ?? '';
                          if ((resUrl.contains('.m3u8') || resUrl.contains('.mp4')) &&
                              !resUrl.contains('beacon') &&
                              !resUrl.contains('analytics') &&
                              !resUrl.contains('google')) {
                            if (mounted && _detectedVideoUrl != resUrl) {
                              setState(() {
                                _detectedVideoUrl = resUrl;
                              });
                            }
                          }
                        },
                        onLoadStop: (controller, url) async {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                          // Clean intrusive popups, auto-play video element, and detect video source
                          try {
                            final res = await controller.evaluateJavascript(source: """
                              (function() {
                                var v = document.querySelector('video');
                                var foundSrc = null;
                                if (v) {
                                  v.muted = false;
                                  v.play().catch(function(){});
                                  if (v.currentSrc && (v.currentSrc.startsWith('http://') || v.currentSrc.startsWith('https://'))) {
                                    foundSrc = v.currentSrc;
                                  } else if (v.src && (v.src.startsWith('http://') || v.src.startsWith('https://'))) {
                                    foundSrc = v.src;
                                  } else {
                                    var srcEl = v.querySelector('source');
                                    if (srcEl && srcEl.src) foundSrc = srcEl.src;
                                  }
                                }
                                var ads = document.querySelectorAll('.ad, .ads, [id*="ad-"], [class*="popup"], [id*="banner"]');
                                ads.forEach(function(el) { el.style.display = 'none'; });
                                return foundSrc;
                              })();
                            """);
                            if (res != null && res.toString().isNotEmpty && res.toString() != 'null') {
                              if (mounted) {
                                setState(() {
                                  _detectedVideoUrl = res.toString();
                                });
                              }
                            }
                          } catch (_) {}
                        },
                      ),

                      // Sleek dark loading indicator before page paints (prevents white canvas flash)
                      if (_isLoading && _progress < 0.25 && _errorMessage == null)
                        Positioned.fill(
                          child: Container(
                            color: const Color(0xFF141416),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CupertinoActivityIndicator(radius: 14, color: Colors.white70),
                                  SizedBox(height: 14),
                                  Text(
                                    '正在加载网页...',
                                    style: TextStyle(color: Colors.white60, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Error Retry Overlay
                      if (_errorMessage != null)
                        Positioned.fill(
                          child: Container(
                            color: const Color(0xFF141416),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.exclamationmark_triangle,
                                      color: Color(0xFFFF9F0A),
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    '网页加载失败',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CupertinoButton(
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                        color: IosTheme.primaryPink,
                                        borderRadius: BorderRadius.circular(18),
                                        onPressed: () {
                                          setState(() {
                                            _errorMessage = null;
                                            _isLoading = true;
                                            _progress = 0.0;
                                          });
                                          _webViewController?.reload();
                                        },
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(CupertinoIcons.refresh, size: 14, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text('重新加载', style: TextStyle(color: Colors.white, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      CupertinoButton(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        color: Colors.white12,
                                        borderRadius: BorderRadius.circular(18),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: widget.url));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('已复制网页链接'),
                                              duration: Duration(seconds: 1),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                        child: const Text('复制链接', style: TextStyle(color: Colors.white, fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating Detected Video Native Play Banner
          if (_detectedVideoUrl != null && _detectedVideoUrl!.isNotEmpty && !_isLandscape)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: BouncingButton(
                onTap: () => _openInNativePlayer(_detectedVideoUrl!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: IosTheme.primaryPink.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.play_arrow_solid, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '已嗅探到视频流，点击切换内置原生播放器',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Icon(CupertinoIcons.chevron_right, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),

          // Floating Exit-Landscape Button Overlay (Guaranteed visible and accessible in landscape)
          if (_isLandscape)
            Positioned(
              top: MediaQuery.of(context).padding.top + 6,
              left: MediaQuery.of(context).padding.left + 12,
              child: BouncingButton(
                onTap: _toggleOrientation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.fullscreen_exit, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        '退出横屏',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
