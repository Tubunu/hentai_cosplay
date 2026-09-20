import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hentai_cosplay_downloader/models/download_task.dart';
import 'package:hentai_cosplay_downloader/models/history_record.dart';
import 'package:hentai_cosplay_downloader/models/jable_task.dart';
import 'package:hentai_cosplay_downloader/providers/download_provider.dart';
import 'package:hentai_cosplay_downloader/providers/history_provider.dart';
import 'package:hentai_cosplay_downloader/providers/jable_download_provider.dart';
import 'package:hentai_cosplay_downloader/ui/pages/history/browsing_history_page.dart';
import 'package:hentai_cosplay_downloader/ui/theme/ios_theme.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/bouncing_button.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/chrome_insets_coordinator.dart';
import 'package:provider/provider.dart';
import 'widgets/history_record_card.dart';
import 'widgets/task_card.dart';
import 'widgets/task_filter_header.dart';
import 'widgets/task_summary_banner.dart';

class DownloadTasksPage extends StatefulWidget {
  const DownloadTasksPage({super.key});

  @override
  State<DownloadTasksPage> createState() => _DownloadTasksPageState();
}

class _DownloadTasksPageState extends State<DownloadTasksPage> {
  int _resourceSegment = 0; // 0: 图集任务, 1: 视频任务, 2: Jable任务
  int _selectedStatusSegment = 0; // 0: 全部, 1: 进行中, 2: 已完成 (历史), 3: 失败

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final downloadProv = context.watch<DownloadProvider>();
    final historyProv = context.watch<HistoryProvider>();
    final jableProv = context.watch<JableDownloadProvider>();

    final isJableMode = _resourceSegment == 2;
    final isHistoryMode = _selectedStatusSegment == 2;

    // Image & Video tasks (using cached collections from DownloadProvider)
    final imageTasks = downloadProv.imageTasks;
    final videoTasks = downloadProv.videoTasks;
    final jableTasks = jableProv.allTasks;

    // Active, completed, failed (using cached collections from DownloadProvider)
    final imageActive = downloadProv.imageActiveTasks;
    final imageCompleted = downloadProv.imageCompletedTasks;
    final imageFailed = downloadProv.imageFailedTasks;

    final videoActive = downloadProv.videoActiveTasks;
    final videoCompleted = downloadProv.videoCompletedTasks;
    final videoFailed = downloadProv.videoFailedTasks;

    final jableActive = jableProv.activeTasks + jableProv.queuedTasks + jableProv.pausedTasks;
    final jableCompleted = jableProv.completedTasks;
    final jableFailed = jableProv.failedTasks;

    // History Records (using cached precalculated collections and statistics from HistoryProvider)
    final imageRecords = historyProv.imageRecords;
    final videoRecords = historyProv.videoRecords;
    final jableRecords = jableProv.historyRecords;

    final imageTotalImages = historyProv.imageTotalImages;
    final imageTotalBytes = historyProv.imageTotalBytes;
    final videoTotalBytes = historyProv.videoTotalBytes;

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

    final isAnyDownloadingNow = downloadProv.isDownloading || jableProv.isDownloading;
    final isDownloadingNow = isJableMode ? jableProv.isDownloading : downloadProv.isDownloading;
    final currentSpeed = isJableMode ? jableProv.formattedSpeed : downloadProv.formattedSpeed;
    final currentProgress = isJableMode ? jableProv.overallProgress : downloadProv.overallProgress;

    final hasRunningTasks = isJableMode
        ? (jableProv.activeTasks.isNotEmpty || jableProv.queuedTasks.isNotEmpty)
        : (_resourceSegment == 0
            ? downloadProv.imageTasks.any((t) => t.status == TaskStatus.downloading || t.status == TaskStatus.queued)
            : downloadProv.videoTasks.any((t) => t.status == TaskStatus.downloading || t.status == TaskStatus.queued));

    final hasResumableTasks = isJableMode
        ? (jableProv.pausedTasks.isNotEmpty || jableProv.failedTasks.isNotEmpty)
        : (_resourceSegment == 0
            ? downloadProv.imageTasks.any((t) => t.status == TaskStatus.paused || t.status == TaskStatus.failed)
            : downloadProv.videoTasks.any((t) => t.status == TaskStatus.paused || t.status == TaskStatus.failed));

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
                  if (Platform.isIOS && isAnyDownloadingNow)
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

                  // Clear History Button & Browsing History Button (when in Completed / History tab)
                  if (isHistoryMode) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: BouncingButton(
                        onTap: () => BrowsingHistoryPage.open(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: IosTheme.primaryBlue.withValues(alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.clock_fill, size: 12, color: IosTheme.primaryBlue),
                              SizedBox(width: 3),
                              Text(
                                '浏览历史',
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
                    if (hasRunningTasks)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: BouncingButton(
                          onTap: () {
                            if (isJableMode) {
                              jableProv.pauseAllTasks();
                            } else {
                              downloadProv.pauseAllTasks(isVideo: _resourceSegment == 1);
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
                    if (hasResumableTasks)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: BouncingButton(
                          onTap: () {
                            if (isJableMode) {
                              jableProv.resumeAllTasks();
                            } else {
                              downloadProv.resumeAllTasks(isVideo: _resourceSegment == 1);
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
                            downloadProv.clearCompleted(isVideo: _resourceSegment == 1);
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
            TaskResourceSwitcher(
              selectedIndex: _resourceSegment,
              imageCount: imageTasks.length,
              videoCount: videoTasks.length,
              jableCount: jableTasks.length,
              onSegmentChanged: (idx) => setState(() => _resourceSegment = idx),
            ),

            // 3. Speed Banner or History Stats Banner
            if (!isHistoryMode)
              TaskSpeedBanner(
                resourceSegment: _resourceSegment,
                currentSpeed: currentSpeed,
                currentProgress: currentProgress,
                isDownloadingNow: isDownloadingNow,
              )
            else
              TaskHistoryStatsBanner(
                resourceSegment: _resourceSegment,
                imageRecords: imageRecords,
                videoRecords: videoRecords,
                jableRecords: jableRecords,
                imageTotalImages: imageTotalImages,
                imageTotalBytes: imageTotalBytes,
                videoTotalBytes: videoTotalBytes,
              ),

            // 4. Sub Status Segment Filter: [ 全部 ] [ 进行中 ] [ 已完成 (历史) ] [ 失败 ]
            TaskStatusFilterBar(
              selectedSegment: _selectedStatusSegment,
              currentResourceCount: currentResourceCount,
              currentActiveCount: currentActiveCount,
              currentCompletedOrHistoryCount: isJableMode
                  ? jableRecords.length
                  : (_resourceSegment == 0 ? imageRecords.length : videoRecords.length),
              currentFailedCount: currentFailedCount,
              onSegmentChanged: (idx) => setState(() => _selectedStatusSegment = idx),
            ),

            // 5. Main Content Area
            Expanded(
              child: isHistoryMode
                  ? _buildHistoryListView(
                      _resourceSegment,
                      imageRecords,
                      videoRecords,
                      jableRecords,
                      isDark,
                      historyProv,
                      jableProv,
                    )
                  : (isJableMode
                      ? _buildJableTaskListView(jableTasks, _selectedStatusSegment, isDark, jableProv)
                      : _buildCosplayTaskListView(
                          _resourceSegment == 0 ? imageTasks : videoTasks,
                          _selectedStatusSegment,
                          isDark,
                          downloadProv,
                        )),
            ),
          ],
        ),
      ),
    );
  }

  // --- Cosplay & Video Task List ---
  Widget _buildCosplayTaskListView(
    List<AlbumDownloadTask> tasks,
    int statusSegment,
    bool isDark,
    DownloadProvider downloadProv,
  ) {
    final List<AlbumDownloadTask> filteredTasks;
    switch (statusSegment) {
      case 1:
        filteredTasks = tasks
            .where((t) =>
                t.status == TaskStatus.downloading ||
                t.status == TaskStatus.queued ||
                t.status == TaskStatus.paused)
            .toList();
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
      padding: EdgeInsets.fromLTRB(16, 6, 16, ChromeInsets.bottom(context, extra: 24)),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return AlbumTaskCard(task: task, downloadProv: downloadProv);
      },
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
        filteredTasks = tasks
            .where((t) =>
                t.status == JableDownloadStatus.downloading ||
                t.status == JableDownloadStatus.waiting ||
                t.status == JableDownloadStatus.merging ||
                t.status == JableDownloadStatus.paused)
            .toList();
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
      padding: EdgeInsets.fromLTRB(16, 6, 16, ChromeInsets.bottom(context, extra: 24)),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return JableTaskCard(task: task, jableProv: jableProv);
      },
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
        padding: EdgeInsets.fromLTRB(16, 6, 16, ChromeInsets.bottom(context, extra: 24)),
        itemCount: jableRecords.length,
        itemBuilder: (context, index) {
          final record = jableRecords[index];
          return JableHistoryRecordCard(record: record, jableProv: jableProv);
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
      padding: EdgeInsets.fromLTRB(16, 6, 16, ChromeInsets.bottom(context, extra: 24)),
      itemCount: currentRecords.length,
      itemBuilder: (context, index) {
        final record = currentRecords[index];
        return AlbumHistoryRecordCard(record: record, historyProv: historyProv);
      },
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
                historyProv.removeRecords(records.map((r) => r.id).toList());
              }
            },
          ),
        ],
      ),
    );
  }
}
