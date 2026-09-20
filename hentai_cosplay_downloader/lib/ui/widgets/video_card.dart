import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/download_task.dart';
import '../../models/video_item.dart';
import '../../providers/download_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/local_video_provider.dart';
import '../../providers/video_browse_provider.dart';
import '../../services/video_api_service.dart';
import '../pages/video/video_player_page.dart';
import '../theme/ios_theme.dart';
import 'unified_media_card.dart';
import 'package:hentai_cosplay_downloader/utils/app_share.dart';

class VideoCard extends StatefulWidget {
  final VideoItem item;
  final VoidCallback onTap;

  const VideoCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  bool _isParsing = false;

  Future<void> _playOnline(BuildContext context) async {
    if (_isParsing) return;

    // 1. If video URL already cached / resolved
    if (widget.item.videoUrl != null && widget.item.videoUrl!.isNotEmpty) {
      VideoPlayerPage.openRemote(
        context,
        url: widget.item.videoUrl!,
        title: widget.item.title,
        author: widget.item.author,
      );
      return;
    }

    setState(() {
      _isParsing = true;
    });

    // 2. Resolve video URL on the fly
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('正在解析视频'),
        content: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 12),
              const SizedBox(height: 12),
              Text(
                widget.item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final detailed = await VideoApiService.fetchVideoDetail(widget.item);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close dialog

      if (detailed != null && detailed.videoUrl != null && detailed.videoUrl!.isNotEmpty) {
        VideoPlayerPage.openRemote(
          context,
          url: detailed.videoUrl!,
          title: detailed.title,
          author: detailed.author,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('在线播放源解析失败，请进入详情页重试或检查网络'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close dialog
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('在线播放异常: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isParsing = false;
        });
      }
    }
  }

  void _showCardActionSheet(BuildContext context, DownloadProvider downloadProv, FavoriteProvider favProv, bool isFav) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(widget.item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        message: Text(widget.item.author.isNotEmpty ? '${widget.item.author} • ${widget.item.duration}' : widget.item.duration),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _playOnline(context);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.play_circle_fill, color: IosTheme.primaryPink, size: 20),
                SizedBox(width: 8),
                Text('立即在线观看', style: TextStyle(color: IosTheme.primaryPink, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onTap();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.info_circle, size: 18),
                SizedBox(width: 8),
                Text('查看视频详情'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              favProv.toggleVideo(widget.item, siteKey: 'hc_video', siteName: 'HC 视频');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isFav ? '已取消收藏: ${widget.item.title}' : '已加入收藏: ${widget.item.title}'),
                  backgroundColor: IosTheme.primaryPink,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isFav ? CupertinoIcons.heart_slash_circle : CupertinoIcons.heart_circle, size: 18),
                const SizedBox(width: 8),
                Text(isFav ? '从我的收藏中移除' : '收藏至我的收藏'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              downloadProv.addVideoTask(widget.item);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已加入视频下载队列: ${widget.item.title}'),
                  backgroundColor: IosTheme.primaryPink,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.arrow_down_circle, size: 18),
                SizedBox(width: 8),
                Text('下载视频到本地'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              final box = context.findRenderObject() as RenderBox?;
              AppShare.share(context, 
                '${widget.item.title}\n${widget.item.detailUrl}',
                sharePositionOrigin: box != null ? (box.localToGlobal(Offset.zero) & box.size) : null,
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.share, size: 18),
                SizedBox(width: 8),
                Text('分享视频链接'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = context.select<VideoBrowseProvider, bool>((p) => p.isVideoSelected(widget.item));
    final isSelectionMode = context.select<VideoBrowseProvider, bool>((p) => p.isSelectionMode);

    final favId = 'hc_video_${widget.item.slug.isNotEmpty ? widget.item.slug : widget.item.detailUrl.hashCode}';
    final isFav = context.select<FavoriteProvider, bool>(
      (p) => p.isFavoriteItem(id: favId, detailUrl: widget.item.detailUrl),
    );

    // Check if task exists in download queue or completed
    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatus(
        slug: widget.item.slug,
        detailUrl: widget.item.detailUrl,
        title: widget.item.title,
        videoUrl: widget.item.videoUrl,
      ),
    );

    final isLocalDownloaded = context.select<LocalVideoProvider, bool>(
      (p) => p.isVideoDownloaded(title: widget.item.title, detailUrl: widget.item.detailUrl),
    );

    final isHistoryRecorded = context.select<HistoryProvider, bool>(
      (p) => p.isVideoRecorded(title: widget.item.title, detailUrl: widget.item.detailUrl),
    );

    final isDownloaded = taskStatus == TaskStatus.completed || isLocalDownloaded || isHistoryRecorded;
    final isDownloading = taskStatus == TaskStatus.downloading ||
        taskStatus == TaskStatus.queued;

    return UnifiedMediaCard(
      title: widget.item.title,
      coverUrl: widget.item.coverUrl,
      mediaType: UnifiedMediaType.video,
      brandColor: IosTheme.primaryPink,
      httpHeaders: const {
        'Referer': 'https://porn-video-xxx.com/',
      },
      duration: widget.item.duration.isNotEmpty ? widget.item.duration : null,
      author: widget.item.author.isNotEmpty ? widget.item.author : null,
      date: widget.item.date.isNotEmpty ? widget.item.date : null,
      tag: widget.item.tags.isNotEmpty ? widget.item.tags.first : null,
      isSelected: isSelected,
      isSelectionMode: isSelectionMode,
      isDownloaded: isDownloaded,
      isDownloading: isDownloading,
      isFavorite: isFav,
      onFavoriteTap: () {
        context.read<FavoriteProvider>().toggleVideo(widget.item, siteKey: 'hc_video', siteName: 'HC 视频');
      },
      onTap: isSelectionMode
          ? () => context.read<VideoBrowseProvider>().toggleVideoSelection(widget.item)
          : widget.onTap,
      onLongPress: () {
        if (isSelectionMode) {
          context.read<VideoBrowseProvider>().toggleVideoSelection(widget.item);
        } else {
          _showCardActionSheet(context, context.read<DownloadProvider>(), context.read<FavoriteProvider>(), isFav);
        }
      },
    );
  }
}
