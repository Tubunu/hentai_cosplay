import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/download_task.dart';
import '../../../models/video_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/eporner/eporner_api_service.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../video/video_player_page.dart';
import '../video/web_video_player_page.dart';

class EpornerDetailPage extends StatefulWidget {
  final VideoItem item;

  const EpornerDetailPage({super.key, required this.item});

  @override
  State<EpornerDetailPage> createState() => _EpornerDetailPageState();
}

class _EpornerDetailPageState extends State<EpornerDetailPage> {
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
          siteKey: 'eporner',
          siteName: 'EPorner',
          siteColor: const Color(0xFFE53935),
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
      final resolved = await EpornerApiService.resolveVideoDetail(_item);
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
    if (_item.videoUrl != null &&
        _item.videoUrl!.isNotEmpty &&
        (_item.videoUrl!.contains('.m3u8') || _item.videoUrl!.contains('.mp4'))) {
      VideoPlayerPage.openRemote(
        context,
        url: _item.videoUrl!,
        title: _item.title,
        author: _item.author,
        webPlayerUrl: _item.detailUrl,
      );
    } else {
      _openWebPlayer();
    }
  }

  void _openWebPlayer() {
    final embedUrl = _item.rawData['embed']?.toString();
    final targetUrl = (embedUrl != null && embedUrl.isNotEmpty) ? embedUrl : _item.detailUrl;
    WebVideoPlayerPage.open(
      context,
      url: targetUrl,
      title: _item.title,
    );
  }

  void _downloadVideo() {
    final downloadProv = context.read<DownloadProvider>();
    downloadProv.addVideoTask(_item);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 "${_item.title}" 到视频下载队列'),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            videoSite: VideoSiteType.eporner,
            replace: true,
            color: Color(0xFFE53935),
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
                                    color: const Color(0xFFE53935).withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.white, size: 32),
                                ),
                              ),
                            ),

                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE53935),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'EPorner 4K',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                                Text(_item.date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE53935),
                                      foregroundColor: Colors.white,
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
                  color: const Color(0xFFFF2D55),
                  bottomOffset: 24.0,
                ),
              ],
            ),
    );
  }
}
