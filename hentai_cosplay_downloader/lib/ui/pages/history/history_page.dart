import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/history_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/liquid_glass.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

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
    final historyProv = context.watch<HistoryProvider>();
    final records = historyProv.records;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Text(
                    '下载历史',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  if (records.isNotEmpty)
                    BouncingButton(
                      onTap: () {
                        showCupertinoDialog(
                          context: context,
                          builder: (ctx) => CupertinoAlertDialog(
                            title: const Text('清空历史记录'),
                            content: const Text('确认清空所有下载历史记录吗？（已下载的本地文件不会被删除）'),
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
                                  historyProv.clearAll();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '清空记录',
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

            // History Stats Banner
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: LiquidGlass(
                borderRadius: 20,
                blur: 16,
                padding: const EdgeInsets.all(14),
                fluidAuraColor: IosTheme.primaryPurple,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('已下载图集', '${historyProv.totalAlbums} 套', CupertinoIcons.square_stack_3d_up_fill),
                    _buildDivider(isDark),
                    _buildStatItem('图片总计', '${historyProv.totalImages} 张', CupertinoIcons.photo_fill_on_rectangle_fill),
                    _buildDivider(isDark),
                    _buildStatItem('累计占用', _formatBytes(historyProv.totalBytes), CupertinoIcons.chart_pie_fill),
                  ],
                ),
              ),
            ),

            // History Record List
            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.clock,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '暂无下载历史',
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
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
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
                              // Cover
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  color: isDark ? Colors.white10 : Colors.black12,
                                  child: record.coverUrl != null && record.coverUrl!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: record.coverUrl!,
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

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record.title,
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
                                            color: IosTheme.primaryPink.withValues(alpha: 0.12),
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

                              // Delete Record Button
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
                      },
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
}
