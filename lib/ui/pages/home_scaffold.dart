import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/gallery_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/settings_provider.dart';
import '../theme/ios_theme.dart';
import '../widgets/frosted_glass.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/mini_download_bar.dart';
import 'browse/browse_page.dart';
import 'gallery/gallery_page.dart';
import 'history/history_page.dart';
import 'settings/settings_page.dart';
import 'tasks/download_tasks_page.dart';

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    BrowsePage(),
    DownloadTasksPage(),
    HistoryPage(),
    GalleryPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final downloadProv = context.read<DownloadProvider>();
      final historyProv = context.read<HistoryProvider>();
      final galleryProv = context.read<GalleryProvider>();
      final settingsProv = context.read<SettingsProvider>();

      // Link batch completed callback to history & gallery
      downloadProv.onBatchCompleted = (record) {
        historyProv.addRecord(record);
      };
      downloadProv.onPacksChanged = () {
        galleryProv.scanLocalDirectory(settingsProv.config.savePath);
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final downloadProv = context.watch<DownloadProvider>();

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: RepaintBoundary(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Next-Gen Liquid Glass Floating Mini Download Capsule Player
              const MiniDownloadBar(),

              // 2. Next-Gen Liquid Glass Bottom Navigation Bar Capsule
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: LiquidGlass(
                  borderRadius: 28,
                  blur: 16,
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                  fluidAuraColor: IosTheme.primaryPink,
                  child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: CupertinoIcons.compass,
                      activeIcon: CupertinoIcons.compass_fill,
                      label: '在线浏览',
                      isDark: isDark,
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: CupertinoIcons.arrow_down_circle,
                      activeIcon: CupertinoIcons.arrow_down_circle_fill,
                      label: '下载任务',
                      badgeCount: downloadProv.activeTasks.length + downloadProv.queuedTasks.length,
                      isDark: isDark,
                    ),
                    _buildNavItem(
                      index: 2,
                      icon: CupertinoIcons.clock,
                      activeIcon: CupertinoIcons.clock_fill,
                      label: '下载历史',
                      isDark: isDark,
                    ),
                    _buildNavItem(
                      index: 3,
                      icon: CupertinoIcons.photo_on_rectangle,
                      activeIcon: CupertinoIcons.photo_fill_on_rectangle_fill,
                      label: '本地图库',
                      isDark: isDark,
                    ),
                    _buildNavItem(
                      index: 4,
                      icon: CupertinoIcons.gear_alt,
                      activeIcon: CupertinoIcons.gear_alt_fill,
                      label: '系统设置',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
    int badgeCount = 0,
  }) {
    final isSelected = _currentIndex == index;

    return BouncingButton(
      onTap: () {
        setState(() => _currentIndex = index);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    size: 24,
                    color: isSelected ? IosTheme.primaryPink : (isDark ? Colors.white60 : Colors.black45),
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: IosTheme.primaryPink,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: IosTheme.primaryPink.withValues(alpha: 0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? IosTheme.primaryPink : (isDark ? Colors.white60 : Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
