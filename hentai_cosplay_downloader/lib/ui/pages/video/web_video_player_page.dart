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

                      // Refresh Button
                      BouncingButton(
                        onTap: () => _webViewController?.reload(),
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
                    value: _progress,
                    minHeight: 2.5,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(IosTheme.primaryPink),
                  ),

                // WebView Body
                Expanded(
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
                      useShouldOverrideUrlLoading: true,
                      preferredContentMode: UserPreferredContentMode.DESKTOP,
                    ),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                    },
                    onProgressChanged: (controller, progress) {
                      setState(() {
                        _progress = progress / 100;
                        _isLoading = progress < 100;
                      });
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
                      setState(() {
                        _isLoading = false;
                      });
                      // Clean intrusive popups, auto-play video element, and detect video source
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
                    },
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
