import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/album_item.dart';
import '../../../../models/download_task.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/nucosplay_browse_provider.dart';
import '../../../widgets/bouncing_button.dart';

class NucosplayCard extends StatelessWidget {
  final AlbumItem item;
  final VoidCallback onTap;

  const NucosplayCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = context.select<NucosplayBrowseProvider, bool>((p) => p.isSelected(item));
    final isSelectionMode = context.select<NucosplayBrowseProvider, bool>((p) => p.isSelectionMode);
    const themeColor = Color(0xFF7E57C2);

    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == item.slug || t.albumItem.detailUrl == item.detailUrl) {
          return t;
        }
      }
      return null;
    });

    final category = item.tags.isNotEmpty ? item.tags.first : 'NuCosplay';

    return BouncingButton(
      onTap: () {
        if (isSelectionMode) {
          context.read<NucosplayBrowseProvider>().toggleItemSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        context.read<NucosplayBrowseProvider>().toggleItemSelection(item);
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
                        'Referer': 'https://nucosplay.com/',
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                      },
                      placeholder: (context, url) => Container(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                        child: const Center(child: CupertinoActivityIndicator(radius: 10)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                        child: const Icon(CupertinoIcons.photo, size: 32, color: Colors.grey),
                      ),
                    )
                  else
                    Container(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                      child: const Center(child: Icon(CupertinoIcons.photo, color: Colors.grey)),
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

                  // Top-Left Category Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),

                  // Top-Right: Selection Checkbox or Task Status Badge
                  if (isSelectionMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected ? themeColor : Colors.black38,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: isSelected
                            ? const Icon(CupertinoIcons.checkmark, size: 13, color: Colors.white)
                            : null,
                      ),
                    )
                  else if (existingTask != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: existingTask.status == TaskStatus.completed
                              ? const Color(0xFF34C759)
                              : themeColor,
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

                  // Bottom-Left Date / Info
                  if (item.date.isNotEmpty)
                    Positioned(
                      left: 8,
                      bottom: 6,
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.calendar, size: 10, color: Colors.white70),
                          const SizedBox(width: 3),
                          Text(
                            item.date,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Item Information Block
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.person_fill, size: 11, color: themeColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.author.isNotEmpty ? item.author : 'NuCosplay',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          context.read<DownloadProvider>().addAlbumTask(item);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已添加 "${item.title}" 到下载队列'),
                              backgroundColor: themeColor,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            CupertinoIcons.cloud_download,
                            size: 13,
                            color: themeColor,
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
