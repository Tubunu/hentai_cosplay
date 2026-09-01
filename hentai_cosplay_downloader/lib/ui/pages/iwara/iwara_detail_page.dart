import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/download_task.dart';
import '../../../models/video_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/iwara_browse_provider.dart';
import '../../../services/iwara/iwara_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../video/video_player_page.dart';
import '../video/web_video_player_page.dart';

class IwaraDetailPage extends StatefulWidget {
  final VideoItem item;

  const IwaraDetailPage({super.key, required this.item});

  @override
  State<IwaraDetailPage> createState() => _IwaraDetailPageState();
}

class _IwaraDetailPageState extends State<IwaraDetailPage> {
  final ScrollController _scrollController = ScrollController();
  late VideoItem _item;
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedQuality = '1080';

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
          siteKey: 'iwara',
          siteName: 'Iwara',
          siteColor: const Color(0xFF00A8FF),
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
      final resolved = await IwaraApiService.resolveVideoDetail(_item);
      if (mounted) {
        setState(() {
          _item = resolved;
          _isLoading = false;
          final qualities = _item.rawData['qualities'] as Map<String, dynamic>?;
          if (qualities != null && qualities.isNotEmpty) {
            for (final q in ['Source', '1080', '1080p', '720', '720p', '540', '360']) {
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
        (streamUrl.contains('.mp4') || streamUrl.contains('.m3u8') || streamUrl.contains('asta.iwara.tv') || streamUrl.contains('clara.iwara.tv') || streamUrl.contains('bailu.iwara.tv') || streamUrl.contains('youhu.iwara.tv'))) {
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
        backgroundColor: const Color(0xFF00A8FF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFF00A8FF);

    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == _item.slug || t.albumItem.detailUrl == _item.detailUrl) {
          return t;
        }
      }
      return null;
    });

    final numViews = _item.rawData['numViews'] as int? ?? 0;
    final numLikes = _item.rawData['numLikes'] as int? ?? 0;
    final numComments = _item.rawData['numComments'] as int? ?? 0;
    final durationFormatted = _item.rawData['durationFormatted'] as String? ?? '';
    final rating = _item.rawData['rating'] as String? ?? 'general';
    final user = _item.rawData['user'] as Map<String, dynamic>?;
    final qualities = _item.rawData['qualities'] as Map<String, dynamic>? ?? {};
    final body = _item.rawData['body'] as String?;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      floatingActionButton: ScrollToTopButton(scrollController: _scrollController),
      body: CustomScrollView(
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
                videoSite: VideoSiteType.iwara,
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
                        'Referer': 'https://www.iwara.tv/',
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
                            colors: [Color(0xFF00A8FF), Color(0xFF0055FF)],
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
                  // Rating Badge Top Right
                  Positioned(
                    top: 50,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: rating == 'ecchi'
                              ? [const Color(0xFFFF2E63), const Color(0xFFFF5722)]
                              : [const Color(0xFF00A8FF), const Color(0xFF0055FF)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rating == 'ecchi' ? 'R18' : '全年龄',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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

                  // Metadata Row (Views, Likes, Date, Duration)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (durationFormatted.isNotEmpty)
                        _buildMetaBadge(CupertinoIcons.clock, durationFormatted, isDark),
                      if (numViews > 0)
                        _buildMetaBadge(
                          CupertinoIcons.play_fill,
                          numViews >= 10000 ? '${(numViews / 10000).toStringAsFixed(1)}万次播放' : '$numViews 次播放',
                          isDark,
                        ),
                      if (numLikes > 0)
                        _buildMetaBadge(CupertinoIcons.heart_fill, '$numLikes 赞', isDark, color: const Color(0xFFFF4081)),
                      if (numComments > 0)
                        _buildMetaBadge(CupertinoIcons.chat_bubble_fill, '$numComments 评论', isDark),
                      if (_item.date.isNotEmpty)
                        _buildMetaBadge(CupertinoIcons.calendar, _item.date, isDark),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Action Bar (Play, Download, Browser)
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
                      '画质清晰度',
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

                  // Author Info Card
                  if (user != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: themeColor.withValues(alpha: 0.15),
                            child: const Icon(CupertinoIcons.person_fill, color: themeColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _item.author,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                                  ),
                                ),
                                if (user['username'] != null)
                                  Text(
                                    '@${user['username']}',
                                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                                  ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor.withValues(alpha: 0.12),
                              foregroundColor: themeColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () {
                              final userId = user['id']?.toString() ?? user['username']?.toString();
                              if (userId != null && userId.isNotEmpty) {
                                Navigator.pop(context);
                                context.read<IwaraBrowseProvider>().setUserId(userId);
                              }
                            },
                            child: const Text('查看作品', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Video Description / Body
                  if (body != null && body.trim().isNotEmpty) ...[
                    Text(
                      '视频简介',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        body.trim(),
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: isDark ? Colors.white70 : const Color(0xFF3A3A3C),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Tags Section
                  if (_item.tags.isNotEmpty) ...[
                    Text(
                      '标签分类',
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
                            context.read<IwaraBrowseProvider>().setTag(tag);
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
