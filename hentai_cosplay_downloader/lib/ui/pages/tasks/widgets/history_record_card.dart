import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hentai_cosplay_downloader/models/history_record.dart';
import 'package:hentai_cosplay_downloader/models/jable_task.dart';
import 'package:hentai_cosplay_downloader/providers/history_provider.dart';
import 'package:hentai_cosplay_downloader/providers/jable_download_provider.dart';
import 'package:hentai_cosplay_downloader/ui/theme/ios_theme.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/bouncing_button.dart';
import 'package:intl/intl.dart';
import 'task_widgets_common.dart';

class AlbumHistoryRecordCard extends StatelessWidget {
  final HistoryRecord record;
  final HistoryProvider historyProv;

  const AlbumHistoryRecordCard({
    super.key,
    required this.record,
    required this.historyProv,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(record.completedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IosTheme.surfaceLayer1(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: IosTheme.borderSubtle(isDark),
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: record.isVideo ? 72 : 54,
              height: record.isVideo ? 45 : 54,
              color: isDark ? Colors.white10 : Colors.black12,
              child: record.coverUrl != null && record.coverUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: record.coverUrl!,
                      fit: BoxFit.cover,
                      httpHeaders: {
                        'Referer': record.isVideo ? 'https://porn-video-xxx.com/' : 'https://hentai-cosplay-xxx.com/',
                      },
                      placeholder: (_, __) => const Center(child: CupertinoActivityIndicator(radius: 8)),
                      errorWidget: (_, __, ___) => Icon(
                        record.isVideo ? CupertinoIcons.film : CupertinoIcons.photo,
                        color: Colors.grey,
                        size: 22,
                      ),
                    )
                  : Icon(
                      record.isVideo ? CupertinoIcons.film : CupertinoIcons.photo,
                      color: Colors.grey,
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (record.isVideo)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: IosTheme.primaryPink.withAlpha(40),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          '视频',
                          style: TextStyle(
                            color: IosTheme.primaryPink,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (record.author.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: IosTheme.primaryPink.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          record.author,
                          style: const TextStyle(
                            color: IosTheme.primaryPink,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (record.isVideo)
                      Text(
                        record.duration != null && record.duration!.isNotEmpty
                            ? record.duration!
                            : formatBytes(record.downloadedBytes),
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                      )
                    else
                      Text(
                        '${record.imageCount} 张图片',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          BouncingButton(
            onTap: () => historyProv.removeRecord(record.id),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black12,
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.xmark, size: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class JableHistoryRecordCard extends StatelessWidget {
  final JableHistoryRecord record;
  final JableDownloadProvider jableProv;

  const JableHistoryRecordCard({
    super.key,
    required this.record,
    required this.jableProv,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IosTheme.surfaceLayer1(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: IosTheme.borderSubtle(isDark),
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 76,
              height: 48,
              color: isDark ? Colors.white10 : Colors.black12,
              child: record.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: record.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(child: CupertinoActivityIndicator(radius: 8)),
                      errorWidget: (_, __, ___) => const Icon(CupertinoIcons.video_camera, color: Colors.grey, size: 22),
                    )
                  : const Icon(CupertinoIcons.video_camera, color: Colors.grey, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: IosTheme.primaryPink.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        record.siteName,
                        style: const TextStyle(
                          color: IosTheme.primaryPink,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      record.size.isNotEmpty ? record.size : '已保存',
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  record.date,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          BouncingButton(
            onTap: () => jableProv.removeHistoryRecord(record.id),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black12,
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.xmark, size: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
