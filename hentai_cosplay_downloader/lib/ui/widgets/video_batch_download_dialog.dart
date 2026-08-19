import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/video_item.dart';
import '../../providers/download_provider.dart';
import '../theme/ios_theme.dart';

class VideoBatchDownloadDialog extends StatefulWidget {
  final int initialStart;
  final int initialEnd;
  final VideoCategory category;
  final String? keyword;
  final String? tag;

  const VideoBatchDownloadDialog({
    super.key,
    required this.initialStart,
    required this.initialEnd,
    required this.category,
    this.keyword,
    this.tag,
  });

  static Future<void> show(
    BuildContext context, {
    required int initialStart,
    required int initialEnd,
    required VideoCategory category,
    String? keyword,
    String? tag,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => VideoBatchDownloadDialog(
        initialStart: initialStart,
        initialEnd: initialEnd,
        category: category,
        keyword: keyword,
        tag: tag,
      ),
    );
  }

  @override
  State<VideoBatchDownloadDialog> createState() => _VideoBatchDownloadDialogState();
}

class _VideoBatchDownloadDialogState extends State<VideoBatchDownloadDialog> {
  late TextEditingController _startController;
  late TextEditingController _endController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: widget.initialStart.toString());
    _endController = TextEditingController(text: widget.initialEnd.toString());
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _onConfirm() async {
    final start = int.tryParse(_startController.text.trim());
    final end = int.tryParse(_endController.text.trim());

    if (start == null || end == null || start < 1 || end < start) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入合法的起始页和结束页（结束页需大于等于起始页）'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final downloadProv = context.read<DownloadProvider>();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已启动第 $start 到 $end 页视频批量下载队列...'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );

    await downloadProv.addVideoPageRange(
      start,
      end,
      category: widget.category,
      keyword: widget.keyword,
      tag: widget.tag,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
      title: const Row(
        children: [
          Icon(CupertinoIcons.layers_alt_fill, color: IosTheme.primaryPink, size: 22),
          SizedBox(width: 8),
          Text(
            '视频多页区间批量下载',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '指定要一次性全部抓取并加入下载队列的视频页码区间。已下载过的视频将自动跳过。',
            style: TextStyle(
              fontSize: 13,
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
                    const Text('起始页码', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _startController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                padding: EdgeInsets.fromLTRB(10, 20, 10, 0),
                child: Text('至', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('结束页码', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _endController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: IosTheme.primaryPink,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: _isSubmitting ? null : _onConfirm,
          child: _isSubmitting
              ? const CupertinoActivityIndicator(color: Colors.white, radius: 8)
              : const Text('开始批量下载', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
