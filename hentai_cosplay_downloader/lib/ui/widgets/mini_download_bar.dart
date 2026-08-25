import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/download_task.dart';
import '../../models/jable_task.dart';
import '../../providers/download_provider.dart';
import '../../providers/jable_download_provider.dart';
import '../../providers/settings_provider.dart';
import '../theme/ios_theme.dart';
import 'bouncing_button.dart';
import 'liquid_glass.dart';

class MiniDownloadBar extends StatelessWidget {
  final VoidCallback? onTap;

  const MiniDownloadBar({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final downloadProv = context.watch<DownloadProvider>();
    final jableProv = context.watch<JableDownloadProvider>();
    final settingsProv = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasCosplayActive = downloadProv.isDownloading || downloadProv.activeTasks.isNotEmpty;
    final hasJableActive = jableProv.isDownloading || jableProv.activeTasks.isNotEmpty;

    if (!hasCosplayActive && !hasJableActive) {
      return const SizedBox.shrink();
    }

    if (hasCosplayActive) {
      final activeTask = downloadProv.activeTasks.isNotEmpty
          ? downloadProv.activeTasks.first
          : (downloadProv.queuedTasks.isNotEmpty ? downloadProv.queuedTasks.first : null);

      if (activeTask == null) return const SizedBox.shrink();

      final item = activeTask.albumItem;
      final progress = activeTask.progress;
      final speedText = downloadProv.formattedSpeed;

      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: BouncingButton(
          onTap: onTap,
          child: LiquidGlass(
            borderRadius: 20,
            blur: 20,
            opacity: settingsProv.config.navBarOpacity,
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
                        width: 40,
                        height: 40,
                        color: isDark ? Colors.white10 : Colors.black12,
                        child: item.coverUrl != null && item.coverUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.coverUrl!,
                                fit: BoxFit.cover,
                                memCacheWidth: 120,
                                httpHeaders: const {
                                  'Referer': 'https://hentai-cosplay-xxx.com/',
                                },
                                placeholder: (_, __) => const Center(
                                  child: CupertinoActivityIndicator(radius: 8),
                                ),
                                errorWidget: (_, __, ___) => const Icon(
                                  CupertinoIcons.photo,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                              )
                            : const Icon(CupertinoIcons.photo, size: 20, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
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
                                '${activeTask.downloadedImages + activeTask.skippedImages}/${activeTask.totalImages > 0 ? activeTask.totalImages : "?"} 张',
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
                      onTap: () {
                        if (activeTask.status == TaskStatus.downloading) {
                          downloadProv.pauseTask(activeTask);
                        } else {
                          downloadProv.resumeTask(activeTask);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: IosTheme.primaryPink.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          activeTask.status == TaskStatus.downloading
                              ? CupertinoIcons.pause_fill
                              : CupertinoIcons.play_fill,
                          size: 16,
                          color: IosTheme.primaryPink,
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
    } else {
      final activeJable = jableProv.activeTasks.isNotEmpty
          ? jableProv.activeTasks.first
          : (jableProv.queuedTasks.isNotEmpty ? jableProv.queuedTasks.first : null);

      if (activeJable == null) return const SizedBox.shrink();

      final speedText = jableProv.formattedSpeed;
      final progress = (activeJable.progress / 100.0).clamp(0.0, 1.0);

      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: BouncingButton(
          onTap: onTap,
          child: LiquidGlass(
            borderRadius: 20,
            blur: 20,
            opacity: settingsProv.config.navBarOpacity,
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
                        width: 48,
                        height: 32,
                        color: isDark ? Colors.white10 : Colors.black12,
                        child: activeJable.thumbnailUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: activeJable.thumbnailUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 120,
                                placeholder: (_, __) => const Center(
                                  child: CupertinoActivityIndicator(radius: 6),
                                ),
                                errorWidget: (_, __, ___) => const Icon(
                                  CupertinoIcons.video_camera,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              )
                            : const Icon(CupertinoIcons.video_camera, size: 18, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeJable.name,
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
                                activeJable.status == JableDownloadStatus.merging
                                    ? '解密合并中...'
                                    : '${activeJable.completedSegments}/${activeJable.totalSegments > 0 ? activeJable.totalSegments : "?"} 分片',
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
                      onTap: () {
                        if (activeJable.status == JableDownloadStatus.downloading) {
                          jableProv.pauseTask(activeJable);
                        } else {
                          jableProv.resumeTask(activeJable);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: IosTheme.primaryPink.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          activeJable.status == JableDownloadStatus.downloading
                              ? CupertinoIcons.pause_fill
                              : CupertinoIcons.play_fill,
                          size: 16,
                          color: IosTheme.primaryPink,
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
}
