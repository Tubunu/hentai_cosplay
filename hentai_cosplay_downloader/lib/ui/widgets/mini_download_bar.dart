import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/album_item.dart';
import '../../models/download_task.dart';
import '../../models/jable_task.dart';
import '../../providers/download_provider.dart';
import '../../providers/jable_download_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/referer_helper.dart';
import '../theme/ios_theme.dart';
import 'bouncing_button.dart';
import 'liquid_glass.dart';

class MiniDownloadBar extends StatelessWidget {
  final VoidCallback? onTap;

  const MiniDownloadBar({super.key, this.onTap});

  static Map<String, String>? _resolveHeaders(AlbumItem item) {
    final cover = item.coverUrl ?? '';
    if (cover.isEmpty) return null;
    return {'Referer': RefererHelper.getReferer(cover, sourceType: item.sourceType)};
  }

  @override
  Widget build(BuildContext context) {
    final downloadProv = context.watch<DownloadProvider>();
    final jableProv = context.watch<JableDownloadProvider>();
    final navBarOpacity = context.select<SettingsProvider, double>((s) => s.config.navBarOpacity);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalActiveCount = downloadProv.activeTasks.length + jableProv.activeTasks.length;
    final totalQueuedCount = downloadProv.queuedTasks.length + jableProv.queuedTasks.length;
    final totalTaskCount = totalActiveCount + totalQueuedCount;

    final hasCosplayActive = downloadProv.activeTasks.isNotEmpty || downloadProv.queuedTasks.isNotEmpty;
    final hasJableActive = jableProv.activeTasks.isNotEmpty || jableProv.queuedTasks.isNotEmpty;

    if (!hasCosplayActive && !hasJableActive) {
      return const SizedBox.shrink();
    }

    // 若有进行中的 Jable 任务且 Cosplay 未在真正下载，优先展示 Jable
    final preferJable = hasJableActive && (!hasCosplayActive || (!downloadProv.isDownloading && jableProv.isDownloading));

    if (!preferJable && hasCosplayActive) {
      final activeTask = downloadProv.activeTasks.isNotEmpty
          ? downloadProv.activeTasks.first
          : (downloadProv.queuedTasks.isNotEmpty ? downloadProv.queuedTasks.first : null);

      if (activeTask == null) return const SizedBox.shrink();

      final item = activeTask.albumItem;
      final isVideo = activeTask.isVideo || item.isVideo;
      final String progressText;
      if (isVideo) {
        if (activeTask.totalBytes > 0) {
          final dl = (activeTask.downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
          final tot = (activeTask.totalBytes / (1024 * 1024)).toStringAsFixed(1);
          progressText = '$dl / $tot MB';
        } else {
          progressText = '${(activeTask.progress * 100).toStringAsFixed(0)}% • ${(activeTask.downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        }
      } else {
        progressText = '${activeTask.downloadedImages + activeTask.skippedImages}/${activeTask.totalImages > 0 ? activeTask.totalImages : "?"} 张';
      }

      final speedText = totalTaskCount > 1
          ? '${downloadProv.formattedSpeed} • $totalTaskCount个任务'
          : downloadProv.formattedSpeed;

      return _MiniBarLayout(
        title: item.title,
        coverUrl: item.coverUrl,
        headers: _resolveHeaders(item),
        coverWidth: isVideo ? 48 : 40,
        coverHeight: isVideo ? 32 : 40,
        fallbackIcon: isVideo ? CupertinoIcons.film : CupertinoIcons.photo,
        speedText: speedText,
        progressText: progressText,
        progress: activeTask.progress,
        isDownloading: activeTask.status == TaskStatus.downloading,
        onTogglePlayPause: () {
          if (activeTask.status == TaskStatus.downloading) {
            downloadProv.pauseTask(activeTask);
          } else {
            downloadProv.resumeTask(activeTask);
          }
        },
        onCancel: () {
          downloadProv.removeTask(activeTask);
        },
        onTap: onTap,
        navBarOpacity: navBarOpacity,
        isDark: isDark,
      );
    } else {
      final activeJable = jableProv.activeTasks.isNotEmpty
          ? jableProv.activeTasks.first
          : (jableProv.queuedTasks.isNotEmpty ? jableProv.queuedTasks.first : null);

      if (activeJable == null) return const SizedBox.shrink();

      final speedText = totalTaskCount > 1
          ? '${jableProv.formattedSpeed} • $totalTaskCount个任务'
          : jableProv.formattedSpeed;

      return _MiniBarLayout(
        title: activeJable.name,
        coverUrl: activeJable.thumbnailUrl,
        coverWidth: 48,
        coverHeight: 32,
        fallbackIcon: CupertinoIcons.video_camera,
        speedText: speedText,
        progressText: activeJable.status == JableDownloadStatus.merging
            ? '解密合并中...'
            : '${activeJable.completedSegments}/${activeJable.totalSegments > 0 ? activeJable.totalSegments : "?"} 分片',
        progress: (activeJable.progress / 100.0).clamp(0.0, 1.0),
        isDownloading: activeJable.status == JableDownloadStatus.downloading,
        onTogglePlayPause: () {
          if (activeJable.status == JableDownloadStatus.downloading) {
            jableProv.pauseTask(activeJable);
          } else {
            jableProv.resumeTask(activeJable);
          }
        },
        onCancel: () {
          jableProv.removeTask(activeJable);
        },
        onTap: onTap,
        navBarOpacity: navBarOpacity,
        isDark: isDark,
      );
    }
  }
}

class _MiniBarLayout extends StatelessWidget {
  final String title;
  final String? coverUrl;
  final Map<String, String>? headers;
  final double coverWidth;
  final double coverHeight;
  final IconData fallbackIcon;
  final String speedText;
  final String progressText;
  final double progress;
  final bool isDownloading;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onCancel;
  final VoidCallback? onTap;
  final double navBarOpacity;
  final bool isDark;

  const _MiniBarLayout({
    required this.title,
    required this.coverUrl,
    this.headers,
    required this.coverWidth,
    required this.coverHeight,
    required this.fallbackIcon,
    required this.speedText,
    required this.progressText,
    required this.progress,
    required this.isDownloading,
    required this.onTogglePlayPause,
    required this.onCancel,
    required this.onTap,
    required this.navBarOpacity,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: BouncingButton(
        onTap: onTap,
        child: LiquidGlass(
          borderRadius: 20,
          blur: 20,
          opacity: navBarOpacity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          fluidAuraColor: IosTheme.primaryPink,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: coverWidth,
                      height: coverHeight,
                      color: isDark ? Colors.white10 : Colors.black12,
                      child: coverUrl != null && coverUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: coverUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 120,
                              httpHeaders: headers,
                              placeholder: (_, __) => Center(
                                child: CupertinoActivityIndicator(radius: coverHeight < 40 ? 6 : 8),
                              ),
                              errorWidget: (_, __, ___) => Icon(
                                fallbackIcon,
                                size: coverHeight < 40 ? 18 : 20,
                                color: Colors.grey,
                              ),
                            )
                          : Icon(fallbackIcon, size: coverHeight < 40 ? 18 : 20, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: IosTheme.primaryPink.withAlpha(40),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                speedText,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: IosTheme.primaryPink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              progressText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  BouncingButton(
                    onTap: onTogglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: IosTheme.primaryPink.withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDownloading ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                        size: 16,
                        color: IosTheme.primaryPink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BouncingButton(
                    onTap: onCancel,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        size: 16,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  minHeight: 3,
                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  valueColor: const AlwaysStoppedAnimation<Color>(IosTheme.primaryPink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
