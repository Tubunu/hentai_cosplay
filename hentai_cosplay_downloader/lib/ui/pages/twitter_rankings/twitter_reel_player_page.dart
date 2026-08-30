import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../../models/video_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/twitter_rankings/twitter_ranking_api_service.dart';
import '../../../services/twitter_rankings/twitter_site_config.dart';
import '../../widgets/bouncing_button.dart';

class TwitterReelPlayerPage extends StatefulWidget {
  final List<VideoItem> playlist;
  final int initialIndex;
  final TwitterSiteConfig site;

  const TwitterReelPlayerPage({
    super.key,
    required this.playlist,
    required this.initialIndex,
    required this.site,
  });

  @override
  State<TwitterReelPlayerPage> createState() => _TwitterReelPlayerPageState();
}

class _TwitterReelPlayerPageState extends State<TwitterReelPlayerPage> {
  late PageController _pageController;
  late int _currentIndex;

  // Controllers cache: index -> VideoPlayerController
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, bool> _isResolving = {};

  bool _showHeartAnimation = false;
  Offset _heartPosition = Offset.zero;

  // Scrubbing state
  bool _isScrubbing = false;
  Duration _scrubPosition = Duration.zero;
  Duration _scrubTotal = Duration.zero;

  void _recordCurrentHistory(int index) {
    if (index >= 0 && index < widget.playlist.length) {
      final video = widget.playlist[index];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<BrowsingHistoryProvider>().recordVideo(
            video,
            siteKey: 'twitter',
            siteName: widget.site.name.isNotEmpty ? widget.site.name : 'Twitter 榜',
            siteColor: const Color(0xFF1D9BF0),
          );
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Enter immersive full screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _recordCurrentHistory(_currentIndex);
    _initPlayerAtIndex(_currentIndex);
    if (_currentIndex + 1 < widget.playlist.length) {
      _initPlayerAtIndex(_currentIndex + 1);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initPlayerAtIndex(int index) async {
    if (index < 0 || index >= widget.playlist.length) return;
    if (_controllers.containsKey(index) || _isResolving[index] == true) return;

    _isResolving[index] = true;
    var video = widget.playlist[index];

    // Resolve direct video URL if not yet loaded
    if (video.videoUrl == null || video.videoUrl!.isEmpty) {
      try {
        video = await TwitterRankingApiService.resolveVideoDetail(widget.site, video);
        widget.playlist[index] = video;
      } catch (e) {
        debugPrint('Error resolving video at index $index: $e');
      }
    }

    if (!mounted) return;

    if (video.videoUrl != null && video.videoUrl!.isNotEmpty) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(video.videoUrl!),
        httpHeaders: const {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Referer': 'https://x.com/',
        },
      );

      try {
        await controller.initialize();
        await controller.setLooping(true);
        if (!mounted) {
          controller.dispose();
          return;
        }

        setState(() {
          _controllers[index] = controller;
          _isResolving[index] = false;
        });

        // Auto play if it's the active page
        if (index == _currentIndex) {
          controller.play();
        }
      } catch (e) {
        debugPrint('Error initializing video player at index $index: $e');
        if (mounted) {
          setState(() {
            _isResolving[index] = false;
          });
        }
      }
    } else {
      setState(() {
        _isResolving[index] = false;
      });
    }
  }

  void _onPageChanged(int index) {
    // Pause previous video
    if (_controllers.containsKey(_currentIndex)) {
      _controllers[_currentIndex]?.pause();
    }

    setState(() {
      _currentIndex = index;
    });

    _recordCurrentHistory(index);

    // Play current video
    if (_controllers.containsKey(index)) {
      _controllers[index]?.play();
    } else {
      _initPlayerAtIndex(index);
    }

    // Preload next video
    if (index + 1 < widget.playlist.length) {
      _initPlayerAtIndex(index + 1);
    }

    // Dispose far away controllers to save memory
    _controllers.keys.toList().forEach((k) {
      if ((k - index).abs() > 2) {
        _controllers[k]?.dispose();
        _controllers.remove(k);
      }
    });
  }

  void _onDoubleTap(TapDownDetails details) {
    setState(() {
      _heartPosition = details.localPosition;
      _showHeartAnimation = true;
    });

    HapticFeedback.mediumImpact();

    Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _showHeartAnimation = false;
        });
      }
    });
  }

  void _togglePlayPause() {
    final controller = _controllers[_currentIndex];
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  void _downloadCurrentVideo() {
    final video = widget.playlist[_currentIndex];
    final downloadProv = context.read<DownloadProvider>();
    downloadProv.addVideoTask(video);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 "${video.title}" 到下载队列'),
        backgroundColor: widget.site.themeColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Vertical PageView for TikTok Reel browsing
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: _isScrubbing
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: widget.playlist.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final video = widget.playlist[index];
              final controller = _controllers[index];
              final isResolving = _isResolving[index] == true;

              return GestureDetector(
                onTap: _togglePlayPause,
                onDoubleTapDown: _onDoubleTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video player or Thumbnail placeholder
                    if (controller != null && controller.value.isInitialized)
                      Center(
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                      )
                    else if (video.coverUrl != null && video.coverUrl!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: video.coverUrl!,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                          child: CupertinoActivityIndicator(color: Colors.white, radius: 16),
                        ),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(CupertinoIcons.play_rectangle, color: Colors.white54, size: 48),
                        ),
                      )
                    else
                      const Center(
                        child: CupertinoActivityIndicator(color: Colors.white, radius: 16),
                      ),

                    // Loading spinner
                    if (isResolving || (controller != null && controller.value.isBuffering))
                      const Center(
                        child: CupertinoActivityIndicator(color: Colors.white, radius: 18),
                      ),

                    // Paused Play Icon Overlay
                    if (controller != null && !controller.value.isPlaying && !isResolving && !_isScrubbing)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.play_fill,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),

                    // Bottom info gradient
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 40, 76, 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Author & Site badge
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: widget.site.themeColor.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(widget.site.icon, color: Colors.white, size: 11),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.site.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    video.author,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Video title / tweet text
                            Text(
                              video.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.25,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Stats
                            if (video.views.isNotEmpty)
                              Text(
                                video.views,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                            const SizedBox(height: 6),

                            // Interactive Draggable Video Progress Bar
                            if (controller != null && controller.value.isInitialized)
                              _TwitterVideoProgressBar(
                                controller: controller,
                                themeColor: widget.site.themeColor,
                                onScrubbingChanged: (isScrubbing, currentPos, totalDur) {
                                  setState(() {
                                    _isScrubbing = isScrubbing;
                                    _scrubPosition = currentPos;
                                    _scrubTotal = totalDur;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Right Side Action Buttons
                    Positioned(
                      right: 12,
                      bottom: 36,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Download Button
                          _buildActionButton(
                            icon: CupertinoIcons.arrow_down_circle_fill,
                            label: '下载',
                            color: widget.site.themeColor,
                            onTap: _downloadCurrentVideo,
                          ),
                          const SizedBox(height: 16),

                          // Share / Copy Link
                          _buildActionButton(
                            icon: CupertinoIcons.share,
                            label: '分享',
                            onTap: () {
                              Share.share('${video.title}\n${video.detailUrl}');
                            },
                          ),
                          const SizedBox(height: 16),

                          // Index badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${index + 1}/${widget.playlist.length}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Center Screen Scrubbing HUD
          if (_isScrubbing)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.site.themeColor.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.site.themeColor.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.arrow_left_right,
                      color: widget.site.themeColor,
                      size: 28,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatDuration(_scrubPosition)} / ${_formatDuration(_scrubTotal)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Double Tap Heart Animation
          if (_showHeartAnimation)
            Positioned(
              left: _heartPosition.dx - 45,
              top: _heartPosition.dy - 45,
              child: const Icon(
                CupertinoIcons.heart_fill,
                color: Color(0xFFFF2D55),
                size: 90,
              ),
            ),

          // Top Header Bar with Close Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BouncingButton(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.clear, color: Colors.white, size: 20),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.arrow_up_arrow_down, color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      const Text(
                        '上下滑切换',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return BouncingButton(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive draggable video progress bar with time tags
class _TwitterVideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  final Color themeColor;
  final void Function(bool isScrubbing, Duration current, Duration total) onScrubbingChanged;

  const _TwitterVideoProgressBar({
    required this.controller,
    required this.themeColor,
    required this.onScrubbingChanged,
  });

  @override
  State<_TwitterVideoProgressBar> createState() => _TwitterVideoProgressBarState();
}

class _TwitterVideoProgressBarState extends State<_TwitterVideoProgressBar> {
  bool _isDragging = false;
  double _dragRatio = 0.0;

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, val, _) {
        if (!val.isInitialized) return const SizedBox.shrink();

        final durationMs = val.duration.inMilliseconds;
        final positionMs = val.position.inMilliseconds;
        final currentRatio = _isDragging
            ? _dragRatio
            : (durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0);

        final currentDuration = _isDragging
            ? Duration(milliseconds: (_dragRatio * durationMs).toInt())
            : val.position;
        final totalDuration = val.duration;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Time tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isDragging
                        ? widget.themeColor.withValues(alpha: 0.9)
                        : Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_formatDuration(currentDuration)} / ${_formatDuration(totalDuration)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: _isDragging ? FontWeight.bold : FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (_isDragging)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.themeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.arrow_left_right, size: 9, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          '拖动进度条',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),

            // Draggable Slider
            SliderTheme(
              data: SliderThemeData(
                trackHeight: _isDragging ? 5.0 : 3.0,
                activeTrackColor: widget.themeColor,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: _isDragging ? 8.0 : 4.5,
                  elevation: 4,
                  pressedElevation: 8,
                ),
                overlayColor: widget.themeColor.withValues(alpha: 0.35),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackShape: const RectangularSliderTrackShape(),
              ),
              child: Slider(
                value: currentRatio.clamp(0.0, 1.0),
                onChangeStart: (val) {
                  setState(() {
                    _isDragging = true;
                    _dragRatio = val;
                  });
                  final targetMs = (val * durationMs).toInt();
                  widget.onScrubbingChanged(
                    true,
                    Duration(milliseconds: targetMs),
                    totalDuration,
                  );
                  HapticFeedback.selectionClick();
                },
                onChanged: (val) {
                  setState(() {
                    _dragRatio = val;
                  });
                  final targetMs = (val * durationMs).toInt();
                  widget.onScrubbingChanged(
                    true,
                    Duration(milliseconds: targetMs),
                    totalDuration,
                  );
                  HapticFeedback.selectionClick();
                },
                onChangeEnd: (val) {
                  final targetMs = (val * durationMs).toInt();
                  final targetDuration = Duration(milliseconds: targetMs);
                  widget.controller.seekTo(targetDuration);
                  setState(() {
                    _isDragging = false;
                  });
                  widget.onScrubbingChanged(
                    false,
                    targetDuration,
                    totalDuration,
                  );
                  HapticFeedback.mediumImpact();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
