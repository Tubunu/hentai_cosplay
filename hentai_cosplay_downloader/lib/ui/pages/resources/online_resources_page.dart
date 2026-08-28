import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../browse/browse_page.dart';
import '../coomer/coomer_browse_page.dart';
import '../cosplaytele/cosplaytele_browse_page.dart';
import '../eporner/eporner_browse_page.dart';
import '../exhentai/exhentai_browse_page.dart';
import '../hanime1/hanime1_browse_page.dart';
import '../hqporner/hqporner_browse_page.dart';
import '../kuraa/kuraa_browse_page.dart';
import '../misskon/misskon_browse_page.dart';
import '../mzt/mzt_browse_page.dart';
import '../nucosplay/nucosplay_browse_page.dart';
import '../pinse/pinse_browse_page.dart';
import '../pixibb/pixibb_browse_page.dart';
import '../pornbox/pornbox_browse_page.dart';
import '../spankbang/spankbang_browse_page.dart';
import '../twitter_rankings/twitter_browse_page.dart';
import '../video/video_browse_page.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/liquid_glass.dart';

class OnlineResourcesPage extends StatefulWidget {
  const OnlineResourcesPage({super.key});

  @override
  State<OnlineResourcesPage> createState() => _OnlineResourcesPageState();
}

class _OnlineResourcesPageState extends State<OnlineResourcesPage> {
  int _currentIndex = 0;
  final ScrollController _navScrollController = ScrollController();
  final List<GlobalKey> _itemKeys = List.generate(17, (_) => GlobalKey());

  static const List<_SiteTabConfig> _tabs = [
    _SiteTabConfig(
      label: 'HC 图集',
      icon: CupertinoIcons.photo_on_rectangle,
      color: IosTheme.primaryPink,
    ),
    _SiteTabConfig(
      label: 'HC 视频',
      icon: CupertinoIcons.play_rectangle_fill,
      color: Color(0xFFFF5252),
    ),
    _SiteTabConfig(
      label: '妹子图',
      icon: CupertinoIcons.sparkles,
      color: Color(0xFFFF4081),
    ),
    _SiteTabConfig(
      label: 'MissKon',
      icon: CupertinoIcons.camera_fill,
      color: Color(0xFFE74C3C),
    ),
    _SiteTabConfig(
      label: 'Coomer',
      icon: CupertinoIcons.person_2_fill,
      color: Color(0xFF00AFF0),
    ),
    _SiteTabConfig(
      label: '91品色',
      icon: CupertinoIcons.flame_fill,
      color: Color(0xFFFF8C00),
    ),
    _SiteTabConfig(
      label: 'PornBox',
      icon: CupertinoIcons.cube_box_fill,
      color: Color(0xFF8E24AA),
    ),
    _SiteTabConfig(
      label: 'Kuraa',
      icon: CupertinoIcons.cloud_fill,
      color: Color(0xFF00897B),
    ),
    _SiteTabConfig(
      label: 'Twitter 榜',
      icon: CupertinoIcons.chat_bubble_2_fill,
      color: Color(0xFF1D9BF0),
    ),
    _SiteTabConfig(
      label: 'ExHentai',
      icon: CupertinoIcons.book_fill,
      color: Color(0xFF9C27B0),
    ),
    _SiteTabConfig(
      label: 'PixiBB',
      icon: CupertinoIcons.heart_fill,
      color: Color(0xFFFF4081),
    ),
    _SiteTabConfig(
      label: 'CosplayTele',
      icon: CupertinoIcons.paperplane_fill,
      color: Color(0xFF0088CC),
    ),
    _SiteTabConfig(
      label: 'NuCosplay',
      icon: CupertinoIcons.star_circle_fill,
      color: Color(0xFFAB47BC),
    ),
    _SiteTabConfig(
      label: 'Hanime1',
      icon: CupertinoIcons.film_fill,
      color: Color(0xFFFF2E63),
    ),
    _SiteTabConfig(
      label: 'EPorner',
      icon: CupertinoIcons.tv_fill,
      color: Color(0xFFE53935),
    ),
    _SiteTabConfig(
      label: 'HQPorner',
      icon: CupertinoIcons.film_fill,
      color: Color(0xFFFF9800),
    ),
    _SiteTabConfig(
      label: 'SpankBang',
      icon: CupertinoIcons.play_circle_fill,
      color: Color(0xFF2196F3),
    ),
  ];

  @override
  void dispose() {
    _navScrollController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });

    // Auto-scroll the selected pill to center
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[index];
      final context = key.currentContext;
      if (context != null && _navScrollController.hasClients) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: 0.5,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Indexed pages preserving scroll and browse state across all 17 resources
          IndexedStack(
            index: _currentIndex,
            children: const [
              BrowsePage(),             // 0: Hentai Cosplay 图集
              VideoBrowsePage(),        // 1: Hentai Cosplay 在线视频
              MztBrowsePage(),          // 2: 妹子图图库
              MisskonBrowsePage(),      // 3: MissKon 日韩写真
              CoomerBrowsePage(),       // 4: Coomer 创作者社区
              PinseBrowsePage(),        // 5: 91品色 原创视频
              PornboxBrowsePage(),      // 6: PornBox 欧美影视
              KuraaBrowsePage(),        // 7: Kuraa 云盘图库
              TwitterBrowsePage(),      // 8: Twitter 排行榜 (TikTok 版多站点)
              ExHentaiBrowsePage(),     // 9: ExHentai 里站/EH
              PixibbBrowsePage(),       // 10: PixiBB 4K写真
              CosplayteleBrowsePage(),  // 11: CosplayTele 电报合集
              NucosplayBrowsePage(),    // 12: NuCosplay Coser写真
              Hanime1BrowsePage(),      // 13: Hanime1 动漫番剧
              EpornerBrowsePage(),      // 14: EPorner 4K/VR影视
              HqpornerBrowsePage(),     // 15: HQPorner 超清影视
              SpankbangBrowsePage(),    // 16: SpankBang 极速影视
            ],
          ),

          // Floating Adaptive Liquid Glass Segmented Capsule Bar
          Positioned(
            top: topPadding + 6,
            left: 12,
            right: 12,
            child: Align(
              alignment: Alignment.topCenter,
              child: LiquidGlass(
                borderRadius: 24,
                blur: 24,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                fluidAuraColor: _tabs[_currentIndex].color,
                child: SingleChildScrollView(
                  controller: _navScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_tabs.length, (index) {
                      return _buildSegmentItem(
                        index,
                        _tabs[index],
                        isDark,
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(int index, _SiteTabConfig tab, bool isDark) {
    final isSelected = _currentIndex == index;

    return BouncingButton(
      key: _itemKeys[index],
      onTap: () => _onTabSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? tab.color : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: tab.color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tab.icon,
              size: 14.5,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 5),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteTabConfig {
  final String label;
  final IconData icon;
  final Color color;

  const _SiteTabConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
}
