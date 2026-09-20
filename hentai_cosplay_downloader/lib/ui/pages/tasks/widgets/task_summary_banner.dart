import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hentai_cosplay_downloader/models/history_record.dart';
import 'package:hentai_cosplay_downloader/models/jable_task.dart';
import 'package:hentai_cosplay_downloader/ui/theme/ios_theme.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/liquid_glass.dart';
import 'task_widgets_common.dart';

class TaskSpeedBanner extends StatelessWidget {
  final int resourceSegment;
  final String currentSpeed;
  final double currentProgress;
  final bool isDownloadingNow;

  const TaskSpeedBanner({
    super.key,
    required this.resourceSegment,
    required this.currentSpeed,
    required this.currentProgress,
    required this.isDownloadingNow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: LiquidGlass(
        borderRadius: 20,
        blur: 16,
        padding: const EdgeInsets.all(12),
        fluidAuraColor: IosTheme.primaryPink,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: IosTheme.primaryPink.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.speedometer, color: IosTheme.primaryPink, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        resourceSegment == 0
                            ? '图集下载总进度'
                            : (resourceSegment == 1 ? '视频下载总进度' : 'Jable 影视下载总进度'),
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        currentSpeed,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: IosTheme.primaryPink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: isDownloadingNow ? currentProgress : 0.0,
                      minHeight: 4.5,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      valueColor: const AlwaysStoppedAnimation<Color>(IosTheme.primaryPink),
                    ),
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

class TaskHistoryStatsBanner extends StatelessWidget {
  final int resourceSegment;
  final List<HistoryRecord> imageRecords;
  final List<HistoryRecord> videoRecords;
  final List<JableHistoryRecord> jableRecords;
  final int imageTotalImages;
  final int imageTotalBytes;
  final int videoTotalBytes;

  const TaskHistoryStatsBanner({
    super.key,
    required this.resourceSegment,
    required this.imageRecords,
    required this.videoRecords,
    required this.jableRecords,
    required this.imageTotalImages,
    required this.imageTotalBytes,
    required this.videoTotalBytes,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: LiquidGlass(
        borderRadius: 20,
        blur: 16,
        padding: const EdgeInsets.all(14),
        fluidAuraColor: IosTheme.primaryPurple,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: resourceSegment == 0
              ? [
                  _buildStatItem('已下载图集', '${imageRecords.length} 套', CupertinoIcons.square_stack_3d_up_fill),
                  _buildDivider(isDark),
                  _buildStatItem('图片总计', '$imageTotalImages 张', CupertinoIcons.photo_fill_on_rectangle_fill),
                  _buildDivider(isDark),
                  _buildStatItem('累计占用', formatBytes(imageTotalBytes), CupertinoIcons.chart_pie_fill),
                ]
              : (resourceSegment == 1
                  ? [
                      _buildStatItem('已下载视频', '${videoRecords.length} 部', CupertinoIcons.film_fill),
                      _buildDivider(isDark),
                      _buildStatItem('视频总计', '${videoRecords.length} 个文件', CupertinoIcons.play_rectangle_fill),
                      _buildDivider(isDark),
                      _buildStatItem('累计占用', formatBytes(videoTotalBytes), CupertinoIcons.chart_pie_fill),
                    ]
                  : [
                      _buildStatItem('已完成影视', '${jableRecords.length} 部', CupertinoIcons.play_rectangle_fill),
                      _buildDivider(isDark),
                      _buildStatItem('历史记录', '${jableRecords.length} 条', CupertinoIcons.list_bullet),
                      _buildDivider(isDark),
                      _buildStatItem('存储目录', 'jabletv/', CupertinoIcons.folder_fill),
                    ]),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: IosTheme.primaryPurple, size: 18),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 28,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }
}
