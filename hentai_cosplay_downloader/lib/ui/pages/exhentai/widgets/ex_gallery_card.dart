import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/album_item.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/exhentai_browse_provider.dart';
import '../../../widgets/bouncing_button.dart';

class ExGalleryCard extends StatelessWidget {
  final AlbumItem item;
  final VoidCallback onTap;

  const ExGalleryCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  Color _getCategoryColor(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('doujinshi')) return const Color(0xFFE53935);
    if (lower.contains('manga')) return const Color(0xFFFB8C00);
    if (lower.contains('artist')) return const Color(0xFFF57F17);
    if (lower.contains('game')) return const Color(0xFF43A047);
    if (lower.contains('western')) return const Color(0xFF6D4C41);
    if (lower.contains('non-h')) return const Color(0xFF00ACC1);
    if (lower.contains('image')) return const Color(0xFF1E88E5);
    if (lower.contains('cosplay')) return const Color(0xFF8E24AA);
    if (lower.contains('asian')) return const Color(0xFFD81B60);
    return const Color(0xFF757575);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = context.select<ExHentaiBrowseProvider, bool>((p) => p.isSelected(item));
    final isSelectionMode = context.select<ExHentaiBrowseProvider, bool>((p) => p.isSelectionMode);

    final category = item.author.isNotEmpty ? item.author : 'ExHentai';
    final catColor = _getCategoryColor(category);

    final rating = item.rawData['rating']?.toString() ?? '';
    final filecount = item.rawData['filecount']?.toString();

    return BouncingButton(
      onTap: () {
        if (isSelectionMode) {
          context.read<ExHentaiBrowseProvider>().toggleItemSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        context.read<ExHentaiBrowseProvider>().toggleItemSelection(item);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF9C27B0)
                : (isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
            width: isSelected ? 2.0 : 0.6,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF9C27B0).withValues(alpha: 0.3)
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
            // Cover Image with Badges
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.coverUrl != null && item.coverUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: item.coverUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      httpHeaders: const {
                        'Referer': 'https://ex.810114.xyz/',
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                      },
                      placeholder: (context, url) => Container(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                        child: const Center(
                          child: CupertinoActivityIndicator(radius: 10),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                        child: Icon(
                          CupertinoIcons.photo,
                          size: 36,
                          color: catColor.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.book_fill,
                          size: 40,
                          color: catColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),

                  // Bottom Gradient overlay
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 36,
                    child: DecoratedBox(
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
                  ),

                  // Top-Left Category Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: catColor,
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

                  // Top-Right: Selection Checkbox or File Count Badge
                  if (isSelectionMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF9C27B0) : Colors.black38,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: isSelected
                            ? const Icon(CupertinoIcons.checkmark, size: 13, color: Colors.white)
                            : null,
                      ),
                    )
                  else if (filecount != null && filecount.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${filecount}P',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Bottom-Left Rating
                  if (rating.isNotEmpty)
                    Positioned(
                      left: 8,
                      bottom: 6,
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.star_fill, size: 11, color: Color(0xFFFFD54F)),
                          const SizedBox(width: 3),
                          Text(
                            rating,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
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
                      if (item.date.isNotEmpty)
                        Text(
                          item.date.split(' ').first,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const Spacer(),
                      // Quick download button
                      GestureDetector(
                        onTap: () {
                          context.read<DownloadProvider>().addBatchAlbumTasks([item]);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已添加至下载队列: ${item.title}'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9C27B0).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            CupertinoIcons.arrow_down_to_line,
                            size: 13,
                            color: Color(0xFF9C27B0),
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
