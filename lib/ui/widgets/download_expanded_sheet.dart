import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/download_task.dart';
import '../../providers/download_provider.dart';
import '../theme/ios_theme.dart';
import 'frosted_glass.dart';

class DownloadExpandedSheet extends StatefulWidget {
  const DownloadExpandedSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => const DownloadExpandedSheet(),
    );
  }

  @override
  State<DownloadExpandedSheet> createState() => _DownloadExpandedSheetState();
}

class _DownloadExpandedSheetState extends State<DownloadExpandedSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadProv = context.watch<DownloadProvider>();
    final activeTask = downloadProv.currentActiveTask;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xF018181A) : const Color(0xF5F9F9FB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Column(
            children: [
              // Top drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // Header title bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '实时下载监控',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.chevron_down_circle_fill),
                      color: IosTheme.secondaryText(context),
                      iconSize: 28,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Segmented tab switch (Overview / Live Logs)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: IosTheme.primaryPink,
                    borderRadius: BorderRadius.circular(19),
                    boxShadow: [
                      BoxShadow(
                        color: IosTheme.primaryPink.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: IosTheme.secondaryText(context),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  tabs: const [
                    Tab(text: '当前任务与进度'),
                    Tab(text: '实时日志终端'),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(context, downloadProv, activeTask, isDark),
                    _buildLogsTab(context, downloadProv, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    DownloadProvider prov,
    PackDownloadTask? activeTask,
    bool isDark,
  ) {
    if (activeTask == null && prov.allTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.tray,
              size: 56,
              color: IosTheme.secondaryText(context).withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              '当前没有下载任务',
              style: TextStyle(
                fontSize: 16,
                color: IosTheme.secondaryText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final overallPercent = (prov.overallProgress * 100).toInt();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        // Active Pack Hero Card
        if (activeTask != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2C192E), const Color(0xFF1E1E24)]
                    : [const Color(0xFFFFF0F5), const Color(0xFFFFFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: IosTheme.primaryPink.withOpacity(0.25), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: IosTheme.primaryPink.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 76,
                    height: 76,
                    color: Colors.black12,
                    child: activeTask.packItem.coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: activeTask.packItem.coverUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(CupertinoIcons.photo),
                          )
                        : const Icon(CupertinoIcons.photo),
                  ),
                ),
                const SizedBox(width: 16),
                // Titles and speed
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeTask.packItem.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: IosTheme.primaryPink.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              activeTask.packItem.author,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: IosTheme.primaryPink,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            prov.formattedSpeed,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: IosTheme.systemGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Overall Progress Bar Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF222226) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: IosTheme.subtleBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '总下载进度',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  Text(
                    '$overallPercent%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: IosTheme.primaryPink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: prov.overallProgress,
                  minHeight: 10,
                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  valueColor: const AlwaysStoppedAnimation<Color>(IosTheme.primaryPink),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '队列图包: ${prov.activeTasks.length + prov.queuedTasks.length} 个',
                    style: TextStyle(fontSize: 12, color: IosTheme.secondaryText(context)),
                  ),
                  Text(
                    '已完成: ${prov.completedTasks.length} 个',
                    style: TextStyle(fontSize: 12, color: IosTheme.secondaryText(context)),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Action controls
        Row(
          children: [
            Expanded(
              child: BouncingButton(
                onTap: () {
                  if (prov.isDownloading) {
                    prov.pauseAll();
                  } else {
                    prov.resumeAll();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: prov.isDownloading ? Colors.orange.withOpacity(0.15) : IosTheme.primaryPink.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        prov.isDownloading ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                        size: 18,
                        color: prov.isDownloading ? Colors.orange : IosTheme.primaryPink,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        prov.isDownloading ? '暂停全部' : '继续下载',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: prov.isDownloading ? Colors.orange : IosTheme.primaryPink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BouncingButton(
                onTap: prov.cancelAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.trash, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        '清空任务',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Text(
          '任务列表',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),

        ...prov.allTasks.map((t) => _buildTaskRow(context, t, isDark)),
      ],
    );
  }

  Widget _buildTaskRow(BuildContext context, PackDownloadTask task, bool isDark) {
    Color statusColor = Colors.grey;
    String statusText = '等待中';
    if (task.status == TaskStatus.downloading) {
      statusColor = IosTheme.primaryPink;
      statusText = '下载中 (${task.finishedImages}/${task.totalImages})';
    } else if (task.status == TaskStatus.completed) {
      statusColor = IosTheme.systemGreen;
      statusText = '已完成 (${task.downloadedImages}新/${task.skippedImages}跳过)';
    } else if (task.status == TaskStatus.failed) {
      statusColor = Colors.red;
      statusText = '失败';
    } else if (task.status == TaskStatus.paused) {
      statusColor = Colors.orange;
      statusText = '已暂停';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242428) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IosTheme.subtleBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.packItem.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
          if (task.status == TaskStatus.downloading) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.progress,
                minHeight: 5,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                valueColor: const AlwaysStoppedAnimation<Color>(IosTheme.primaryPink),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogsTab(BuildContext context, DownloadProvider prov, bool isDark) {
    return Column(
      children: [
        // Action bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '日志记录 (${prov.logs.length})',
                style: TextStyle(fontSize: 13, color: IosTheme.secondaryText(context)),
              ),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 16),
                    label: const Text('复制日志'),
                    style: TextButton.styleFrom(
                      foregroundColor: IosTheme.primaryPink,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      final text = prov.logs.map((l) => '[${l.timeFormatted}] [${l.level.toUpperCase()}] ${l.message}').join('\n');
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制日志到剪贴板')),
                      );
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(CupertinoIcons.trash, size: 16),
                    label: const Text('清空'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: prov.clearLogs,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Logs terminal list
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF101012) : const Color(0xFF1A1A1E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: prov.logs.isEmpty
                ? const Center(
                    child: Text(
                      '暂无日志',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    reverse: false,
                    itemCount: prov.logs.length,
                    itemBuilder: (context, index) {
                      final log = prov.logs[index];
                      Color logColor = Colors.white70;
                      if (log.level == 'error') logColor = const Color(0xFFFF453A);
                      if (log.level == 'warn') logColor = const Color(0xFFFF9F0A);
                      if (log.level == 'success') logColor = const Color(0xFF30D158);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '[${log.timeFormatted}] ',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                              TextSpan(
                                text: log.message,
                                style: TextStyle(color: logColor, fontSize: 12, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
