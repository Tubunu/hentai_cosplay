import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/album_item.dart';
import '../../../../models/download_task.dart';
import '../../../../providers/coomer_browse_provider.dart';
import '../../../../providers/download_provider.dart';
import '../../../../services/coomer/coomer_api_service.dart';
import '../../../theme/ios_theme.dart';
import '../../../widgets/bouncing_button.dart';

class CoomerPostCard extends StatelessWidget {
  final AlbumItem item;
  final VoidCallback onTap;

  const CoomerPostCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = context.select<CoomerBrowseProvider, bool>((p) => p.isSelected(item));
    final isSelectionMode = context.select<CoomerBrowseProvider, bool>((p) => p.isSelectionMode);

    final raw = item.rawData;
    final service = raw['service']?.toString() ?? 'onlyfans';
    final user = raw['user']?.toString() ?? item.author;
    final fileCount = (raw['fileCount'] ?? item.imageUrls.length) as int;
    final hasVideo = item.tags.contains('Video');

    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == item.slug || t.albumItem.detailUrl == item.detailUrl) {
          return t;
        }
      }
      return null;
    });

    final platformColor = _getServiceColor(service);

    return BouncingButton(
      onTap: () {
        if (isSelectionMode) {
          context.read<CoomerBrowseProvider>().toggleItemSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        context.read<CoomerBrowseProvider>().toggleItemSelection(item);
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
            // Media Cover / Preview
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
                            'Referer': 'https://coomer.st/',
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

                  // Platform Badge (OnlyFans / Fansly / Patreon...)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: platformColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        service.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  // File count badge (e.g. 5P / Video)
                  Positioned(
                    bottom: 6,
                    left: 8,
                    child: Row(
                      children: [
                        if (hasVideo) ...[
                          const Icon(CupertinoIcons.play_rectangle_fill, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                        ] else ...[
                          const Icon(CupertinoIcons.photo_on_rectangle, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          fileCount > 0 ? '$fileCount 附件' : (hasVideo ? '视频' : '图文'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
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
                          color: existingTask.status == TaskStatus.completed
                              ? const Color(0xFF34C759)
                              : IosTheme.primaryPink,
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
                  Row(
                    children: [
                      // Creator avatar
                      ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: CoomerApiService.resolveAvatarUrl(service, user),
                          width: 16,
                          height: 16,
                          fit: BoxFit.cover,
                          httpHeaders: const {'Referer': 'https://coomer.st/'},
                          errorWidget: (_, __, ___) => const Icon(CupertinoIcons.person_crop_circle, size: 16),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          user,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: platformColor,
                          ),
                        ),
                      ),
                      if (item.date.isNotEmpty)
                        Text(
                          item.date,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: isDark ? Colors.white : Colors.black87,
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

  Color _getServiceColor(String service) {
    switch (service.toLowerCase()) {
      case 'onlyfans':
        return const Color(0xFF00AFF0);
      case 'fansly':
        return const Color(0xFF3399FF);
      case 'patreon':
        return const Color(0xFFFF424D);
      case 'candfans':
        return const Color(0xFFFF8C00);
      default:
        return const Color(0xFF9B51E0);
    }
  }
}
