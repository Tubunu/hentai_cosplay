import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/kuraa_browse_provider.dart';
import '../../../../services/kuraa/kuraa_api_service.dart';
import '../../../widgets/bouncing_button.dart';

class KuraaItemCard extends StatelessWidget {
  final KuraaFileItem item;
  final VoidCallback onTap;

  const KuraaItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = context.select<KuraaBrowseProvider, bool>((p) => p.isSelected(item));
    final isSelectionMode = context.select<KuraaBrowseProvider, bool>((p) => p.isSelectionMode);
    final folderCover = item.isFolder
        ? context.select<KuraaBrowseProvider, String?>((p) => p.getFolderCover(item.id))
        : null;

    final isFolder = item.isFolder;
    final isImage = item.isImage;
    final isVideo = item.isVideo;

    // Detect if folder name contains page count like 35P, 175P
    final pMatch = RegExp(r'(\d+)\s*P', caseSensitive: false).firstMatch(item.name);
    final pageCountStr = pMatch != null ? '${pMatch.group(1)}P' : null;

    final themeColor = const Color(0xFF00897B);

    final displayImageUrl = item.hasThumbnail || isImage
        ? (item.thumbnailUrl.isNotEmpty ? item.thumbnailUrl : item.previewUrl)
        : (folderCover != null && folderCover.isNotEmpty ? folderCover : null);

    return BouncingButton(
      onTap: () {
        if (isSelectionMode) {
          context.read<KuraaBrowseProvider>().toggleItemSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        context.read<KuraaBrowseProvider>().toggleItemSelection(item);
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
                  ? themeColor.withValues(alpha: 0.3)
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
            // Preview / Thumbnail / Folder Cover Banner
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (displayImageUrl != null && displayImageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: displayImageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      placeholder: (context, url) => Container(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                        child: const Center(
                          child: CupertinoActivityIndicator(radius: 10),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                        child: Icon(
                          isFolder
                              ? CupertinoIcons.folder_fill
                              : isVideo
                                  ? CupertinoIcons.play_circle_fill
                                  : CupertinoIcons.photo,
                          size: 36,
                          color: themeColor.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isFolder
                              ? (isDark
                                  ? [const Color(0xFF1E3A3A), const Color(0xFF132B2B)]
                                  : [const Color(0xFFE0F2F1), const Color(0xFFB2DFDB)])
                              : (isDark
                                  ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]
                                  : [const Color(0xFFF2F2F7), const Color(0xFFE5E5EA)]),
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isFolder
                                  ? CupertinoIcons.folder_fill
                                  : isVideo
                                      ? CupertinoIcons.play_circle_fill
                                      : isImage
                                          ? CupertinoIcons.photo
                                          : CupertinoIcons.doc_fill,
                              size: 40,
                              color: isFolder
                                  ? themeColor
                                  : (isDark ? Colors.white60 : Colors.black45),
                            ),
                            if (pageCountStr != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                pageCountStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: themeColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // Gradient shadow at bottom of image
                  if (displayImageUrl != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 30,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Folder indicator badge if displaying cover
                  if (isFolder && displayImageUrl != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.folder_fill, color: Colors.white, size: 10),
                            if (pageCountStr != null) ...[
                              const SizedBox(width: 3),
                              Text(
                                pageCountStr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // Selection Checkbox Badge
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
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isFolder
                              ? themeColor.withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isFolder ? '图包' : (item.extension?.toUpperCase() ?? 'FILE'),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: isFolder
                                ? themeColor
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!isFolder && item.size > 0)
                        Text(
                          _formatSize(item.size),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else if (item.updatedAt.isNotEmpty)
                        Text(
                          item.updatedAt.split('T').first,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontWeight: FontWeight.w500,
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
