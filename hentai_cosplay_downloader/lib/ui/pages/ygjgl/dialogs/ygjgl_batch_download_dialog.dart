import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/ygjgl/ygjgl_post_item.dart';
import '../../../../models/ygjgl/ygjgl_vod_item.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/ygjgl_browse_provider.dart';
import '../../../../services/ygjgl/ygjgl_api_service.dart';
import '../../../widgets/bouncing_button.dart';

class YgjglBatchDownloadDialog extends StatefulWidget {
  final int subTab; // 0: vod, 1: image, 2: audio
  final int currentPage;
  final int totalPages;

  const YgjglBatchDownloadDialog({
    super.key,
    required this.subTab,
    required this.currentPage,
    required this.totalPages,
  });

  static Future<void> show(
    BuildContext context, {
    required int subTab,
    required int currentPage,
    required int totalPages,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => YgjglBatchDownloadDialog(
        subTab: subTab,
        currentPage: currentPage,
        totalPages: totalPages,
      ),
    );
  }

  @override
  State<YgjglBatchDownloadDialog> createState() => _YgjglBatchDownloadDialogState();
}

class _YgjglBatchDownloadDialogState extends State<YgjglBatchDownloadDialog> {
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: widget.currentPage.toString());
    final defaultEnd = (widget.currentPage + 2).clamp(1, widget.totalPages > 0 ? widget.totalPages : 50);
    _endController = TextEditingController(text: defaultEnd.toString());
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  String get _typeTitle {
    switch (widget.subTab) {
      case 0:
        return '点播视频';
      case 1:
        return '写真套图';
      case 2:
        return '电台音频';
      default:
        return '资源';
    }
  }

  Future<void> _submit() async {
    final start = int.tryParse(_startController.text.trim()) ?? 1;
    final end = int.tryParse(_endController.text.trim()) ?? start;

    if (start < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('起始页码必须大于或等于 1'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (start > end) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('起始页码不能大于结束页码'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (end - start > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('单次批量抓取最多支持 10 页'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final downloadProv = context.read<DownloadProvider>();
    final ygjglProv = context.read<YgjglBrowseProvider>();

    try {
      int totalAdded = 0;

      if (widget.subTab == 0) {
        // VOD
        for (int p = start; p <= end; p++) {
          final res = await YgjglApiService.fetchVodList(
            page: p,
            size: 40,
            q: ygjglProv.vodKeyword,
            sort: ygjglProv.vodSort,
            tag: ygjglProv.vodSelectedRegion == '免费区' ? null : ygjglProv.vodSelectedRegion,
            freeOnly: ygjglProv.vodSelectedRegion == '免费区',
            year: ygjglProv.vodSelectedYear,
            month: ygjglProv.vodSelectedMonth,
          );
          final items = res['items'] as List<YgjglVodItem>? ?? [];
          if (items.isNotEmpty) {
            downloadProv.addBatchVideoTasks(items.map((e) => e.toVideoItem()).toList());
            totalAdded += items.length;
          }
        }
      } else {
        // Image or Audio
        final kind = widget.subTab == 1 ? 'image' : 'audio';
        for (int p = start; p <= end; p++) {
          final res = await YgjglApiService.fetchPostList(
            kind: kind,
            page: p,
            size: 24,
            q: widget.subTab == 1 ? ygjglProv.imageKeyword : ygjglProv.audioKeyword,
            tag: widget.subTab == 1 ? ygjglProv.imageSelectedTag : ygjglProv.audioSelectedTag,
            series: widget.subTab == 1 ? ygjglProv.imageSelectedSeries : null,
            range: widget.subTab == 1 ? ygjglProv.imageRange : ygjglProv.audioRange,
            sort: widget.subTab == 1 ? ygjglProv.imageSort : ygjglProv.audioSort,
          );
          final items = res['items'] as List<YgjglPostItem>? ?? [];
          if (items.isNotEmpty) {
            if (widget.subTab == 1) {
              downloadProv.addBatchAlbumTasks(items.map((e) => e.toAlbumItem()).toList());
            } else {
              downloadProv.addBatchVideoTasks(items.map((e) => e.toVideoItem()).toList());
            }
            totalAdded += items.length;
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已成功添加 $totalAdded 个$_typeTitle到下载任务！'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量添加失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentPink = Color(0xFFFF5A8A);

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(CupertinoIcons.square_stack_3d_down_right_fill, color: accentPink, size: 22),
          const SizedBox(width: 8),
          Text(
            '批量下载$_typeTitle',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '输入需要连续抓取的页码范围，系统将自动将所有条目加入后台下载队列。',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('起始页', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _startController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2C2C30) : const Color(0xFFF2F2F7),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 20, 12, 0),
                child: Text('至', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('结束页', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _endController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2C2C30) : const Color(0xFFF2F2F7),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '当前共有 ${widget.totalPages} 页',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text('取消', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
        ),
        BouncingButton(
          onTap: _isSubmitting ? null : _submit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF5A8A), Color(0xFFFF8FB3)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    '开始抓取',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}
