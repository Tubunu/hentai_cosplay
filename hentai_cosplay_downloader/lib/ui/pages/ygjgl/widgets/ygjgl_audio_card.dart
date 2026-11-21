import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/download_task.dart';
import '../../../../models/ygjgl/ygjgl_post_item.dart';
import '../../../../providers/download_provider.dart';
import '../../../widgets/bouncing_button.dart';
import '../details/ygjgl_audio_detail_page.dart';

class YgjglAudioCard extends StatelessWidget {
  final YgjglPostItem item;
  final VoidCallback? onTap;

  const YgjglAudioCard({
    super.key,
    required this.item,
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
    const accentPink = Color(0xFFFF5A8A);

    return BouncingButton(
      onTap: onTap ??
          () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => YgjglAudioDetailPage(item: item),
              ),
            );
          },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E22) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // 1. Cover with vinyl / audio icon overlay
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
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
                        child: const Icon(CupertinoIcons.headphones, size: 28, color: Colors.white30),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.play_fill, size: 10, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 2. Info area
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (item.text.isNotEmpty)
                    Text(
                      item.text.replaceAll('\n', ' ').trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (item.tags.isNotEmpty)
                        Flexible(
                          child: Text(
                            item.tags.take(3).map((t) => '#$t').join(' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF5856D6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (item.views > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '👁 ${_formatNumber(item.views)}',
                          style: TextStyle(
                            fontSize: 10,
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

            // 3. Quick Audio Download button
            Consumer<DownloadProvider>(
              builder: (context, downloadProv, _) {
                final vItem = item.toVideoItem();
                final status = downloadProv.getTaskStatus(
                  slug: vItem.slug,
                  detailUrl: vItem.detailUrl,
                  title: vItem.title,
                );

                final isDownloaded = status == TaskStatus.completed;
                final isDownloading = status == TaskStatus.downloading || status == TaskStatus.queued;

                return GestureDetector(
                  onTap: () {
                    if (isDownloaded) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('该音频已在下载任务中完成'), duration: Duration(seconds: 1)),
                      );
                    } else if (!isDownloading) {
                      downloadProv.addVideoTask(vItem);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已加入下载任务: ${item.title}'), duration: const Duration(seconds: 1)),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFF2F3F5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDownloaded
                          ? CupertinoIcons.check_mark_circled_solid
                          : (isDownloading
                              ? CupertinoIcons.arrow_down_circle_fill
                              : CupertinoIcons.arrow_down_to_line),
                      size: 18,
                      color: isDownloaded
                          ? const Color(0xFF34C759)
                          : (isDownloading ? accentPink : (isDark ? Colors.white70 : Colors.black87)),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
