import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/download_task.dart';
import '../../../models/video_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/hohoj/hohoj_api_service.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../video/video_player_page.dart';
import '../video/web_video_player_page.dart';

class HohojDetailPage extends StatefulWidget {
  final VideoItem item;

  const HohojDetailPage({super.key, required this.item});

  @override
  State<HohojDetailPage> createState() => _HohojDetailPageState();
}

class _HohojDetailPageState extends State<HohojDetailPage> {
  final ScrollController _scrollController = ScrollController();
  late VideoItem _item;
  bool _isLoading = true;
  String? _errorMessage;

  static const _themeColor = Color(0xFFE74C3C);

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
          siteKey: 'hohoj',
          siteName: 'HoHoJ',
          siteColor: _themeColor,
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
      final resolved = await HohojApiService.resolveVideoDetail(_item);
      if (mounted) {
        setState(() {
          _item = resolved;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _playVideo() {
    final videoUrl = _item.videoUrl ?? '';
    if (videoUrl.isNotEmpty &&
        videoUrl.startsWith('http') &&
        (videoUrl.contains('.mp4') || videoUrl.contains('.m3u8'))) {
      VideoPlayerPage.openRemote(
        context,
        url: videoUrl,
        title: _item.title,
        author: _item.author,
        webPlayerUrl: _item.detailUrl,
      );
    } else {
      _openWebPlayer();
    }
  }

  void _openWebPlayer() {
    final embedUrl = _item.rawData['embed_url'] as String? ?? _item.detailUrl;
    WebVideoPlayerPage.open(
      context,
      url: embedUrl.isNotEmpty ? embedUrl : _item.detailUrl,
      title: _item.title,
    );
  }

  void _startDownload() {
    final dp = context.read<DownloadProvider>();
    dp.addVideoTask(_item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加入下载队列: ${_item.title}'),
        backgroundColor: _themeColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatus(slug: _item.slug, detailUrl: _item.detailUrl),
    );
    final isDownloaded = taskStatus == TaskStatus.completed;
    final isDownloading = taskStatus == TaskStatus.downloading ||
        taskStatus == TaskStatus.queued;

    final views = _item.views.isNotEmpty ? _item.views : (_item.rawData['views'] as String? ?? '');
    final likes = _item.rawData['likes'] as String? ?? '';
    final badge = _item.rawData['badge'] as String? ?? '';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF7F7F8),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Cupertino style SliverAppBar
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.back, color: Colors.white, size: 20),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: RandomActionButton.video(
                      videoSite: VideoSiteType.hohoj,
                      color: _themeColor,
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_item.coverUrl != null && _item.coverUrl!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: _item.coverUrl!,
                          fit: BoxFit.cover,
                          httpHeaders: const {
                            'Referer': 'https://hohoj.tv/',
                            'User-Agent':
                                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                          },
                          placeholder: (_, __) => Container(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            child: const Center(child: CupertinoActivityIndicator()),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            child: const Icon(CupertinoIcons.film, size: 48, color: Colors.white38),
                          ),
                        )
                      else
                        Container(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          child: const Icon(CupertinoIcons.film, size: 48, color: Colors.white38),
                        ),

                      // Gradient overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.75),
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Center play button
                      Center(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _playVideo,
                          child: Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _themeColor.withValues(alpha: 0.9),
                              boxShadow: [
                                BoxShadow(
                                  color: _themeColor.withValues(alpha: 0.45),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.play_arrow_solid,
                              size: 34,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content body
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Loading indicator
                      if (_isLoading)
                        const LinearProgressIndicator(
                          color: _themeColor,
                          backgroundColor: Colors.transparent,
                        ),

                      // Error message
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '解析失败: $_errorMessage',
                                  style: const TextStyle(color: Colors.red, fontSize: 13),
                                ),
                              ),
                              TextButton(
                                onPressed: _resolveDetail,
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        ),

                      // Title
                      Text(
                        _item.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Info bar (ID, badge, views, likes, date)
                      Row(
                        children: [
                          if (badge.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _themeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _themeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (views.isNotEmpty) ...[
                            Icon(CupertinoIcons.eye, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                            const SizedBox(width: 4),
                            Text(
                              views,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (likes.isNotEmpty) ...[
                            Icon(CupertinoIcons.heart, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                            const SizedBox(width: 4),
                            Text(
                              likes,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (_item.date.isNotEmpty) ...[
                            Icon(CupertinoIcons.calendar, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                            const SizedBox(width: 4),
                            Text(
                              _item.date,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Action Buttons Row
                      Row(
                        children: [
                          // Play Button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _playVideo,
                              icon: const Icon(CupertinoIcons.play_arrow_solid, size: 16),
                              label: const Text('播放视频', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _themeColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Web Player Button
                          OutlinedButton.icon(
                            onPressed: _openWebPlayer,
                            icon: const Icon(CupertinoIcons.globe, size: 16),
                            label: const Text('网页'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white70 : Colors.black87,
                              side: BorderSide(
                                color: isDark ? const Color(0x33FFFFFF) : const Color(0x22000000),
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Download Button
                          ElevatedButton.icon(
                            onPressed: isDownloaded || isDownloading ? null : _startDownload,
                            icon: Icon(
                              isDownloaded
                                  ? CupertinoIcons.checkmark_circle_fill
                                  : (isDownloading
                                      ? CupertinoIcons.arrow_down_circle_fill
                                      : CupertinoIcons.cloud_download),
                              size: 16,
                            ),
                            label: Text(
                              isDownloaded ? '已下载' : (isDownloading ? '下载中' : '下载'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                              foregroundColor: isDark ? Colors.white : Colors.black87,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Share Button
                          IconButton(
                            icon: const Icon(CupertinoIcons.share),
                            onPressed: () {
                              Share.share('${_item.title}\n${_item.detailUrl}');
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // Tags & Actresses
                      if (_item.tags.isNotEmpty) ...[
                        Text(
                          '标签与演员',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _item.tags.map((t) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEBEBF0),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Bottom spacing
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Scroll to Top Button
          ScrollToTopButton(
            scrollController: _scrollController,
            color: _themeColor,
          ),
        ],
      ),
    );
  }
}
