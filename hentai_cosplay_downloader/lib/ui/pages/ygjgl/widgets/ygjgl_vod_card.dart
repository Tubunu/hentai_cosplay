import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/download_task.dart';
import '../../../../models/ygjgl/ygjgl_vod_item.dart';
import '../../../../providers/download_provider.dart';
import '../../../widgets/bouncing_button.dart';
import '../details/ygjgl_vod_detail_page.dart';

class YgjglVodCard extends StatelessWidget {
  final YgjglVodItem item;
  final VoidCallback? onTap;

  const YgjglVodCard({
    super.key,
    required this.item,
    this.onTap,
  });

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
                builder: (_) => YgjglVodDetailPage(item: item),
              ),
            );
          },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E22) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Cover Image & Badges
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: item.coverUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 480,
                    httpHeaders: const {
                      'Referer': 'https://ygjgl.one/',
                      'User-Agent':
                          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
                    },
                    placeholder: (_, __) => Container(
                      color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFF0F0F2),
                      child: const Center(
                        child: CupertinoActivityIndicator(),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFF0F0F2),
                      child: Icon(
                        CupertinoIcons.play_rectangle,
                        size: 32,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                    ),
                  ),

                  // Duration badge (bottom right)
                  if (item.duration.isNotEmpty)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.duration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  // Free / VIP Badge (top left)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: item.isFree
                              ? [const Color(0xFF34C759), const Color(0xFF30D158)]
                              : [const Color(0xFFFF5A8A), const Color(0xFFFF8FB3)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: (item.isFree ? const Color(0xFF34C759) : accentPink).withOpacity(0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        item.isFree ? '免费' : (item.coin > 0 ? 'VIP' : '点播'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  // Size badge (top right)
                  if (item.size.isNotEmpty)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          item.size,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 2. Info area
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
                      height: 1.3,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (item.actor.isNotEmpty) ...[
                        Flexible(
                          child: Text(
                            item.actor,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: accentPink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (item.published.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text('·', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
                          ),
                      ],
                      if (item.published.isNotEmpty)
                        Text(
                          item.published.length >= 10 ? item.published.substring(0, 10) : item.published,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                        ),
                      const Spacer(),
                      // Quick Download Button
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
                                  const SnackBar(content: Text('该视频已在下载列表中完成'), duration: Duration(seconds: 1)),
                                );
                              } else if (!isDownloading) {
                                downloadProv.addVideoTask(vItem);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('已加入下载任务: ${item.title}'), duration: const Duration(seconds: 1)),
                                );
                              }
                            },
                            child: Icon(
                              isDownloaded
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : (isDownloading
                                      ? CupertinoIcons.arrow_down_circle_fill
                                      : CupertinoIcons.arrow_down_circle),
                              size: 18,
                              color: isDownloaded
                                  ? const Color(0xFF34C759)
                                  : (isDownloading ? accentPink : (isDark ? Colors.white38 : Colors.black38)),
                            ),
                          );
                        },
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
