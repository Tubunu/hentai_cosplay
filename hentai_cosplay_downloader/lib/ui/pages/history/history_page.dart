import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/history_record.dart';
import '../../../providers/history_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/liquid_glass.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _resourceSegment = 0; // 0: 图片历史, 1: 视频历史

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

    final imageRecords = historyProv.records.where((r) => !r.isVideo).toList();
    final videoRecords = historyProv.records.where((r) => r.isVideo).toList();
    final currentRecords = _resourceSegment == 0 ? imageRecords : videoRecords;

    final imageTotalImages = imageRecords.fold<int>(0, (sum, r) => sum + r.imageCount);
    final imageTotalBytes = imageRecords.fold<int>(0, (sum, r) => sum + r.downloadedBytes);

    final videoTotalBytes = videoRecords.fold<int>(0, (sum, r) => sum + r.downloadedBytes);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  const Text(
                    '下载历史',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  if (currentRecords.isNotEmpty)
                    BouncingButton(
                      onTap: () {
                        showCupertinoDialog(
                          context: context,
                          builder: (ctx) => CupertinoAlertDialog(
                            title: Text('清空${_resourceSegment == 0 ? "图片" : "视频"}历史记录'),
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
                                  for (final r in currentRecords) {
                                    historyProv.removeRecord(r.id);
                                  }
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

            // Top Resource Capsule Switcher: [ 📸 图片历史 ]   [ 🎬 视频历史 ]
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
                      label: '图片历史',
                      count: imageRecords.length,
                      icon: CupertinoIcons.photo_on_rectangle,
                      isDark: isDark,
                    ),
                    _buildResourceSwitcherItem(
                      index: 1,
                      label: '视频历史',
                      count: videoRecords.length,
                      icon: CupertinoIcons.play_rectangle_fill,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),

            // History Stats Banner
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
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
                      : [
                          _buildStatItem('已下载视频', '${videoRecords.length} 部', CupertinoIcons.film_fill),
                          _buildDivider(isDark),
                          _buildStatItem('视频总计', '${videoRecords.length} 个文件', CupertinoIcons.play_rectangle_fill),
                          _buildDivider(isDark),
                          _buildStatItem('累计占用', _formatBytes(videoTotalBytes), CupertinoIcons.chart_pie_fill),
                        ],
                ),
              ),
            ),

            // History Record List
            Expanded(
              child: currentRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _resourceSegment == 0 ? CupertinoIcons.photo : CupertinoIcons.film,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _resourceSegment == 0 ? '暂无图片下载历史' : '暂无视频下载历史',
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
                      itemCount: currentRecords.length,
                      itemBuilder: (context, index) {
                        final record = currentRecords[index];
                        return _buildRecordCard(record, isDark, historyProv);
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

  Widget _buildRecordCard(HistoryRecord record, bool isDark, HistoryProvider historyProv) {
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
          // Cover / Thumbnail
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
                      placeholder: (_, __) => const Center(
                        child: CupertinoActivityIndicator(radius: 8),
                      ),
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

          // Info
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
