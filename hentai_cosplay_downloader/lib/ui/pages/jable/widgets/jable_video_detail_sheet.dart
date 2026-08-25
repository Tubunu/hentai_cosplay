import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/jable_video_item.dart';
import '../../../../providers/jable_download_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../services/jable/scrapers/base_scraper.dart';
import '../../../theme/ios_theme.dart';
import '../../../widgets/bouncing_button.dart';
import '../../video/video_player_page.dart';
import '../../video/web_video_player_page.dart';

class JableVideoDetailSheet extends StatefulWidget {
  final VideoCardModel video;
  final BaseScraper scraper;

  const JableVideoDetailSheet({
    super.key,
    required this.video,
    required this.scraper,
  });

  static void show(BuildContext context, VideoCardModel video, BaseScraper scraper) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JableVideoDetailSheet(video: video, scraper: scraper),
    );
  }

  @override
  State<JableVideoDetailSheet> createState() => _JableVideoDetailSheetState();
}

class _JableVideoDetailSheetState extends State<JableVideoDetailSheet> {
  bool _isResolvingStream = false;
  String? _streamError;

  Future<void> _watchOnline() async {
    setState(() {
      _isResolvingStream = true;
      _streamError = null;
    });

    try {
      final detail = await widget.scraper.parseVideoDetail(widget.video.url);
      if (!mounted) return;

      setState(() {
        _isResolvingStream = false;
      });

      Navigator.pop(context); // Close sheet

      if (detail.m3u8Url.contains('.m3u8') ||
          detail.m3u8Url.contains('.mp4') ||
          detail.m3u8Url.contains('get_video') ||
          detail.m3u8Url.contains('hls')) {
        VideoPlayerPage.openRemote(
          context,
          url: detail.m3u8Url,
          title: detail.title.isNotEmpty ? detail.title : widget.video.title,
          headers: detail.headers,
          webPlayerUrl: detail.webPlayerUrl ?? widget.video.url,
        );
      } else {
        WebVideoPlayerPage.open(
          context,
          url: detail.webPlayerUrl ?? detail.m3u8Url,
          title: detail.title.isNotEmpty ? detail.title : widget.video.title,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResolvingStream = false;
        _streamError = '原生流解析失败: $e';
      });
    }
  }

  void _watchViaWeb() {
    Navigator.pop(context);
    WebVideoPlayerPage.open(
      context,
      url: widget.video.url,
      title: widget.video.title,
    );
  }

  void _addToDownloadQueue() async {
    final downloadProvider = context.read<JableDownloadProvider>();
    final success = await downloadProvider.enqueue(
      widget.video.url,
      initialTitle: widget.video.title,
      initialThumbnail: widget.video.thumbnail,
      siteName: widget.video.siteName,
      duration: widget.video.duration,
    );

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '已添加至 Jable 下载队列' : '该视频已在下载列表或历史记录中'),
        backgroundColor: success ? Colors.green[700] : Colors.orange[800],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final savePath = context.select<SettingsProvider, String>((p) => p.config.savePath);
    final jableSavePath = "$savePath/jabletv";

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Video Cover & Info Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 120,
                  height: 80,
                  child: CachedNetworkImage(
                    imageUrl: widget.video.thumbnail,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: isDark ? Colors.white10 : Colors.black12),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark ? Colors.white10 : Colors.black12,
                      child: const Icon(CupertinoIcons.video_camera, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title and Meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: IosTheme.primaryPink.withAlpha(40),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.video.siteName,
                            style: const TextStyle(
                              color: IosTheme.primaryPink,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (widget.video.duration.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            widget.video.duration,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 14),

          // Save Path Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.folder, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "保存目录: $jableSavePath",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          if (_streamError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.exclamationmark_circle, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _streamError!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    color: IosTheme.primaryPink,
                    onPressed: _watchViaWeb,
                    child: const Text('转网页播放', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Triple Action Buttons: 原生在线播放, 网页极速播放 & 加入下载
          Row(
            children: [
              // 1. 原生在线播放
              Expanded(
                flex: 3,
                child: BouncingButton(
                  onTap: _isResolvingStream ? () {} : _watchOnline,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black.withAlpha(15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: IosTheme.primaryPink.withAlpha(100),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isResolvingStream)
                          const CupertinoActivityIndicator(radius: 8)
                        else
                          const Icon(CupertinoIcons.play_circle_fill, color: IosTheme.primaryPink, size: 19),
                        const SizedBox(width: 6),
                        Text(
                          _isResolvingStream ? '解析中...' : '在线播放',
                          style: const TextStyle(
                            color: IosTheme.primaryPink,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. 网页播放模式
              BouncingButton(
                onTap: _watchViaWeb,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.globe, size: 18, color: Colors.blueAccent),
                      SizedBox(width: 4),
                      Text('网页播放', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 3. 加入下载队列
              Expanded(
                flex: 3,
                child: BouncingButton(
                  onTap: _addToDownloadQueue,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2D55), Color(0xFFFF2A6D)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2D55).withAlpha(90),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.arrow_down_circle_fill, color: Colors.white, size: 19),
                        SizedBox(width: 6),
                        Text(
                          '加入下载',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
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
        ],
      ),
    );
  }
}
