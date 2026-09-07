import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A reusable, memory-safe dialog for jumping to a specific page number.
/// Accurately manages and disposes its [FixedExtentScrollController] to eliminate memory leaks.
class JumpPageDialog extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final Color? themeColor;
  final ValueChanged<int> onPageSelected;

  const JumpPageDialog({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.themeColor,
    required this.onPageSelected,
  });

  /// Static helper to display the dialog
  static Future<void> show(
    BuildContext context, {
    required int currentPage,
    required int totalPages,
    Color? themeColor,
    required ValueChanged<int> onPageSelected,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => JumpPageDialog(
        currentPage: currentPage,
        totalPages: totalPages,
        themeColor: themeColor,
        onPageSelected: onPageSelected,
      ),
    );
  }

  @override
  State<JumpPageDialog> createState() => _JumpPageDialogState();
}

class _JumpPageDialogState extends State<JumpPageDialog> {
  late final FixedExtentScrollController _scrollController;
  late int _selectedPage;

  @override
  void initState() {
    super.initState();
    _selectedPage = widget.currentPage;
    final maxPages = widget.totalPages > 0 ? widget.totalPages : 50;
    final initialItem = (widget.currentPage - 1).clamp(0, maxPages - 1);
    _scrollController = FixedExtentScrollController(initialItem: initialItem);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = widget.themeColor ?? Theme.of(context).primaryColor;
    final maxPages = widget.totalPages > 0 ? widget.totalPages : 50;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        '跳转页码',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        height: 150,
        child: CupertinoPicker(
          itemExtent: 40,
          scrollController: _scrollController,
          onSelectedItemChanged: (index) {
            _selectedPage = index + 1;
          },
          children: List.generate(
            maxPages,
            (index) => Center(child: Text('第 ${index + 1} 页')),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: effectiveColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(context);
            widget.onPageSelected(_selectedPage);
          },
          child: const Text('跳转', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
