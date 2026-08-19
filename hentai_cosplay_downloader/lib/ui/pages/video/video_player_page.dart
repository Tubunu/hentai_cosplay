import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../models/video_item.dart';
import '../../widgets/bouncing_button.dart';

class VideoPlayerPage extends StatefulWidget {
  final String? localFilePath;
  final String? remoteVideoUrl;
  final String title;
  final String author;

  const VideoPlayerPage({
    super.key,
    this.localFilePath,
    this.remoteVideoUrl,
    required this.title,
    this.author = '',
  });

  static void openLocal(BuildContext context, LocalVideoItem video) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => VideoPlayerPage(
          localFilePath: video.filePath,
          title: video.title,
          author: video.author,
        ),
      ),
    );
  }

  static void openRemote(BuildContext context, {required String url, required String title, String author = ''}) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => VideoPlayerPage(
          remoteVideoUrl: url,
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
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isSeeking = false;
  double _sliderValue = 0.0;

  // Rotation and Display Controls
  int _quarterTurns = 0; // 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°
  bool _isLandscape = false;
  bool _isFillMode = false; // false = Contain, true = Cover/Fill

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.localFilePath != null && widget.localFilePath!.isNotEmpty) {
        final file = File(widget.localFilePath!);
        if (!await file.exists()) {
          setState(() {
            _hasError = true;
            _errorMessage = '本地视频文件不存在或已被移除';
          });
          return;
        }
        _controller = VideoPlayerController.file(file);
      } else if (widget.remoteVideoUrl != null && widget.remoteVideoUrl!.isNotEmpty) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.remoteVideoUrl!),
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36',
            'Referer': 'https://porn-video-xxx.com/',
          },
        );
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = '未提供有效的视频源';
        });
        return;
      }

      await _controller.initialize();
      _controller.addListener(_onControllerUpdate);
      _controller.play();

      setState(() {
        _isInitialized = true;
      });

      _startHideTimer();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = '视频加载失败: $e';
      });
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    if (!_isSeeking && _controller.value.isInitialized) {
      setState(() {
        final duration = _controller.value.duration.inMilliseconds;
        final position = _controller.value.position.inMilliseconds;
        if (duration > 0) {
          _sliderValue = (position / duration).clamp(0.0, 1.0);
        }
      });
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying) {
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
    if (!_isInitialized) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        _controller.play();
        _startHideTimer();
      }
    });
  }

  void _seekRelative(int seconds) {
    if (!_isInitialized) return;
    final newPos = _controller.value.position + Duration(seconds: seconds);
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : newPos > _controller.value.duration
            ? _controller.value.duration
            : newPos;
    _controller.seekTo(clamped);
    _startHideTimer();
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
        backgroundColor: const Color(0xFFFF2D55),
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
        backgroundColor: const Color(0xFFFF2D55),
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
    _hideTimer?.cancel();
    // Always restore system orientation & overlays when leaving player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (_isInitialized) {
      _controller.removeListener(_onControllerUpdate);
      _controller.dispose();
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
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            onPressed: () {
                              setState(() {
                                _hasError = false;
                                _errorMessage = '';
                              });
                              _initPlayer();
                            },
                            child: const Text('重试播放'),
                          ),
                        ],
                      ),
                    )
                  : _isInitialized
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
                                        width: _controller.value.size.width > 0 ? _controller.value.size.width : 16,
                                        height: _controller.value.size.height > 0 ? _controller.value.size.height : 9,
                                        child: VideoPlayer(_controller),
                                      ),
                                    ),
                                  )
                                : AspectRatio(
                                    aspectRatio: _controller.value.aspectRatio > 0
                                        ? _controller.value.aspectRatio
                                        : 16 / 9,
                                    child: VideoPlayer(_controller),
                                  ),
                          ),
                        )
                      : const Center(
                          child: CupertinoActivityIndicator(color: Colors.white, radius: 16),
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

                      // Title & Author
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (widget.author.isNotEmpty)
                              Text(
                                widget.author,
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
                            color: _quarterTurns > 0 ? const Color(0xFFFF2D55) : Colors.white.withAlpha(40),
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
                            color: _isFillMode ? const Color(0xFFFF2D55) : Colors.white.withAlpha(40),
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
                            color: _isLandscape ? const Color(0xFFFF2D55) : Colors.white.withAlpha(40),
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

              // Center Play / Pause & Skip Buttons
              if (_isInitialized)
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // -10s
                      BouncingButton(
                        onTap: () => _seekRelative(-10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(CupertinoIcons.gobackward_10, color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(width: 32),

                      // Play/Pause
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
                          child: Icon(
                            _controller.value.isPlaying
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),

                      // +10s
                      BouncingButton(
                        onTap: () => _seekRelative(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(CupertinoIcons.goforward_10, color: Colors.white, size: 28),
                        ),
                      ),
                    ],
                  ),
                ),

              // Bottom Progress Bar & Time
              if (_isInitialized)
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3.5,
                            activeTrackColor: const Color(0xFFFF2D55),
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayColor: const Color(0xFFFF2D55).withAlpha(40),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          ),
                          child: Slider(
                            value: _sliderValue,
                            onChanged: (val) {
                              setState(() {
                                _isSeeking = true;
                                _sliderValue = val;
                              });
                            },
                            onChangeEnd: (val) {
                              final totalMs = _controller.value.duration.inMilliseconds;
                              final targetMs = (val * totalMs).toInt();
                              _controller.seekTo(Duration(milliseconds: targetMs));
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
                                _formatDuration(_controller.value.position),
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                _formatDuration(_controller.value.duration),
                                style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
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
