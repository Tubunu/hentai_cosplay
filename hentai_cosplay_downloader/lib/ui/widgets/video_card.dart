import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/download_task.dart';
import '../../models/video_item.dart';
import '../../providers/download_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/local_video_provider.dart';
import '../../providers/video_browse_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final browseProv = context.watch<VideoBrowseProvider>();
    final downloadProv = context.watch<DownloadProvider>();
    final localVideoProv = context.watch<LocalVideoProvider>();
    final historyProv = context.watch<HistoryProvider>();

    final isSelected = browseProv.isVideoSelected(item);
    final isSelectionMode = browseProv.isSelectionMode;

    // Check if task exists in download queue or completed
    final existingTask = downloadProv.allTasks.cast<AlbumDownloadTask?>().firstWhere(
      (t) => t?.isVideo == true && (
        (item.slug.isNotEmpty && t?.albumItem.slug == item.slug) ||
        t?.albumItem.title == item.title ||
        (item.detailUrl.isNotEmpty && t?.albumItem.detailUrl == item.detailUrl)
      ),
      orElse: () => null,
    );

    // Check if video is downloaded locally or recorded in history
    final isDownloaded = existingTask?.status == TaskStatus.completed ||
        localVideoProv.videos.any((v) =>
            v.title == item.title ||
            (item.detailUrl.isNotEmpty && v.sourceUrl == item.detailUrl)) ||
        historyProv.records.any((r) =>
            r.isVideo == true &&
            (r.title == item.title ||
             (item.detailUrl.isNotEmpty && r.detailUrl == item.detailUrl)));

    return BouncingButton(
      onTap: onTap,
      onLongPress: () => browseProv.toggleVideoSelection(item),
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
            // 16:9 Thumbnail Image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.coverUrl != null && item.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.coverUrl!,
                          fit: BoxFit.cover,
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

                  // Center Play Icon Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2),
                      ),
                      child: const Icon(
                        CupertinoIcons.play_fill,
                        color: Colors.white,
                        size: 16,
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

                    // Author & Date row
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
                        if (item.date.isNotEmpty)
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
