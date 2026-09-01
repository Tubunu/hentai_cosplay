import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/download_task.dart';
import '../../../models/video_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/rule34video_browse_provider.dart';
import '../../../services/rule34video/rule34video_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../video/video_player_page.dart';
import '../video/web_video_player_page.dart';

class Rule34VideoDetailPage extends StatefulWidget {
  final VideoItem item;

  const Rule34VideoDetailPage({super.key, required this.item});

  @override
  State<Rule34VideoDetailPage> createState() => _Rule34VideoDetailPageState();
}

class _Rule34VideoDetailPageState extends State<Rule34VideoDetailPage> {
  final ScrollController _scrollController = ScrollController();
  late VideoItem _item;
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedQuality = '1080p';

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
          siteKey: 'rule34video',
          siteName: 'Rule34Video',
          siteColor: const Color(0xFFFF6B35),
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
      final resolved = await Rule34VideoApiService.resolveVideoDetail(_item);
      if (mounted) {
        setState(() {
          _item = resolved;
          _isLoading = false;
          final qualities = _item.rawData['qualities'] as Map<String, dynamic>?;
          if (qualities != null && qualities.isNotEmpty) {
            for (final q in ['1080p', '720p', '480p', '360p']) {
              if (qualities.containsKey(q)) {
                _selectedQuality = q;
                break;
              }
            }
          }
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
    final qualities = _item.rawData['qualities'] as Map<String, dynamic>?;
    String? streamUrl;
    if (qualities != null && qualities.containsKey(_selectedQuality)) {
      streamUrl = qualities[_selectedQuality]?.toString();
    }
    streamUrl ??= _item.videoUrl;

    if (streamUrl != null &&
        streamUrl.isNotEmpty &&
        (streamUrl.contains('.mp4') || streamUrl.contains('.m3u8') || streamUrl.contains('get_file'))) {
      VideoPlayerPage.openRemote(
        context,
        url: streamUrl,
        title: _item.title,
        author: _item.author,
        webPlayerUrl: _item.detailUrl,
      );
    } else {
      WebVideoPlayerPage.open(
        context,
        url: _item.detailUrl,
        title: _item.title,
      );
    }
  }

  void _downloadCurrentVideo(BuildContext context) {
    final qualities = _item.rawData['qualities'] as Map<String, dynamic>?;
    String? streamUrl;
    if (qualities != null && qualities.containsKey(_selectedQuality)) {
      streamUrl = qualities[_selectedQuality]?.toString();
    }
    streamUrl ??= _item.videoUrl;

    final targetItem = _item.copyWith(videoUrl: streamUrl);
    context.read<DownloadProvider>().addVideoTask(targetItem);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加入下载队列: ${_item.title} ($_selectedQuality)'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFFF6B35),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFFFF6B35);

    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == _item.slug || t.albumItem.detailUrl == _item.detailUrl) {
          return t;
        }
      }
      return null;
    });

    final duration = _item.rawData['duration'] as String? ?? '';
    final rating = _item.rawData['rating'] as String? ?? '';
    final qualities = _item.rawData['qualities'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
          // 1. App Bar
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back),
              color: Colors.white,
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              RandomActionButton.video(
                videoSite: VideoSiteType.rule34video,
                color: themeColor,
              ),
              const SizedBox(width: 8),
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
                        'Referer': 'https://rule34video.com/',
                        'User-Agent':
                            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                      },
                      placeholder: (_, __) => Container(color: Colors.black26),
                      errorWidget: (_, __, ___) => Container(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                        child: const Icon(CupertinoIcons.film_fill, size: 48, color: Colors.grey),
                      ),
                    ),
                  // Dark Vignette
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  // Play Center Button
                  Center(
                    child: BouncingButton(
                      onTap: _playVideo,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF9F1A)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(CupertinoIcons.play_fill, size: 32, color: Colors.white),
                      ),
                    ),
                  ),
                  // HD Badge Top Right
                  Positioned(
                    top: 50,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF9F1A)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '1080P HD',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _item.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Metadata Row (Duration, Rating, Date)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (duration.isNotEmpty)
                        _buildMetaBadge(CupertinoIcons.clock, duration, isDark),
                      if (rating.isNotEmpty)
                        _buildMetaBadge(CupertinoIcons.hand_thumbsup_fill, rating, isDark, color: const Color(0xFFFF9F1A)),
                      if (_item.date.isNotEmpty)
                        _buildMetaBadge(CupertinoIcons.calendar, _item.date, isDark),
                      if (_item.author.isNotEmpty && _item.author != 'Rule34Video')
                        _buildMetaBadge(CupertinoIcons.person_alt_circle_fill, _item.author, isDark, color: themeColor),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Action Bar (Play, Download)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          icon: const Icon(CupertinoIcons.play_fill, size: 18, color: Colors.white),
                          label: const Text('立即播放', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                          onPressed: _playVideo,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: themeColor.withValues(alpha: 0.6), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: Icon(
                            existingTask != null && existingTask.status == TaskStatus.completed
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.arrow_down_circle_fill,
                            size: 18,
                            color: themeColor,
                          ),
                          label: Text(
                            existingTask != null
                                ? (existingTask.status == TaskStatus.completed ? '已下载' : '${(existingTask.progress * 100).toInt()}%')
                                : '下载视频',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: themeColor),
                          ),
                          onPressed: () => _downloadCurrentVideo(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Quality Stream Selector
                  if (qualities.isNotEmpty) ...[
                    Text(
                      '清晰度画质',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: qualities.keys.map((q) {
                        final isSel = _selectedQuality == q;
                        return ChoiceChip(
                          label: Text(q.toUpperCase()),
                          selected: isSel,
                          selectedColor: themeColor,
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSel ? themeColor : (isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
                              width: 0.5,
                            ),
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedQuality = q);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Tags Section
                  if (_item.tags.isNotEmpty) ...[
                    Text(
                      '标签与分类',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _item.tags.map((tag) {
                        return ActionChip(
                          label: Text('#$tag'),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF3A3A3C),
                          ),
                          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                              width: 0.5,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            context.read<Rule34VideoBrowseProvider>().setTag(tag);
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CupertinoActivityIndicator(radius: 14)),
                    ),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      ScrollToTopButton(
        scrollController: _scrollController,
        color: themeColor,
      ),
    ],
  ),
);
  }

  Widget _buildMetaBadge(IconData icon, String text, bool isDark, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color ?? (isDark ? Colors.white60 : Colors.black54)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
