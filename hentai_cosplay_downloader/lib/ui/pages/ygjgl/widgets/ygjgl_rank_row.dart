import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../models/ygjgl/ygjgl_post_item.dart';
import '../../../widgets/bouncing_button.dart';
import '../details/ygjgl_audio_detail_page.dart';
import '../details/ygjgl_post_detail_page.dart';

class YgjglRankRow extends StatelessWidget {
  final YgjglPostItem item;
  final int index;
  final VoidCallback? onTap;

  const YgjglRankRow({
    super.key,
    required this.item,
    required this.index,
    this.onTap,
  });

  String _formatNumber(int n) {
    if (n >= 100000000) return '${(n / 100000000).toStringAsFixed(1)}亿';
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rank = item.rank ?? (index + 1);

    // Rank badge colors
    Gradient? badgeGradient;
    Color badgeColor = isDark ? const Color(0xFF2C2C30) : const Color(0xFFF2F3F5);
    Color textColor = isDark ? Colors.white70 : const Color(0xFF8E8E93);

    if (rank == 1) {
      badgeGradient = const LinearGradient(colors: [Color(0xFFFFD166), Color(0xFFF7B32B)]);
      textColor = const Color(0xFF7A4B00);
    } else if (rank == 2) {
      badgeGradient = const LinearGradient(colors: [Color(0xFFE3E7EE), Color(0xFFC3C9D4)]);
      textColor = const Color(0xFF5B6270);
    } else if (rank == 3) {
      badgeGradient = const LinearGradient(colors: [Color(0xFFF2C9A8), Color(0xFFDBA57F)]);
      textColor = const Color(0xFF7A4B2A);
    }

    return BouncingButton(
      onTap: onTap ??
          () {
            if (item.isAudio) {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => YgjglAudioDetailPage(item: item),
                ),
              );
            } else {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => YgjglPostDetailPage(item: item),
                ),
              );
            }
          },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFFBE9EF),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 1. Rank Number
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeGradient == null ? badgeColor : null,
                gradient: badgeGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 2. Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 54,
                height: 72,
                child: CachedNetworkImage(
                  imageUrl: item.cover,
                  fit: BoxFit.cover,
                  httpHeaders: const {
                    'Referer': 'https://ygjgl.one/',
                    'User-Agent':
                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
                  },
                  placeholder: (_, __) => Container(
                    color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFF0F0F2),
                    child: const Center(child: CupertinoActivityIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFF0F0F2),
                    child: const Icon(CupertinoIcons.photo, size: 20, color: Colors.white24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 3. Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (item.seriesTitle.isNotEmpty)
                        Flexible(
                          child: Text(
                            item.seriesTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFFF5A8A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (item.tags.isNotEmpty)
                        Flexible(
                          child: Text(
                            '#${item.tags.first}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ),
                      if (item.views > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '👁 ${_formatNumber(item.views)}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                        ),
                      ],
                      if (item.imageCount > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${item.imageCount}张',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Chevron
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
