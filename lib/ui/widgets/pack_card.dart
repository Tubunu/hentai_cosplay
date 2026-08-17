import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/pack_item.dart';
import '../theme/ios_theme.dart';
import 'frosted_glass.dart';

class PackCard extends StatelessWidget {
  final PackItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDownload;
  final bool isSelected;
  final bool isSelectionMode;

  const PackCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.onDownload,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: BouncingButton(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album Art Cover Container
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: item.coverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: item.coverUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 360,
                              memCacheHeight: 520,
                              maxWidthDiskCache: 600,
                              placeholder: (context, url) => Container(
                                color: isDark ? const Color(0xFF24242A) : const Color(0xFFE5E5EA),
                                child: const Center(
                                  child: CupertinoActivityIndicator(radius: 10),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: isDark ? const Color(0xFF24242A) : const Color(0xFFE5E5EA),
                                child: const Center(
                                  child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 32),
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade300,
                              child: const Icon(CupertinoIcons.photo),
                            ),
                    ),
                  ),

                  // Image count badge (top right) - Optimized lightweight crystal badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        color: Colors.black.withValues(alpha: 0.58),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.photo_on_rectangle, color: Colors.white, size: 11),
                          const SizedBox(width: 4),
                          Text(
                            '${item.urls.length}P',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Quick download button (bottom right)
                  if (!isSelectionMode)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: BouncingButton(
                        onTap: onDownload,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: isDark ? const Color(0xDD2C2C34) : const Color(0xEEFFFFFF),
                            border: Border.all(
                              color: IosTheme.primaryPink.withValues(alpha: 0.35),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.arrow_down_to_line,
                            color: IosTheme.primaryPink,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                  // Selection Checkbox (if in selection mode)
                  if (isSelectionMode)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected ? IosTheme.primaryPink : Colors.black45,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          isSelected ? CupertinoIcons.checkmark_alt : null,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Title & Author Text
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: IosTheme.secondaryText(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
