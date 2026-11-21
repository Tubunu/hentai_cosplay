import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../../models/download_task.dart';
import '../../../../models/favorite_item.dart';
import '../../../../models/ygjgl/ygjgl_vod_item.dart';
import '../../../../providers/browsing_history_provider.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/favorite_provider.dart';
import '../../../../services/ygjgl/ygjgl_api_service.dart';
import '../../../../utils/app_share.dart';
import '../../../widgets/bouncing_button.dart';
import '../../../widgets/unified_photo_viewer.dart';
import '../../video/video_player_page.dart';
import '../../video/web_video_player_page.dart';

class YgjglVodDetailPage extends StatefulWidget {
  final YgjglVodItem item;

  const YgjglVodDetailPage({super.key, required this.item});

  @override
  State<YgjglVodDetailPage> createState() => _YgjglVodDetailPageState();
}

class _YgjglVodDetailPageState extends State<YgjglVodDetailPage> {
  late YgjglVodItem _item;
  bool _isLoading = true;
  String? _mp4Url;
  VideoPlayerController? _playerController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadDetailsAndStream();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BrowsingHistoryProvider>().recordVideo(
              _item.toVideoItem(),
              siteKey: 'ygjgl_vod',
              siteName: '一个够了 · 点播',
              siteColor: const Color(0xFFFF5A8A),
            );
      }
    });
  }

  Future<void> _loadDetailsAndStream() async {
    setState(() => _isLoading = true);

    // 1. Fetch full details (includes pics preview)
    final detail = await YgjglApiService.fetchVodDetail(_item.id);
    if (detail != null) {
      _item = detail;
    }

    // 2. Fetch MP4 URL
    final mp4 = await YgjglApiService.resolveVodStream(_item.id);
    _mp4Url = mp4;

    if (mounted) {
      setState(() => _isLoading = false);
      if (mp4 != null && mp4.isNotEmpty) {
        _initMiniPlayer(mp4);
      }
    }
  }

  void _initMiniPlayer(String url) async {
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
        if (playing != _isPlaying) {
          setState(() => _isPlaying = playing);
        }
      });
      setState(() {
        _playerController = ctrl;
      });
    } catch (_) {
    }
  }

  @override
  void dispose() {
    _playerController?.dispose();
    super.dispose();
  }

  void _openFullScreenPlayer() {
    if (_mp4Url != null && _mp4Url!.isNotEmpty) {
      _playerController?.pause();
      VideoPlayerPage.openRemote(
        context,
        url: _mp4Url!,
        title: _item.title,
        author: _item.actor,
        webPlayerUrl: 'https://ygjgl.one/play?id=${_item.id}',
        headers: const {
          'Referer': 'https://ygjgl.one/',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        },
      );
    } else {
      WebVideoPlayerPage.open(
        context,
        url: 'https://ygjgl.one/play?id=${_item.id}',
        title: _item.title,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentPink = Color(0xFFFF5A8A);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF7F8FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Cupertino-style Navigation Bar
          SliverAppBar(
            pinned: true,
            expandedHeight: 250,
            backgroundColor: isDark ? const Color(0xFF1A1A1E) : Colors.white,
            foregroundColor: isDark ? Colors.white : Colors.black,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // Share button
              IconButton(
                icon: const Icon(CupertinoIcons.share),
                onPressed: () {
                  AppShare.share(
                    context,
                    '【一个够了】${_item.title}\nhttps://ygjgl.one/play?id=${_item.id}',
                  );
                },
              ),
              // Favorite button
              Consumer<FavoriteProvider>(
                builder: (context, favProv, _) {
                  final isFav = favProv.isFavoriteItem(
                    id: _item.id,
                    detailUrl: 'https://ygjgl.one/play?id=${_item.id}',
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
                        coverUrl: _item.coverUrl,
                        detailUrl: 'https://ygjgl.one/play?id=${_item.id}',
                        author: _item.actor,
                        date: _item.published,
                        mediaType: 'video',
                        siteKey: 'ygjgl_vod',
                        siteName: '一个够了 · 点播',
                        duration: _item.duration,
                        tags: _item.tags,
                        videoUrl: _mp4Url,
                        addedAt: DateTime.now(),
                      );
                      favProv.toggleFavorite(favItem);
                    },
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Video player or cover poster
                  if (_playerController != null && _playerController!.value.isInitialized)
                    GestureDetector(
                      onTap: () {
                        if (_playerController!.value.isPlaying) {
                          _playerController!.pause();
                        } else {
                          _playerController!.play();
                        }
                      },
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _playerController!.value.aspectRatio,
                          child: VideoPlayer(_playerController!),
                        ),
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: _item.coverUrl,
                      fit: BoxFit.cover,
                      httpHeaders: const {
                        'Referer': 'https://ygjgl.one/',
                      },
                    ),

                  // Overlay gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),

                  // Center Play Button / Loading Indicator
                  Center(
                    child: _isLoading
                        ? const CupertinoActivityIndicator(radius: 16, color: Colors.white)
                        : BouncingButton(
                            onTap: _openFullScreenPlayer,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: accentPink.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accentPink.withOpacity(0.5),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                CupertinoIcons.play_fill,
                                size: 30,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),

                  // Bottom badges
                  Positioned(
                    left: 16,
                    bottom: 12,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _item.isFree ? const Color(0xFF34C759) : accentPink,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _item.isFree ? '免费' : 'VIP',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_item.duration.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            _item.duration,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                        if (_item.size.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            _item.size,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _item.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Key-Value Grid (Actor, Published, Size, Duration)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildMetaRow('主演演员', _item.actor.isNotEmpty ? _item.actor : '暂无', isDark, accentPink),
                        const Divider(height: 16),
                        _buildMetaRow('发布时间', _item.published.isNotEmpty ? _item.published : '暂无', isDark, null),
                        const Divider(height: 16),
                        _buildMetaRow('片源大小', _item.size.isNotEmpty ? _item.size : '暂无', isDark, null),
                        const Divider(height: 16),
                        _buildMetaRow('影片时长', _item.duration.isNotEmpty ? _item.duration : '暂无', isDark, null),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons (Play Fullscreen, Download, Web Mode)
                  Row(
                    children: [
                      // Fullscreen Play Button
                      Expanded(
                        child: BouncingButton(
                          onTap: _openFullScreenPlayer,
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF5A8A), Color(0xFFFF8FB3)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: accentPink.withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.play_circle_fill, color: Colors.white, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  '全屏播放',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Download Button
                      Consumer<DownloadProvider>(
                        builder: (context, downloadProv, _) {
                          final vItem = _item.copyWith(mp4Url: _mp4Url).toVideoItem();
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
                                  const SnackBar(content: Text('该视频已在下载任务中完成')),
                                );
                              } else if (!isDownloading) {
                                downloadProv.addVideoTask(vItem);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('已加入下载任务: ${_item.title}')),
                                );
                              }
                            },
                            child: Container(
                              height: 46,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFEFEFF4),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isDownloaded
                                        ? CupertinoIcons.check_mark_circled_solid
                                        : (isDownloading
                                            ? CupertinoIcons.arrow_down_circle_fill
                                            : CupertinoIcons.arrow_down_circle),
                                    size: 19,
                                    color: isDownloaded
                                        ? const Color(0xFF34C759)
                                        : (isDownloading ? accentPink : (isDark ? Colors.white : Colors.black87)),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isDownloaded ? '已下载' : (isDownloading ? '下载中' : '下载视频'),
                                    style: TextStyle(
                                      color: isDownloaded
                                          ? const Color(0xFF34C759)
                                          : (isDownloading ? accentPink : (isDark ? Colors.white : Colors.black87)),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),

                      // Web mode fallback
                      BouncingButton(
                        onTap: () {
                          WebVideoPlayerPage.open(
                            context,
                            url: 'https://ygjgl.one/play?id=${_item.id}',
                            title: _item.title,
                          );
                        },
                        child: Container(
                          height: 46,
                          width: 46,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFEFEFF4),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(CupertinoIcons.globe, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tags
                  if (_item.tags.isNotEmpty) ...[
                    Text(
                      '标签分类',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _item.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF222226) : const Color(0xFFF0F0F3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),
                  ],

                  // Preview Photos (Sample Gallery)
                  if (_item.pics.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '剧照预览 (${_item.pics.length}张)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            UnifiedPhotoViewer.open(
                              context,
                              imageUrls: _item.pics,
                              initialIndex: 0,
                              title: _item.title,
                              author: _item.actor,
                            );
                          },
                          child: const Text(
                            '查看全图',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFFF5A8A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _item.pics.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final picUrl = _item.pics[idx];
                          return GestureDetector(
                            onTap: () {
                              UnifiedPhotoViewer.open(
                                context,
                                imageUrls: _item.pics,
                                initialIndex: idx,
                                title: _item.title,
                                author: _item.actor,
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: CachedNetworkImage(
                                  imageUrl: picUrl,
                                  fit: BoxFit.cover,
                                  httpHeaders: const {
                                    'Referer': 'https://ygjgl.one/',
                                  },
                                  placeholder: (_, __) => Container(
                                    color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFF0F0F2),
                                    child: const Center(child: CupertinoActivityIndicator()),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFF0F0F2),
                                    child: const Icon(CupertinoIcons.photo, color: Colors.white24),
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
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, bool isDark, Color? highlightColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: highlightColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }
}
