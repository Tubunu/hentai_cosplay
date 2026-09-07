import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/album_item.dart';
import '../../../../models/download_task.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/nsfwpub_browse_provider.dart';
import '../../../widgets/bouncing_button.dart';

class NsfwpubAlbumCard extends StatelessWidget {
  final AlbumItem item;
  final VoidCallback onTap;

  const NsfwpubAlbumCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = context.select<NsfwpubBrowseProvider, bool>((p) => p.isSelected(item));
    final isSelectionMode = context.select<NsfwpubBrowseProvider, bool>((p) => p.isSelectionMode);
    const themeColor = Color(0xFFD63384);

    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == item.slug || t.albumItem.detailUrl == item.detailUrl) {
          return t;
        }
      }
      return null;
    });

    final photoCount = item.rawData['photo_count'] as int? ?? 0;
    final model = item.rawData['model'] as String? ?? '';
    final cosplay = item.rawData['cosplay'] as String? ?? '';

    return BouncingButton(
      onTap: () {
        if (isSelectionMode) {
          context.read<NsfwpubBrowseProvider>().toggleItemSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        context.read<NsfwpubBrowseProvider>().toggleItemSelection(item);
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
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image with badges
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.coverUrl != null && item.coverUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: item.coverUrl!,
                      fit: BoxFit.cover,
                      httpHeaders: const {
                        'Referer': 'https://nsfwpub.com/',
                        'User-Agent':
                            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                      },
                      placeholder: (context, url) => Container(
                        color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                        child: const Center(
                          child: CupertinoActivityIndicator(radius: 12),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                        child: const Icon(CupertinoIcons.photo, size: 36, color: Colors.grey),
                      ),
                    )
                  else
                    Container(
                      color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                      child: const Icon(CupertinoIcons.photo, size: 36, color: Colors.grey),
                    ),

                  // Gradient Overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.75),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Photo Count Badge (Bottom Left)
                  if (photoCount > 0)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.camera_fill, size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              '$photoCount P',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Download Status Badge (Top Right)
                  if (existingTask != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: existingTask.status == TaskStatus.completed
                              ? Colors.green.withValues(alpha: 0.85)
                              : themeColor.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          existingTask.status == TaskStatus.completed
                              ? CupertinoIcons.check_mark
                              : CupertinoIcons.arrow_down,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  // Selection Checkbox
                  if (isSelectionMode || isSelected)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? themeColor : Colors.black45,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: isSelected
                            ? const Icon(CupertinoIcons.check_mark, size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
            ),

            // Card Text Details
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Model & Cosplay Tags
                  Row(
                    children: [
                      if (model.isNotEmpty && model != 'NSFWPub')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            model,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: themeColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (cosplay.isNotEmpty)
                        Expanded(
                          child: Text(
                            cosplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.black45,
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
