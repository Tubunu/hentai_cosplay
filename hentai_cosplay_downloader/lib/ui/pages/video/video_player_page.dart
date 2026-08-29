import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../models/video_item.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import 'web_video_player_page.dart';

class VideoPlayerPage extends StatefulWidget {
  final List<LocalVideoItem>? playlist;
  final int initialIndex;
  final String? localFilePath;
  final String? remoteVideoUrl;
  final String? webPlayerUrl;
  final Map<String, String>? httpHeaders;
  final String title;
  final String author;

  const VideoPlayerPage({
    super.key,
    this.playlist,
    this.initialIndex = 0,
    this.localFilePath,
    this.remoteVideoUrl,
    this.webPlayerUrl,
    this.httpHeaders,
    required this.title,
    this.author = '',
  });

  static void openLocal(
    BuildContext context, {
    required LocalVideoItem video,
    List<LocalVideoItem>? playlist,
    int? initialIndex,
  }) {
    final list = playlist ?? [video];
    final index = initialIndex ?? (list.isNotEmpty ? list.indexOf(video).clamp(0, list.length - 1) : 0);

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => VideoPlayerPage(
          playlist: list,
          initialIndex: index,
          localFilePath: video.filePath,
          title: video.title,
          author: video.author,
        ),
      ),
    );
  }

  static void openRemote(
    BuildContext context, {
    required String url,
    required String title,
    String author = '',
    Map<String, String>? headers,
    String? webPlayerUrl,
  }) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => VideoPlayerPage(
          remoteVideoUrl: url,
          webPlayerUrl: webPlayerUrl,
          httpHeaders: headers,
          title: title,
          author: author,
        ),
      ),
    );
  }

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _controller;
  VideoPlayerController? _pendingController;
  bool _isDisposed = false;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isSeeking = false;
  double _sliderValue = 0.0;

  // Playlist state
  late int _currentIndex;
  late String _currentTitle;
  late String _currentAuthor;
  late String? _currentFilePath;
  late String? _currentRemoteUrl;
  late String? _currentWebPlayerUrl;
  late Map<String, String>? _currentHttpHeaders;
  int _initGen = 0;

  // Rotation and Display Controls
  int _quarterTurns = 0; // 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°
  bool _isLandscape = false;
  bool _isFillMode = false; // false = Contain, true = Cover/Fill

  bool get _hasPlaylist => widget.playlist != null && widget.playlist!.length > 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentTitle = widget.title;
    _currentAuthor = widget.author;
    _currentFilePath = widget.localFilePath;
    _currentRemoteUrl = widget.remoteVideoUrl;
    _currentWebPlayerUrl = widget.webPlayerUrl;
    _currentHttpHeaders = widget.httpHeaders;

    if (widget.playlist != null && widget.playlist!.isNotEmpty && _currentIndex < widget.playlist!.length) {
      final currentItem = widget.playlist![_currentIndex];
      _currentTitle = currentItem.title;
      _currentAuthor = currentItem.author;
      _currentFilePath = currentItem.filePath;
    }

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (_isDisposed) return;
    final currentGen = ++_initGen;

    // Safely dispose old controller before loading new stream
    final oldController = _controller;
    _controller = null;
    if (oldController != null) {
      oldController.removeListener(_onControllerUpdate);
      try {
        await oldController.pause();
      } catch (_) {}
      oldController.dispose();
    }

    try {
      VideoPlayerController? newController;
      if (_currentFilePath != null && _currentFilePath!.isNotEmpty) {
        final file = File(_currentFilePath!);
        if (!await file.exists()) {
          if (!mounted || _isDisposed || currentGen != _initGen) return;
          setState(() {
            _hasError = true;
            _errorMessage = '本地视频文件不存在或已被移除';
          });
          return;
        }
        newController = VideoPlayerController.file(file);
      } else if (_currentRemoteUrl != null && _currentRemoteUrl!.isNotEmpty) {
        Map<String, String> headers;
        if (_currentHttpHeaders != null && _currentHttpHeaders!.isNotEmpty) {
          headers = _currentHttpHeaders!;
        } else {
          String referer = 'https://cn.pornhub.com/';
          if (_currentWebPlayerUrl != null && _currentWebPlayerUrl!.isNotEmpty) {
            try {
              final uri = Uri.parse(_currentWebPlayerUrl!);
              referer = '${uri.scheme}://${uri.host}/';
            } catch (_) {}
          } else if (_currentRemoteUrl != null && _currentRemoteUrl!.isNotEmpty) {
            try {
              final uri = Uri.parse(_currentRemoteUrl!);
              referer = '${uri.scheme}://${uri.host}/';
            } catch (_) {}
          }
          headers = {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
            'Referer': referer,
            'Origin': referer.replaceAll(RegExp(r'/$'), ''),
            'Cookie':
                'age_verified=1; platform=pc; accessAgeDisclaimerPH=1; cookie_preferences=%7B%221%22%3A1%2C%222%22%3A1%2C%223%22%3A1%2C%224%22%3A1%7D; hasVisited=1;',
          };
        }
        newController = VideoPlayerController.networkUrl(
          Uri.parse(_currentRemoteUrl!),
          httpHeaders: headers,
        );
      } else {
        if (!mounted || _isDisposed || currentGen != _initGen) return;
        setState(() {
          _hasError = true;
          _errorMessage = '未提供有效的视频源';
        });
        return;
      }

      _pendingController = newController;
      await newController.initialize();
      _pendingController = null;

      if (!mounted || _isDisposed || currentGen != _initGen) {
        try {
          await newController.pause();
        } catch (_) {}
        newController.dispose();
        return;
      }

      _controller = newController;
      _controller!.addListener(_onControllerUpdate);
      _controller!.play();

      setState(() {
        _isInitialized = true;
      });

      _startHideTimer();
    } catch (e) {
      _pendingController = null;
      if (!mounted || _isDisposed || currentGen != _initGen) return;
      setState(() {
        _hasError = true;
        _errorMessage = '视频加载失败: $e';
      });
    }
  }

  void _onControllerUpdate() {
    final controller = _controller;
    if (!mounted || _isDisposed || !_isInitialized || controller == null) return;
    if (controller.value.position >= controller.value.duration && controller.value.duration > Duration.zero) {
      if (_hasPlaylist && !_isSeeking) {
        _playNext();
      }
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isDisposed && _controller?.value.isPlaying == true) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (!_isInitialized || controller == null) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        controller.play();
        _startHideTimer();
      }
    });
  }

  void _seekRelative(int seconds) {
    final controller = _controller;
    if (!_isInitialized || controller == null) return;
    final newPos = controller.value.position + Duration(seconds: seconds);
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : newPos > controller.value.duration
            ? controller.value.duration
            : newPos;
    controller.seekTo(clamped);
    _startHideTimer();
  }

  /// Switch video to a specified playlist index
  Future<void> _switchToIndex(int index) async {
    if (!_hasPlaylist || _isDisposed) return;
    final playlist = widget.playlist!;
    final safeIndex = (index + playlist.length) % playlist.length;
    final nextItem = playlist[safeIndex];

    _hideTimer?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onControllerUpdate);
      try {
        await controller.pause();
      } catch (_) {}
      controller.dispose();
    }

    if (!mounted || _isDisposed) return;

    setState(() {
      _currentIndex = safeIndex;
      _currentTitle = nextItem.title;
      _currentAuthor = nextItem.author;
      _currentFilePath = nextItem.filePath;
      _isInitialized = false;
      _hasError = false;
      _errorMessage = '';
      _sliderValue = 0.0;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在播放 [${safeIndex + 1}/${playlist.length}]: ${nextItem.title}'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
      ),
    );

    await _initPlayer();
  }

  /// Play previous video in current list order
  void _playPrevious() {
    if (!_hasPlaylist) return;
    _switchToIndex(_currentIndex - 1);
  }

  /// Play next video in current list order
  void _playNext() {
    if (!_hasPlaylist) return;
    _switchToIndex(_currentIndex + 1);
  }

  /// Play random video from playlist
  void _playRandom() {
    if (!_hasPlaylist || _controller == null) return;
    final playlist = widget.playlist!;
    if (playlist.length == 1) {
      _controller?.seekTo(Duration.zero);
      _controller?.play();
      return;
    }

    int nextIndex;
    final rng = math.Random();
    do {
      nextIndex = rng.nextInt(playlist.length);
    } while (nextIndex == _currentIndex && playlist.length > 1);

    _switchToIndex(nextIndex);
  }

  /// Rotate video content by 90 degrees
  void _rotateVideoContent() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
    });
    final angle = _quarterTurns * 90;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('画面已旋转 $angle°'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );
    _startHideTimer();
  }

  /// Toggle device screen orientation (Portrait <-> Landscape)
  void _toggleScreenOrientation() {
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
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _startHideTimer();
  }

  /// Toggle aspect ratio fill mode
  void _toggleFillMode() {
    setState(() {
      _isFillMode = !_isFillMode;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFillMode ? '已切换至：铺满全屏' : '已切换至：原始比例'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );
    _startHideTimer();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _isDisposed = true;
    _hideTimer?.cancel();
    _hideTimer = null;

    // Restore portrait orientation smoothly without triggering full activity rebuild
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    final pending = _pendingController;
    _pendingController = null;
    if (pending != null) {
      try {
        pending.pause();
      } catch (_) {}
      pending.dispose();
    }

    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onControllerUpdate);
      try {
        controller.pause();
      } catch (_) {}
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // Video Display with 90° Content Rotation & Aspect Ratio Options
            Center(
              child: _hasError
                  ? Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.exclamationmark_circle, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage.contains('Source error')
                                ? '该视频源受源站防盗链/安全策略保护，建议点击下方切换网页极速播放'
                                : _errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              CupertinoButton.filled(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                onPressed: () {
                                  setState(() {
                                    _hasError = false;
                                    _errorMessage = '';
                                  });
                                  _initPlayer();
                                },
                                child: const Text('重试播放', style: TextStyle(fontSize: 13)),
                              ),
                              if (_currentWebPlayerUrl != null && _currentWebPlayerUrl!.isNotEmpty) ...[
                                CupertinoButton(
                                  color: const Color(0xFFFF9900),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    WebVideoPlayerPage.open(context, url: _currentWebPlayerUrl!, title: _currentTitle);
                                  },
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.globe, size: 16, color: Colors.black),
                                      SizedBox(width: 6),
                                      Text('网页极速播放', style: TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    )
                  : (_isInitialized && _controller != null)
                      ? GestureDetector(
                          onTap: _toggleControls,
                          behavior: HitTestBehavior.opaque,
                          child: RotatedBox(
                            quarterTurns: _quarterTurns,
                            child: _isFillMode
                                ? SizedBox.expand(
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 16,
                                        height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 9,
                                        child: VideoPlayer(_controller!),
                                      ),
                                    ),
                                  )
                                : AspectRatio(
                                    aspectRatio: _controller!.value.aspectRatio > 0
                                        ? _controller!.value.aspectRatio
                                        : 16 / 9,
                                    child: VideoPlayer(_controller!),
                                  ),
                          ),
                        )
                      : const Center(
                          child: CupertinoActivityIndicator(color: Colors.white, radius: 16),
                        ),
            ),

            // Live Buffering Spinner Overlay for Remote Video Streams
            if (_isInitialized && _controller != null && _controller!.value.isBuffering)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12, width: 0.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoActivityIndicator(color: Colors.white, radius: 9),
                      SizedBox(width: 8),
                      Text(
                        '正在缓冲...',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            // Controls Overlay
            if (_showControls) ...[
              // Top Bar with Title and Action Buttons (Rotation, Fullscreen, Aspect)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back Button
                      BouncingButton(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(40),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.back, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title & Author & Playlist Index
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _currentTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (_hasPlaylist) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: IosTheme.primaryPink.withAlpha(180),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_currentIndex + 1}/${widget.playlist!.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (_currentAuthor.isNotEmpty)
                              Text(
                                _currentAuthor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 1. 90° Content Rotate Button
                      BouncingButton(
                        onTap: _rotateVideoContent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _quarterTurns > 0 ? IosTheme.primaryPink : Colors.white.withAlpha(40),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24, width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.rotate_right, color: Colors.white, size: 16),
                              if (_quarterTurns > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '${_quarterTurns * 90}°',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 2. Fit / Fill Toggle Button
                      BouncingButton(
                        onTap: _toggleFillMode,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isFillMode ? IosTheme.primaryPink : Colors.white.withAlpha(40),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 0.5),
                          ),
                          child: Icon(
                            _isFillMode ? Icons.fit_screen : Icons.aspect_ratio,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 3. Screen Orientation Switch (Portrait <-> Landscape)
                      BouncingButton(
                        onTap: _toggleScreenOrientation,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isLandscape ? IosTheme.primaryPink : Colors.white.withAlpha(40),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 0.5),
                          ),
                          child: Icon(
                            _isLandscape ? CupertinoIcons.device_phone_portrait : CupertinoIcons.device_phone_landscape,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Center Control Bar with Playlist Previous / Next / Random / Play / 10s Skips
              if (_isInitialized)
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Random Video Button (if playlist exists)
                      if (_hasPlaylist) ...[
                        BouncingButton(
                          onTap: _playRandom,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(CupertinoIcons.shuffle, color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Previous Video in List Order
                        BouncingButton(
                          onTap: _playPrevious,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(CupertinoIcons.backward_end_fill, color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],

                      // -10s
                      BouncingButton(
                        onTap: () => _seekRelative(-10),
                        child: Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(CupertinoIcons.gobackward_10, color: Colors.white, size: 24),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Large Play/Pause
                      BouncingButton(
                        onTap: _togglePlayPause,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF2D55), Color(0xFFFF2A6D)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF2D55).withAlpha(120),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: (_controller != null)
                              ? ValueListenableBuilder<VideoPlayerValue>(
                                  valueListenable: _controller!,
                                  builder: (context, val, _) {
                                    return Icon(
                                      val.isPlaying
                                          ? CupertinoIcons.pause_fill
                                          : CupertinoIcons.play_fill,
                                      color: Colors.white,
                                      size: 34,
                                    );
                                  },
                                )
                              : const SizedBox(),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // +10s
                      BouncingButton(
                        onTap: () => _seekRelative(10),
                        child: Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(CupertinoIcons.goforward_10, color: Colors.white, size: 24),
                        ),
                      ),

                      // Next Video in List Order (if playlist exists)
                      if (_hasPlaylist) ...[
                        const SizedBox(width: 14),
                        BouncingButton(
                          onTap: _playNext,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(CupertinoIcons.forward_end_fill, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Bottom Progress Bar & Time
              if (_isInitialized && _controller != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                      top: 16,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller!,
                      builder: (context, videoVal, _) {
                        final durationMs = videoVal.duration.inMilliseconds;
                        final positionMs = videoVal.position.inMilliseconds;
                        final currentProgress = (_isSeeking)
                            ? _sliderValue
                            : (durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0);

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3.5,
                                activeTrackColor: IosTheme.primaryPink,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayColor: IosTheme.primaryPink.withAlpha(40),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              ),
                              child: Slider(
                                value: currentProgress,
                                onChanged: (val) {
                                  setState(() {
                                    _isSeeking = true;
                                    _sliderValue = val;
                                  });
                                },
                                onChangeEnd: (val) {
                                  final totalMs = _controller?.value.duration.inMilliseconds ?? 0;
                                  final targetMs = (val * totalMs).toInt();
                                  _controller?.seekTo(Duration(milliseconds: targetMs));
                                  setState(() {
                                    _isSeeking = false;
                                  });
                                  _startHideTimer();
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(_isSeeking
                                        ? Duration(milliseconds: (_sliderValue * durationMs).toInt())
                                        : videoVal.position),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    _formatDuration(videoVal.duration),
                                    style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
