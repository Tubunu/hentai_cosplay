import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/download_task.dart';
import '../../../models/video_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/av123/av123_api_service.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../video/video_player_page.dart';
import '../video/web_video_player_page.dart';

class Av123DetailPage extends StatefulWidget {
  final VideoItem item;

  const Av123DetailPage({super.key, required this.item});

  @override
  State<Av123DetailPage> createState() => _Av123DetailPageState();
}

class _Av123DetailPageState extends State<Av123DetailPage> {
  final ScrollController _scrollController = ScrollController();
  late VideoItem _item;
  bool _isLoading = true;
  String? _errorMessage;
  Av123DetailData? _detailData;

  static const _themeColor = Color(0xFFE50914);

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
          siteKey: 'av123',
          siteName: '123AV',
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
      final detail = await Av123ApiService.fetchDetail(_item);
      if (mounted) {
        setState(() {
          _detailData = detail;
          _item = detail.item;
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

  bool _isResolvingStream = false;

  Future<void> _playVideo([String? specificEmbedUrl, bool forceWeb = false]) async {
    final embedUrl = specificEmbedUrl ??
        (_detailData != null && _detailData!.embedUrls.isNotEmpty
            ? _detailData!.embedUrls.first
            : _item.detailUrl);

    if (forceWeb) {
      WebVideoPlayerPage.open(
        context,
        url: embedUrl,
        title: _item.title,
      );
      return;
    }

    if (embedUrl.endsWith('.mp4') || embedUrl.endsWith('.m3u8')) {
      VideoPlayerPage.openRemote(
        context,
        url: embedUrl,
        title: _item.title,
        author: _item.author,
        webPlayerUrl: _item.detailUrl,
        headers: const {'Referer': 'https://javplayer.cc/'},
      );
      return;
    }

    setState(() {
      _isResolvingStream = true;
    });

    try {
      final streamUrl = await Av123ApiService.resolveStreamUrl(embedUrl);
      if (!mounted) return;
      setState(() {
        _isResolvingStream = false;
      });

      if (streamUrl != null && streamUrl.isNotEmpty) {
        VideoPlayerPage.openRemote(
          context,
          url: streamUrl,
          title: _item.title,
          author: _item.author,
          webPlayerUrl: _item.detailUrl,
          headers: const {'Referer': 'https://javplayer.cc/'},
        );
      } else {
        WebVideoPlayerPage.open(
          context,
          url: embedUrl,
          title: _item.title,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResolvingStream = false;
      });
      WebVideoPlayerPage.open(
        context,
        url: embedUrl,
        title: _item.title,
      );
    }
  }

  void _handleDownload() {
    context.read<DownloadProvider>().addVideoTask(_item);

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('已添加到下载队列'),
        content: Text(_item.title),
        actions: [
          CupertinoDialogAction(
            child: const Text('确定'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final downloadProvider = context.watch<DownloadProvider>();
    final task = downloadProvider.allTasks.cast<AlbumDownloadTask?>().firstWhere(
          (t) => t?.albumItem.slug == _item.slug || t?.albumItem.detailUrl == _item.detailUrl,
          orElse: () => null,
        );

    final isDownloaded = task?.status == TaskStatus.completed;
    final isDownloading = task?.status == TaskStatus.downloading ||
        task?.status == TaskStatus.queued;

    final duration = _item.duration.trim();
    final showDuration = duration.isNotEmpty &&
        duration != '0:00' &&
        duration != '00:00' &&
        duration != '0';
    final releaseDate = _detailData?.releaseDate ?? (_item.date.isNotEmpty ? _item.date : null);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF7F7F8),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
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
                      videoSite: VideoSiteType.av123,
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
                            'Referer': 'https://123av.com/cn',
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
                          onPressed: () => _playVideo(),
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
                                  '部分信息加载异常: $_errorMessage',
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

                      // Badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_item.slug.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: _themeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _item.slug.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _themeColor,
                                ),
                              ),
                            ),
                          if (showDuration)
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
                          if (releaseDate != null && releaseDate.isNotEmpty)
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
                                    CupertinoIcons.calendar,
                                    size: 13,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    releaseDate,
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

                      // Actresses
                      if (_detailData != null && _detailData!.actresses.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              CupertinoIcons.person_2_fill,
                              size: 15,
                              color: _themeColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _detailData!.actresses.join(', '),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _themeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Server Line Switcher (if multiple episodes/streams available)
                      if (_detailData != null && _detailData!.embedUrls.length > 1) ...[
                        Text(
                          '播放线路切换 (${_detailData!.embedUrls.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (int i = 0; i < _detailData!.embedUrls.length; i++)
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                borderRadius: BorderRadius.circular(10),
                                onPressed: () => _playVideo(_detailData!.embedUrls[i]),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.play_circle_fill,
                                      size: 16,
                                      color: _themeColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '播放源 ${i + 1}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Action Buttons (Play / Web Play / Download)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isResolvingStream ? null : () => _playVideo(),
                              icon: _isResolvingStream
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CupertinoActivityIndicator(color: Colors.white),
                                    )
                                  : const Icon(CupertinoIcons.play_arrow_solid, size: 18),
                              label: Text(_isResolvingStream ? '解析播放中...' : '立即播放'),
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
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(12),
                            onPressed: () => _playVideo(null, true),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.globe,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '网页',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(12),
                            onPressed: isDownloaded ? null : _handleDownload,
                            child: Row(
                              children: [
                                Icon(
                                  isDownloaded
                                      ? CupertinoIcons.check_mark_circled_solid
                                      : (isDownloading
                                          ? CupertinoIcons.arrow_down_circle_fill
                                          : CupertinoIcons.arrow_down_to_line),
                                  size: 18,
                                  color: isDownloaded
                                      ? CupertinoColors.systemGreen
                                      : _themeColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isDownloaded
                                      ? '已下载'
                                      : (isDownloading ? '下载中' : '下载'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDownloaded
                                        ? CupertinoColors.systemGreen
                                        : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Tags section
                      if (_detailData != null && _detailData!.tags.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          '影片类型与标签',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _detailData!.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF242426) : const Color(0xFFF0F0F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                '# $tag',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : const Color(0xFF3A3A3C),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
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
