import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/download_task.dart';
import '../../../models/video_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/thothub/thothub_api_service.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../video/video_player_page.dart';
import '../video/web_video_player_page.dart';

class ThothubDetailPage extends StatefulWidget {
  final VideoItem item;

  const ThothubDetailPage({super.key, required this.item});

  @override
  State<ThothubDetailPage> createState() => _ThothubDetailPageState();
}

class _ThothubDetailPageState extends State<ThothubDetailPage> {
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
    _resolveDetail();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BrowsingHistoryProvider>().recordVideo(
          _item,
          siteKey: 'thothub',
          siteName: 'Thothub',
          siteColor: const Color(0xFF00ADB5),
        );
      }
    });
  }

  Future<void> _resolveDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resolved = await ThothubApiService.resolveVideoDetail(_item);
      if (mounted) {
        setState(() {
          _item = resolved;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '解析视频失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _playVideo({bool forceWebPlayer = false}) {
    final streamUrl = _item.videoUrl ?? '';
    final isDirectStream = !forceWebPlayer &&
        streamUrl.isNotEmpty &&
        (streamUrl.contains('.mp4') || streamUrl.contains('.m3u8')) &&
        !streamUrl.contains('thothub.to/videos/');

    if (isDirectStream) {
      VideoPlayerPage.openRemote(
        context,
        url: streamUrl,
        title: _item.title,
        author: 'Thothub',
        webPlayerUrl: _item.detailUrl,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': 'https://thothub.to/',
        },
      );
    } else {
      // Open with Built-in Web Player mode
      WebVideoPlayerPage.open(context, url: _item.detailUrl, title: _item.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFF00ADB5);

    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatus(slug: _item.slug, detailUrl: _item.detailUrl),
    );
    final isDownloaded = taskStatus == TaskStatus.completed;
    final isDownloading = taskStatus == TaskStatus.downloading ||
        taskStatus == TaskStatus.queued;

    final streamUrl = _item.videoUrl ?? '';
    final hasDirectStream = streamUrl.isNotEmpty &&
        (streamUrl.contains('.mp4') || streamUrl.contains('.m3u8')) &&
        !streamUrl.contains('thothub.to/videos/');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF7F8FA),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Immersive AppBar
              SliverAppBar(
                pinned: true,
                backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                foregroundColor: isDark ? Colors.white : Colors.black87,
                elevation: 0,
                title: Text(
                  _item.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  RandomActionButton.video(
                    videoSite: VideoSiteType.thothub,
                    color: themeColor,
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Video Hero Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Cover Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            color: Colors.black,
                            width: double.infinity,
                            height: double.infinity,
                            child: _item.coverUrl != null && _item.coverUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: _item.coverUrl!,
                                    fit: BoxFit.cover,
                                    httpHeaders: const {
                                      'Referer': 'https://thothub.to/',
                                      'User-Agent':
                                          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                                    },
                                    placeholder: (context, url) => const Center(
                                      child: CupertinoActivityIndicator(radius: 14),
                                    ),
                                    errorWidget: (context, url, error) => const Center(
                                      child: Icon(CupertinoIcons.play_rectangle, size: 48, color: Colors.grey),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(CupertinoIcons.play_rectangle, size: 48, color: Colors.grey),
                                  ),
                          ),
                        ),

                        // Dark Tint
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                        ),

                        // Big Play Button
                        GestureDetector(
                          onTap: () => _playVideo(forceWebPlayer: false),
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: themeColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: themeColor.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  spreadRadius: 2,
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

                        // Loading Spinner
                        if (_isLoading)
                          Positioned(
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CupertinoActivityIndicator(radius: 8, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    '正在解析视频...',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_errorMessage != null && !_isLoading)
                          Positioned(
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Title and Badges
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _item.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Duration & Views
                      Row(
                        children: [
                          if (_item.duration.isNotEmpty) ...[
                            Icon(CupertinoIcons.time, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                            const SizedBox(width: 4),
                            Text(
                              _item.duration,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 14),
                          ],
                          if (_item.views.isNotEmpty) ...[
                            Icon(CupertinoIcons.eye, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                            const SizedBox(width: 4),
                            Text(
                              _item.views,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 14),
                          ],
                          if (_item.date.isNotEmpty) ...[
                            Icon(CupertinoIcons.calendar, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                            const SizedBox(width: 4),
                            Text(
                              _item.date,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Dual Play Buttons Row (Direct Play + Web Play)
                      Row(
                        children: [
                          // Primary Play Button
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(CupertinoIcons.play_arrow_solid, size: 18),
                              label: Text(hasDirectStream ? '原生直接播放' : '内置播放器'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () => _playVideo(forceWebPlayer: false),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Web Browser Player Mode Button
                          ElevatedButton.icon(
                            icon: const Icon(CupertinoIcons.globe, size: 18),
                            label: const Text('网页播放模式'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                              foregroundColor: isDark ? Colors.white : Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () => _playVideo(forceWebPlayer: true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Download Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: Icon(
                            isDownloaded
                                ? CupertinoIcons.check_mark_circled_solid
                                : (isDownloading ? CupertinoIcons.arrow_down_circle_fill : CupertinoIcons.arrow_down_to_line),
                            size: 18,
                            color: themeColor,
                          ),
                          label: Text(
                            isDownloaded
                                ? '视频已下载完成'
                                : (isDownloading ? '视频正在下载中...' : '下载视频'),
                            style: const TextStyle(
                              color: themeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: themeColor, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: (isDownloaded || isDownloading)
                              ? null
                              : () {
                                  final downloadProv = context.read<DownloadProvider>();
                                  downloadProv.addVideoTask(_item);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('已添加视频到下载任务'),
                                      backgroundColor: themeColor,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Specifications Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(CupertinoIcons.info_circle_fill, size: 16, color: themeColor),
                                SizedBox(width: 6),
                                Text(
                                  '视频详情与规格',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildSpecRow('站点来源', 'Thothub (Gamer Girl & Creator Leaks)', isDark),
                            _buildSpecRow('视频编号', _item.slug, isDark),
                            if (_item.duration.isNotEmpty) _buildSpecRow('视频时长', _item.duration, isDark),
                            if (_item.views.isNotEmpty) _buildSpecRow('播放热度', _item.views, isDark),
                            _buildSpecRow(
                              '播放链路',
                              hasDirectStream ? '支持 MP4 原生加速直链' : 'KVS 动态播放流 (支持网页内置播放)',
                              isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tags Wrap
                      if (_item.tags.isNotEmpty) ...[
                        Text(
                          '分类与标签',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _item.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
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
                        const SizedBox(height: 40),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          ScrollToTopButton(scrollController: _scrollController),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
