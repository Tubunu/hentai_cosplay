import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hentai_cosplay_downloader/models/download_task.dart';
import 'package:hentai_cosplay_downloader/models/jable_task.dart';
import 'package:hentai_cosplay_downloader/providers/download_provider.dart';
import 'package:hentai_cosplay_downloader/providers/jable_download_provider.dart';
import 'package:hentai_cosplay_downloader/ui/theme/ios_theme.dart';
import 'task_widgets_common.dart';

class AlbumTaskCard extends StatelessWidget {
  final AlbumDownloadTask task;
  final DownloadProvider downloadProv;

  const AlbumTaskCard({
    super.key,
    required this.task,
    required this.downloadProv,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = task.albumItem;
    final progress = task.progress;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: task.isVideo ? 72 : 56,
                  height: task.isVideo ? 45 : 72,
                  child: item.coverUrl != null && item.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.coverUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey.withAlpha(50)),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey.withAlpha(50),
                            child: Icon(task.isVideo ? CupertinoIcons.film : CupertinoIcons.photo, color: Colors.grey, size: 20),
                          ),
                        )
                      : Container(
                          color: Colors.grey.withAlpha(50),
                          child: Icon(task.isVideo ? CupertinoIcons.film : CupertinoIcons.photo, color: Colors.grey, size: 20),
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
                        if (task.isVideo)
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
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.author,
                      style: const TextStyle(
                        fontSize: 11,
                        color: IosTheme.primaryPink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        TaskStatusBadge(status: task.status),
                        const Spacer(),
                        Builder(
                          builder: (context) {
                            String etaText = '';
                            if (task.status == TaskStatus.downloading && downloadProv.currentSpeedBps > 0) {
                              double remainingBytes = 0;
                              if (task.isVideo && task.totalBytes > 0) {
                                remainingBytes = (task.totalBytes - task.downloadedBytes).toDouble();
                              } else if (!task.isVideo && task.totalImages > 0 && task.downloadedImages > 0 && task.downloadedBytes > 0) {
                                double avgBytes = task.downloadedBytes / task.downloadedImages;
                                remainingBytes = (task.totalImages - task.downloadedImages) * avgBytes;
                              }
                              
                              if (remainingBytes > 0) {
                                int seconds = (remainingBytes / downloadProv.currentSpeedBps).ceil();
                                if (seconds < 60) {
                                  etaText = ' · $seconds秒';
                                } else if (seconds < 3600) {
                                  etaText = ' · ${(seconds / 60).floor()}分钟';
                                } else {
                                  etaText = ' · ${(seconds / 3600).floor()}小时${((seconds % 3600) / 60).floor()}分';
                                }
                              }
                            }

                            if (task.isVideo) {
                              return Text(
                                task.status == TaskStatus.completed
                                    ? '下载完成 (${formatBytes(task.downloadedBytes)})'
                                    : (task.downloadedBytes > 0
                                        ? '${(progress * 100).toStringAsFixed(1)}% · ${formatBytes(task.downloadedBytes)}${task.totalBytes > 0 ? ' / ${formatBytes(task.totalBytes)}' : ''}$etaText'
                                        : (task.duration != null && task.duration!.isNotEmpty ? task.duration! : '高清视频')),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            } else {
                              return Text(
                                '${task.downloadedImages + task.skippedImages} / ${task.totalImages > 0 ? task.totalImages : '?'} 张$etaText',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (task.status == TaskStatus.downloading ||
              task.status == TaskStatus.paused ||
              task.status == TaskStatus.queued) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  task.status == TaskStatus.paused ? Colors.orange : IosTheme.primaryPink,
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (task.status == TaskStatus.downloading)
                TaskActionButton(
                  icon: CupertinoIcons.pause_fill,
                  label: '暂停',
                  color: Colors.orange,
                  onTap: () => downloadProv.pauseTask(task),
                ),
              if (task.status == TaskStatus.paused || task.status == TaskStatus.failed)
                TaskActionButton(
                  icon: CupertinoIcons.play_fill,
                  label: '继续',
                  color: IosTheme.primaryPink,
                  onTap: () => downloadProv.resumeTask(task),
                ),
              const SizedBox(width: 8),
              TaskActionButton(
                icon: CupertinoIcons.trash,
                label: '移除',
                color: Colors.redAccent,
                onTap: () => downloadProv.removeTask(task),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class JableTaskCard extends StatelessWidget {
  final JableDownloadTask task;
  final JableDownloadProvider jableProv;

  const JableTaskCard({
    super.key,
    required this.task,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 80,
                  height: 52,
                  child: task.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: task.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey.withAlpha(50)),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey.withAlpha(50),
                            child: const Icon(CupertinoIcons.video_camera, color: Colors.grey, size: 24),
                          ),
                        )
                      : Container(
                          color: Colors.grey.withAlpha(50),
                          child: const Icon(CupertinoIcons.video_camera, color: Colors.grey, size: 24),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: IosTheme.primaryPink.withAlpha(40),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task.siteName,
                            style: const TextStyle(
                              color: IosTheme.primaryPink,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (task.status == JableDownloadStatus.downloading)
                          Builder(
                            builder: (context) {
                              String etaText = '';
                              if (jableProv.currentSpeedBps > 0) {
                                double remainingSegments = (task.totalSegments - task.completedSegments).toDouble();
                                if (remainingSegments > 0) {
                                  double remainingBytes = remainingSegments * 2500000; // rough estimate 2.5MB/segment
                                  int seconds = (remainingBytes / jableProv.currentSpeedBps).ceil();
                                  if (seconds < 60) {
                                    etaText = ' · $seconds秒';
                                  } else if (seconds < 3600) {
                                    etaText = ' · ${(seconds / 60).floor()}分钟';
                                  } else {
                                    etaText = ' · ${(seconds / 3600).floor()}小时${((seconds % 3600) / 60).floor()}分';
                                  }
                                }
                              }
                              return Text(
                                "${task.completedSegments}/${task.totalSegments > 0 ? task.totalSegments : '?'} 分片 · ${task.speed}$etaText",
                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                              );
                            },
                          )
                        else if (task.status == JableDownloadStatus.merging)
                          const Text(
                            "正在解密合并...",
                            style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                          )
                        else
                          JableStatusBadge(status: task.status),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (task.status == JableDownloadStatus.downloading ||
              task.status == JableDownloadStatus.waiting ||
              task.status == JableDownloadStatus.paused) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (task.progress / 100).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  task.status == JableDownloadStatus.paused ? Colors.orange : IosTheme.primaryPink,
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (task.status == JableDownloadStatus.downloading)
                TaskActionButton(
                  icon: CupertinoIcons.pause_fill,
                  label: '暂停',
                  color: Colors.orange,
                  onTap: () => jableProv.pauseTask(task),
                ),
              if (task.status == JableDownloadStatus.paused || task.status == JableDownloadStatus.failed)
                TaskActionButton(
                  icon: CupertinoIcons.play_fill,
                  label: '继续',
                  color: IosTheme.primaryPink,
                  onTap: () => jableProv.resumeTask(task),
                ),
              const SizedBox(width: 8),
              TaskActionButton(
                icon: CupertinoIcons.trash,
                label: '移除',
                color: Colors.redAccent,
                onTap: () => jableProv.removeTask(task),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
