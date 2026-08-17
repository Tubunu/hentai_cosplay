import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/download_task.dart';
import '../../../providers/download_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/liquid_glass.dart';

class DownloadTasksPage extends StatefulWidget {
  const DownloadTasksPage({super.key});

  @override
  State<DownloadTasksPage> createState() => _DownloadTasksPageState();
}

class _DownloadTasksPageState extends State<DownloadTasksPage> {
  int _selectedSegment = 0; // 0: All, 1: Active, 2: Completed, 3: Failed

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final downloadProv = context.watch<DownloadProvider>();

    final List<AlbumDownloadTask> filteredTasks;
    switch (_selectedSegment) {
      case 1:
        filteredTasks = downloadProv.allTasks
            .where((t) => t.status == TaskStatus.downloading || t.status == TaskStatus.queued || t.status == TaskStatus.paused)
            .toList();
        break;
      case 2:
        filteredTasks = downloadProv.completedTasks;
        break;
      case 3:
        filteredTasks = downloadProv.failedTasks;
        break;
      case 0:
      default:
        filteredTasks = downloadProv.allTasks;
        break;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Text(
                    '任务管理',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),

                  // iOS PiP Button
                  if (Platform.isIOS && downloadProv.isDownloading)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: BouncingButton(
                        onTap: () {
                          downloadProv.startPip();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('已激活画中画后台保活，切到后台可保持不间断下载'),
                              backgroundColor: IosTheme.primaryPink,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: IosTheme.primaryBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.picture_in_picture_alt_rounded, size: 13, color: IosTheme.primaryBlue),
                              SizedBox(width: 4),
                              Text(
                                '画中画',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: IosTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Pause All Button
                  if (downloadProv.activeTasks.isNotEmpty || downloadProv.queuedTasks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: BouncingButton(
                        onTap: () => downloadProv.pauseAllTasks(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.pause_fill, size: 12, color: Colors.orange),
                              SizedBox(width: 4),
                              Text(
                                '全部暂停',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Resume All Button
                  if (downloadProv.pausedTasks.isNotEmpty || downloadProv.failedTasks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: BouncingButton(
                        onTap: () => downloadProv.resumeAllTasks(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: IosTheme.primaryPink.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.play_fill, size: 12, color: IosTheme.primaryPink),
                              SizedBox(width: 4),
                              Text(
                                '全部开始',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: IosTheme.primaryPink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Clear Completed Button
                  if (downloadProv.completedTasks.isNotEmpty)
                    BouncingButton(
                      onTap: () => downloadProv.clearCompleted(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '清理完成',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Speed & Overall Progress Banner
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: LiquidGlass(
                borderRadius: 20,
                blur: 16,
                padding: const EdgeInsets.all(14),
                fluidAuraColor: IosTheme.primaryPink,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: IosTheme.primaryPink.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.speedometer, color: IosTheme.primaryPink, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('当前下载速度', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                              Text(
                                downloadProv.formattedSpeed,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: IosTheme.primaryPink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: downloadProv.isDownloading ? downloadProv.overallProgress : 0.0,
                              minHeight: 5,
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
            ),

            // Segmented Tab Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: FrostedGlass(
                borderRadius: 16,
                blur: 12,
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildSegmentButton(0, '全部 (${downloadProv.allTasks.length})'),
                    _buildSegmentButton(1, '进行中 (${downloadProv.activeTasks.length + downloadProv.queuedTasks.length})'),
                    _buildSegmentButton(2, '已完成 (${downloadProv.completedTasks.length})'),
                    _buildSegmentButton(3, '失败 (${downloadProv.failedTasks.length})'),
                  ],
                ),
              ),
            ),

            // Task List
            Expanded(
              child: filteredTasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.tray,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '暂无下载任务',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        return _buildTaskCard(task, isDark, downloadProv);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(int index, String label) {
    final isSelected = _selectedSegment == index;

    return Expanded(
      child: BouncingButton(
        onTap: () => setState(() => _selectedSegment = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? IosTheme.primaryPink : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(AlbumDownloadTask task, bool isDark, DownloadProvider downloadProv) {
    final item = task.albumItem;
    final progress = task.progress;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 54,
                  height: 54,
                  color: isDark ? Colors.white10 : Colors.black12,
                  child: item.coverUrl != null && item.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.coverUrl!,
                          fit: BoxFit.cover,
                          httpHeaders: const {
                            'Referer': 'https://zh.hentai-cosplay-xxx.com/',
                          },
                          placeholder: (_, __) => const Center(
                            child: CupertinoActivityIndicator(radius: 8),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            CupertinoIcons.photo,
                            color: Colors.grey,
                            size: 24,
                          ),
                        )
                      : const Icon(CupertinoIcons.photo, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 12),

              // Title & Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildStatusBadge(task.status),
                        const SizedBox(width: 8),
                        Text(
                          '${task.downloadedImages + task.skippedImages} / ${task.totalImages > 0 ? task.totalImages : "?"} 张',
                          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (task.status == TaskStatus.downloading)
                    BouncingButton(
                      onTap: () => downloadProv.pauseTask(task),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.pause_fill, size: 16, color: Colors.orange),
                      ),
                    )
                  else if (task.status == TaskStatus.paused || task.status == TaskStatus.failed)
                    BouncingButton(
                      onTap: () => downloadProv.resumeTask(task),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: IosTheme.primaryPink.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.play_fill, size: 16, color: IosTheme.primaryPink),
                      ),
                    ),
                  const SizedBox(width: 6),
                  BouncingButton(
                    onTap: () => downloadProv.removeTask(task),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.trash, size: 16, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: task.status == TaskStatus.completed ? 1.0 : (progress > 0 ? progress : null),
              minHeight: 4,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(
                task.status == TaskStatus.completed
                    ? IosTheme.primaryGreen
                    : (task.status == TaskStatus.failed ? Colors.red : IosTheme.primaryPink),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TaskStatus status) {
    String label;
    Color color;

    switch (status) {
      case TaskStatus.completed:
        label = '已完成';
        color = IosTheme.primaryGreen;
        break;
      case TaskStatus.downloading:
        label = '下载中';
        color = IosTheme.primaryPink;
        break;
      case TaskStatus.queued:
        label = '队列中';
        color = IosTheme.primaryBlue;
        break;
      case TaskStatus.paused:
        label = '已暂停';
        color = Colors.orange;
        break;
      case TaskStatus.failed:
        label = '失败';
        color = Colors.red;
        break;
      default:
        label = '空闲';
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
