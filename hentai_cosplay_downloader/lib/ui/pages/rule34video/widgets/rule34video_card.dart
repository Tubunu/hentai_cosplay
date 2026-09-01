import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/download_task.dart';
import '../../../../models/video_item.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/rule34video_browse_provider.dart';
import '../../../widgets/bouncing_button.dart';

class Rule34VideoCard extends StatelessWidget {
  final VideoItem item;
  final VoidCallback onTap;

  const Rule34VideoCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = context.select<Rule34VideoBrowseProvider, bool>((p) => p.isSelected(item));
    final isSelectionMode = context.select<Rule34VideoBrowseProvider, bool>((p) => p.isSelectionMode);
    const themeColor = Color(0xFFFF6B35);

    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == item.slug || t.albumItem.detailUrl == item.detailUrl) {
          return t;
        }
      }
      return null;
    });

    final duration = item.rawData['duration'] as String? ?? '';
    final rating = item.rawData['rating'] as String? ?? '';

    return BouncingButton(
      onTap: () {
        if (isSelectionMode) {
          context.read<Rule34VideoBrowseProvider>().toggleItemSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        context.read<Rule34VideoBrowseProvider>().toggleItemSelection(item);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? themeColor
                : (isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
            width: isSelected ? 2.0 : 0.6,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? themeColor.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image with Badges & Gradients
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.coverUrl != null && item.coverUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: item.coverUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 450,
                      httpHeaders: const {
                        'Referer': 'https://rule34video.com/',
                        'User-Agent':
                            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                      },
                      placeholder: (context, url) => Container(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                        child: const Center(child: CupertinoActivityIndicator(radius: 10)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                        child: const Icon(CupertinoIcons.film_fill, size: 32, color: Colors.grey),
                      ),
                    )
                  else
                    Container(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                      child: const Center(child: Icon(CupertinoIcons.film_fill, color: Colors.grey)),
                    ),

                  // Bottom Gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 42,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // HD Badge (Top Left)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF9F1A)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'HD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Duration Badge (Bottom Right)
                  if (duration.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          duration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  // Rating / Added (Bottom Left)
                  if (rating.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      left: 8,
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.hand_thumbsup_fill, size: 10, color: Color(0xFFFF9F1A)),
                          const SizedBox(width: 3),
                          Text(
                            rating,
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                  // Multi-select Indicator
                  if (isSelectionMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? themeColor : Colors.black.withValues(alpha: 0.55),
                          border: Border.all(
                            color: Colors.white,
                            width: 1.8,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(CupertinoIcons.checkmark, size: 15, color: Colors.white)
                            : null,
                      ),
                    ),

                  // Download Status Badge (Top Right if not selection mode)
                  if (!isSelectionMode && existingTask != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              existingTask.status == TaskStatus.completed
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.arrow_down_circle_fill,
                              size: 13,
                              color: existingTask.status == TaskStatus.completed ? const Color(0xFF4CD964) : themeColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              existingTask.status == TaskStatus.completed ? '已下载' : '${(existingTask.progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: existingTask.status == TaskStatus.completed ? const Color(0xFF4CD964) : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Card Text Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.tv_fill, size: 12, color: themeColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.author.isNotEmpty ? item.author : 'Rule34Video',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                      if (item.date.isNotEmpty)
                        Text(
                          item.date,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
