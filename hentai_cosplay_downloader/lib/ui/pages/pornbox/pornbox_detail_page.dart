import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/download_task.dart';
import '../../../models/video_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/pornbox/pornbox_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../video/video_player_page.dart';
import '../video/web_video_player_page.dart';

class PornboxDetailPage extends StatefulWidget {
  final VideoItem item;

  const PornboxDetailPage({super.key, required this.item});

  @override
  State<PornboxDetailPage> createState() => _PornboxDetailPageState();
}

class _PornboxDetailPageState extends State<PornboxDetailPage> {
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BrowsingHistoryProvider>().recordVideo(
          _item,
          siteKey: 'pornbox',
          siteName: 'PornBox',
          siteColor: const Color(0xFF8E24AA),
        );
      }
    });
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detailed = await PornboxApiService.fetchVideoDetail(_item);
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

  void _playVideo() {
    if (_item.videoUrl != null && _item.videoUrl!.isNotEmpty) {
      VideoPlayerPage.openRemote(
        context,
        url: _item.videoUrl!,
        title: _item.title,
        author: _item.author,
        webPlayerUrl: _item.detailUrl,
      );
    } else {
      _openWebPlayer();
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
        backgroundColor: const Color(0xFF8E24AA),
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
            expandedHeight: 0,
            backgroundColor: isDark ? const Color(0xCC1A1A1E) : const Color(0xCCFFFFFF),
            elevation: 0,
            leading: BouncingButton(
              onTap: () => Navigator.pop(context),
              child: const Icon(CupertinoIcons.back, size: 24),
            ),
            title: Text(
              _item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            actions: [
              const RandomActionButton.video(
                videoSite: VideoSiteType.pornbox,
                replace: true,
                color: Color(0xFFAB47BC),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.share),
                tooltip: '分享',
                onPressed: () {
                  if (_item.detailUrl.isNotEmpty) {
                    Share.share('${_item.title}\n${_item.detailUrl}');
                  }
                },
              ),
            ],
          ),

          // Video Poster & Play Button Banner
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
                              httpHeaders: const {
                                'Referer': 'https://pornbox.com/',
                                'Cookie': PornboxApiService.kDefaultCookie,
                              },
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
                          onTap: _item.videoUrl != null ? _playVideo : _fetchDetail,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8E24AA).withValues(alpha: 0.5),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.play_fill,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),

                      // Duration pill
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
                                _item.duration.isNotEmpty ? _item.duration : 'PORNBOX',
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

          // Video Meta & Download Action
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

                    // Studio / Channel & Tags
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E24AA).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.film_fill, color: Color(0xFF8E24AA), size: 14),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _item.author,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8E24AA),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E24AA).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PornBox 独家',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF8E24AA),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Action Buttons Row (Native Player / Web Player)
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: BouncingButton(
                            onTap: _playVideo,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8E24AA).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.play_arrow_solid, color: Colors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    '原生播放器',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: BouncingButton(
                            onTap: _openWebPlayer,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.globe,
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

                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        '💡 提示：官方仅提供数秒精彩预告，完整正片请点击「完整网页播放」观看',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
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
                                color: isDark ? const Color(0xFF2A1B3D) : const Color(0xFFF3E5F5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF8E24AA).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    existingTask?.status == TaskStatus.completed
                                        ? CupertinoIcons.checkmark_alt
                                        : CupertinoIcons.arrow_down_circle_fill,
                                    color: const Color(0xFF8E24AA),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    existingTask?.status == TaskStatus.completed
                                        ? '已下载至本地 (重新下载)'
                                        : '下载此视频到本地',
                                    style: const TextStyle(
                                      color: Color(0xFF8E24AA),
                                      fontSize: 13,
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
        color: const Color(0xFF8E24AA),
        bottomOffset: 24.0,
      ),
    ],
  ),
);
}
}
