import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/album_item.dart';
import '../../models/download_task.dart';
import '../../providers/browse_provider.dart';
import '../../providers/download_provider.dart';
import '../theme/ios_theme.dart';
import 'bouncing_button.dart';

class AlbumCard extends StatelessWidget {
  final AlbumItem item;
  final VoidCallback onTap;

  const AlbumCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final browseProv = context.watch<BrowseProvider>();
    final downloadProv = context.watch<DownloadProvider>();

    final isSelected = browseProv.isAlbumSelected(item);
    final isSelectionMode = browseProv.isSelectionMode;

    // Check if album is in download queue or completed
    final existingTask = downloadProv.allTasks.cast<AlbumDownloadTask?>().firstWhere(
      (t) => t?.albumItem.slug == item.slug || t?.albumItem.detailUrl == item.detailUrl,
      orElse: () => null,
    );

    return BouncingButton(
      onTap: () {
        if (isSelectionMode) {
          browseProv.toggleAlbumSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        browseProv.toggleAlbumSelection(item);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? IosTheme.primaryPink
                : (isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
            width: isSelected ? 2.0 : 0.6,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? IosTheme.primaryPink.withValues(alpha: 0.25)
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
            // Cover Image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.coverUrl != null && item.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.coverUrl!,
                          fit: BoxFit.cover,
                          httpHeaders: const {
                            'Referer': 'https://hentai-cosplay-xxx.com/',
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
                              CupertinoIcons.photo,
                              size: 32,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          child: const Icon(CupertinoIcons.photo, size: 32, color: Colors.grey),
                        ),

                  // Gradient shadow overlay at bottom of cover
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Date badge at bottom left of cover
                  if (item.date.isNotEmpty)
                    Positioned(
                      left: 8,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.date,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  // Top right: Selection checkmark OR Download Status Pill
                  Positioned(
                    top: 8,
                    right: 8,
                    child: isSelectionMode
                        ? AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: isSelected ? IosTheme.primaryPink : Colors.black45,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    CupertinoIcons.checkmark,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          )
                        : (existingTask != null
                            ? _buildTaskStatusBadge(existingTask)
                            : const SizedBox.shrink()),
                  ),
                ],
              ),
            ),

            // Text info container
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Author Tag
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: IosTheme.primaryPink.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: IosTheme.primaryPink,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Quick download trigger
                      if (!isSelectionMode)
                        BouncingButton(
                          onTap: () {
                            downloadProv.addAlbumTask(item);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已加入下载队列: ${item.title}'),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: const Icon(
                            CupertinoIcons.arrow_down_circle_fill,
                            size: 20,
                            color: IosTheme.primaryPink,
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
