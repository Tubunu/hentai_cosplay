import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/download_task.dart';
import '../../../../models/video_item.dart';
import '../../../../providers/download_provider.dart';
import '../../../../services/twitter_rankings/twitter_site_config.dart';
import '../../../widgets/bouncing_button.dart';

class TwitterVideoCard extends StatelessWidget {
  final VideoItem video;
  final TwitterSiteConfig site;
  final VoidCallback onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onSelectToggle;

  const TwitterVideoCard({
    super.key,
    required this.video,
    required this.site,
    required this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onSelectToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check download status from DownloadProvider
    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == video.slug || t.albumItem.title == video.title) {
          return t;
        }
      }
      return null;
    });

    final isDownloaded = existingTask?.status == TaskStatus.completed;

    return BouncingButton(
      onTap: isSelectionMode ? onSelectToggle : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: site.themeColor, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with Duration & Selection Checkbox
            AspectRatio(
              aspectRatio: 1.25,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (video.coverUrl != null && video.coverUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: video.coverUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      placeholder: (_, __) => Container(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                        child: const Center(child: CupertinoActivityIndicator(radius: 8)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                        child: const Icon(CupertinoIcons.play_rectangle, color: Colors.grey, size: 28),
                      ),
                    )
                  else
                    Container(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                      child: const Icon(CupertinoIcons.play_rectangle, color: Colors.grey, size: 28),
                    ),

                  // Gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.2),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Center Play Icon Indicator
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.2),
                      ),
                      child: const Icon(
                        CupertinoIcons.play_fill,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),

                  // Duration Pill
                  if (video.duration.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          video.duration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                  // Top Site Badge
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: site.themeColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(site.icon, color: Colors.white, size: 9),
                          const SizedBox(width: 3),
                          Text(
                            site.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Downloaded check badge
                  if (isDownloaded)
                    Positioned(
                      top: 6,
                      right: isSelectionMode ? 32 : 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: CupertinoColors.systemGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 10),
                      ),
                    ),

                  // Selection Checkbox
                  if (isSelectionMode)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected ? site.themeColor : Colors.black45,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: isSelected
                            ? const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 13)
                            : null,
                      ),
                    ),
                ],
              ),
            ),

            // Video Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Author & Stats Row
                  Row(
                    children: [
                      // Author Handle
                      Expanded(
                        child: Text(
                          video.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: site.themeColor,
                          ),
                        ),
                      ),

                      // Quick 1-click Download button
                      BouncingButton(
                        onTap: () {
                          final downloadProv = context.read<DownloadProvider>();
                          downloadProv.addVideoTask(video);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已添加 "${video.title}" 到下载队列'),
                              backgroundColor: site.themeColor,
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: site.themeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            isDownloaded
                                ? CupertinoIcons.arrow_down_doc_fill
                                : CupertinoIcons.cloud_download,
                            size: 13,
                            color: site.themeColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Views / Likes info
                  if (video.views.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      video.views,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
