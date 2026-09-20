import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hentai_cosplay_downloader/ui/theme/ios_theme.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/bouncing_button.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/frosted_glass.dart';

class TaskResourceSwitcher extends StatelessWidget {
  final int selectedIndex;
  final int imageCount;
  final int videoCount;
  final int jableCount;
  final ValueChanged<int> onSegmentChanged;

  const TaskResourceSwitcher({
    super.key,
    required this.selectedIndex,
    required this.imageCount,
    required this.videoCount,
    required this.jableCount,
    required this.onSegmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
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
            _buildItem(
              context: context,
              index: 0,
              label: '图集任务',
              count: imageCount,
              icon: CupertinoIcons.photo_on_rectangle,
              isDark: isDark,
            ),
            _buildItem(
              context: context,
              index: 1,
              label: '视频任务',
              count: videoCount,
              icon: CupertinoIcons.film_fill,
              isDark: isDark,
            ),
            _buildItem(
              context: context,
              index: 2,
              label: 'Jable任务',
              count: jableCount,
              icon: CupertinoIcons.play_rectangle_fill,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required int index,
    required String label,
    required int count,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = selectedIndex == index;

    return Expanded(
      child: BouncingButton(
        onTap: () {
          if (selectedIndex != index) {
            onSegmentChanged(index);
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
                      color: IosTheme.primaryPink.withAlpha(90),
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
                size: 13,
                color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 4),
              Text(
                '$label ($count)',
                style: TextStyle(
                  fontSize: 11.5,
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
}

class TaskStatusFilterBar extends StatelessWidget {
  final int selectedSegment;
  final int currentResourceCount;
  final int currentActiveCount;
  final int currentCompletedOrHistoryCount;
  final int currentFailedCount;
  final ValueChanged<int> onSegmentChanged;

  const TaskStatusFilterBar({
    super.key,
    required this.selectedSegment,
    required this.currentResourceCount,
    required this.currentActiveCount,
    required this.currentCompletedOrHistoryCount,
    required this.currentFailedCount,
    required this.onSegmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: FrostedGlass(
        borderRadius: 14,
        blur: 12,
        padding: const EdgeInsets.all(2.5),
        child: Row(
          children: [
            _buildButton(0, '全部 ($currentResourceCount)'),
            _buildButton(1, '进行中 ($currentActiveCount)'),
            _buildButton(2, '已完成 / 历史 ($currentCompletedOrHistoryCount)'),
            _buildButton(3, '失败 ($currentFailedCount)'),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(int index, String label) {
    final isSelected = selectedSegment == index;

    return Expanded(
      child: BouncingButton(
        onTap: () => onSegmentChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? IosTheme.primaryPink : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
