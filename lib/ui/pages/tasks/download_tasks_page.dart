import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/download_task.dart';
import '../../../providers/download_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/download_expanded_sheet.dart';
import '../../widgets/frosted_glass.dart';

class DownloadTasksPage extends StatelessWidget {
  const DownloadTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final downloadProv = context.watch<DownloadProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeTasks = downloadProv.activeTasks;
    final pausedTasks = downloadProv.pausedTasks;
    final queuedTasks = downloadProv.queuedTasks;
    final completedTasks = downloadProv.completedTasks;
    final failedTasks = downloadProv.failedTasks;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Ambient Mesh Glow
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Container(
              decoration: const BoxDecoration(gradient: IosTheme.ambientMesh),
            ),
          ),

          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Large Hero Title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'QUEUE & DOWNLOADS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: IosTheme.primaryPink.withOpacity(0.9),
                              ),
                            ),
                            const Text(
                              '下载任务',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),

                        // Live Monitor Button
                        BouncingButton(
                          onTap: () => DownloadExpandedSheet.show(context),
                          child: FrostedGlass(
                            borderRadius: 16,
                            blur: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            backgroundColor: isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF),
                            child: const Row(
                              children: [
                                Icon(CupertinoIcons.waveform_circle_fill, color: IosTheme.primaryPink, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  '实时监控',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: IosTheme.primaryPink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Control Action Buttons Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        // Resume/Pause All
                        Expanded(
                          child: BouncingButton(
                            onTap: () {
                              if (downloadProv.isDownloading) {
                                downloadProv.pauseAll();
                              } else {
                                downloadProv.resumeAll();
                              }
                            },
                            child: FrostedGlass(
                              borderRadius: 14,
                              blur: 15,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              backgroundColor: downloadProv.isDownloading
                                  ? Colors.orange.withOpacity(0.15)
                                  : IosTheme.primaryPink.withOpacity(0.15),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    downloadProv.isDownloading ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                                    size: 16,
                                    color: downloadProv.isDownloading ? Colors.orange : IosTheme.primaryPink,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    downloadProv.isDownloading ? '全部暂停' : '全部开始',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: downloadProv.isDownloading ? Colors.orange : IosTheme.primaryPink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Retry Failed
                        if (failedTasks.isNotEmpty) ...[
                          Expanded(
                            child: BouncingButton(
                              onTap: downloadProv.retryFailedTasks,
                              child: FrostedGlass(
                                borderRadius: 14,
                                blur: 15,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                backgroundColor: Colors.red.withOpacity(0.15),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.refresh_circled_solid, size: 16, color: Colors.red),
                                    SizedBox(width: 6),
                                    Text(
                                      '重试失败',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],

                        // Clear Completed
                        BouncingButton(
                          onTap: downloadProv.clearCompleted,
                          child: FrostedGlass(
                            borderRadius: 14,
                            blur: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            backgroundColor: isDark ? const Color(0x7728282E) : const Color(0xCCFFFFFF),
                            child: Icon(
                              CupertinoIcons.trash,
                              size: 16,
                              color: IosTheme.secondaryText(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Empty State
                if (downloadProv.allTasks.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.tray_fill,
                            size: 64,
                            color: IosTheme.secondaryText(context).withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '暂无下载任务',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: IosTheme.secondaryText(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '前往在线浏览页面点击下载或批量抓取',
                            style: TextStyle(
                              fontSize: 13,
                              color: IosTheme.secondaryText(context).withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // 1. Active Downloads Section
                  if (activeTasks.isNotEmpty) ...[
                    _buildSectionHeader('正在下载 (${activeTasks.length})', IosTheme.primaryPink),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildTaskCard(context, activeTasks[index], isDark, downloadProv),
                          childCount: activeTasks.length,
                        ),
                      ),
                    ),
                  ],

                  // 2. Paused Section
                  if (pausedTasks.isNotEmpty) ...[
                    _buildSectionHeader('已暂停 (${pausedTasks.length})', Colors.orange),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildTaskCard(context, pausedTasks[index], isDark, downloadProv),
                          childCount: pausedTasks.length,
                        ),
                      ),
                    ),
                  ],

                  // 3. Queued Section
                  if (queuedTasks.isNotEmpty) ...[
                    _buildSectionHeader('等待队列 (${queuedTasks.length})', Colors.grey),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildTaskCard(context, queuedTasks[index], isDark, downloadProv),
                          childCount: queuedTasks.length,
                        ),
                      ),
                    ),
                  ],

                  // 4. Failed Section
                  if (failedTasks.isNotEmpty) ...[
                    _buildSectionHeader('下载失败 (${failedTasks.length})', Colors.red),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildTaskCard(context, failedTasks[index], isDark, downloadProv),
                          childCount: failedTasks.length,
                        ),
                      ),
                    ),
                  ],

                  // 5. Completed Section
                  if (completedTasks.isNotEmpty) ...[
                    _buildSectionHeader('已完成 (${completedTasks.length})', IosTheme.systemGreen),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildTaskCard(context, completedTasks[index], isDark, downloadProv),
                          childCount: completedTasks.length,
                        ),
                      ),
                    ),
                  ],
                ],

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: downloadProv.hasActiveOrPausedTasks ? 210 : 130,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 20, 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    PackDownloadTask task,
    bool isDark,
    DownloadProvider prov,
  ) {
    final percent = (task.progress * 100).toInt();

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? const Color(0x9924242A) : const Color(0xF2FFFFFF),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 60,
                height: 60,
                color: Colors.black12,
                child: task.packItem.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: task.packItem.coverUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 150,
                        memCacheHeight: 150,
                        errorWidget: (_, __, ___) => const Icon(CupertinoIcons.photo),
                      )
                    : const Icon(CupertinoIcons.photo),
              ),
            ),
            const SizedBox(width: 14),

            // Info & Progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.packItem.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${task.packItem.author}  •  ${task.finishedImages}/${task.totalImages} 张',
                    style: TextStyle(
                      fontSize: 11,
                      color: IosTheme.secondaryText(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: task.progress,
                      minHeight: 5,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        task.status == TaskStatus.failed
                            ? Colors.red
                            : (task.status == TaskStatus.completed
                                ? IosTheme.systemGreen
                                : (task.status == TaskStatus.paused
                                    ? Colors.orange
                                    : IosTheme.primaryPink)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Action Buttons (Play/Pause & Cancel)
            if (!task.isDone) ...[
              IconButton(
                icon: Icon(
                  task.status == TaskStatus.downloading
                      ? CupertinoIcons.pause_circle_fill
                      : CupertinoIcons.play_circle_fill,
                  size: 26,
                  color: task.status == TaskStatus.paused ? Colors.orange : IosTheme.primaryPink,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (task.status == TaskStatus.downloading) {
                    prov.pauseSingleTask(task.id);
                  } else if (task.status == TaskStatus.paused) {
                    prov.resumeSingleTask(task.id);
                  }
                },
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(CupertinoIcons.xmark_circle, size: 20, color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => prov.cancelSingleTask(task.id),
              ),
            ] else ...[
              // Percent Text
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: task.status == TaskStatus.completed
                      ? IosTheme.systemGreen
                      : Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
