import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../models/video_item.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../../services/playback_progress_service.dart';
import 'web_video_player_page.dart';

enum VideoScaleMode {
  contain('原始比例', '自适应居中，黑边填充', Icons.aspect_ratio),
  cover('裁剪铺满', '保持比例填满，边缘裁剪', Icons.crop_free),
  stretch('拉伸铺满', '强制拉伸画面至全屏', Icons.fit_screen),
  ratio16_9('16:9', '强制 16:9 宽屏比例', Icons.tv),
  ratio4_3('4:3', '强制 4:3 标清比例', Icons.crop_portrait);

  final String label;
  final String description;
  final IconData icon;

  const VideoScaleMode(this.label, this.description, this.icon);

  VideoScaleMode next() {
    final nextIndex = (index + 1) % VideoScaleMode.values.length;
    return VideoScaleMode.values[nextIndex];
  }
}

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
  VideoScaleMode _scaleMode = VideoScaleMode.contain;

  // Playback features & gestures
  double _playbackSpeed = 1.0;
  bool _isScreenLocked = false;
  bool _isLongPressingSpeed = false;
  String? _quickSeekIndicator;
  Timer? _seekIndicatorTimer;
  bool _showLockControl = true;
  Timer? _lockControlTimer;

  // 亮度与音量手势
  double _brightnessLevel = 1.0; // 0.1 ~ 1.0
  double _volumeLevel = 1.0; // 0.0 ~ 1.0
  String? _hudType; // 'brightness' or 'volume'
  double _hudValue = 1.0;
  Timer? _hudTimer;
  bool _isDraggingGesture = false;

  // 断点续播状态
  int _lastSavedSecond = 0;
  String? _resumeToastText;
  Timer? _resumeToastTimer;

  String get _currentVideoKey => PlaybackProgressService.computeKey(
    filePath: _currentFilePath,
    webPlayerUrl: _currentWebPlayerUrl,
    title: _currentTitle,
    remoteUrl: _currentRemoteUrl,
  );

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
      if (_playbackSpeed != 1.0) {
        _controller!.setPlaybackSpeed(_playbackSpeed);
      }
      if (_volumeLevel != 1.0) {
        _controller!.setVolume(_volumeLevel);
      }
      _controller!.play();
      WakelockPlus.enable().catchError((_) {});

      // 自动检测并恢复断点续播进度
      final key = _currentVideoKey;
      final savedSeconds = await PlaybackProgressService.getProgress(key);
      if (savedSeconds != null && savedSeconds > 10 && _controller != null && mounted) {
        final targetPos = Duration(seconds: savedSeconds);
        final dur = _controller!.value.duration;
        // 如果时长未就绪或播放点未到最后 3 秒，均允许断点恢复
        if (dur == Duration.zero || targetPos < dur - const Duration(seconds: 3)) {
          await _controller!.seekTo(targetPos);
          if (mounted) {
            _showResumeToast(savedSeconds);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });

      _startHideTimer();
    } catch (e) {
      _pendingController = null;
      WakelockPlus.disable().catchError((_) {});
      if (!mounted || _isDisposed || currentGen != _initGen) return;
      setState(() {
        _hasError = true;
        _errorMessage = '视频加载失败: $e';
      });
    }
  }

  void _showResumeToast(int savedSeconds) {
    final timeStr = _formatDuration(Duration(seconds: savedSeconds));
    setState(() {
      _resumeToastText = '已恢复至上次播放进度 $timeStr';
    });
    _resumeToastTimer?.cancel();
    _resumeToastTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _resumeToastText = null;
        });
      }
    });
  }

  void _restartFromBeginning() {
    _controller?.seekTo(Duration.zero);
    PlaybackProgressService.clearProgress(_currentVideoKey);
    setState(() {
      _resumeToastText = null;
    });
  }

  void _onControllerUpdate() {
    final controller = _controller;
    if (!mounted || _isDisposed || !_isInitialized || controller == null) return;

    // 定期保存播放进度（每 5 秒存一次）
    final currentSecond = controller.value.position.inSeconds;
    if ((currentSecond - _lastSavedSecond).abs() >= 5) {
      _lastSavedSecond = currentSecond;
      PlaybackProgressService.saveProgress(
        key: _currentVideoKey,
        positionSeconds: currentSecond,
        durationSeconds: controller.value.duration.inSeconds,
      );
    }

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
    if (_isScreenLocked) {
      setState(() {
        _showLockControl = !_showLockControl;
      });
      if (_showLockControl) {
        _startLockControlTimer();
      }
      return;
    }
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _startLockControlTimer() {
    _lockControlTimer?.cancel();
    _lockControlTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isScreenLocked) {
        setState(() {
          _showLockControl = false;
        });
      }
    });
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (!_isInitialized || controller == null) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        WakelockPlus.disable().catchError((_) {});
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        controller.play();
        WakelockPlus.enable().catchError((_) {});
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

  void _handleDoubleTapDown(TapDownDetails details) {
    if (_isScreenLocked || !_isInitialized || _controller == null) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLeft = details.globalPosition.dx < screenWidth / 2;
    final seconds = isLeft ? -10 : 10;
    _seekRelative(seconds);
    HapticFeedback.selectionClick();
    setState(() {
      _quickSeekIndicator = isLeft ? '-10s' : '+10s';
    });
    _seekIndicatorTimer?.cancel();
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 750), () {
      if (mounted) {
        setState(() {
          _quickSeekIndicator = null;
        });
      }
    });
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    if (_isScreenLocked || !_isInitialized || _controller == null) return;
    if (_controller!.value.isPlaying) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isLongPressingSpeed = true;
      });
      _controller!.setPlaybackSpeed(2.0);
    }
  }

  void _handleLongPressEnd([LongPressEndDetails? details]) {
    if (_isLongPressingSpeed && _controller != null) {
      HapticFeedback.lightImpact();
      setState(() {
        _isLongPressingSpeed = false;
      });
      _controller!.setPlaybackSpeed(_playbackSpeed);
    }
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    if (_isScreenLocked || !_isInitialized || _controller == null) return;
    _isDraggingGesture = true;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLeft = details.globalPosition.dx < screenWidth / 2;
    setState(() {
      _hudType = isLeft ? 'brightness' : 'volume';
      _hudValue = isLeft ? _brightnessLevel : _volumeLevel;
    });
    _hudTimer?.cancel();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDraggingGesture || _isScreenLocked || !_isInitialized || _controller == null) return;
    final screenHeight = MediaQuery.of(context).size.height;
    // 向上滑动增加数值，向下滑动减少数值
    final deltaFraction = -details.delta.dy / (screenHeight * 0.7);

    setState(() {
      if (_hudType == 'brightness') {
        _brightnessLevel = (_brightnessLevel + deltaFraction).clamp(0.1, 1.0);
        _hudValue = _brightnessLevel;
      } else if (_hudType == 'volume') {
        _volumeLevel = (_volumeLevel + deltaFraction).clamp(0.0, 1.0);
        _hudValue = _volumeLevel;
        _controller?.setVolume(_volumeLevel);
      }
    });
  }

  void _handleVerticalDragEnd([DragEndDetails? details]) {
    _isDraggingGesture = false;
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _hudType = null;
        });
      }
    });
  }

  Widget _buildGestureHud() {
    final isBrightness = _hudType == 'brightness';
    final percentage = (_hudValue * 100).round();
    final IconData icon = isBrightness
        ? (_hudValue > 0.5 ? CupertinoIcons.sun_max_fill : CupertinoIcons.sun_min_fill)
        : (_hudValue == 0
            ? CupertinoIcons.volume_off
            : (_hudValue > 0.5 ? CupertinoIcons.volume_up : CupertinoIcons.volume_down));

    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(
            '$percentage%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _hudValue,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(IosTheme.primaryPink),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeToast() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xE61C1C1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.arrow_clockwise_circle_fill, color: IosTheme.primaryPink, size: 16),
          const SizedBox(width: 8),
          Text(
            _resumeToastText!,
            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _restartFromBeginning,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: IosTheme.primaryPink.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '从头开始',
                style: TextStyle(color: IosTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSpeedSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('播放倍速'),
        actions: [0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
          final isSelected = _playbackSpeed == speed;
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() {
                _playbackSpeed = speed;
              });
              _controller?.setPlaybackSpeed(speed);
              Navigator.pop(ctx);
              _startHideTimer();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected) ...[
                  const Icon(CupertinoIcons.checkmark_alt, color: IosTheme.primaryPink, size: 18),
                  const SizedBox(width: 6),
                ],
                Text(
                  '${speed}x',
                  style: TextStyle(
                    color: isSelected ? IosTheme.primaryPink : null,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  /// Switch video to a specified playlist index
  Future<void> _switchToIndex(int index) async {
    if (!_hasPlaylist || _isDisposed) return;
    final playlist = widget.playlist!;
    final safeIndex = (index + playlist.length) % playlist.length;
    final nextItem = playlist[safeIndex];

    _hideTimer?.cancel();
    _resumeToastTimer?.cancel();
    _resumeToastText = null;
    _lastSavedSecond = 0;

    // 保存切歌前当前视频的播放进度
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      PlaybackProgressService.saveProgress(
        key: _currentVideoKey,
        positionSeconds: controller.value.position.inSeconds,
        durationSeconds: controller.value.duration.inSeconds,
      );
    }
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

  /// Toggle aspect ratio scale mode (cycle to next)
  void _toggleScaleMode() {
    setState(() {
      _scaleMode = _scaleMode.next();
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已切换比例：${_scaleMode.label} (${_scaleMode.description})'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );
    _startHideTimer();
  }

  /// Show scale mode picker sheet
  void _showScaleModePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择画面比例'),
        message: const Text('针对不同片源比例或变形片源切换适合的显示模式'),
        actions: VideoScaleMode.values.map((mode) {
          final isSelected = mode == _scaleMode;
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _scaleMode = mode;
              });
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已切换比例：${mode.label}'),
                  backgroundColor: IosTheme.primaryPink,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(milliseconds: 900),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(mode.icon, size: 18, color: isSelected ? IosTheme.primaryPink : null),
                const SizedBox(width: 8),
                Text(
                  mode.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? IosTheme.primaryPink : null,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  const Icon(CupertinoIcons.checkmark, size: 16, color: IosTheme.primaryPink),
                ],
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  /// Builds the video surface with correct aspect ratio and scaling
  Widget _buildVideoSurface() {
    if (_controller == null || !_isInitialized) {
      return const SizedBox.shrink();
    }

    final videoVal = _controller!.value;
    final videoSize = videoVal.size;
    final double rawRatio = videoVal.aspectRatio;
    final double originalRatio = rawRatio > 0
        ? rawRatio
        : (videoSize.width > 0 && videoSize.height > 0
            ? videoSize.width / videoSize.height
            : 16 / 9);

    switch (_scaleMode) {
      case VideoScaleMode.contain:
        // 核心修复：必须通过 Center 提供 loose constraints，AspectRatio 才能生效！
        return Center(
          child: AspectRatio(
            aspectRatio: originalRatio,
            child: VideoPlayer(_controller!),
          ),
        );

      case VideoScaleMode.cover:
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: videoSize.width > 0 ? videoSize.width : 16,
              height: videoSize.height > 0 ? videoSize.height : 9,
              child: VideoPlayer(_controller!),
            ),
          ),
        );

      case VideoScaleMode.stretch:
        return SizedBox.expand(
          child: VideoPlayer(_controller!),
        );

      case VideoScaleMode.ratio16_9:
        return Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: VideoPlayer(_controller!),
          ),
        );

      case VideoScaleMode.ratio4_3:
        return Center(
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: VideoPlayer(_controller!),
          ),
        );
    }
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
    _seekIndicatorTimer?.cancel();
    _lockControlTimer?.cancel();
    _hudTimer?.cancel();
    _resumeToastTimer?.cancel();
    WakelockPlus.disable().catchError((_) {});

    // 保存退出时的最后播放进度
    final currentCtrl = _controller;
    if (currentCtrl != null && currentCtrl.value.isInitialized) {
      PlaybackProgressService.saveProgress(
        key: _currentVideoKey,
        positionSeconds: currentCtrl.value.position.inSeconds,
        durationSeconds: currentCtrl.value.duration.inSeconds,
      );
    }

    // Restore default orientation and system UI
    SystemChrome.setPreferredOrientations([]);
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
    return PopScope(
      canPop: !_isScreenLocked,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isScreenLocked) {
          setState(() {
            _showLockControl = true;
          });
          _startLockControlTimer();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('屏幕已锁定，请先点击左侧锁图标解锁'),
              backgroundColor: IosTheme.primaryPink,
              behavior: SnackBarBehavior.floating,
              duration: Duration(milliseconds: 1500),
            ),
          );
        }
      },
      child: Scaffold(
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
                          onDoubleTapDown: _handleDoubleTapDown,
                          onDoubleTap: () {},
                          onLongPressStart: _handleLongPressStart,
                          onLongPressEnd: _handleLongPressEnd,
                          onLongPressCancel: () => _handleLongPressEnd(),
                          onVerticalDragStart: _handleVerticalDragStart,
                          onVerticalDragUpdate: _handleVerticalDragUpdate,
                          onVerticalDragEnd: _handleVerticalDragEnd,
                          onVerticalDragCancel: () => _handleVerticalDragEnd(),
                          behavior: HitTestBehavior.opaque,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              RotatedBox(
                                quarterTurns: _quarterTurns,
                                child: _buildVideoSurface(),
                              ),
                              // 软件平滑亮度调节蒙层
                              if (_brightnessLevel < 0.99)
                                IgnorePointer(
                                  child: Container(
                                    color: Colors.black.withValues(alpha: (1.0 - _brightnessLevel) * 0.85),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : const Center(
                          child: CupertinoActivityIndicator(color: Colors.white, radius: 16),
                        ),
            ),

            // 亮度与音量手势悬浮胶囊 HUD
            if (_hudType != null)
              IgnorePointer(
                child: Center(
                  child: _buildGestureHud(),
                ),
              ),

            // 断点续播恢复提示条
            if (_resumeToastText != null)
              Positioned(
                bottom: 85,
                left: 20,
                right: 20,
                child: Center(
                  child: _buildResumeToast(),
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

            // Live Seek Indicator Overlay (+10s / -10s)
            if (_quickSeekIndicator != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _quickSeekIndicator!.startsWith('+') ? CupertinoIcons.goforward_10 : CupertinoIcons.gobackward_10,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _quickSeekIndicator!,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            // Live 2.0x Fast Forwarding Badge Overlay (Triggered by Long Press)
            if (_isLongPressingSpeed)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: IosTheme.primaryPink, width: 1.2),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.forward_fill, color: IosTheme.primaryPink, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '2.0x 快进中',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            // Screen Lock Toggle Button (Left Edge, Floating)
            if ((_showControls || _isScreenLocked) && _showLockControl && _isInitialized)
              Positioned(
                left: 16,
                top: MediaQuery.of(context).size.height / 2 - 24,
                child: SafeArea(
                  child: BouncingButton(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      setState(() {
                        _isScreenLocked = !_isScreenLocked;
                        if (_isScreenLocked) {
                          _showControls = false;
                          _showLockControl = true;
                          _startLockControlTimer();
                        } else {
                          _showControls = true;
                          _startHideTimer();
                        }
                      });
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_isScreenLocked ? '屏幕已锁定，防误触生效' : '屏幕已解锁'),
                          backgroundColor: IosTheme.primaryPink,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(milliseconds: 900),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isScreenLocked ? IosTheme.primaryPink : Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 0.8),
                        boxShadow: [
                          if (_isScreenLocked)
                            BoxShadow(
                              color: IosTheme.primaryPink.withAlpha(120),
                              blurRadius: 10,
                            ),
                        ],
                      ),
                      child: Icon(
                        _isScreenLocked ? CupertinoIcons.lock_fill : CupertinoIcons.lock_open,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

            // Controls Overlay
            if (_showControls && !_isScreenLocked) ...[
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

                      // 2. Aspect Ratio Scale Mode Toggle Button (Tap to cycle, Long-press to choose)
                      BouncingButton(
                        onTap: _toggleScaleMode,
                        onLongPress: _showScaleModePicker,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _scaleMode != VideoScaleMode.contain ? IosTheme.primaryPink : Colors.white.withAlpha(40),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 0.5),
                          ),
                          child: Icon(
                            _scaleMode.icon,
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
                      const SizedBox(width: 8),

                      // 4. Playback Speed Selector Button
                      BouncingButton(
                        onTap: _showSpeedSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: _playbackSpeed != 1.0 ? IosTheme.primaryPink : Colors.white.withAlpha(40),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24, width: 0.5),
                          ),
                          child: Text(
                            '${_playbackSpeed}x',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                                onChangeStart: (val) {
                                  _hideTimer?.cancel();
                                  setState(() {
                                    _isSeeking = true;
                                    _sliderValue = val;
                                  });
                                },
                                onChanged: (val) {
                                  _hideTimer?.cancel();
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
    ),
  );
}
}
