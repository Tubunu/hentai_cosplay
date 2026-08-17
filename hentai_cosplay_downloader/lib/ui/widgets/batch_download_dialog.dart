import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/browse_provider.dart';
import '../../providers/download_provider.dart';
import '../theme/ios_theme.dart';
import 'bouncing_button.dart';
import 'frosted_glass.dart';

class BatchDownloadDialog extends StatefulWidget {
  final int initialStartPage;
  final int initialEndPage;

  const BatchDownloadDialog({
    super.key,
    this.initialStartPage = 1,
    this.initialEndPage = 5,
  });

  static Future<void> show(BuildContext context, {int initialStart = 1, int initialEnd = 5}) async {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => BatchDownloadDialog(
        initialStartPage: initialStart,
        initialEndPage: initialEnd,
      ),
    );
  }

  @override
  State<BatchDownloadDialog> createState() => _BatchDownloadDialogState();
}

class _BatchDownloadDialogState extends State<BatchDownloadDialog> {
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: widget.initialStartPage.toString());
    _endController = TextEditingController(text: widget.initialEndPage.toString());
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _submit() async {
    final start = int.tryParse(_startController.text.trim()) ?? 1;
    final end = int.tryParse(_endController.text.trim()) ?? start;

    if (start < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('起始页码必须大于或等于 1'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (start > end) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('起始页码不能大于结束页码'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final downloadProv = context.read<DownloadProvider>();
    final browseProv = context.read<BrowseProvider>();
    final keyword = browseProv.searchKeyword.isNotEmpty ? browseProv.searchKeyword : null;

    Navigator.pop(context);

    // Asynchronously fetch and add page range to queue
    downloadProv.addPageRange(start, end, keyword: keyword);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在批量抓取第 $start 到 $end 页图集并加入下载队列...'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: FrostedGlass(
        borderRadius: 28,
        blur: 30,
        padding: const EdgeInsets.all(22),
        backgroundColor: isDark ? const Color(0xE624242A) : const Color(0xF2FFFFFF),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: IosTheme.primaryPink.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    CupertinoIcons.layers_alt_fill,
                    color: IosTheme.primaryPink,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '批量区间下载',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Text(
              '输入要批量抓取并下载的页码范围，应用将自动分页拉取所有图集并加入下载队列：',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            // Start & End Page Inputs
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '起始页码',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _startController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 20, 12, 0),
                  child: Icon(CupertinoIcons.arrow_right, size: 18, color: Colors.grey),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '结束页码',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _endController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: BouncingButton(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          '取消',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BouncingButton(
                    onTap: _isSubmitting ? null : _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: IosTheme.primaryPink,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: IosTheme.primaryPink.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '开始批量下载',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
