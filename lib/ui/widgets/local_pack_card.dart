import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../theme/ios_theme.dart';
import 'frosted_glass.dart';

class LocalPackCard extends StatelessWidget {
  final LocalPackInfo pack;
  final VoidCallback onTap;

  const LocalPackCard({
    super.key,
    required this.pack,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: BouncingButton(
        onTap: onTap,
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
                      child: pack.coverPath != null
                          ? Image.file(
                              File(pack.coverPath!),
                              fit: BoxFit.cover,
                              cacheWidth: 360,
                              cacheHeight: 520,
                              errorBuilder: (context, error, stackTrace) => Container(
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

                  // Image count badge (top right)
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
                          const Icon(CupertinoIcons.photo_fill, color: Colors.white, size: 11),
                          const SizedBox(width: 4),
                          Text(
                            '${pack.imageCount}P',
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

                  // Archive badge (bottom left)
                  if (pack.isArchived)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: IosTheme.secondaryPurple.withValues(alpha: 0.88),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: IosTheme.secondaryPurple.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.archivebox_fill, color: Colors.white, size: 10),
                            SizedBox(width: 3),
                            Text(
                              '归档',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Title & Author
            Text(
              pack.title,
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
              pack.author,
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
