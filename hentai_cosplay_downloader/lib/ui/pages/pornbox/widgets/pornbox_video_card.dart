import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/download_task.dart';
import '../../../../models/video_item.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/pornbox_browse_provider.dart';
import '../../../../services/pornbox/pornbox_api_service.dart';
import '../../../widgets/bouncing_button.dart';

class PornboxVideoCard extends StatelessWidget {
  final VideoItem item;
  final VoidCallback onTap;

  const PornboxVideoCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = context.select<PornboxBrowseProvider, bool>((p) => p.isSelected(item));
    final isSelectionMode = context.select<PornboxBrowseProvider, bool>((p) => p.isSelectionMode);

    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == item.slug || t.albumItem.detailUrl == item.detailUrl) {
          return t;
        }
      }
      return null;
    });

    final is4K = item.tags.contains('4K') || item.views.contains('4K');
    final isHD = is4K || item.tags.contains('HD') || item.views.contains('高清');

    return BouncingButton(
      onTap: () {
        if (isSelectionMode) {
          context.read<PornboxBrowseProvider>().toggleItemSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        context.read<PornboxBrowseProvider>().toggleItemSelection(item);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8E24AA)
                : (isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
            width: isSelected ? 2.0 : 0.6,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF8E24AA).withValues(alpha: 0.3)
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
            // Video Thumbnail
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.coverUrl != null && item.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.coverUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 450,
                          httpHeaders: const {
                            'Referer': 'https://pornbox.com/',
                            'Cookie': PornboxApiService.kDefaultCookie,
                          },
                          placeholder: (context, url) => Container(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            child: const Center(
                              child: CupertinoActivityIndicator(radius: 10),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            child: const Icon(
                              CupertinoIcons.cube_box_fill,
                              size: 32,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          child: const Icon(CupertinoIcons.cube_box_fill, color: Colors.grey),
                        ),

                  // Bottom Gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Studio / Brand Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E24AA).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.author.isNotEmpty ? item.author : 'PORNBOX',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  // 4K / HD Badge
                  if (is4K || isHD)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: is4K ? const Color(0xFFFFD700) : Colors.redAccent.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          is4K ? '4K' : 'HD',
                          style: TextStyle(
                            color: is4K ? Colors.black : Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                  // Duration Badge
                  if (item.duration.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.clock, size: 10, color: Colors.white70),
                            const SizedBox(width: 3),
                            Text(
                              item.duration,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Task Status Badge
                  if (existingTask != null)
                    Positioned(
                      top: 8,
                      right: is4K || isHD ? 36 : 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: existingTask.status == TaskStatus.completed
                              ? const Color(0xFF34C759)
                              : const Color(0xFF8E24AA),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          existingTask.status == TaskStatus.completed
                              ? CupertinoIcons.checkmark
                              : CupertinoIcons.arrow_down,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  // Selection Checkbox
                  if (isSelectionMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF8E24AA) : Colors.black45,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          isSelected ? CupertinoIcons.checkmark_alt : null,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Metadata & Title
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.film_fill, size: 11, color: Color(0xFF8E24AA)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
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
