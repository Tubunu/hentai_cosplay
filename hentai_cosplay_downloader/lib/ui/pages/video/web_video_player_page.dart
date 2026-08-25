import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';

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

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
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
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: !_isLandscape,
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
                    onTap: () => Navigator.pop(context),
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
                onLoadStop: (controller, url) async {
                  setState(() {
                    _isLoading = false;
                  });
                  // Clean intrusive popups and auto-play video element
                  await controller.evaluateJavascript(source: """
                    (function() {
                      // Attempt to trigger video autoplay
                      var v = document.querySelector('video');
                      if (v) {
                        v.muted = false;
                        v.play().catch(function(){});
                      }
                      // Hide common ad overlays
                      var ads = document.querySelectorAll('.ad, .ads, [id*="ad-"], [class*="popup"], [id*="banner"]');
                      ads.forEach(function(el) { el.style.display = 'none'; });
                    })();
                  """);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
