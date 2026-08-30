import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/download_task.dart';
import '../../../models/video_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/pornhub/pornhub_api_service.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../video/video_player_page.dart';
import '../video/web_video_player_page.dart';

class PornhubDetailPage extends StatefulWidget {
  final VideoItem item;

  const PornhubDetailPage({super.key, required this.item});

  @override
  State<PornhubDetailPage> createState() => _PornhubDetailPageState();
}

class _PornhubDetailPageState extends State<PornhubDetailPage> {
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
          siteKey: 'pornhub',
          siteName: 'Pornhub',
          siteColor: const Color(0xFFFF9900),
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
      final resolved = await PornhubApiService.resolveVideoDetail(_item);
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
    final hasDirectStream = _item.videoUrl != null &&
        _item.videoUrl!.isNotEmpty &&
        _item.videoUrl != _item.detailUrl &&
        (_item.videoUrl!.contains('.m3u8') || _item.videoUrl!.contains('.mp4'));

    if (hasDirectStream) {
      VideoPlayerPage.openRemote(
        context,
        url: _item.videoUrl!,
        title: _item.title,
        author: _item.author,
        webPlayerUrl: _item.detailUrl,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
          'Referer': 'https://cn.pornhub.com/',
          'Origin': 'https://cn.pornhub.com',
          'Cookie':
              'age_verified=1; platform=pc; accessAgeDisclaimerPH=1; cookie_preferences=%7B%221%22%3A1%2C%222%22%3A1%2C%223%22%3A1%2C%224%22%3A1%7D; hasVisited=1;',
        },
      );
    } else {
      WebVideoPlayerPage.open(
        context,
        url: _item.detailUrl,
        title: _item.title,
      );
    }
  }

  void _openWebPlayer() {
    WebVideoPlayerPage.open(
      context,
      url: _item.detailUrl,
      title: _item.title,
    );
  }

  void _downloadVideo() {
    final downloadProv = context.read<DownloadProvider>();
    downloadProv.addVideoTask(_item);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 "${_item.title}" 到视频下载队列'),
        backgroundColor: const Color(0xFFFF9900),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFFFF9900);

    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == _item.slug || t.albumItem.detailUrl == _item.detailUrl) {
          return t;
        }
      }
      return null;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          const RandomActionButton.video(
            videoSite: VideoSiteType.pornhub,
            replace: true,
            color: themeColor,
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
                      Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _resolveDetail, child: const Text('重试')),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                      'Referer': 'https://cn.pornhub.com/',
                                      'User-Agent':
                                          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
                                    },
                                    placeholder: (context, url) => Container(
                                      color: Colors.black,
                                      child: const Center(child: CupertinoActivityIndicator()),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.black,
                                      child: const Icon(CupertinoIcons.video_camera, color: Colors.white24, size: 48),
                                    ),
                                  )
                                else
                                  Container(
                                    color: Colors.black,
                                    child: const Icon(CupertinoIcons.video_camera, color: Colors.white24, size: 48),
                                  ),

                                Center(
                                  child: GestureDetector(
                                    onTap: _playVideo,
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: themeColor.withValues(alpha: 0.95),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.black, size: 32),
                                    ),
                                  ),
                                ),

                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: themeColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Pornhub HD',
                                      style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _item.title,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, height: 1.3),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(CupertinoIcons.eye, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(_item.views, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(width: 16),
                                    const Icon(CupertinoIcons.clock, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(_item.duration.isNotEmpty ? _item.duration : 'HD', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    const Spacer(),
                                    Text(_item.author, style: const TextStyle(color: themeColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: themeColor,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(CupertinoIcons.play_circle_fill, size: 18),
                                        label: const Text('在线极速播放', style: TextStyle(fontWeight: FontWeight.bold)),
                                        onPressed: _playVideo,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: isDark ? Colors.white : Colors.black87,
                                          side: const BorderSide(color: Colors.white24),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(CupertinoIcons.globe, size: 18),
                                        label: const Text('网页播放模式'),
                                        onPressed: _openWebPlayer,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: existingTask?.status == TaskStatus.completed
                                          ? Colors.green
                                          : (isDark ? Colors.grey[850] : Colors.grey[200]),
                                      foregroundColor: existingTask?.status == TaskStatus.completed ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: Icon(
                                      existingTask?.status == TaskStatus.completed
                                          ? CupertinoIcons.checkmark_alt
                                          : CupertinoIcons.arrow_down_to_line,
                                      size: 18,
                                    ),
                                    label: Text(
                                      existingTask?.status == TaskStatus.completed
                                          ? '视频已下载到本地'
                                          : '下载此视频到本地',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: _downloadVideo,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                const Text('视频标签', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _item.tags.map((t) {
                                    return Chip(
                                      label: Text(t, style: const TextStyle(fontSize: 11)),
                                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    );
                                  }).toList(),
                                ),
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
