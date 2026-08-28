import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/album_item.dart';
import '../../../../models/download_task.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/misskon_browse_provider.dart';
import '../../../theme/ios_theme.dart';
import '../../../widgets/bouncing_button.dart';

class MisskonAlbumCard extends StatelessWidget {
  final AlbumItem item;
  final VoidCallback onTap;

  const MisskonAlbumCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = context.select<MisskonBrowseProvider, bool>((p) => p.isSelected(item));
    final isSelectionMode = context.select<MisskonBrowseProvider, bool>((p) => p.isSelectionMode);

    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == item.slug || t.albumItem.detailUrl == item.detailUrl) {
          return t;
        }
      }
      return null;
    });

    final views = item.rawData['views']?.toString() ?? '';

    return BouncingButton(
      onTap: () {
        if (isSelectionMode) {
          context.read<MisskonBrowseProvider>().toggleItemSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        context.read<MisskonBrowseProvider>().toggleItemSelection(item);
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
                          memCacheWidth: 450,
                          httpHeaders: const {
                            'Referer': 'https://misskon.com/',
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
                          child: const Icon(CupertinoIcons.photo, color: Colors.grey),
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

                  // MissKon Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE74C3C).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'MissKon',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  // Views count
                  if (views.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      left: 8,
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.eye_fill, size: 10.5, color: Colors.white70),
                          const SizedBox(width: 3),
                          Text(
                            views,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Task Status Badge
                  if (existingTask != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(existingTask.status),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor(existingTask.status).withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getStatusIcon(existingTask.status),
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
                          color: isSelected ? IosTheme.primaryPink : Colors.black45,
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
                  if (item.tags.isNotEmpty)
                    Text(
                      item.tags.take(3).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return const Color(0xFF34C759);
      case TaskStatus.downloading:
        return IosTheme.primaryPink;
      case TaskStatus.queued:
        return const Color(0xFFFF9500);
      case TaskStatus.paused:
        return Colors.grey;
      case TaskStatus.failed:
        return const Color(0xFFFF3B30);
      default:
        return Colors.transparent;
    }
  }

  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return CupertinoIcons.checkmark;
      case TaskStatus.downloading:
        return CupertinoIcons.arrow_down;
      case TaskStatus.queued:
        return CupertinoIcons.clock;
      case TaskStatus.paused:
        return CupertinoIcons.pause;
      case TaskStatus.failed:
        return CupertinoIcons.exclamationmark;
      default:
        return CupertinoIcons.circle;
    }
  }
}
