import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/download_task.dart';
import '../../models/video_item.dart';
import '../../providers/download_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/local_video_provider.dart';
import '../../providers/video_browse_provider.dart';
import '../../services/video_api_service.dart';
import '../pages/video/video_player_page.dart';
import '../theme/ios_theme.dart';
import 'bouncing_button.dart';

class VideoCard extends StatelessWidget {
  final VideoItem item;
  final VoidCallback onTap;

  const VideoCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  Future<void> _playOnline(BuildContext context) async {
    // 1. If video URL already cached / resolved
    if (item.videoUrl != null && item.videoUrl!.isNotEmpty) {
      VideoPlayerPage.openRemote(
        context,
        url: item.videoUrl!,
        title: item.title,
        author: item.author,
      );
      return;
    }

    // 2. Resolve video URL on the fly
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const CupertinoActivityIndicator(color: Colors.white, radius: 8),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '正在解析在线播放源: ${item.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );

    try {
      final detailed = await VideoApiService.fetchVideoDetail(item);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

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
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('在线播放异常: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCardActionSheet(BuildContext context, DownloadProvider downloadProv) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        message: Text(item.author.isNotEmpty ? '${item.author} • ${item.duration}' : item.duration),
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
              onTap();
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
              downloadProv.addVideoTask(item);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已加入视频下载队列: ${item.title}'),
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
              Share.share(
                '${item.title}\n${item.detailUrl}',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = context.select<VideoBrowseProvider, bool>((p) => p.isVideoSelected(item));
    final isSelectionMode = context.select<VideoBrowseProvider, bool>((p) => p.isSelectionMode);

    // Check if task exists in download queue or completed
    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.isVideo && (
          (item.slug.isNotEmpty && t.albumItem.slug == item.slug) ||
          t.albumItem.title == item.title ||
          (item.detailUrl.isNotEmpty && t.albumItem.detailUrl == item.detailUrl)
        )) {
          return t;
        }
      }
      return null;
    });

    // Check if video is downloaded locally or recorded in history
    final isLocalDownloaded = context.select<LocalVideoProvider, bool>((p) => p.videos.any((v) =>
        v.title == item.title ||
        (item.detailUrl.isNotEmpty && v.sourceUrl == item.detailUrl)));

    final isHistoryRecorded = context.select<HistoryProvider, bool>((p) => p.records.any((r) =>
        r.isVideo == true &&
        (r.title == item.title ||
         (item.detailUrl.isNotEmpty && r.detailUrl == item.detailUrl))));

    final isDownloaded = existingTask?.status == TaskStatus.completed || isLocalDownloaded || isHistoryRecorded;

    return BouncingButton(
      onTap: isSelectionMode ? () => context.read<VideoBrowseProvider>().toggleVideoSelection(item) : onTap,
      onLongPress: () {
        if (isSelectionMode) {
          context.read<VideoBrowseProvider>().toggleVideoSelection(item);
        } else {
          _showCardActionSheet(context, context.read<DownloadProvider>());
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? IosTheme.primaryPink.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: isSelected ? 12 : 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isSelected
                ? IosTheme.primaryPink
                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04)),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 16:9 Thumbnail Image with Center Play Button
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.coverUrl != null && item.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.coverUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 480,
                          httpHeaders: const {
                            'Referer': 'https://porn-video-xxx.com/',
                          },
                          placeholder: (context, url) => Container(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            child: const Center(
                              child: CupertinoActivityIndicator(radius: 10),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            child: const Icon(CupertinoIcons.film, color: Colors.grey, size: 28),
                          ),
                        )
                      : Container(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          child: const Icon(CupertinoIcons.film, color: Colors.grey, size: 28),
                        ),

                  // Subtle dark gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),

                  // Center Play Icon Badge (High-Performance lightweight translucent button)
                  if (!isSelectionMode)
                    Center(
                      child: BouncingButton(
                        onTap: () => _playOnline(context),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.55),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                              BoxShadow(
                                color: IosTheme.primaryPink.withValues(alpha: 0.25),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.play_fill,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                  // Duration Badge (bottom-right)
                  if (item.duration.isNotEmpty)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.time, size: 10, color: Colors.white70),
                            const SizedBox(width: 3),
                            Text(
                              item.duration,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Top right: Selection checkmark OR Download Status Pill / Green Checkmark
                  Positioned(
                    top: 6,
                    right: 6,
                    child: isSelectionMode
                        ? AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected ? IosTheme.primaryPink : Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: isSelected
                                ? const Icon(CupertinoIcons.checkmark, size: 14, color: Colors.white)
                                : null,
                          )
                        : (isDownloaded
                            ? _buildCompletedBadge()
                            : (existingTask != null
                                ? _buildTaskStatusBadge(existingTask)
                                : const SizedBox.shrink())),
                  ),
                ],
              ),
            ),

            // Video Info Metadata
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),

                    // Author & Online Play Pill Row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: IosTheme.primaryPink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        // Quick Online Play Trigger Pill
                        if (!isSelectionMode)
                          BouncingButton(
                            onTap: () => _playOnline(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: IosTheme.primaryPink.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: IosTheme.primaryPink.withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.play_circle_fill, size: 10, color: IosTheme.primaryPink),
                                  SizedBox(width: 3),
                                  Text(
                                    '观看',
                                    style: TextStyle(
                                      color: IosTheme.primaryPink,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (item.date.isNotEmpty)
                          Text(
                            item.date,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedBadge() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: IosTheme.primaryGreen.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: IosTheme.primaryGreen.withValues(alpha: 0.5),
            blurRadius: 6,
          ),
        ],
      ),
      child: const Icon(CupertinoIcons.checkmark_alt, size: 14, color: Colors.white),
    );
  }

  Widget _buildTaskStatusBadge(AlbumDownloadTask task) {
    Color bg;
    IconData icon;

    switch (task.status) {
      case TaskStatus.completed:
        bg = IosTheme.primaryGreen;
        icon = CupertinoIcons.checkmark_alt;
        break;
      case TaskStatus.downloading:
        bg = IosTheme.primaryPink;
        icon = CupertinoIcons.arrow_down;
        break;
      case TaskStatus.queued:
        bg = IosTheme.primaryBlue;
        icon = CupertinoIcons.clock;
        break;
      case TaskStatus.failed:
        bg = Colors.red;
        icon = CupertinoIcons.exclamationmark;
        break;
      case TaskStatus.paused:
        bg = Colors.orange;
        icon = CupertinoIcons.pause;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.5),
            blurRadius: 6,
          ),
        ],
      ),
      child: Icon(icon, size: 14, color: Colors.white),
    );
  }
}
