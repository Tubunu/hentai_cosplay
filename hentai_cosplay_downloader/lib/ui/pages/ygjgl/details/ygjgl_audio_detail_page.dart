import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../../models/download_task.dart';
import '../../../../models/favorite_item.dart';
import '../../../../models/ygjgl/ygjgl_post_item.dart';
import '../../../../providers/browsing_history_provider.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/favorite_provider.dart';
import '../../../../services/ygjgl/ygjgl_api_service.dart';
import '../../../../utils/app_share.dart';
import '../../../widgets/bouncing_button.dart';
import '../../../widgets/unified_photo_viewer.dart';

class YgjglAudioDetailPage extends StatefulWidget {
  final YgjglPostItem item;

  const YgjglAudioDetailPage({super.key, required this.item});

  @override
  State<YgjglAudioDetailPage> createState() => _YgjglAudioDetailPageState();
}

class _YgjglAudioDetailPageState extends State<YgjglAudioDetailPage>
    with SingleTickerProviderStateMixin {
  late YgjglPostItem _item;
  VideoPlayerController? _audioController;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );

    _loadDetailAndAudio();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BrowsingHistoryProvider>().recordVideo(
              _item.toVideoItem(),
              siteKey: 'ygjgl_audio',
              siteName: '一个够了 · 电台',
              siteColor: const Color(0xFF5856D6),
            );
      }
    });
  }

  Future<void> _loadDetailAndAudio() async {
    final detail = await YgjglApiService.fetchPostDetail(_item.id, defaultKind: 'audio');
    if (detail != null && mounted) {
      setState(() => _item = detail);
    }

    if (mounted && _item.audioUrl.isNotEmpty) {
      _initAudioPlayer(_item.audioUrl);
    }
  }

  void _initAudioPlayer(String url) async {
    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: const {
          'Referer': 'https://ygjgl.one/',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        },
      );
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      ctrl.addListener(() {
        if (!mounted) return;
        final playing = ctrl.value.isPlaying;
        final pos = ctrl.value.position;
        final dur = ctrl.value.duration;

        if (playing != _isPlaying) {
          setState(() {
            _isPlaying = playing;
            if (playing) {
              _rotationController.repeat();
            } else {
              _rotationController.stop();
            }
          });
        }
        setState(() {
          _position = pos;
          _duration = dur;
        });
      });

      setState(() {
        _audioController = ctrl;
      });
      // Auto play
      ctrl.play();
    } catch (_) {}
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _audioController?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  void _togglePlayPause() {
    if (_audioController == null) return;
    if (_audioController!.value.isPlaying) {
      _audioController!.pause();
    } else {
      _audioController!.play();
    }
  }

  void _seekRelative(int seconds) {
    if (_audioController == null) return;
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration ? _duration : target);
    _audioController!.seekTo(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentPurple = Color(0xFF5856D6);
    const accentPink = Color(0xFFFF5A8A);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        title: const Text('电台广播', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          // Share
          IconButton(
            icon: const Icon(CupertinoIcons.share),
            onPressed: () {
              AppShare.share(
                context,
                '【一个够了 · 电台】${_item.title}\nhttps://ygjgl.one/post?id=${_item.id}',
              );
            },
          ),
          // Favorite
          Consumer<FavoriteProvider>(
            builder: (context, favProv, _) {
              final isFav = favProv.isFavoriteItem(
                id: _item.id,
                detailUrl: 'https://ygjgl.one/post?id=${_item.id}',
              );
              return IconButton(
                icon: Icon(
                  isFav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  color: isFav ? accentPink : null,
                ),
                onPressed: () {
                  final favItem = FavoriteItem(
                    id: _item.id,
                    title: _item.title,
                    coverUrl: _item.cover,
                    detailUrl: 'https://ygjgl.one/post?id=${_item.id}',
                    author: _item.tags.isNotEmpty ? _item.tags.first : '电台',
                    date: _item.published,
                    mediaType: 'video',
                    siteKey: 'ygjgl_audio',
                    siteName: '一个够了 · 电台',
                    tags: _item.tags,
                    videoUrl: _item.audioUrl,
                    addedAt: DateTime.now(),
                  );
                  favProv.toggleFavorite(favItem);
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // 1. Vinyl / Rotating Artwork
              Center(
                child: RotationTransition(
                  turns: _rotationController,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isPlaying ? accentPurple : Colors.black).withOpacity(0.35),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: _item.cover,
                            fit: BoxFit.cover,
                            httpHeaders: const {
                              'Referer': 'https://ygjgl.one/',
                            },
                          ),
                          // Center vinyl hole
                          Center(
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black26, width: 4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 2. Title & speaker
              Text(
                _item.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              if (_item.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _item.text.trim(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // 3. Audio Progress Slider
              Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accentPurple,
                      inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                      thumbColor: accentPurple,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _duration.inMilliseconds > 0
                          ? _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble()
                          : 0.0,
                      max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                      onChanged: (val) {
                        if (_audioController != null) {
                          _audioController!.seekTo(Duration(milliseconds: val.toInt()));
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Playback Controls (-15s, Play/Pause, +15s)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rewind 15s
                  IconButton(
                    iconSize: 32,
                    icon: const Icon(CupertinoIcons.gobackward_15),
                    color: isDark ? Colors.white70 : Colors.black87,
                    onPressed: () => _seekRelative(-15),
                  ),
                  const SizedBox(width: 24),

                  // Play / Pause Button
                  BouncingButton(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5856D6), Color(0xFF7A79E2)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentPurple.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Forward 15s
                  IconButton(
                    iconSize: 32,
                    icon: const Icon(CupertinoIcons.goforward_15),
                    color: isDark ? Colors.white70 : Colors.black87,
                    onPressed: () => _seekRelative(15),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. Download Button
              Consumer<DownloadProvider>(
                builder: (context, downloadProv, _) {
                  final vItem = _item.toVideoItem();
                  final status = downloadProv.getTaskStatus(
                    slug: vItem.slug,
                    detailUrl: vItem.detailUrl,
                    title: vItem.title,
                  );

                  final isDownloaded = status == TaskStatus.completed;
                  final isDownloading = status == TaskStatus.downloading || status == TaskStatus.queued;

                  return BouncingButton(
                    onTap: () {
                      if (isDownloaded) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('该音频已在下载任务中完成')),
                        );
                      } else if (!isDownloading) {
                        downloadProv.addVideoTask(vItem);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已加入下载任务: ${_item.title}')),
                        );
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E5EA),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isDownloaded
                                ? CupertinoIcons.check_mark_circled_solid
                                : (isDownloading
                                    ? CupertinoIcons.arrow_down_circle_fill
                                    : CupertinoIcons.arrow_down_to_line),
                            size: 19,
                            color: isDownloaded
                                ? const Color(0xFF34C759)
                                : (isDownloading ? accentPurple : (isDark ? Colors.white : Colors.black87)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isDownloaded ? '音频已下载' : (isDownloading ? '正在下载音频...' : '下载该电台音频 (MP3)'),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: isDownloaded
                                  ? const Color(0xFF34C759)
                                  : (isDownloading ? accentPurple : (isDark ? Colors.white : Colors.black87)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // 6. Accompanying Photos Gallery (if any)
              if (_item.images.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '伴随写真 (${_item.images.length}张)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _item.images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final imgUrl = _item.images[idx];
                      return GestureDetector(
                        onTap: () {
                          UnifiedPhotoViewer.open(
                            context,
                            imageUrls: _item.images,
                            initialIndex: idx,
                            title: _item.title,
                            httpHeaders: const {
                              'Referer': 'https://ygjgl.one/',
                            },
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AspectRatio(
                            aspectRatio: 0.75,
                            child: CachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.cover,
                              httpHeaders: const {
                                'Referer': 'https://ygjgl.one/',
                              },
                              placeholder: (_, __) => Container(
                                color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFF0F0F2),
                                child: const Center(child: CupertinoActivityIndicator()),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
