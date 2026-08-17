import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/history_record.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/history_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/frosted_glass.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyProv = context.watch<HistoryProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalPacks = historyProv.totalPacksDownloaded + historyProv.totalPacksSkipped;
    final totalImages = historyProv.totalImagesDownloaded;
    final totalDuration = historyProv.totalDurationSeconds;

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
                              'STATS & REPLAY',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: IosTheme.primaryPink.withOpacity(0.9),
                              ),
                            ),
                            const Text(
                              '下载历史',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),

                        if (historyProv.records.isNotEmpty)
                          BouncingButton(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: const Text('清空历史记录？'),
                                  content: const Text('这将清除所有下载批次记录与统计数据（不会删除已下载的本地图片文件）。'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('取消'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        historyProv.clearHistory();
                                      },
                                      child: const Text('确认清空'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: FrostedGlass(
                              borderRadius: 16,
                              blur: 15,
                              padding: const EdgeInsets.all(8),
                              backgroundColor: isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF),
                              child: const Icon(CupertinoIcons.trash, color: Colors.red, size: 18),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Apple Music Replay Statistics Hero Cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        // Total Packs Card
                        Expanded(
                          child: _buildStatCard(
                            context: context,
                            title: '累计图包',
                            value: totalPacks.toString(),
                            unit: '个',
                            icon: CupertinoIcons.square_stack_3d_up_fill,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFA2D55), Color(0xFFFF6A88)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Total Images Card
                        Expanded(
                          child: _buildStatCard(
                            context: context,
                            title: '累计图片',
                            value: totalImages.toString(),
                            unit: '张',
                            icon: CupertinoIcons.photo_fill_on_rectangle_fill,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8A3FFC), Color(0xFFB066FE)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Total Time Card
                        Expanded(
                          child: _buildStatCard(
                            context: context,
                            title: '累计耗时',
                            value: totalDuration >= 60
                                ? '${(totalDuration / 60).toStringAsFixed(1)}'
                                : '${totalDuration.toStringAsFixed(0)}',
                            unit: totalDuration >= 60 ? '分' : '秒',
                            icon: CupertinoIcons.stopwatch_fill,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF007AFF), Color(0xFF409CFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(22, 20, 20, 8),
                    child: Text(
                      '批次记录',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),

                // History Records List
                if (historyProv.records.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.clock,
                            size: 56,
                            color: IosTheme.secondaryText(context).withOpacity(0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '暂无下载历史记录',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: IosTheme.secondaryText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final record = historyProv.records[index];
                          return _buildHistoryRecordCard(context, record, isDark, historyProv);
                        },
                        childCount: historyProv.records.length,
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: context.watch<DownloadProvider>().hasActiveOrPausedTasks ? 210 : 130,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRecordCard(
    BuildContext context,
    HistoryRecord record,
    bool isDark,
    HistoryProvider prov,
  ) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(CupertinoIcons.calendar, size: 14, color: IosTheme.primaryPink),
                    const SizedBox(width: 6),
                    Text(
                      record.timestamp,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark_circle, size: 18),
                  color: IosTheme.secondaryText(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => prov.deleteRecord(record.id),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                _buildTag('图包 +${record.packsDownloaded}', IosTheme.primaryPink),
                const SizedBox(width: 6),
                _buildTag('图片 +${record.imagesDownloaded}', IosTheme.secondaryPurple),
                const SizedBox(width: 6),
                if (record.imagesSkipped > 0) ...[
                  _buildTag('跳过 ${record.imagesSkipped}', Colors.grey),
                  const SizedBox(width: 6),
                ],
                const Spacer(),
                Text(
                  '耗时 ${record.durationSec.toStringAsFixed(1)}s',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: IosTheme.secondaryText(context),
                  ),
                ),
              ],
            ),

            if (record.packTitles.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '包含图包: ${record.packTitles.take(3).join("、")}${record.packTitles.length > 3 ? " 等" : ""}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: IosTheme.secondaryText(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
