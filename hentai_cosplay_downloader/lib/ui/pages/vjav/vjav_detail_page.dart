import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/download_task.dart';
import '../../../models/video_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/vjav/vjav_api_service.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../video/video_player_page.dart';
import '../video/web_video_player_page.dart';

class VjavDetailPage extends StatefulWidget {
  final VideoItem item;

  const VjavDetailPage({super.key, required this.item});

  @override
  State<VjavDetailPage> createState() => _VjavDetailPageState();
}

class _VjavDetailPageState extends State<VjavDetailPage> {
  final ScrollController _scrollController = ScrollController();
  late VideoItem _item;
  bool _isLoading = true;
  String? _errorMessage;

  static const _themeColor = Color(0xFFFF9900);

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
          siteKey: 'vjav',
          siteName: 'VJAV',
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
      final resolved = await VjavApiService.resolveVideoDetail(_item);
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
    if (videoUrl.isNotEmpty && videoUrl.startsWith('http') && (videoUrl.contains('.mp4') || videoUrl.contains('.m3u8'))) {
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
    WebVideoPlayerPage.open(
      context,
      url: _item.detailUrl,
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

    final duration = _item.duration.isNotEmpty ? _item.duration : (_item.rawData['duration'] as String? ?? '');
    final views = _item.views.isNotEmpty ? _item.views : (_item.rawData['views'] as String? ?? '');
    final rating = _item.rawData['rating']?.toString() ?? '';

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
                      videoSite: VideoSiteType.vjav,
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
                            'Referer': 'https://vjav.com/',
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
                          minHeight: 2,
                        ),

                      // Error message banner
                      if (_errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.info_circle, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '解析提醒: $_errorMessage',
                                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                                ),
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
                          color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Info badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: _themeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ID: ${_item.slug}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _themeColor,
                              ),
                            ),
                          ),
                          if (duration.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.time,
                                    size: 13,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    duration,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (views.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.eye_fill,
                                    size: 13,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    views,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (rating.isNotEmpty && rating != '0')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    CupertinoIcons.star_fill,
                                    size: 13,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$rating%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons
                      Row(
                        children: [
                          // Play button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _playVideo,
                              icon: const Icon(CupertinoIcons.play_arrow_solid, size: 18),
                              label: Text(_item.videoUrl != null && _item.videoUrl!.endsWith('.mp4') ? '高速原画播放' : '在线播放'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _themeColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Web player button
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(12),
                            onPressed: _openWebPlayer,
                            child: Icon(
                              CupertinoIcons.compass,
                              color: isDark ? Colors.white : Colors.black87,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Download button
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(12),
                            onPressed: isDownloaded || isDownloading
                                ? null
                                : _startDownload,
                            child: Icon(
                              isDownloaded
                                  ? CupertinoIcons.checkmark_alt
                                  : (isDownloading
                                      ? CupertinoIcons.arrow_down_circle
                                      : CupertinoIcons.arrow_down),
                              color: isDownloaded
                                  ? const Color(0xFF34C759)
                                  : (isDark ? Colors.white : Colors.black87),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Tags section
                      if (_item.tags.isNotEmpty) ...[
                        Text(
                          '标签与演员',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1D1D1F),
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
                                color: isDark ? const Color(0xFF242426) : const Color(0xFFF0F0F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                                ),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : const Color(0xFF3A3A3C),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Bottom spacing
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Scroll to top
          Positioned(
            right: 16,
            bottom: 24,
            child: ScrollToTopButton(
              scrollController: _scrollController,
              threshold: 400,
            ),
          ),
        ],
      ),
    );
  }
}
