import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../services/coomer/coomer_api_service.dart';
import '../../../theme/ios_theme.dart';
import '../../../widgets/bouncing_button.dart';
import '../../../widgets/frosted_glass.dart';

class CoomerCreatorCard extends StatelessWidget {
  final CoomerCreator creator;
  final VoidCallback onTap;

  const CoomerCreatorCard({
    super.key,
    required this.creator,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final serviceColor = _getServiceColor(creator.service);

    return BouncingButton(
      onTap: onTap,
      child: FrostedGlass(
        borderRadius: 18,
        blur: 15,
        padding: const EdgeInsets.all(12),
        backgroundColor: isDark ? const Color(0x991E1E24) : Colors.white,
        child: Row(
          children: [
            // Creator Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 52,
                height: 52,
                child: CachedNetworkImage(
                  imageUrl: creator.avatarUrl,
                  fit: BoxFit.cover,
                  httpHeaders: const {'Referer': 'https://coomer.st/'},
                  placeholder: (_, __) => Container(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                    child: const Center(child: CupertinoActivityIndicator(radius: 8)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                    child: Icon(CupertinoIcons.person_fill, color: serviceColor, size: 28),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: serviceColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          creator.service.toUpperCase(),
                          style: TextStyle(
                            color: serviceColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          creator.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.heart_fill, size: 12, color: IosTheme.primaryPink),
                      const SizedBox(width: 4),
                      Text(
                        '${creator.favorited} 关注',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (creator.updated.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(
                          '更新于 ${creator.updated.length >= 10 ? creator.updated.substring(0, 10) : creator.updated}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Chevron
            const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
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
