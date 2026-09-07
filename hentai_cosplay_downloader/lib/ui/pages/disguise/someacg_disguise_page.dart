import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/wallpaper_item.dart';
import '../../../providers/disguise_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/wallpaper_service.dart';
import '../../widgets/bouncing_button.dart';
import 'wallpaper_detail_page.dart';

class SomeAcgDisguisePage extends StatefulWidget {
  const SomeAcgDisguisePage({super.key});

  @override
  State<SomeAcgDisguisePage> createState() => _SomeAcgDisguisePageState();
}

class _SomeAcgDisguisePageState extends State<SomeAcgDisguisePage> {
  int _currentBottomNavIndex = 0;
  String _selectedCategory = 'all';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;

  List<WallpaperItem> _wallpapers = [];
  bool _isLoading = true;
  int _page = 1;

  // Emergency tap counter for Logo (5 rapid taps to trigger unlock modal)
  int _logoTapCount = 0;
  DateTime _lastLogoTapTime = DateTime.now();

  final List<Map<String, String>> _categories = [
    {'key': 'all', 'label': '全部精选'},
    {'key': 'mobile', 'label': '📱 手机竖屏'},
    {'key': 'pc', 'label': '💻 电脑宽屏'},
    {'key': 'genshin', 'label': '✨ 原神'},
    {'key': 'starrail', 'label': '🚀 星穹铁道'},
    {'key': 'miku', 'label': '🎵 初音未来'},
    {'key': 'arknights', 'label': '🛡️ 明日方舟'},
  ];

  @override
  void initState() {
    super.initState();
    _loadWallpapers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadWallpapers({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
    }
    setState(() => _isLoading = true);

    final results = await WallpaperService.fetchWallpapers(
      category: _selectedCategory,
      query: _isSearching ? _searchController.text.trim() : '',
      page: _page,
    );

    if (!mounted) return;
    setState(() {
      if (refresh || _page == 1) {
        _wallpapers = results;
      } else {
        _wallpapers.addAll(results);
      }
      _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF7F8FA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Top Bar with SomeACG Branding & Secret Unlock Gestures
            _buildTopBar(isDark),

            // 2. Search Bar
            _buildSearchBar(isDark),

            // 3. Category Filter Chips (Only for Tab 0 / Tab 1)
            if (_currentBottomNavIndex != 2) _buildCategoryBar(isDark),

            // 4. Main Body Content
            Expanded(
              child: _buildBodyContent(isDark),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
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

          // Random Wallpaper button
          BouncingButton(
            onTap: () => _loadWallpapers(refresh: true),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                CupertinoIcons.shuffle,
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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

  Widget _buildCategoryBar(bool isDark) {
    return SizedBox(
      height: 38,
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

  Widget _buildBodyContent(bool isDark) {
    if (_currentBottomNavIndex == 2) {
      return _buildAboutPage(isDark);
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(),
            SizedBox(height: 12),
            Text('正在加载精选壁纸...', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
            const Text('暂无相关壁纸', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            BouncingButton(
              onTap: () => _loadWallpapers(refresh: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

    return RefreshIndicator(
      onRefresh: () => _loadWallpapers(refresh: true),
      color: const Color(0xFFFF2D55),
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _wallpapers.length,
        itemBuilder: (context, index) {
          final item = _wallpapers[index];
          return _buildWallpaperCard(item, isDark);
        },
      ),
    );
  }

  Widget _buildWallpaperCard(WallpaperItem item, bool isDark) {
    return BouncingButton(
      onTap: () => WallpaperDetailPage.open(context, item),
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
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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

            // Gradient Overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 70,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Top Resolution Badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
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
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.tags.isNotEmpty ? '#${item.tags.first}' : '#精选',
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      Row(
                        children: [
                          const Icon(CupertinoIcons.heart_fill, color: Colors.redAccent, size: 10),
                          const SizedBox(width: 3),
                          Text(
                            '${item.likes}',
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
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
              Container(
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
              const SizedBox(height: 14),
              const Text(
                'SomeACG Wallpaper',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'https://www.someacg.top',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFFFF2D55),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _handleLogoTap,
                child: const Text(
                  'Version 2.4.1 (Build 2024.09)',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

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
                'SomeACG 是一个专注于分享高质量二次元（ACG）动漫精选壁纸的非营利社区，涵盖原神、崩坏星穹铁道、明日方舟、初音未来等热门作品及插画创作者的原画作品。',
                style: TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

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
            _buildNavItem(1, '每日排行', CupertinoIcons.flame, isDark),
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
          setState(() {
            _currentBottomNavIndex = index;
            if (index == 0) _selectedCategory = 'all';
            if (index == 1) _selectedCategory = 'pc';
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
