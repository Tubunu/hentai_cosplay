import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/download_task.dart';
import '../../../models/video_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/cosplayporntube/cosplayporntube_api_service.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../video/video_player_page.dart';
import '../video/web_video_player_page.dart';

class CosplayporntubeDetailPage extends StatefulWidget {
  final VideoItem item;

  const CosplayporntubeDetailPage({super.key, required this.item});

  @override
  State<CosplayporntubeDetailPage> createState() => _CosplayporntubeDetailPageState();
}

class _CosplayporntubeDetailPageState extends State<CosplayporntubeDetailPage> {
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
          siteKey: 'cosplayporntube',
          siteName: 'CosplayPornTube',
          siteColor: const Color(0xFFFF9800),
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
      final resolved = await CosplayporntubeApiService.resolveVideoDetail(_item);
      if (mounted) {
        setState(() {
          _item = resolved;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '解析视频详情失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _playVideo() {
    final streamUrl = _item.videoUrl;
    final hasDirectStream = streamUrl != null &&
        streamUrl.isNotEmpty &&
        streamUrl != _item.detailUrl &&
        (streamUrl.contains('.mp4') || streamUrl.contains('.m3u8'));

    if (hasDirectStream) {
      VideoPlayerPage.openRemote(
        context,
        url: streamUrl,
        title: _item.title,
        author: 'CosplayPornTube',
        webPlayerUrl: _item.detailUrl,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': 'https://cosplayporntube.com/',
        },
      );
    } else {
      WebVideoPlayerPage.open(context, url: _item.detailUrl, title: _item.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFFFF9800);

    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatus(slug: _item.slug, detailUrl: _item.detailUrl),
    );
    final isDownloaded = taskStatus == TaskStatus.completed;
    final isDownloading = taskStatus == TaskStatus.downloading ||
        taskStatus == TaskStatus.queued;

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
                    videoSite: VideoSiteType.cosplayporntube,
                    color: themeColor,
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Poster / Hero Preview
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: _item.coverUrl != null && _item.coverUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: _item.coverUrl!,
                                  fit: BoxFit.cover,
                                  httpHeaders: const {
                                    'Referer': 'https://cosplayporntube.com/',
                                    'User-Agent':
                                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                                  },
                                  placeholder: (_, __) => Container(
                                    color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
                                    child: const Center(
                                      child: CupertinoActivityIndicator(radius: 14),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
                                    child: const Icon(CupertinoIcons.play_rectangle, size: 48, color: Colors.grey),
                                  ),
                                )
                              : Container(
                                  color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
                                  child: const Icon(CupertinoIcons.play_rectangle, size: 48, color: Colors.grey),
                                ),
                        ),

                        // Dim Overlay
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.25),
                          ),
                        ),

                        // Big Play Button
                        GestureDetector(
                          onTap: _playVideo,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.95),
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

                        // Loading Spinner on resolve
                        if (_isLoading)
                          Positioned(
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CupertinoActivityIndicator(radius: 8, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    '正在解析视频直链...',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
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

              // Title and Actions
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

                      // Metadata Tags (Views, Duration)
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
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.exclamationmark_triangle, size: 14, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Buttons Row (Play, Download)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(CupertinoIcons.play_circle_fill, size: 18),
                              label: const Text('立即播放', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _playVideo,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(
                                isDownloaded
                                    ? CupertinoIcons.check_mark_circled_solid
                                    : (isDownloading ? CupertinoIcons.arrow_down_circle_fill : CupertinoIcons.cloud_download),
                                size: 18,
                              ),
                              label: Text(
                                isDownloaded ? '已下载' : (isDownloading ? '下载中' : '下载视频'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: themeColor,
                                side: const BorderSide(color: themeColor, width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: (isDownloaded || isDownloading)
                                  ? null
                                  : () {
                                      final downloadProv = context.read<DownloadProvider>();
                                      downloadProv.addAlbumTask(_item.toAlbumItem());
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('已添加视频到下载队列'),
                                          backgroundColor: themeColor,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Web Play Mode Button
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          icon: const Icon(CupertinoIcons.globe, size: 16),
                          label: const Text('若直链无法播放，点击使用【内置网页播放模式】', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.white60 : Colors.black54,
                          ),
                          onPressed: () {
                            WebVideoPlayerPage.open(context, url: _item.detailUrl, title: _item.title);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tags List
                      if (_item.tags.isNotEmpty) ...[
                        Text(
                          '标签与分类 (${_item.tags.length})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _item.tags.map((t) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: isDark ? 0.18 : 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: themeColor.withValues(alpha: 0.25), width: 0.6),
                              ),
                              child: Text(
                                t,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: themeColor,
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

              // Safe bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),

          ScrollToTopButton(scrollController: _scrollController),
        ],
      ),
    );
  }
}
