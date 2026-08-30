import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/download_task.dart';
import '../../../models/video_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/hanime1_browse_provider.dart';
import '../../../services/hanime1/hanime1_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../video/video_player_page.dart';
import '../video/web_video_player_page.dart';

class Hanime1DetailPage extends StatefulWidget {
  final VideoItem item;

  const Hanime1DetailPage({super.key, required this.item});

  @override
  State<Hanime1DetailPage> createState() => _Hanime1DetailPageState();
}

class _Hanime1DetailPageState extends State<Hanime1DetailPage> {
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
          siteKey: 'hanime1',
          siteName: 'Hanime1',
          siteColor: const Color(0xFFFF2E63),
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
      final resolved = await Hanime1ApiService.resolveVideoDetail(_item);
      if (mounted) {
        setState(() {
          _item = resolved;
          _isLoading = false;
          final qualities = _item.rawData['qualities'] as Map<String, dynamic>?;
          if (qualities != null && qualities.isNotEmpty) {
            if (qualities.containsKey('1080p')) {
              _selectedQuality = '1080p';
            } else {
              _selectedQuality = qualities.keys.first;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '解析动漫详情失败: $e';
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
        (streamUrl.contains('.mp4') || streamUrl.contains('.m3u8'))) {
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

  void _downloadVideo() {
    final downloadProv = context.read<DownloadProvider>();
    final qualities = _item.rawData['qualities'] as Map<String, dynamic>?;
    String? streamUrl;
    if (qualities != null && qualities.containsKey(_selectedQuality)) {
      streamUrl = qualities[_selectedQuality]?.toString();
    }
    streamUrl ??= _item.videoUrl;

    final itemToDownload = _item.copyWith(videoUrl: streamUrl);
    downloadProv.addVideoTask(itemToDownload);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 "${_item.title}" 到动漫下载队列'),
        backgroundColor: const Color(0xFFFF2E63),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFFFF2E63);

    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == _item.slug || t.albumItem.detailUrl == _item.detailUrl) {
          return t;
        }
      }
      return null;
    });

    final episodes = (_item.rawData['episodes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final qualities = (_item.rawData['qualities'] as Map?)?.cast<String, String>() ?? {};

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F6F9),
      appBar: AppBar(
        title: Text(_item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          const RandomActionButton.video(
            videoSite: VideoSiteType.hanime1,
            replace: true,
            color: Color(0xFFFF2E63),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            onPressed: _resolveDetail,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.amber, size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _resolveDetail,
                        style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                        child: const Text('重试加载', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    SingleChildScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Video Player Cover Preview
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_item.coverUrl != null && _item.coverUrl!.isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: _item.coverUrl!,
                                fit: BoxFit.cover,
                                httpHeaders: const {
                                  'Referer': 'https://hanime1.me/',
                                  'User-Agent':
                                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                                },
                                placeholder: (context, url) => Container(
                                  color: Colors.black26,
                                  child: const Center(child: CupertinoActivityIndicator()),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.black38,
                                  child: const Icon(CupertinoIcons.film_fill, color: Colors.white54, size: 48),
                                ),
                              )
                            else
                              Container(
                                color: Colors.black45,
                                child: const Icon(CupertinoIcons.film_fill, color: Colors.white54, size: 48),
                              ),

                            // Dark overlay
                            Container(color: Colors.black.withValues(alpha: 0.3)),

                            // Play Button
                            Center(
                              child: BouncingButton(
                                onTap: _playVideo,
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF2E63), Color(0xFFFF5722)],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: themeColor.withValues(alpha: 0.5),
                                        blurRadius: 16,
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

                            // Quality Badge
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: themeColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _selectedQuality.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Title & Metadata
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _item.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Broadcaster / Views / Date row
                            Row(
                              children: [
                                if (_item.author.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      context.read<Hanime1BrowseProvider>().setSelectedBroadcaster(_item.author);
                                      Navigator.pop(context);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: themeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(CupertinoIcons.tv, size: 13, color: themeColor),
                                          const SizedBox(width: 4),
                                          Text(
                                            _item.author,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: themeColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                if (_item.views.isNotEmpty)
                                  Row(
                                    children: [
                                      Icon(CupertinoIcons.eye_fill, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                                      const SizedBox(width: 4),
                                      Text(
                                        _item.views,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white54 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (_item.date.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Text(
                                    _item.date,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Quality Selector
                            if (qualities.length > 1) ...[
                              Text(
                                '画质选择',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: qualities.keys.map((q) {
                                  final isSel = q == _selectedQuality;
                                  return ChoiceChip(
                                    label: Text(q.toUpperCase()),
                                    selected: isSel,
                                    selectedColor: themeColor,
                                    labelStyle: TextStyle(
                                      color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() => _selectedQuality = q);
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Action Buttons: Play & Download
                            Row(
                              children: [
                                Expanded(
                                  child: BouncingButton(
                                    onTap: _playVideo,
                                    child: Container(
                                      height: 46,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFFF2E63), Color(0xFFFF5722)],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: themeColor.withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(CupertinoIcons.play_fill, color: Colors.white, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            '在线全屏播放',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: BouncingButton(
                                    onTap: _downloadVideo,
                                    child: Container(
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: existingTask != null
                                              ? const Color(0xFF4CAF50)
                                              : (isDark ? const Color(0x33FFFFFF) : const Color(0x22000000)),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            existingTask?.status == TaskStatus.completed
                                                ? CupertinoIcons.check_mark_circled_solid
                                                : CupertinoIcons.arrow_down_to_line,
                                            color: existingTask?.status == TaskStatus.completed
                                                ? const Color(0xFF4CAF50)
                                                : themeColor,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            existingTask?.status == TaskStatus.completed
                                                ? '已下载'
                                                : (existingTask != null ? '下载中' : '下载到本地'),
                                            style: TextStyle(
                                              color: existingTask?.status == TaskStatus.completed
                                                  ? const Color(0xFF4CAF50)
                                                  : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Related Episodes / Series Playlist
                            if (episodes.isNotEmpty) ...[
                              Text(
                                '系列选集 / 关联推荐',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 140,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: episodes.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                                  itemBuilder: (context, idx) {
                                    final ep = episodes[idx];
                                    final epUrl = ep['url']?.toString() ?? '';
                                    final epTitle = ep['title']?.toString() ?? '';
                                    final epCover = ep['cover']?.toString() ?? '';

                                    return BouncingButton(
                                      onTap: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => Hanime1DetailPage(
                                              item: VideoItem(
                                                title: epTitle,
                                                slug: 'hanime1_${epUrl.hashCode}',
                                                detailUrl: epUrl,
                                                coverUrl: epCover.isNotEmpty ? epCover : _item.coverUrl,
                                                date: _item.date,
                                                author: _item.author,
                                                tags: _item.tags,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: 160,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: epCover.isNotEmpty
                                                  ? CachedNetworkImage(
                                                      imageUrl: epCover,
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      httpHeaders: const {
                                                        'Referer': 'https://hanime1.me/',
                                                      },
                                                    )
                                                  : Container(color: Colors.black26),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(6),
                                              child: Text(
                                                epTitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Tags Cloud
                            if (_item.tags.isNotEmpty) ...[
                              Text(
                                '标签分类',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _item.tags.map((tag) {
                                  return ActionChip(
                                    label: Text(tag),
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : const Color(0xFF2C2C2E),
                                    ),
                                    backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                    onPressed: () {
                                      context.read<Hanime1BrowseProvider>().setSelectedTag(tag);
                                      Navigator.pop(context);
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ScrollToTopButton(
                  scrollController: _scrollController,
                  color: themeColor,
                  bottomOffset: 24.0,
                ),
              ],
            ),
    );
  }
}
