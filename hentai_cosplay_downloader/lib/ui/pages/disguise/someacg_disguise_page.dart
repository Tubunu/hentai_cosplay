import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/wallpaper_item.dart';
import '../../../providers/disguise_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/network_client.dart';
import '../../../services/storage_service.dart';
import '../../../services/wallpaper_service.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import 'wallpaper_detail_page.dart';
import 'package:hentai_cosplay_downloader/utils/app_share.dart';

class SomeAcgDisguisePage extends StatefulWidget {
  const SomeAcgDisguisePage({super.key});

  @override
  State<SomeAcgDisguisePage> createState() => _SomeAcgDisguisePageState();
}

class _SomeAcgDisguisePageState extends State<SomeAcgDisguisePage> {
  int _currentBottomNavIndex = 0; // 0: 精选壁纸, 1: 热门榜单, 2: 关于本站
  String _selectedCategory = 'all';
  String _rankingRange = '1M'; // 1d, 1w, 1M, 1y

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _isSearching = false;
  List<WallpaperItem> _wallpapers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  bool _showBackToTop = false;
  WallpaperItem? _selectedWallpaper;

  // Emergency tap counter for Logo/Version (5 rapid taps to trigger unlock modal)
  int _logoTapCount = 0;
  DateTime _lastLogoTapTime = DateTime.now();

  final List<Map<String, String>> _categories = [
    {'key': 'all', 'label': '全部精选'},
    {'key': 'mobile', 'label': '📱 手机竖屏'},
    {'key': 'pc', 'label': '💻 电脑宽屏'},
    {'key': 'genshin', 'label': '✨ 原神'},
    {'key': 'starrail', 'label': '🚀 星穹铁道'},
    {'key': 'bluearchive', 'label': '🎓 碧蓝档案'},
    {'key': 'miku', 'label': '🎵 初音未来'},
    {'key': 'arknights', 'label': '🛡️ 明日方舟'},
  ];

  final List<Map<String, String>> _rankingRanges = [
    {'key': '1d', 'label': '🔥 今日热榜'},
    {'key': '1w', 'label': '⚡ 本周飙升'},
    {'key': '1M', 'label': '🌟 月度精选'},
    {'key': '1y', 'label': '🏆 年度殿堂'},
  ];

  final List<String> _hotSearchTags = [
    '原神',
    '星穹铁道',
    '初音未来',
    '明日方舟',
    '碧蓝档案',
    '绝区零',
    '风景',
    '赛博朋克',
    '黑丝',
    '白发',
    '和风',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadWallpapers();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final offset = _scrollController.offset;
    if (offset > 500 && !_showBackToTop) {
      setState(() => _showBackToTop = true);
    } else if (offset <= 500 && _showBackToTop) {
      setState(() => _showBackToTop = false);
    }

    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 350) {
      if (!_isLoading && !_isLoadingMore && _hasMore && _currentBottomNavIndex != 2) {
        _loadMoreWallpapers();
      }
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _loadWallpapers({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }
    setState(() => _isLoading = true);

    final isRankingTab = _currentBottomNavIndex == 1;
    final results = await WallpaperService.fetchWallpapers(
      category: isRankingTab ? 'ranking' : _selectedCategory,
      query: _isSearching ? _searchController.text.trim() : '',
      page: _page,
      sorting: isRankingTab ? 'toplist' : (_selectedCategory == 'pc' || _selectedCategory == 'mobile' ? 'toplist' : 'toplist'),
      topRange: _rankingRange,
    );

    if (!mounted) return;
    setState(() {
      _wallpapers = results;
      _isLoading = false;
      _hasMore = results.length >= 12;
    });
  }

  Future<void> _loadMoreWallpapers() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _page + 1;
    final isRankingTab = _currentBottomNavIndex == 1;

    final results = await WallpaperService.fetchWallpapers(
      category: isRankingTab ? 'ranking' : _selectedCategory,
      query: _isSearching ? _searchController.text.trim() : '',
      page: nextPage,
      sorting: isRankingTab ? 'toplist' : 'toplist',
      topRange: _rankingRange,
    );

    if (!mounted) return;
    setState(() {
      _page = nextPage;
      if (results.isEmpty) {
        _hasMore = false;
      } else {
        _wallpapers.addAll(results);
        _hasMore = results.length >= 12;
      }
      _isLoadingMore = false;
    });
  }

  void _handleSearchSubmit(String text) {
    final settingsProv = context.read<SettingsProvider>();
    final disguiseProv = context.read<DisguiseProvider>();

    // 1. 核心暗号解锁检测
    final isUnlock = disguiseProv.tryUnlockWithCode(text, settingsProv.config.disguiseUnlockCode);
    if (isUnlock) {
      return; // 解锁成功，AppLockGate 会自动切换为真主页
    }

    // 2. 普通搜索正常执行
    setState(() {
      _isSearching = text.trim().isNotEmpty;
    });
    _loadWallpapers(refresh: true);
  }

  void _handleLogoTap() {
    final now = DateTime.now();
    if (now.difference(_lastLogoTapTime).inMilliseconds < 500) {
      _logoTapCount++;
      if (_logoTapCount >= 5) {
        _logoTapCount = 0;
        _showPasscodeUnlockDialog();
      }
    } else {
      _logoTapCount = 1;
    }
    _lastLogoTapTime = now;
  }

  void _handleLogoLongPress() {
    final config = context.read<SettingsProvider>().config;
    if (config.disguiseQuickUnlock) {
      context.read<DisguiseProvider>().unlock();
    }
  }

  void _showPasscodeUnlockDialog() {
    final controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('SomeACG 权限认证'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '请输入管理暗号',
            obscureText: true,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('验证'),
            onPressed: () {
              Navigator.pop(ctx);
              final input = controller.text;
              final settings = context.read<SettingsProvider>();
              context.read<DisguiseProvider>().tryUnlockWithCode(input, settings.config.disguiseUnlockCode);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _quickDownloadWallpaper(WallpaperItem item) async {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const CupertinoActivityIndicator(color: Colors.white, radius: 8),
            const SizedBox(width: 8),
            Expanded(child: Text('正在下载壁纸原图: ${item.title}', maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: const Color(0xFFFF2D55),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );

    try {
      await StorageService.requestStoragePermissions();

      Directory? targetDir;
      if (Platform.isAndroid) {
        final pictures = Directory('/storage/emulated/0/Pictures/SomeACG');
        try {
          if (!await pictures.exists()) await pictures.create(recursive: true);
          targetDir = pictures;
        } catch (_) {
          final downloads = Directory('/storage/emulated/0/Download/SomeACG');
          try {
            if (!await downloads.exists()) await downloads.create(recursive: true);
            targetDir = downloads;
          } catch (_) {
            final ext = await getExternalStorageDirectory();
            if (ext != null) {
              final sub = Directory(p.join(ext.path, 'SomeACG'));
              if (!await sub.exists()) await sub.create(recursive: true);
              targetDir = sub;
            }
          }
        }
      }

      if (targetDir == null) {
        final doc = await getApplicationDocumentsDirectory();
        final sub = Directory(p.join(doc.path, 'SomeACG'));
        if (!await sub.exists()) await sub.create(recursive: true);
        targetDir = sub;
      }

      final ext = item.rawUrl.endsWith('.png') ? 'png' : 'jpg';
      final fileName = 'SomeACG_${item.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final savePath = p.join(targetDir.path, fileName);

      final dio = NetworkClient.createDio();
      final headers = item.rawUrl.contains('pixiv') || item.rawUrl.contains('pximg')
          ? {'Referer': 'https://www.pixiv.net/'}
          : null;
      await dio.download(
        item.rawUrl,
        savePath,
        options: headers != null ? Options(headers: headers) : null,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('壁纸已保存至: $savePath', maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          backgroundColor: IosTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: '分享',
            textColor: Colors.white,
            onPressed: () {
              AppShare.shareXFiles(context, [XFile(savePath)], text: item.title);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存壁纸失败: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedWallpaper != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          setState(() => _selectedWallpaper = null);
        },
        child: WallpaperDetailPage(
          item: _selectedWallpaper!,
          onBack: () => setState(() => _selectedWallpaper = null),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // 处于伪装主页时按系统返回键，最小化应用至后台，严防误触返回泄漏下层真实页面
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF7F8FA),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 1. Top Bar with SomeACG Branding & Secret Unlock Gestures
              _buildTopBar(isDark),

              // 2. Search Bar & Hot Search Chips
              if (_currentBottomNavIndex != 2) ...[
                _buildSearchBar(isDark),
                if (_isSearching) _buildHotTagsRow(isDark),
              ],

              // 3. Category Filter Chips (Tab 0) / Ranking Filter Chips (Tab 1)
              if (_currentBottomNavIndex == 0)
                _buildCategoryBar(isDark)
              else if (_currentBottomNavIndex == 1)
                _buildRankingRangeBar(isDark),

              // 4. Main Body Content
              Expanded(
                child: _buildBodyContent(isDark),
              ),
            ],
          ),
        ),
        floatingActionButton: _showBackToTop && _currentBottomNavIndex != 2
            ? FloatingActionButton(
                mini: true,
                backgroundColor: const Color(0xFFFF2D55),
                foregroundColor: Colors.white,
                elevation: 4,
                onPressed: _scrollToTop,
                child: const Icon(CupertinoIcons.arrow_up, size: 20),
              )
            : null,
        bottomNavigationBar: _buildBottomNav(isDark),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Logo & Slogan with Secret Triggers
          GestureDetector(
            onTap: _handleLogoTap,
            onLongPress: _handleLogoLongPress,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF2D55), Color(0xFF5856D6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2D55).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'S',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'SomeACG',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2D55).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '壁纸站',
                            style: TextStyle(
                              color: Color(0xFFFF2D55),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '高清二次元精选壁纸 · 每日更新',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // Refresh button
          BouncingButton(
            onTap: () {
              HapticFeedback.lightImpact();
              _loadWallpapers(refresh: true);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                CupertinoIcons.refresh,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E24) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
            width: 0.8,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              CupertinoIcons.search,
              size: 16,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: '搜索壁纸、动漫、角色、标签...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _handleSearchSubmit,
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _handleSearchSubmit('');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    CupertinoIcons.clear_circled_solid,
                    size: 16,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            BouncingButton(
              onTap: () => _handleSearchSubmit(_searchController.text),
              child: Container(
                margin: const EdgeInsets.only(right: 5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2D55), Color(0xFFFF375F)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '搜索',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotTagsRow(bool isDark) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _hotSearchTags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final tag = _hotSearchTags[index];
          return BouncingButton(
            onTap: () {
              _searchController.text = tag;
              _handleSearchSubmit(tag);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#$tag',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryBar(bool isDark) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat['key'];

          return BouncingButton(
            onTap: () {
              if (_selectedCategory == cat['key']) return;
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = cat['key']!);
              _loadWallpapers(refresh: true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF1D1D1F))
                    : (isDark ? const Color(0xFF1A1A20) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08)),
                  width: 0.8,
                ),
              ),
              child: Text(
                cat['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRankingRangeBar(bool isDark) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _rankingRanges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final range = _rankingRanges[index];
          final isSelected = _rankingRange == range['key'];

          return BouncingButton(
            onTap: () {
              if (_rankingRange == range['key']) return;
              HapticFeedback.selectionClick();
              setState(() => _rankingRange = range['key']!);
              _loadWallpapers(refresh: true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF2D55)
                    : (isDark ? const Color(0xFF1A1A20) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08)),
                  width: 0.8,
                ),
              ),
              child: Text(
                range['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBodyContent(bool isDark) {
    if (_currentBottomNavIndex == 2) {
      return _buildAboutPage(isDark);
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(radius: 14),
            SizedBox(height: 12),
            Text('正在加载精选 ACG 壁纸...', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    if (_wallpapers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.photo_on_rectangle, size: 54, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('暂无匹配的高清壁纸', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            BouncingButton(
              onTap: () => _loadWallpapers(refresh: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('重试加载', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
    }

    final isLandscapeCategory = _selectedCategory == 'pc';
    final childRatio = isLandscapeCategory ? 1.48 : (_selectedCategory == 'mobile' ? 0.65 : 0.72);

    return RefreshIndicator(
      onRefresh: () => _loadWallpapers(refresh: true),
      color: const Color(0xFFFF2D55),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: childRatio,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _wallpapers[index];
                  final rank = _currentBottomNavIndex == 1 ? index + 1 : null;
                  return _buildWallpaperCard(item, isDark, rank: rank);
                },
                childCount: _wallpapers.length,
              ),
            ),
          ),

          // Bottom loading more spinner or end notice
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _isLoadingMore
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoActivityIndicator(radius: 9),
                          SizedBox(width: 8),
                          Text('正在加载更多壁纸...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      )
                    : (_hasMore
                        ? const Text('滑动自动加载更多', style: TextStyle(color: Colors.grey, fontSize: 11))
                        : const Text('已加载全部壁纸', style: TextStyle(color: Colors.grey, fontSize: 11))),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildWallpaperCard(WallpaperItem item, bool isDark, {int? rank}) {
    return BouncingButton(
      key: ValueKey('wallpaper_card_${item.id}'),
      onTap: () => setState(() => _selectedWallpaper = item),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Wallpaper Thumbnail
            CachedNetworkImage(
              imageUrl: item.previewUrl,
              fit: BoxFit.cover,
              memCacheWidth: 480,
              httpHeaders: item.previewUrl.contains('pixiv') || item.previewUrl.contains('pximg')
                  ? const {'Referer': 'https://www.pixiv.net/'}
                  : null,
              placeholder: (context, url) => Container(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                child: const Center(child: CupertinoActivityIndicator(radius: 8)),
              ),
              errorWidget: (context, url, error) => Container(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                child: const Center(
                  child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 28),
                ),
              ),
            ),

            // Bottom Gradient Scrim
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 76,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.90),
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.65, 1.0],
                  ),
                ),
              ),
            ),

            // Top-Left Resolution Badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: Text(
                  item.resolution.split('·').first.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            // Top-Right: Rank Medal (if on Ranking tab) or Quick Download Trigger
            Positioned(
              top: 8,
              right: 8,
              child: rank != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: rank == 1
                            ? const Color(0xFFFFD700)
                            : (rank == 2 ? const Color(0xFFC0C0C0) : (rank == 3 ? const Color(0xFFCD7F32) : Colors.black54)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          color: rank <= 3 ? Colors.black : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  : BouncingButton(
                      onTap: () => _quickDownloadWallpaper(item),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.arrow_down_to_line, color: Colors.white, size: 12),
                      ),
                    ),
            ),

            // Bottom Title & Likes
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.tags.isNotEmpty ? '#${item.tags.first}' : '#插画',
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      Row(
                        children: [
                          const Icon(CupertinoIcons.heart_fill, color: Colors.redAccent, size: 10),
                          const SizedBox(width: 3),
                          Text(
                            '${item.likes}',
                            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutPage(bool isDark) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 10),
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _handleLogoTap,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF2D55), Color(0xFF5856D6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2D55).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'S',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 42,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'SomeACG Wallpaper',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'https://someacg.top',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFFF2D55),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _handleLogoTap,
                child: const Text(
                  'Version 3.2.0 (Build 2026.09) · 点击5次认证',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Secret Admin Authentication Entry
        BouncingButton(
          onTap: _showPasscodeUnlockDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF2D55).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(CupertinoIcons.lock_shield, color: Color(0xFFFF2D55), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('管理员权限认证', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      SizedBox(height: 2),
                      Text('输入专属通行暗号进入管理模式', style: TextStyle(color: Colors.grey, fontSize: 11.5)),
                    ],
                  ),
                ),
                Icon(CupertinoIcons.chevron_forward, color: Colors.grey, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Cache Management
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '数据与存储',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(CupertinoIcons.folder, color: Colors.blueAccent, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('保存路径: Pictures/SomeACG', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(CupertinoIcons.trash, color: Colors.orangeAccent, size: 18),
                  const SizedBox(width: 10),
                  const Text('壁纸图片缓存', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: const Color(0xFFFF2D55),
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () {
                      PaintingBinding.instance.imageCache.clear();
                      PaintingBinding.instance.imageCache.clearLiveImages();
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已清除内存壁纸图片缓存'),
                          backgroundColor: IosTheme.primaryGreen,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Text('清理缓存', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // About Description
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '关于本站',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                'SomeACG 是一个专注于分享高质量二次元（ACG）动漫精选壁纸的非营利社区，涵盖原神、崩坏星穹铁道、明日方舟、碧蓝档案、初音未来等热门作品及插画创作者的原画作品。支持手机竖屏与电脑 4K 超清宽屏壁纸下载。',
                style: TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Disclaimer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '免责声明',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '本站所有壁纸资源均搜集于互联网公共开放平台，版权归原作者所有。壁纸仅供个人欣赏与设备美化交流，请勿用于任何商业用途。',
                style: TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return SafeArea(
      top: false,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141418) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
              width: 0.6,
            ),
          ),
        ),
        child: Row(
          children: [
            _buildNavItem(0, '精选壁纸', CupertinoIcons.photo, isDark),
            _buildNavItem(1, '热门榜单', CupertinoIcons.flame, isDark),
            _buildNavItem(2, '关于本站', CupertinoIcons.info, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon, bool isDark) {
    final isSelected = _currentBottomNavIndex == index;

    return Expanded(
      child: BouncingButton(
        onTap: () {
          if (_currentBottomNavIndex == index) {
            _scrollToTop();
            return;
          }
          HapticFeedback.selectionClick();
          setState(() {
            _currentBottomNavIndex = index;
            if (index == 0) _selectedCategory = 'all';
          });
          if (index != 2) _loadWallpapers(refresh: true);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFFFF2D55) : (isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? const Color(0xFFFF2D55) : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
