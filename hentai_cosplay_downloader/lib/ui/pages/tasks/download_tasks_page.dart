import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/download_task.dart';
import '../../../models/history_record.dart';
import '../../../models/jable_task.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/history_provider.dart';
import '../../../providers/jable_download_provider.dart';
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
  int _resourceSegment = 0; // 0: 图集任务, 1: 视频任务, 2: Jable任务
  int _selectedStatusSegment = 0; // 0: 全部, 1: 进行中, 2: 已完成 (历史), 3: 失败

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final downloadProv = context.watch<DownloadProvider>();
    final historyProv = context.watch<HistoryProvider>();
    final jableProv = context.watch<JableDownloadProvider>();

    final isJableMode = _resourceSegment == 2;
    final isHistoryMode = _selectedStatusSegment == 2;

    // Image & Video tasks
    final imageTasks = downloadProv.allTasks.where((t) => !t.isVideo).toList();
    final videoTasks = downloadProv.allTasks.where((t) => t.isVideo).toList();
    final jableTasks = jableProv.allTasks;

    // Active, completed, failed
    final imageActive = imageTasks.where((t) => t.status == TaskStatus.downloading || t.status == TaskStatus.queued || t.status == TaskStatus.paused).toList();
    final imageCompleted = imageTasks.where((t) => t.status == TaskStatus.completed).toList();
    final imageFailed = imageTasks.where((t) => t.status == TaskStatus.failed).toList();

    final videoActive = videoTasks.where((t) => t.status == TaskStatus.downloading || t.status == TaskStatus.queued || t.status == TaskStatus.paused).toList();
    final videoCompleted = videoTasks.where((t) => t.status == TaskStatus.completed).toList();
    final videoFailed = videoTasks.where((t) => t.status == TaskStatus.failed).toList();

    final jableActive = jableProv.activeTasks + jableProv.queuedTasks + jableProv.pausedTasks;
    final jableCompleted = jableProv.completedTasks;
    final jableFailed = jableProv.failedTasks;

    // History Records
    final imageRecords = historyProv.records.where((r) => !r.isVideo).toList();
    final videoRecords = historyProv.records.where((r) => r.isVideo).toList();
    final jableRecords = jableProv.historyRecords;

    final imageTotalImages = imageRecords.fold<int>(0, (sum, r) => sum + r.imageCount);
    final imageTotalBytes = imageRecords.fold<int>(0, (sum, r) => sum + r.downloadedBytes);
    final videoTotalBytes = videoRecords.fold<int>(0, (sum, r) => sum + r.downloadedBytes);

    int currentResourceCount = 0;
    int currentActiveCount = 0;
    int currentCompletedCount = 0;
    int currentFailedCount = 0;

    if (_resourceSegment == 0) {
      currentResourceCount = imageTasks.length;
      currentActiveCount = imageActive.length;
      currentCompletedCount = imageCompleted.length;
      currentFailedCount = imageFailed.length;
    } else if (_resourceSegment == 1) {
      currentResourceCount = videoTasks.length;
      currentActiveCount = videoActive.length;
      currentCompletedCount = videoCompleted.length;
      currentFailedCount = videoFailed.length;
    } else {
      currentResourceCount = jableTasks.length;
      currentActiveCount = jableActive.length;
      currentCompletedCount = jableCompleted.length;
      currentFailedCount = jableFailed.length;
    }

    final isDownloadingNow = isJableMode ? jableProv.isDownloading : downloadProv.isDownloading;
    final currentSpeed = isJableMode ? jableProv.formattedSpeed : downloadProv.formattedSpeed;
    final currentProgress = isJableMode ? jableProv.overallProgress : downloadProv.overallProgress;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Top Bar with Title and Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  const Text(
                    '下载任务',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),

                  // iOS PiP Button
                  if (Platform.isIOS && isDownloadingNow)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: BouncingButton(
                        onTap: () {
                          if (!isJableMode) downloadProv.startPip();
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
                            color: IosTheme.primaryBlue.withAlpha(40),
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

                  // Clear History Button (when in Completed / History tab)
                  if (isHistoryMode) ...[
                    BouncingButton(
                      onTap: () => _confirmClearHistory(context, _resourceSegment, historyProv, jableProv),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '清空历史',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Pause All Button
                    if (currentActiveCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: BouncingButton(
                          onTap: () {
                            if (isJableMode) {
                              jableProv.pauseAllTasks();
                            } else {
                              downloadProv.pauseAllTasks();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha(40),
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
                    if (currentFailedCount > 0 || (isJableMode ? jableProv.pausedTasks.isNotEmpty : false))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: BouncingButton(
                          onTap: () {
                            if (isJableMode) {
                              jableProv.resumeAllTasks();
                            } else {
                              downloadProv.resumeAllTasks();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                            decoration: BoxDecoration(
                              color: IosTheme.primaryPink.withAlpha(40),
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

                    // Clear Completed Tasks Button
                    if (currentCompletedCount > 0)
                      BouncingButton(
                        onTap: () {
                          if (isJableMode) {
                            jableProv.clearCompleted();
                          } else {
                            downloadProv.clearCompleted();
                          }
                        },
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
                ],
              ),
            ),

            // 2. Top Resource Capsule Switcher: [ 📸 图集任务 ] [ 🎬 视频任务 ] [ 📺 Jable任务 ]
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
                      label: '图集任务',
                      count: imageTasks.length,
                      icon: CupertinoIcons.photo_on_rectangle,
                      isDark: isDark,
                    ),
                    _buildResourceSwitcherItem(
                      index: 1,
                      label: '视频任务',
                      count: videoTasks.length,
                      icon: CupertinoIcons.film_fill,
                      isDark: isDark,
                    ),
                    _buildResourceSwitcherItem(
                      index: 2,
                      label: 'Jable任务',
                      count: jableTasks.length,
                      icon: CupertinoIcons.play_rectangle_fill,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),

            // 3. Speed & Overall Progress Banner (when not in history view)
            if (!isHistoryMode)
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
                                  _resourceSegment == 0
                                      ? '图集下载总进度'
                                      : (_resourceSegment == 1 ? '视频下载总进度' : 'Jable 影视下载总进度'),
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
              )
            else
              // 3. History Stats Banner (when in history view)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: LiquidGlass(
                  borderRadius: 20,
                  blur: 16,
                  padding: const EdgeInsets.all(14),
                  fluidAuraColor: IosTheme.primaryPurple,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _resourceSegment == 0
                        ? [
                            _buildStatItem('已下载图集', '${imageRecords.length} 套', CupertinoIcons.square_stack_3d_up_fill),
                            _buildDivider(isDark),
                            _buildStatItem('图片总计', '$imageTotalImages 张', CupertinoIcons.photo_fill_on_rectangle_fill),
                            _buildDivider(isDark),
                            _buildStatItem('累计占用', _formatBytes(imageTotalBytes), CupertinoIcons.chart_pie_fill),
                          ]
                        : (_resourceSegment == 1
                            ? [
                                _buildStatItem('已下载视频', '${videoRecords.length} 部', CupertinoIcons.film_fill),
                                _buildDivider(isDark),
                                _buildStatItem('视频总计', '${videoRecords.length} 个文件', CupertinoIcons.play_rectangle_fill),
                                _buildDivider(isDark),
                                _buildStatItem('累计占用', _formatBytes(videoTotalBytes), CupertinoIcons.chart_pie_fill),
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
              ),

            // 4. Sub Status Segment Filter: [ 全部 ] [ 进行中 ] [ 已完成 (历史) ] [ 失败 ]
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: FrostedGlass(
                borderRadius: 14,
                blur: 12,
                padding: const EdgeInsets.all(2.5),
                child: Row(
                  children: [
                    _buildStatusSegmentButton(0, '全部 ($currentResourceCount)'),
                    _buildStatusSegmentButton(1, '进行中 ($currentActiveCount)'),
                    _buildStatusSegmentButton(2, '已完成 / 历史 (${isJableMode ? jableRecords.length : (_resourceSegment == 0 ? imageRecords.length : videoRecords.length)})'),
                    _buildStatusSegmentButton(3, '失败 ($currentFailedCount)'),
                  ],
                ),
              ),
            ),

            // 5. Main Content Area
            Expanded(
              child: isHistoryMode
                  ? _buildHistoryListView(_resourceSegment, imageRecords, videoRecords, jableRecords, isDark, historyProv, jableProv)
                  : (isJableMode
                      ? _buildJableTaskListView(jableTasks, _selectedStatusSegment, isDark, jableProv)
                      : _buildCosplayTaskListView(_resourceSegment == 0 ? imageTasks : videoTasks, _selectedStatusSegment, isDark, downloadProv)),
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
                      color: IosTheme.primaryPink.withAlpha(90),
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
                size: 13,
                color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 4),
              Text(
                '$label ($count)',
                style: TextStyle(
                  fontSize: 11.5,
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
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  // --- Cosplay & Porn-Video Task List ---
  Widget _buildCosplayTaskListView(
    List<AlbumDownloadTask> tasks,
    int statusSegment,
    bool isDark,
    DownloadProvider downloadProv,
  ) {
    final List<AlbumDownloadTask> filteredTasks;
    switch (statusSegment) {
      case 1:
        filteredTasks = tasks.where((t) => t.status == TaskStatus.downloading || t.status == TaskStatus.queued || t.status == TaskStatus.paused).toList();
        break;
      case 2:
        filteredTasks = tasks.where((t) => t.status == TaskStatus.completed).toList();
        break;
      case 3:
        filteredTasks = tasks.where((t) => t.status == TaskStatus.failed).toList();
        break;
      case 0:
      default:
        filteredTasks = tasks;
        break;
    }

    if (filteredTasks.isEmpty) {
      return Center(
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
              _resourceSegment == 0 ? '暂无图片任务' : '暂无视频任务',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return _buildTaskCard(task, isDark, downloadProv);
      },
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
                        _buildStatusBadge(task.status),
                        const Spacer(),
                        if (task.isVideo)
                          Text(
                            task.status == TaskStatus.completed
                                ? '下载完成 (${_formatBytes(task.downloadedBytes)})'
                                : (task.downloadedBytes > 0
                                    ? '${(progress * 100).toStringAsFixed(1)}% · ${_formatBytes(task.downloadedBytes)}${task.totalBytes > 0 ? ' / ${_formatBytes(task.totalBytes)}' : ''}'
                                    : (task.duration != null && task.duration!.isNotEmpty ? task.duration! : '高清视频')),
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

  // --- Jable Task List ---
  Widget _buildJableTaskListView(
    List<JableDownloadTask> tasks,
    int statusSegment,
    bool isDark,
    JableDownloadProvider jableProv,
  ) {
    final List<JableDownloadTask> filteredTasks;
    switch (statusSegment) {
      case 1:
        filteredTasks = tasks.where((t) =>
            t.status == JableDownloadStatus.downloading ||
            t.status == JableDownloadStatus.waiting ||
            t.status == JableDownloadStatus.merging ||
            t.status == JableDownloadStatus.paused).toList();
        break;
      case 2:
        filteredTasks = tasks.where((t) => t.status == JableDownloadStatus.completed).toList();
        break;
      case 3:
        filteredTasks = tasks.where((t) => t.status == JableDownloadStatus.failed).toList();
        break;
      case 0:
      default:
        filteredTasks = tasks;
        break;
    }

    if (filteredTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.play_rectangle, size: 46, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              '暂无 Jable 下载任务',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return _buildJableTaskCard(task, isDark, jableProv);
      },
    );
  }

  Widget _buildJableTaskCard(JableDownloadTask task, bool isDark, JableDownloadProvider jableProv) {
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
                          Text(
                            "${task.completedSegments}/${task.totalSegments > 0 ? task.totalSegments : '?'} 分片 · ${task.speed}",
                            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                          )
                        else if (task.status == JableDownloadStatus.merging)
                          const Text(
                            "正在解密合并...",
                            style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                          )
                        else
                          _buildJableStatusBadge(task.status),
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
                _buildActionBtn(
                  icon: CupertinoIcons.pause_fill,
                  label: '暂停',
                  color: Colors.orange,
                  onTap: () => jableProv.pauseTask(task),
                ),
              if (task.status == JableDownloadStatus.paused || task.status == JableDownloadStatus.failed)
                _buildActionBtn(
                  icon: CupertinoIcons.play_fill,
                  label: '继续',
                  color: IosTheme.primaryPink,
                  onTap: () => jableProv.resumeTask(task),
                ),
              const SizedBox(width: 8),
              _buildActionBtn(
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

  // --- History Records Unified List View ---
  Widget _buildHistoryListView(
    int resourceSegment,
    List<HistoryRecord> imageRecords,
    List<HistoryRecord> videoRecords,
    List<JableHistoryRecord> jableRecords,
    bool isDark,
    HistoryProvider historyProv,
    JableDownloadProvider jableProv,
  ) {
    if (resourceSegment == 2) {
      if (jableRecords.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.play_rectangle, size: 48, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 12),
              Text(
                '暂无 Jable 下载历史记录',
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
        itemCount: jableRecords.length,
        itemBuilder: (context, index) {
          final record = jableRecords[index];
          return _buildJableHistoryCard(record, isDark, jableProv);
        },
      );
    }

    final currentRecords = resourceSegment == 0 ? imageRecords : videoRecords;
    if (currentRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(resourceSegment == 0 ? CupertinoIcons.photo : CupertinoIcons.film, size: 48, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              resourceSegment == 0 ? '暂无图片下载历史' : '暂无视频下载历史',
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
      itemCount: currentRecords.length,
      itemBuilder: (context, index) {
        final record = currentRecords[index];
        return _buildHistoryRecordCard(record, isDark, historyProv);
      },
    );
  }

  Widget _buildJableHistoryCard(JableHistoryRecord record, bool isDark, JableDownloadProvider jableProv) {
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

  Widget _buildHistoryRecordCard(HistoryRecord record, bool isDark, HistoryProvider historyProv) {
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(record.completedAt);

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
                            : _formatBytes(record.downloadedBytes),
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
        color: color.withAlpha(40),
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

  Widget _buildJableStatusBadge(JableDownloadStatus status) {
    Color color;
    String label;

    switch (status) {
      case JableDownloadStatus.completed:
        color = IosTheme.primaryGreen;
        label = '已完成';
        break;
      case JableDownloadStatus.downloading:
        color = IosTheme.primaryPink;
        label = '下载中';
        break;
      case JableDownloadStatus.merging:
        color = Colors.orange;
        label = '合并中';
        break;
      case JableDownloadStatus.waiting:
        color = IosTheme.primaryBlue;
        label = '等待中';
        break;
      case JableDownloadStatus.paused:
        color = Colors.orange;
        label = '已暂停';
        break;
      case JableDownloadStatus.failed:
        color = Colors.red;
        label = '失败';
        break;
      default:
        color = Colors.grey;
        label = '取消';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
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
          color: color.withAlpha(35),
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

  void _confirmClearHistory(BuildContext context, int resourceSegment, HistoryProvider historyProv, JableDownloadProvider jableProv) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('清空${resourceSegment == 0 ? "图片" : (resourceSegment == 1 ? "视频" : "Jable")}历史记录'),
        content: const Text('确认清空记录吗？（已下载的本地文件不会被删除）'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('清空'),
            onPressed: () {
              Navigator.pop(ctx);
              if (resourceSegment == 2) {
                jableProv.clearAllHistory();
              } else {
                final records = resourceSegment == 0
                    ? historyProv.records.where((r) => !r.isVideo).toList()
                    : historyProv.records.where((r) => r.isVideo).toList();
                for (final r in records) {
                  historyProv.removeRecord(r.id);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
