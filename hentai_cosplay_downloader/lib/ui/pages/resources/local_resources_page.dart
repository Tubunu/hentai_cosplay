import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../gallery/local_gallery_page.dart';
import '../../theme/ios_theme.dart';
import '../video/local_video_page.dart';
import '../local_jable/local_jable_page.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';

class LocalResourcesPage extends StatefulWidget {
  const LocalResourcesPage({super.key});

  @override
  State<LocalResourcesPage> createState() => _LocalResourcesPageState();
}

class _LocalResourcesPageState extends State<LocalResourcesPage> {
  int _currentIndex = 0; // 0: 图片, 1: 视频, 2: Jable

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
              LocalGalleryPage(),
              LocalVideoPage(),
              LocalJablePage(),
            ],
          ),

          // Floating Top Segmented Control Capsule (Compact: 图片 / 视频 / Jable)
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            right: 14,
            child: FrostedGlass(
              borderRadius: 20,
              blur: 25,
              padding: const EdgeInsets.all(2.5),
              backgroundColor: isDark
                  ? const Color(0xCC1E1E24)
                  : const Color(0xCCFFFFFF),
              borderColor: isDark ? Colors.white12 : Colors.black12,
              borderWidth: 0.5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSegmentItem(0, '图片', CupertinoIcons.photo_fill_on_rectangle_fill, isDark),
                  _buildSegmentItem(1, '视频', CupertinoIcons.film_fill, isDark),
                  _buildSegmentItem(2, 'Jable', CupertinoIcons.play_rectangle_fill, isDark),
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? IosTheme.primaryPink
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: IosTheme.primaryPink.withAlpha(90),
                    blurRadius: 6,
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
              size: 12,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
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
