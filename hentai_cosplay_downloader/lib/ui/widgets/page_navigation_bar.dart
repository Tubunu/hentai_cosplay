import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/ios_theme.dart';
import 'bouncing_button.dart';
import 'frosted_glass.dart';

class PageNavigationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final ValueChanged<int> onPageSelected;

  const PageNavigationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.isLoading,
    required this.onPageSelected,
  });

  void _showJumpDialog(BuildContext context) {
    final controller = TextEditingController(text: currentPage.toString());
    showCupertinoDialog(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: const Text('跳转到指定页码'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('请输入 1 ~ $totalPages 之间的页码:'),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('取消'),
              onPressed: () => Navigator.pop(ctx),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('跳转'),
              onPressed: () {
                final input = int.tryParse(controller.text.trim());
                Navigator.pop(ctx);
                if (input != null && input >= 1 && input <= totalPages) {
                  onPageSelected(input);
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FrostedGlass(
        borderRadius: 24,
        blur: 16,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // First page
            BouncingButton(
              onTap: (!isLoading && currentPage > 1) ? () => onPageSelected(1) : null,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  CupertinoIcons.backward_end_fill,
                  size: 16,
                  color: currentPage > 1 ? IosTheme.primaryPink : (isDark ? Colors.white24 : Colors.black26),
                ),
              ),
            ),

            // Previous page
            BouncingButton(
              onTap: (!isLoading && currentPage > 1) ? () => onPageSelected(currentPage - 1) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: currentPage > 1
                      ? IosTheme.primaryPink.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.chevron_left,
                      size: 14,
                      color: currentPage > 1 ? IosTheme.primaryPink : (isDark ? Colors.white24 : Colors.black26),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '上一页',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: currentPage > 1 ? IosTheme.primaryPink : (isDark ? Colors.white24 : Colors.black26),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Page Indicator Capsule (Tap to jump)
            BouncingButton(
              onTap: totalPages > 1 ? () => _showJumpDialog(context) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: IosTheme.primaryPink,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: IosTheme.primaryPink.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: CupertinoActivityIndicator(radius: 6, color: Colors.white),
                      ),
                    Text(
                      '$currentPage / $totalPages',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Next page
            BouncingButton(
              onTap: (!isLoading && currentPage < totalPages) ? () => onPageSelected(currentPage + 1) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: currentPage < totalPages
                      ? IosTheme.primaryPink.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Text(
                      '下一页',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: currentPage < totalPages ? IosTheme.primaryPink : (isDark ? Colors.white24 : Colors.black26),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: currentPage < totalPages ? IosTheme.primaryPink : (isDark ? Colors.white24 : Colors.black26),
                    ),
                  ],
                ),
              ),
            ),

            // Last page
            BouncingButton(
              onTap: (!isLoading && currentPage < totalPages) ? () => onPageSelected(totalPages) : null,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  CupertinoIcons.forward_end_fill,
                  size: 16,
                  color: currentPage < totalPages ? IosTheme.primaryPink : (isDark ? Colors.white24 : Colors.black26),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
