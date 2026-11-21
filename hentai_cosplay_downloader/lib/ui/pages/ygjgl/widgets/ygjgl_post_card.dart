import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/download_task.dart';
import '../../../../models/ygjgl/ygjgl_post_item.dart';
import '../../../../providers/download_provider.dart';
import '../../../widgets/bouncing_button.dart';
import '../details/ygjgl_audio_detail_page.dart';
import '../details/ygjgl_post_detail_page.dart';

class YgjglPostCard extends StatelessWidget {
  final YgjglPostItem item;
  final VoidCallback? onTap;

  const YgjglPostCard({
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
            // 1. Cover Image
            AspectRatio(
              aspectRatio: item.isAudio ? 1.0 : 0.78,
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
                      child: const Center(
                        child: CupertinoActivityIndicator(),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFF0F0F2),
                      child: Icon(
                        item.isAudio ? CupertinoIcons.music_note : CupertinoIcons.photo,
                        size: 32,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                    ),
                  ),

                  // Top gradient shadow
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Image count or audio badge (top left)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.isAudio
                            ? const Color(0xFF5856D6).withOpacity(0.9)
                            : Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.isAudio ? CupertinoIcons.headphones : CupertinoIcons.photo,
                            color: Colors.white,
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.isAudio ? '电台' : '${item.imageCount} 张',
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

                  // Views badge (top right)
                  if (item.views > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '👁 ${_formatNumber(item.views)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                  // Date chip (bottom right)
                  if (item.published.isNotEmpty)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          item.published.length >= 10 ? item.published.substring(0, 10) : item.published,
                          style: const TextStyle(
                            color: Colors.white70,
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
                  const SizedBox(height: 4),
                  if (item.seriesTitle.isNotEmpty)
                    Text(
                      '📚 ${item.seriesTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: accentPink,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else if (item.text.isNotEmpty)
                    Text(
                      item.text.replaceAll('\n', ' ').trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Tags
                      if (item.tags.isNotEmpty)
                        Flexible(
                          child: Text(
                            item.tags.take(2).map((t) => '#$t').join(' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                          ),
                        ),
                      const Spacer(),
                      // Download button
                      Consumer<DownloadProvider>(
                        builder: (context, downloadProv, _) {
                          final albumItem = item.toAlbumItem();
                          final task = downloadProv.getTaskForAlbum(albumItem);
                          final isDownloaded = task?.status == TaskStatus.completed;
                          final isDownloading = task?.status == TaskStatus.downloading || task?.status == TaskStatus.queued;

                          return GestureDetector(
                            onTap: () {
                              if (isDownloaded) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('该图集已在下载列表中完成'), duration: Duration(seconds: 1)),
                                );
                              } else if (!isDownloading) {
                                downloadProv.addAlbumTask(albumItem);
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
