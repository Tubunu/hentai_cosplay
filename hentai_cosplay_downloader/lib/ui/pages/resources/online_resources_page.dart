import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../browse/browse_page.dart';
import '../../theme/ios_theme.dart';
import '../video/video_browse_page.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';

class OnlineResourcesPage extends StatefulWidget {
  const OnlineResourcesPage({super.key});

  @override
  State<OnlineResourcesPage> createState() => _OnlineResourcesPageState();
}

class _OnlineResourcesPageState extends State<OnlineResourcesPage> {
  int _currentIndex = 0; // 0: 在线图片, 1: 在线视频

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Indexed pages preserving scroll state
          IndexedStack(
            index: _currentIndex,
            children: const [
              BrowsePage(),
              VideoBrowsePage(),
            ],
          ),

          // Floating Top Segmented Control Capsule
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: FrostedGlass(
              borderRadius: 22,
              blur: 25,
              padding: const EdgeInsets.all(3),
              backgroundColor: isDark
                  ? const Color(0xCC1E1E24)
                  : const Color(0xCCFFFFFF),
              borderColor: isDark ? Colors.white12 : Colors.black12,
              borderWidth: 0.5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSegmentItem(0, '在线图片', CupertinoIcons.photo_on_rectangle, isDark),
                  _buildSegmentItem(1, '在线视频', CupertinoIcons.play_rectangle_fill, isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(int index, String label, IconData icon, bool isDark) {
    final isSelected = _currentIndex == index;

    return BouncingButton(
      onTap: () {
        if (_currentIndex != index) {
          setState(() {
            _currentIndex = index;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? IosTheme.primaryPink
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
