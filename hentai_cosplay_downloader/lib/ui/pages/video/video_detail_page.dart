import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/video_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/video_browse_provider.dart';
import '../../../services/video_api_service.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'video_player_page.dart';

class VideoDetailPage extends StatefulWidget {
  final VideoItem initialItem;

  const VideoDetailPage({super.key, required this.initialItem});

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  final ScrollController _scrollController = ScrollController();
  late VideoItem _item;
  bool _isLoading = true;
  bool _isTriggeredPlayAfterLoad = false;
  String? _errorMessage;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _item = widget.initialItem;
    _loadVideoDetails();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BrowsingHistoryProvider>().recordVideo(
          _item,
          siteKey: 'hc_video',
          siteName: 'HC 视频',
          siteColor: const Color(0xFFFF5252),
        );
      }
    });
  }

  Future<void> _loadVideoDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detailed = await VideoApiService.fetchVideoDetail(_item);
      if (!mounted) return;
      if (detailed != null) {
        setState(() {
          _item = detailed;
          _isLoading = false;
        });

        if (_isTriggeredPlayAfterLoad) {
          _isTriggeredPlayAfterLoad = false;
          _playOnline();
        }
      } else {
        setState(() {
          _errorMessage = '解析视频详情失败，请检查网络后重试';
          _isLoading = false;
          _isTriggeredPlayAfterLoad = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '加载出错: $e';
        _isLoading = false;
        _isTriggeredPlayAfterLoad = false;
      });
    }
  }

  void _playOnline() {
    if (_item.videoUrl != null && _item.videoUrl!.isNotEmpty) {
      VideoPlayerPage.openRemote(
        context,
        url: _item.videoUrl!,
        title: _item.title,
        author: _item.author,
      );
    } else if (_isLoading) {
      setState(() {
        _isTriggeredPlayAfterLoad = true;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CupertinoActivityIndicator(color: Colors.white, radius: 8),
              SizedBox(width: 10),
              Text('正在解析在线视频流，解析完成后将自动开始播放...'),
            ],
          ),
          backgroundColor: IosTheme.primaryPink,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('正在重新尝试解析在线播放源...'),
          backgroundColor: IosTheme.primaryPink,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _isTriggeredPlayAfterLoad = true;
      });
      _loadVideoDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final downloadProv = context.read<DownloadProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
          // Collapsible App Bar with 16:9 Video Poster and Live Play Overlay
          SliverAppBar(
            expandedHeight: 270,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: FrostedGlass(
                borderRadius: 20,
                blur: 15,
                backgroundColor: isDark ? Colors.black45 : Colors.white60,
                child: IconButton(
                  icon: const Icon(CupertinoIcons.chevron_back, size: 20),
                  color: isDark ? Colors.white : Colors.black,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              const RandomActionButton.video(
                videoSite: VideoSiteType.hcVideo,
                replace: true,
                color: IosTheme.primaryPink,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FrostedGlass(
                  borderRadius: 20,
                  blur: 15,
                  backgroundColor: isDark ? Colors.black45 : Colors.white60,
                  child: Builder(
                    builder: (btnContext) => IconButton(
                      icon: const Icon(CupertinoIcons.share, color: IosTheme.primaryPink, size: 19),
                      onPressed: () {
                        final box = btnContext.findRenderObject() as RenderBox?;
                        Share.share(
                          '${_item.title}\n${_item.detailUrl}',
                          sharePositionOrigin: box != null ? (box.localToGlobal(Offset.zero) & box.size) : null,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster Image
                  _item.coverUrl != null && _item.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _item.coverUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 600,
                          httpHeaders: const {
                            'Referer': 'https://porn-video-xxx.com/',
                          },
                        )
                      : Container(color: Colors.grey[900]),

                  // Ambient Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),

                  // Center Big Glass Play Button on Cover (Tap to play online!)
                  Center(
                    child: BouncingButton(
                      onTap: _playOnline,
                      child: LiquidGlass(
                        borderRadius: 36,
                        blur: 20,
                        fluidAuraColor: IosTheme.primaryPink,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isLoading && _isTriggeredPlayAfterLoad)
                              const CupertinoActivityIndicator(color: Colors.white, radius: 12)
                            else
                              const Icon(
                                CupertinoIcons.play_fill,
                                color: Colors.white,
                                size: 28,
                              ),
                            const SizedBox(width: 8),
                            const Text(
                              '在线观看',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Title & Duration Badge
                  Positioned(
                    bottom: 14,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              _item.author,
                              style: const TextStyle(
                                color: IosTheme.primaryPink,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_item.duration.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _item.duration,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: IosTheme.primaryPink.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: IosTheme.primaryPink.withValues(alpha: 0.4), width: 0.5),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.checkmark_seal_fill, size: 10, color: IosTheme.primaryPink),
                                  SizedBox(width: 4),
                                  Text(
                                    '支持在线观看',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Primary Action Buttons Row (在线播放 & 下载视频)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  // 1. Primary Action: 立即在线播放
                  Expanded(
                    flex: 6,
                    child: BouncingButton(
                      onTap: _playOnline,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: IosTheme.musicGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: IosTheme.primaryPink.withValues(alpha: 0.38),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isLoading && _isTriggeredPlayAfterLoad)
                              const CupertinoActivityIndicator(color: Colors.white, radius: 9)
                            else
                              const Icon(CupertinoIcons.play_circle_fill, color: Colors.white, size: 21),
                            const SizedBox(width: 7),
                            Text(
                              _isLoading && _isTriggeredPlayAfterLoad ? '正在解析...' : '立即在线播放',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // 2. Secondary Action: 下载视频
                  Expanded(
                    flex: 5,
                    child: BouncingButton(
                      onTap: () {
                        downloadProv.addVideoTask(_item);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已加入视频下载队列: ${_item.title}'),
                            backgroundColor: IosTheme.primaryPink,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF24242A) : const Color(0xFFE8E8EE),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.arrow_down_circle_fill,
                              color: isDark ? Colors.white70 : Colors.black87,
                              size: 19,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '下载视频',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
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
            ),
          ),

          // Video Tags Row (if loaded)
          if (_item.tags.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _item.tags.map((tag) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: BouncingButton(
                          onTap: () {
                            context.read<VideoBrowseProvider>().setTag(tag);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.tag_fill, size: 11, color: IosTheme.primaryPink),
                                const SizedBox(width: 5),
                                Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

          // Video Detail Information Card (Liquid Glass)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: LiquidGlass(
                borderRadius: 22,
                blur: 24,
                padding: const EdgeInsets.all(18),
                fluidAuraColor: IosTheme.primaryPink,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(CupertinoIcons.film_fill, color: IosTheme.primaryPink, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          '视频详细信息与播放流',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        if (_isLoading)
                          const CupertinoActivityIndicator(radius: 7),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            CupertinoActivityIndicator(radius: 8),
                            SizedBox(width: 8),
                            Text('正在解析视频播放源与完整信息...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      )
                    else if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                            ),
                            TextButton(
                              onPressed: _loadVideoDetails,
                              child: const Text('重试', style: TextStyle(fontSize: 12, color: IosTheme.primaryPink)),
                            ),
                          ],
                        ),
                      ),
                    _buildInfoRow('作者 / 演者', _item.author, isDark),
                    if (_item.duration.isNotEmpty) _buildInfoRow('视频时长', _item.duration, isDark),
                    if (_item.date.isNotEmpty) _buildInfoRow('发布时间', _item.date, isDark),
                    _buildInfoRow('原始页面', _item.detailUrl, isDark),
                    if (_item.videoUrl != null)
                      _buildInfoRow('在线播放源', '已就绪 (支持直接在线点播)', isDark),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
      ScrollToTopButton(
        scrollController: _scrollController,
        color: IosTheme.primaryPink,
        bottomOffset: 24.0,
      ),
    ],
  ),
);
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
