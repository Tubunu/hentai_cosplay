import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/history_record.dart';
import '../../providers/download_provider.dart';
import '../../providers/gallery_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/jable_download_provider.dart';
import '../../providers/local_jable_provider.dart';
import '../../providers/local_video_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/config_service.dart';
import '../../services/history_router.dart';
import '../theme/ios_theme.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/chrome_insets_coordinator.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/mini_download_bar.dart';
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
  final ChromeInsetsController _chromeController = ChromeInsetsController();
  DownloadProvider? _downloadProv;
  JableDownloadProvider? _jableDownloadProv;
  void Function(HistoryRecord)? _albumCompletedHandler;
  void Function()? _albumsChangedHandler;
  void Function()? _jableTasksChangedHandler;

  List<Widget> get _pages => [
    const OnlineImagesPage(),                                             // 0: 在线图片
    const OnlineVideosPage(),                                             // 1: 在线视频 (含 Jable 及全部视频源)
    const DownloadTasksPage(),                                            // 2: 下载任务 (内置历史与三分类)
    const LocalResourcesPage(),                                           // 3: 本地资源 (图片、视频、Jable)
    const SettingsPage(),                                                 // 4: 系统设置
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = ConfigService.loadConfig().lastActiveTabIndex.clamp(0, 4);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _downloadProv = context.read<DownloadProvider>();
      _jableDownloadProv = context.read<JableDownloadProvider>();

      final historyProv = context.read<HistoryProvider>();
      final galleryProv = context.read<GalleryProvider>();
      final localVideoProv = context.read<LocalVideoProvider>();
      final localJableProv = context.read<LocalJableProvider>();
      final settingsProv = context.read<SettingsProvider>();

      _albumCompletedHandler = (record) {
        if (!mounted) return;
        historyProv.addRecord(record);
      };
      _albumsChangedHandler = () {
        if (!mounted) return;
        galleryProv.scanLocalDirectory(settingsProv.config.savePath);
        localVideoProv.scanLocalVideos(settingsProv.config.savePath);
      };
      _jableTasksChangedHandler = () {
        if (!mounted) return;
        localJableProv.scanLocalVideos();
      };

      if (_albumCompletedHandler != null) {
        _downloadProv?.addAlbumCompletedListener(_albumCompletedHandler!);
      }
      if (_albumsChangedHandler != null) {
        _downloadProv?.addAlbumsChangedListener(_albumsChangedHandler!);
      }
      if (_jableTasksChangedHandler != null) {
        _jableDownloadProv?.addTasksChangedListener(_jableTasksChangedHandler!);
      }

      // Check if there was an active viewing record before process termination
      final activeRecord = ConfigService.getActiveViewingRecord();
      if (activeRecord != null) {
        HistoryRouter.openRecord(context, activeRecord);
      }
    });
  }

  @override
  void dispose() {
    if (_albumCompletedHandler != null) {
      _downloadProv?.removeAlbumCompletedListener(_albumCompletedHandler!);
    }
    if (_albumsChangedHandler != null) {
      _downloadProv?.removeAlbumsChangedListener(_albumsChangedHandler!);
    }
    if (_jableTasksChangedHandler != null) {
      _jableDownloadProv?.removeTasksChangedListener(_jableTasksChangedHandler!);
    }
    _downloadProv = null;
    _jableDownloadProv = null;
    _chromeController.dispose();
    super.dispose();
  }

  void _switchIndex(int index) {
    if (_currentIndex == index) return;
    _chromeController.setNavHidden(false);
    setState(() => _currentIndex = index);
    context.read<SettingsProvider>().setLastActiveTabIndex(index);
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

    return ChromeInsetsScope(
      controller: _chromeController,
      child: Scaffold(
        extendBody: true,
        body: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.vertical) {
              final autoHide = context.read<SettingsProvider>().config.autoHideNavigationOnScroll;
              if (autoHide) {
                _chromeController.onScrollDirection(
                  notification.direction,
                  offset: notification.metrics.pixels,
                );
              }
            }
            return false;
          },
          child: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
        ),
        bottomNavigationBar: AnimatedBuilder(
          animation: _chromeController,
          builder: (context, child) {
            final autoHide = context.select<SettingsProvider, bool>(
              (p) => p.config.autoHideNavigationOnScroll,
            );
            final isHidden = autoHide && _chromeController.isNavHidden;
            return AnimatedSlide(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              offset: isHidden ? const Offset(0, 1.4) : Offset.zero,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: isHidden ? 0.0 : 1.0,
                child: child,
              ),
            );
          },
          child: SafeArea(
            top: false,
            child: RepaintBoundary(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Floating Mini Download Player Bar (hidden when already on Downloads page)
                  if (_currentIndex != 2)
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
                            icon: CupertinoIcons.photo_on_rectangle,
                            activeIcon: CupertinoIcons.photo_fill_on_rectangle_fill,
                            label: '在线图片',
                            isDark: isDark,
                          ),
                          _buildNavItem(
                            index: 1,
                            icon: CupertinoIcons.play_rectangle,
                            activeIcon: CupertinoIcons.play_rectangle_fill,
                            label: '在线视频',
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
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: IosTheme.primaryPink,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: IosTheme.primaryPink.withAlpha(150),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
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
