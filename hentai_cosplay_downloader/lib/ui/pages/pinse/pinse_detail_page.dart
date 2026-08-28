import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/download_task.dart';
import '../../../models/video_item.dart';
import '../../../providers/download_provider.dart';
import '../../../services/pinse/pinse_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../video/video_player_page.dart';
import '../video/web_video_player_page.dart';

class PinseDetailPage extends StatefulWidget {
  final VideoItem item;

  const PinseDetailPage({super.key, required this.item});

  @override
  State<PinseDetailPage> createState() => _PinseDetailPageState();
}

class _PinseDetailPageState extends State<PinseDetailPage> {
  final ScrollController _scrollController = ScrollController();
  late VideoItem _item;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detailed = await PinseApiService.fetchVideoDetail(_item);
      if (mounted) {
        setState(() {
          _item = detailed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '获取视频详情失败: $e';
        });
      }
    }
  }

  Future<void> _playVideo() async {
    if (_item.videoUrl != null &&
        _item.videoUrl!.isNotEmpty &&
        (_item.videoUrl!.contains('.m3u8') || _item.videoUrl!.contains('.mp4'))) {
      VideoPlayerPage.openRemote(
        context,
        url: _item.videoUrl!,
        title: _item.title,
        author: _item.author,
        webPlayerUrl: _item.detailUrl,
      );
      return;
    }

    // If stream not loaded yet, resolve on-demand
    setState(() => _isLoading = true);
    try {
      final detailed = await PinseApiService.resolveVideoDetail(_item);
      if (mounted) {
        setState(() {
          _item = detailed;
          _isLoading = false;
        });
        if (detailed.videoUrl != null &&
            detailed.videoUrl!.isNotEmpty &&
            (detailed.videoUrl!.contains('.m3u8') || detailed.videoUrl!.contains('.mp4'))) {
          VideoPlayerPage.openRemote(
            context,
            url: detailed.videoUrl!,
            title: detailed.title,
            author: detailed.author,
            webPlayerUrl: detailed.detailUrl,
          );
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
      WebVideoPlayerPage.open(
        context,
        url: _item.videoUrl ?? _item.detailUrl,
        title: _item.title,
      );
    }
  }

  void _openWebPlayer() {
    WebVideoPlayerPage.open(
      context,
      url: _item.detailUrl,
      title: _item.title,
    );
  }

  void _downloadVideo() {
    final downloadProv = context.read<DownloadProvider>();
    downloadProv.addVideoTask(_item);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 "${_item.title}" 到视频下载队列'),
        backgroundColor: const Color(0xFFFF8C00),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == _item.slug || t.albumItem.detailUrl == _item.detailUrl) {
          return t;
        }
      }
      return null;
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
          // Cupertino Navigation Bar
          SliverAppBar(
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              _item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            actions: [
              const RandomActionButton.video(
                videoSite: VideoSiteType.pinse,
                replace: true,
                color: Color(0xFFFF8C00),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.share),
                onPressed: () {
                  Share.share('${_item.title}\n${_item.detailUrl}');
                },
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.arrow_clockwise),
                onPressed: _fetchDetail,
              ),
            ],
          ),

          // Video Poster Hero / Play Button Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Cover Poster
                      _item.coverUrl != null && _item.coverUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _item.coverUrl!,
                              fit: BoxFit.cover,
                              httpHeaders: const {'Referer': 'https://91pinse.com/'},
                              placeholder: (_, __) => Container(color: Colors.black26),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.black87,
                                child: const Icon(CupertinoIcons.film, color: Colors.white30, size: 48),
                              ),
                            )
                          : Container(
                              color: Colors.black87,
                              child: const Icon(CupertinoIcons.film, color: Colors.white30, size: 48),
                            ),

                      // Dark Overlay
                      Container(
                        color: Colors.black.withValues(alpha: 0.35),
                      ),

                      // Play Button
                      Center(
                        child: BouncingButton(
                          onTap: _playVideo,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8C00), Color(0xFFFF5252)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF8C00).withValues(alpha: 0.5),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.play_fill,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),

                      // HD / Duration pill
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.clock_fill, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                _item.duration.isNotEmpty ? _item.duration : '91品色',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Video Meta & Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FrostedGlass(
                borderRadius: 20,
                blur: 20,
                padding: const EdgeInsets.all(16),
                backgroundColor: isDark ? const Color(0x991E1E24) : Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _item.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Author & Tags
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8C00).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.person_fill, color: Color(0xFFFF8C00), size: 14),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _item.author,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF8C00),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8C00).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '91 原创',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF8C00),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Online Playback & Web Mode Row
                    Row(
                      children: [
                        // Online Play Button
                        Expanded(
                          flex: 3,
                          child: BouncingButton(
                            onTap: _playVideo,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF8C00), Color(0xFFFF5252)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF8C00).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.play_circle_fill, color: Colors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    '在线极速播放',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Web Player Mode Button
                        Expanded(
                          flex: 2,
                          child: BouncingButton(
                            onTap: _openWebPlayer,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.compass_fill,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '网页播放',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Download Action Button
                    Row(
                      children: [
                        Expanded(
                          child: BouncingButton(
                            onTap: _downloadVideo,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E2836) : const Color(0xFFE8F1FC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    existingTask?.status == TaskStatus.completed
                                        ? CupertinoIcons.checkmark_alt
                                        : CupertinoIcons.arrow_down_circle_fill,
                                    color: const Color(0xFF2196F3),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    existingTask?.status == TaskStatus.completed
                                        ? '已下载至本地 (重新下载)'
                                        : '下载此视频到本地',
                                    style: const TextStyle(
                                      color: Color(0xFF2196F3),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading or Error info
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CupertinoActivityIndicator(radius: 12),
                ),
              ),
            ),

          if (_errorMessage != null && !_isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.amber, size: 36),
                      const SizedBox(height: 8),
                      Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchDetail,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      ScrollToTopButton(
        scrollController: _scrollController,
        color: const Color(0xFFFF8C00),
        bottomOffset: 24.0,
      ),
    ],
  ),
);
}
}
