import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/download_task.dart';
import '../../../models/video_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/xnxx/xnxx_api_service.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../video/video_player_page.dart';
import '../video/web_video_player_page.dart';

class XnxxDetailPage extends StatefulWidget {
  final VideoItem item;

  const XnxxDetailPage({super.key, required this.item});

  @override
  State<XnxxDetailPage> createState() => _XnxxDetailPageState();
}

class _XnxxDetailPageState extends State<XnxxDetailPage> {
  final ScrollController _scrollController = ScrollController();
  late VideoItem _item;
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedQuality = 'high';

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
          siteKey: 'xnxx',
          siteName: 'XNXX',
          siteColor: const Color(0xFF0275D8),
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
      final resolved = await XnxxApiService.resolveVideoDetail(_item);
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

  String? _getEffectiveStreamUrl() {
    if (_selectedQuality == 'low') {
      final low = _item.rawData['video_low'] as String?;
      if (low != null && low.isNotEmpty) return low;
    }
    final high = _item.rawData['video_high'] as String?;
    if (high != null && high.isNotEmpty) return high;
    final hls = _item.rawData['video_hls'] as String?;
    if (hls != null && hls.isNotEmpty) return hls;
    return _item.videoUrl;
  }

  void _playVideo() {
    final streamUrl = _getEffectiveStreamUrl();
    final hasDirectStream = streamUrl != null &&
        streamUrl.isNotEmpty &&
        streamUrl != _item.detailUrl &&
        (streamUrl.contains('.mp4') || streamUrl.contains('.m3u8'));

    if (hasDirectStream) {
      VideoPlayerPage.openRemote(
        context,
        url: streamUrl,
        title: _item.title,
        author: 'XNXX',
        webPlayerUrl: _item.detailUrl,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': 'https://www.xnxx.com/',
        },
      );
    } else {
      WebVideoPlayerPage.open(context, url: _item.detailUrl, title: _item.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFF0275D8);

    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatus(slug: _item.slug, detailUrl: _item.detailUrl),
    );
    final isDownloaded = taskStatus == TaskStatus.completed;
    final isDownloading = taskStatus == TaskStatus.downloading ||
        taskStatus == TaskStatus.queued;

    final hasHigh = (_item.rawData['video_high'] as String? ?? '').isNotEmpty;
    final hasLow = (_item.rawData['video_low'] as String? ?? '').isNotEmpty;

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
                    videoSite: VideoSiteType.xnxx,
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
                                    'Referer': 'https://www.xnxx.com/',
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

                      // Metadata Tags (Duration, Resolution, Views, Direct Stream Status)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (_item.duration.isNotEmpty && _item.duration != '-') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.time, size: 13, color: isDark ? Colors.white70 : Colors.black54),
                                  const SizedBox(width: 4),
                                  Text(
                                    _item.duration,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if ((_item.rawData['resolution'] as String? ?? '').isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 0.6),
                              ),
                              child: Text(
                                _item.rawData['resolution'] as String,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: themeColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                          if (_item.views.isNotEmpty && _item.views != '-') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.eye, size: 13, color: isDark ? Colors.white70 : Colors.black54),
                                  const SizedBox(width: 4),
                                  Text(
                                    _item.views,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if ((_item.rawData['video_url'] as String? ?? '').isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 0.6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.checkmark_seal_fill, size: 12, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    '直链已解析',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Quality Switcher / Indicator
                      if (hasHigh && hasLow) ...[
                        Row(
                          children: [
                            const Text('画质选择: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('高清 (High)'),
                              selected: _selectedQuality == 'high',
                              selectedColor: themeColor.withValues(alpha: 0.2),
                              labelStyle: TextStyle(
                                color: _selectedQuality == 'high' ? themeColor : null,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _selectedQuality = 'high');
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('标清 (Low)'),
                              selected: _selectedQuality == 'low',
                              selectedColor: themeColor.withValues(alpha: 0.2),
                              labelStyle: TextStyle(
                                color: _selectedQuality == 'low' ? themeColor : null,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _selectedQuality = 'low');
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ] else if (hasHigh) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.sparkles, size: 14, color: themeColor),
                              const SizedBox(width: 6),
                              Text(
                                '画质支持: 高清直链 (High MP4 ${_item.rawData['resolution'] ?? ''})',
                                style: const TextStyle(fontSize: 12, color: themeColor, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else if ((_item.rawData['video_hls'] as String? ?? '').isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.dot_radiowaves_left_right, size: 14, color: Colors.blue),
                              SizedBox(width: 6),
                              Text(
                                '画质支持: 自适应高清流 (HLS m3u8)',
                                style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

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
                          label: const Text('若直链播放失败，点击使用【内置网页播放模式】', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.white60 : Colors.black54,
                          ),
                          onPressed: () {
                            WebVideoPlayerPage.open(context, url: _item.detailUrl, title: _item.title);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Video Specifications Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(CupertinoIcons.info_circle_fill, size: 16, color: themeColor),
                                SizedBox(width: 6),
                                Text(
                                  '视频详细参数',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Divider(height: 18),
                            _buildInfoRow('来源站点', 'XNXX.COM (官方直链)', isDark),
                            if (_item.slug.isNotEmpty)
                              _buildInfoRow('视频编号', _item.slug, isDark),
                            if (_item.duration.isNotEmpty && _item.duration != '-')
                              _buildInfoRow('视频时长', _item.duration, isDark),
                            if ((_item.rawData['resolution'] as String? ?? '').isNotEmpty)
                              _buildInfoRow('视频分辨率', _item.rawData['resolution'] as String, isDark),
                            if (_item.views.isNotEmpty && _item.views != '-')
                              _buildInfoRow('全网播放', _item.views, isDark),
                            _buildInfoRow(
                              '直链解析',
                              (_item.rawData['video_url'] as String? ?? '').isNotEmpty ? '已成功获取直连媒体流' : '网页直接播放就绪',
                              isDark,
                            ),
                            _buildInfoRow('下载支持', '支持后台并发断点续传', isDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Tags List
                      Text(
                        '标签与分类 (${_item.tags.isEmpty ? 1 : _item.tags.length})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (_item.tags.isNotEmpty ? _item.tags : const ['XNXX', '高清视频']).map((t) {
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
                      const SizedBox(height: 30),
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

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
