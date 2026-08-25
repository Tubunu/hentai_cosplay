import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/gallery_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/jable_download_provider.dart';
import '../../providers/local_jable_provider.dart';
import '../../providers/local_video_provider.dart';
import '../../providers/settings_provider.dart';
import '../theme/ios_theme.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/mini_download_bar.dart';
import 'jable/jable_browse_page.dart';
import 'resources/local_resources_page.dart';
import 'resources/online_resources_page.dart';
import 'settings/settings_page.dart';
import 'tasks/download_tasks_page.dart';

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  int _currentIndex = 0;
  bool _jableActivated = false;
  DownloadProvider? _downloadProv;
  JableDownloadProvider? _jableDownloadProv;

  List<Widget> get _pages => [
    const OnlineResourcesPage(),                                          // 0: 在线资源
    _jableActivated ? const JableBrowsePage() : const SizedBox.shrink(), // 1: Jable 专区 (仅在点击激活后挂载)
    const DownloadTasksPage(),                                            // 2: 下载任务 (内置历史与三分类)
    const LocalResourcesPage(),                                           // 3: 本地资源 (图片、视频、Jable)
    const SettingsPage(),                                                 // 4: 系统设置
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _downloadProv = context.read<DownloadProvider>();
      _jableDownloadProv = context.read<JableDownloadProvider>();

      final historyProv = context.read<HistoryProvider>();
      final galleryProv = context.read<GalleryProvider>();
      final localVideoProv = context.read<LocalVideoProvider>();
      final localJableProv = context.read<LocalJableProvider>();
      final settingsProv = context.read<SettingsProvider>();

      _downloadProv?.onAlbumCompleted = (record) {
        historyProv.addRecord(record);
      };
      _downloadProv?.onAlbumsChanged = () {
        galleryProv.scanLocalDirectory(settingsProv.config.savePath);
        localVideoProv.scanLocalVideos(settingsProv.config.savePath);
      };

      _jableDownloadProv?.onTasksChanged = () {
        localJableProv.scanLocalVideos();
      };
    });
  }

  @override
  void dispose() {
    _downloadProv?.onAlbumCompleted = null;
    _downloadProv?.onAlbumsChanged = null;
    _downloadProv = null;
    _jableDownloadProv?.onTasksChanged = null;
    _jableDownloadProv = null;
    super.dispose();
  }

  void _switchIndex(int index) {
    if (index == 1 && !_jableActivated) {
      setState(() {
        _jableActivated = true;
        _currentIndex = index;
      });
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalBadgeCount = context.select<DownloadProvider, int>(
          (p) => p.activeTasks.length + p.queuedTasks.length,
        ) +
        context.select<JableDownloadProvider, int>(
          (p) => p.activeTasks.length + p.queuedTasks.length,
        );

    final navBarOpacity = context.select<SettingsProvider, double>(
      (p) => p.config.navBarOpacity,
    );

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
              // 1. Floating Mini Download Player Bar
              MiniDownloadBar(
                onTap: () => _switchIndex(2), // Switch to Download Tasks
              ),

              // 2. Next-Gen Liquid Glass Bottom Navigation Bar Capsule (5 Items)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: LiquidGlass(
                  borderRadius: 28,
                  blur: 20,
                  opacity: navBarOpacity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  fluidAuraColor: IosTheme.primaryPink,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(
                        index: 0,
                        icon: CupertinoIcons.compass,
                        activeIcon: CupertinoIcons.compass_fill,
                        label: '在线资源',
                        isDark: isDark,
                      ),
                      _buildNavItem(
                        index: 1,
                        icon: CupertinoIcons.play_rectangle,
                        activeIcon: CupertinoIcons.play_rectangle_fill,
                        label: 'Jable',
                        isDark: isDark,
                      ),
                      _buildNavItem(
                        index: 2,
                        icon: CupertinoIcons.arrow_down_circle,
                        activeIcon: CupertinoIcons.arrow_down_circle_fill,
                        label: '下载任务',
                        badgeCount: totalBadgeCount,
                        isDark: isDark,
                      ),
                      _buildNavItem(
                        index: 3,
                        icon: CupertinoIcons.folder,
                        activeIcon: CupertinoIcons.folder_fill,
                        label: '本地资源',
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
      onTap: () => _switchIndex(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    size: 21,
                    color: isSelected ? IosTheme.primaryPink : (isDark ? Colors.white60 : Colors.black45),
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: IosTheme.primaryPink,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: IosTheme.primaryPink.withAlpha(150),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
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
                fontSize: 9.5,
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
