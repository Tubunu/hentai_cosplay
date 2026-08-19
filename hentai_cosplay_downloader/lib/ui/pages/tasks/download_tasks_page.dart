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
  int _resourceSegment = 0; // 0: 图片任务, 1: 视频任务
  int _selectedStatusSegment = 0; // 0: 全部, 1: 进行中, 2: 已完成, 3: 失败

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final downloadProv = context.watch<DownloadProvider>();

    final imageTasks = downloadProv.allTasks.where((t) => !t.isVideo).toList();
    final videoTasks = downloadProv.allTasks.where((t) => t.isVideo).toList();
    final currentResourceTasks = _resourceSegment == 0 ? imageTasks : videoTasks;

    final activeTasks = currentResourceTasks
        .where((t) => t.status == TaskStatus.downloading || t.status == TaskStatus.queued || t.status == TaskStatus.paused)
        .toList();
    final completedTasks = currentResourceTasks.where((t) => t.status == TaskStatus.completed).toList();
    final failedTasks = currentResourceTasks.where((t) => t.status == TaskStatus.failed).toList();

    final List<AlbumDownloadTask> filteredTasks;
    switch (_selectedStatusSegment) {
      case 1:
        filteredTasks = activeTasks;
        break;
      case 2:
        filteredTasks = completedTasks;
        break;
      case 3:
        filteredTasks = failedTasks;
        break;
      case 0:
      default:
        filteredTasks = currentResourceTasks;
        break;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar with Resource Switcher & Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  const Text(
                    '任务管理',
                    style: TextStyle(
                      fontSize: 24,
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
                            const SnackBar(
                              content: Text('已激活画中画后台保活，切到后台可保持不间断下载'),
                              backgroundColor: IosTheme.primaryPink,
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
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
                  if (activeTasks.isNotEmpty)
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
                  if (currentResourceTasks.any((t) => t.status == TaskStatus.paused || t.status == TaskStatus.failed))
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
                  if (completedTasks.isNotEmpty)
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

            // Top Resource Capsule Switcher: [ 📸 图片任务 ]   [ 🎬 视频任务 ]
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: FrostedGlass(
                borderRadius: 18,
                blur: 16,
                padding: const EdgeInsets.all(3),
                backgroundColor: isDark ? const Color(0xCC1E1E24) : const Color(0xCCFFFFFF),
                borderColor: isDark ? Colors.white12 : Colors.black12,
                borderWidth: 0.5,
                child: Row(
                  children: [
                    _buildResourceSwitcherItem(
                      index: 0,
                      label: '图片任务',
                      count: imageTasks.length,
                      icon: CupertinoIcons.photo_on_rectangle,
                      isDark: isDark,
                    ),
                    _buildResourceSwitcherItem(
                      index: 1,
                      label: '视频任务',
                      count: videoTasks.length,
                      icon: CupertinoIcons.play_rectangle_fill,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),

            // Speed & Overall Progress Banner
            Padding(
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
                        color: IosTheme.primaryPink.withValues(alpha: 0.15),
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
                                _resourceSegment == 0 ? '图片下载总进度' : '视频下载总进度',
                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                downloadProv.formattedSpeed,
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
                              value: downloadProv.isDownloading ? downloadProv.overallProgress : 0.0,
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
            ),

            // Sub Status Segmented Tab Filter: [ 全部 ] [ 进行中 ] [ 已完成 ] [ 失败 ]
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: FrostedGlass(
                borderRadius: 14,
                blur: 12,
                padding: const EdgeInsets.all(2.5),
                child: Row(
                  children: [
                    _buildStatusSegmentButton(0, '全部 (${currentResourceTasks.length})'),
                    _buildStatusSegmentButton(1, '进行中 (${activeTasks.length})'),
                    _buildStatusSegmentButton(2, '已完成 (${completedTasks.length})'),
                    _buildStatusSegmentButton(3, '失败 (${failedTasks.length})'),
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
                            _resourceSegment == 0 ? CupertinoIcons.photo : CupertinoIcons.film,
                            size: 46,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _resourceSegment == 0 ? '暂无图片下载任务' : '暂无视频下载任务',
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
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
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

  Widget _buildResourceSwitcherItem({
    required int index,
    required String label,
    required int count,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _resourceSegment == index;

    return Expanded(
      child: BouncingButton(
        onTap: () {
          if (_resourceSegment != index) {
            setState(() {
              _resourceSegment = index;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? IosTheme.primaryPink : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: IosTheme.primaryPink.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 6),
              Text(
                '$label ($count)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSegmentButton(int index, String label) {
    final isSelected = _selectedStatusSegment == index;

    return Expanded(
      child: BouncingButton(
        onTap: () => setState(() => _selectedStatusSegment = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? IosTheme.primaryPink : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: task.isVideo ? 72 : 56,
                  height: task.isVideo ? 45 : 72,
                  child: item.coverUrl != null && item.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.coverUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey.withValues(alpha: 0.2)),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey.withValues(alpha: 0.2),
                            child: Icon(task.isVideo ? CupertinoIcons.film : CupertinoIcons.photo, color: Colors.grey, size: 20),
                          ),
                        )
                      : Container(
                          color: Colors.grey.withValues(alpha: 0.2),
                          child: Icon(task.isVideo ? CupertinoIcons.film : CupertinoIcons.photo, color: Colors.grey, size: 20),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and Info
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
                              color: IosTheme.primaryPink.withValues(alpha: 0.15),
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

                    // Status and Info Row
                    Row(
                      children: [
                        _buildStatusBadge(task.status),
                        const Spacer(),
                        if (task.isVideo)
                          Text(
                            task.status == TaskStatus.completed
                                ? '下载完成'
                                : (task.duration != null && task.duration!.isNotEmpty ? task.duration! : '高清视频'),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          Text(
                            '${task.downloadedImages + task.skippedImages} / ${task.totalImages > 0 ? task.totalImages : '?'} 张',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Progress Bar (if not completed)
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

          // Action Row
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (task.status == TaskStatus.downloading)
                _buildActionBtn(
                  icon: CupertinoIcons.pause_fill,
                  label: '暂停',
                  color: Colors.orange,
                  onTap: () => downloadProv.pauseTask(task),
                ),
              if (task.status == TaskStatus.paused || task.status == TaskStatus.failed)
                _buildActionBtn(
                  icon: CupertinoIcons.play_fill,
                  label: '继续',
                  color: IosTheme.primaryPink,
                  onTap: () => downloadProv.resumeTask(task),
                ),
              const SizedBox(width: 8),
              _buildActionBtn(
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

  Widget _buildStatusBadge(TaskStatus status) {
    Color color;
    String label;

    switch (status) {
      case TaskStatus.completed:
        color = IosTheme.primaryGreen;
        label = '已完成';
        break;
      case TaskStatus.downloading:
        color = IosTheme.primaryPink;
        label = '下载中';
        break;
      case TaskStatus.queued:
        color = IosTheme.primaryBlue;
        label = '等待中';
        break;
      case TaskStatus.paused:
        color = Colors.orange;
        label = '已暂停';
        break;
      case TaskStatus.failed:
        color = Colors.red;
        label = '失败';
        break;
      default:
        color = Colors.grey;
        label = '未开始';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return BouncingButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
