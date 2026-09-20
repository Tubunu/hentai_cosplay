import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../site_registry.dart';
import '../../../providers/browse_provider.dart';
import '../../../providers/coomer_browse_provider.dart';
import '../../../providers/cosplaytele_browse_provider.dart';
import '../../../providers/cosvault_browse_provider.dart';
import '../../../providers/eporner_browse_provider.dart';
import '../../../providers/exhentai_browse_provider.dart';
import '../../../providers/galleryepic_browse_provider.dart';
import '../../../providers/hanime1_browse_provider.dart';
import '../../../providers/hqporner_browse_provider.dart';
import '../../../providers/iwara_browse_provider.dart';
import '../../../providers/kuraa_browse_provider.dart';
import '../../../providers/misskon_browse_provider.dart';
import '../../../providers/mzt_browse_provider.dart';
import '../../../providers/nucosplay_browse_provider.dart';
import '../../../providers/pinse_browse_provider.dart';
import '../../../providers/pixibb_browse_provider.dart';
import '../../../providers/pornbox_browse_provider.dart';
import '../../../providers/pornhub_browse_provider.dart';
import '../../../providers/rule34video_browse_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/spankbang_browse_provider.dart';
import '../../../providers/twitter_browse_provider.dart';
import '../../../providers/video_browse_provider.dart';
import '../../../providers/xvideos_browse_provider.dart';
import '../../../providers/cosxplay_browse_provider.dart';
import '../../../providers/cosplayporntube_browse_provider.dart';
import '../../../providers/xhamster_browse_provider.dart';
import '../../../providers/xnxx_browse_provider.dart';
import '../../../providers/nsfwpub_browse_provider.dart';
import '../../../providers/thothub_browse_provider.dart';
import '../../../providers/njav_browse_provider.dart';
import '../../../providers/vjav_browse_provider.dart';
import '../../../providers/javguru_browse_provider.dart';
import '../../../providers/av123_browse_provider.dart';
import '../../../providers/javmost_browse_provider.dart';
import '../../../providers/memojav_browse_provider.dart';
import '../../../providers/hohoj_browse_provider.dart';
import '../../../providers/jable_browse_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/chrome_insets_coordinator.dart';
import '../../widgets/liquid_glass.dart';
import '../favorites/favorites_page.dart';
import '../history/browsing_history_page.dart';
import '../settings/resource_order_setting_page.dart';
import 'online_resources_hub_sheet.dart';

class OnlineMediaPage extends StatefulWidget {
  final ResourceMediaType mediaType;

  const OnlineMediaPage({
    super.key,
    required this.mediaType,
  });

  @override
  State<OnlineMediaPage> createState() => _OnlineMediaPageState();
}

class _OnlineMediaPageState extends State<OnlineMediaPage> {
  String? _activeSiteKey;
  dynamic _selectedCategoryFilter; // null = all, 'favorites' = favorites, or ResourceCategory
  final ScrollController _navScrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};
  final Set<String> _visitedSiteKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settingsProv = context.read<SettingsProvider>();
      final sites = ResourceSiteRegistry.getOrderedSites(
        settingsProv.config.onlineResourceSortOrder,
        hiddenKeys: settingsProv.config.hiddenResourceSites,
        mediaType: widget.mediaType,
      );
      if (sites.isNotEmpty) {
        final savedKey = widget.mediaType == ResourceMediaType.image
            ? settingsProv.config.lastImageSiteKey
            : settingsProv.config.lastVideoSiteKey;
        final initialKey = sites.any((s) => s.key == savedKey)
            ? savedKey
            : sites.first.key;
        _switchActiveSite(initialKey);
      }
    });
  }

  @override
  void dispose() {
    _navScrollController.dispose();
    super.dispose();
  }

  void _switchActiveSite(String siteKey) {
    if (_activeSiteKey == siteKey && _visitedSiteKeys.contains(siteKey)) return;

    setState(() {
      _activeSiteKey = siteKey;
      _visitedSiteKeys.add(siteKey);
    });

    context.read<SettingsProvider>().setLastSiteKey(widget.mediaType, siteKey);

    _ensureSiteDataLoaded(siteKey);

    // Auto-scroll pill into center
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[siteKey];
      final itemContext = key?.currentContext;
      if (itemContext != null && _navScrollController.hasClients) {
        Scrollable.ensureVisible(
          itemContext,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: 0.5,
        );
      }
    });
  }

  void _ensureSiteDataLoaded(String siteKey) {
    switch (siteKey) {
      case 'jable':
        final p = context.read<JableBrowseProvider>();
        final s0 = p.getStateFor(0);
        if (s0.categories.isEmpty && !s0.loadingCategories && s0.errorMessage == null) {
          p.loadCategories(siteIndex: 0);
        }
        break;
      case 'missav':
        final p = context.read<JableBrowseProvider>();
        final s1 = p.getStateFor(1);
        if (s1.categories.isEmpty && !s1.loadingCategories && s1.errorMessage == null) {
          p.loadCategories(siteIndex: 1);
        }
        break;
      case 'supjav':
        final p = context.read<JableBrowseProvider>();
        final s2 = p.getStateFor(2);
        if (s2.categories.isEmpty && !s2.loadingCategories && s2.errorMessage == null) {
          p.loadCategories(siteIndex: 2);
        }
        break;
      case 'hc_gallery':
        final p = context.read<BrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'hc_video':
        final p = context.read<VideoBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'mzt':
        final p = context.read<MztBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'misskon':
        final p = context.read<MisskonBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'coomer':
        final p = context.read<CoomerBrowseProvider>();
        if (p.posts.isEmpty && p.creators.isEmpty && !p.isLoading && p.errorMessage == null) {
          p.loadData(reset: true);
        }
        break;
      case 'pinse':
        final p = context.read<PinseBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'pornbox':
        final p = context.read<PornboxBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'kuraa':
        final p = context.read<KuraaBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'twitter':
        final p = context.read<TwitterBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.fetchData();
        break;
      case 'exhentai':
        final p = context.read<ExHentaiBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'pixibb':
        final p = context.read<PixibbBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'cosplaytele':
        final p = context.read<CosplayteleBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'nucosplay':
        final p = context.read<NucosplayBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'cosvault':
        final p = context.read<CosvaultBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'galleryepic':
        final p = context.read<GalleryepicBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'hanime1':
        final p = context.read<Hanime1BrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'iwara':
        final p = context.read<IwaraBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'rule34video':
        final p = context.read<Rule34VideoBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'eporner':
        final p = context.read<EpornerBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'hqporner':
        final p = context.read<HqpornerBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'spankbang':
        final p = context.read<SpankbangBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'pornhub':
        final p = context.read<PornhubBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'xvideos':
        final p = context.read<XVideosBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'cosxplay':
        final p = context.read<CosxplayBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'cosplayporntube':
        final p = context.read<CosplayporntubeBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'xhamster':
        final p = context.read<XhamsterBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'xnxx':
        final p = context.read<XnxxBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'nsfwpub':
        final p = context.read<NsfwpubBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'thothub':
        final p = context.read<ThothubBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'njav':
        final p = context.read<NjavBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'vjav':
        final p = context.read<VjavBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'javguru':
        final p = context.read<JavguruBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadVideos();
        break;
      case 'av123':
        final p = context.read<Av123BrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadVideos();
        break;
      case 'javmost':
        final p = context.read<JavmostBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadVideos();
        break;
      case 'memojav':
        final p = context.read<MemojavBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
      case 'hohoj':
        final p = context.read<HohojBrowseProvider>();
        if (p.items.isEmpty && !p.isLoading && p.errorMessage == null) p.loadPage(1);
        break;
    }
  }

  void _showCategoryPicker(BuildContext context, List<ResourceSiteItem> allSites, Set<String> favoriteKeys) {
    final isImage = widget.mediaType == ResourceMediaType.image;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('选择${widget.mediaType.label}分类'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedCategoryFilter = null);
            },
            child: Text(
              '全部站点 (${allSites.length})',
              style: TextStyle(
                fontWeight: _selectedCategoryFilter == null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedCategoryFilter = 'favorites');
            },
            child: Text(
              '⭐ 我的常用 (${allSites.where((s) => favoriteKeys.contains(s.key)).length})',
              style: TextStyle(
                color: const Color(0xFFFFB300),
                fontWeight: _selectedCategoryFilter == 'favorites' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (!isImage) ...[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _selectedCategoryFilter = ResourceCategory.jav);
              },
              child: Text(
                '🌸 日本 JAV (${allSites.where((s) => s.category == ResourceCategory.jav).length})',
                style: TextStyle(
                  fontWeight: _selectedCategoryFilter == ResourceCategory.jav ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _selectedCategoryFilter = ResourceCategory.anime);
              },
              child: Text(
                '✨ 动漫 3D (${allSites.where((s) => s.category == ResourceCategory.anime).length})',
                style: TextStyle(
                  fontWeight: _selectedCategoryFilter == ResourceCategory.anime ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _selectedCategoryFilter = ResourceCategory.video);
              },
              child: Text(
                '🎬 综合影视 (${allSites.where((s) => s.category == ResourceCategory.video).length})',
                style: TextStyle(
                  fontWeight: _selectedCategoryFilter == ResourceCategory.video ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _selectedCategoryFilter = ResourceCategory.creator);
              },
              child: Text(
                '💎 创作者/社媒 (${allSites.where((s) => s.category == ResourceCategory.creator).length})',
                style: TextStyle(
                  fontWeight: _selectedCategoryFilter == ResourceCategory.creator ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  String _getCategoryFilterLabel() {
    if (_selectedCategoryFilter == null) return '分类';
    if (_selectedCategoryFilter == 'favorites') return '常用';
    if (_selectedCategoryFilter is ResourceCategory) {
      return (_selectedCategoryFilter as ResourceCategory).label;
    }
    return '分类';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final settingsProv = context.watch<SettingsProvider>();
    final favoriteKeys = settingsProv.config.favoriteResourceSites.toSet();

    // All available visible sites in user's sort order for this mediaType
    final visibleSites = ResourceSiteRegistry.getOrderedSites(
      settingsProv.config.onlineResourceSortOrder,
      hiddenKeys: settingsProv.config.hiddenResourceSites,
      mediaType: widget.mediaType,
    );

    // If all sites hidden
    if (visibleSites.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.eye_slash_fill,
                  size: 56,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
                const SizedBox(height: 16),
                Text(
                  '所有${widget.mediaType.label}站点已被隐藏',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '您已在设置中隐藏了该分类的所有站点。请前往设置重新开启想要查看的站点。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ResourceOrderSettingPage.open(context),
                  icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 16),
                  label: const Text('管理站点显示'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IosTheme.primaryPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Determine active site
    if (_activeSiteKey == null || !visibleSites.any((s) => s.key == _activeSiteKey)) {
      _activeSiteKey = visibleSites.first.key;
    }
    final activeSite = visibleSites.firstWhere(
      (s) => s.key == _activeSiteKey,
      orElse: () => visibleSites.first,
    );

    // Ensure key exists for every site item
    for (final s in visibleSites) {
      _itemKeys.putIfAbsent(s.key, () => GlobalKey());
    }

    _visitedSiteKeys.add(activeSite.key);

    // Filter pills shown in the horizontal capsule bar according to selected filter
    final displayedPillSites = visibleSites.where((site) {
      if (_selectedCategoryFilter == 'favorites') {
        return favoriteKeys.contains(site.key);
      } else if (_selectedCategoryFilter is ResourceCategory) {
        return site.category == _selectedCategoryFilter;
      }
      return true;
    }).toList();

    // If the category filter filtered out all visible sites, fallback to show all
    final effectivePillSites = displayedPillSites.isNotEmpty ? displayedPillSites : visibleSites;

    // Active index within the full visibleSites list for IndexedStack
    final activeStackIndex = visibleSites.indexWhere((s) => s.key == activeSite.key).clamp(0, visibleSites.length - 1);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Indexed pages with lazy mounting and persistent caching
          IndexedStack(
            index: activeStackIndex,
            children: visibleSites.map((site) {
              if (!_visitedSiteKeys.contains(site.key)) {
                return const SizedBox.shrink();
              }
              return site.builder(context);
            }).toList(),
          ),

          // Floating Liquid Glass Capsule Bar
          Positioned(
            top: topPadding + 6,
            left: 10,
            right: 10,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: ChromeInsetsScope.of(context, listen: false),
              builder: (context, child) {
                final isHidden = ChromeInsets.isHidden(context);
                return AnimatedSlide(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  offset: isHidden ? const Offset(0, -1.4) : Offset.zero,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: isHidden ? 0.0 : 1.0,
                    child: child,
                  ),
                );
              },
              child: Row(
                children: [
                  // Site switcher capsule bar
                  Expanded(
                    child: LiquidGlass(
                    borderRadius: 24,
                    blur: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                    fluidAuraColor: activeSite.color,
                    child: Row(
                      children: [
                        // Category Picker Button
                        BouncingButton(
                          onTap: () => _showCategoryPicker(context, visibleSites, favoriteKeys),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: _selectedCategoryFilter != null
                                  ? IosTheme.primaryPink.withValues(alpha: 0.18)
                                  : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _selectedCategoryFilter == 'favorites'
                                      ? CupertinoIcons.star_fill
                                      : CupertinoIcons.line_horizontal_3_decrease,
                                  size: 12.5,
                                  color: _selectedCategoryFilter == 'favorites'
                                      ? const Color(0xFFFFB300)
                                      : (_selectedCategoryFilter != null
                                          ? IosTheme.primaryPink
                                          : (isDark ? Colors.white70 : Colors.black87)),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _getCategoryFilterLabel(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedCategoryFilter != null
                                        ? IosTheme.primaryPink
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                                Icon(
                                  CupertinoIcons.chevron_down,
                                  size: 10,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 4),

                        // Horizontally scrolling site pills
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _navScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(effectivePillSites.length, (idx) {
                                final site = effectivePillSites[idx];
                                return _buildSegmentItem(
                                  site: site,
                                  isSelected: site.key == activeSite.key,
                                  isDark: isDark,
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Hub Grid Navigation Button (⊞ 资源大厅)
                BouncingButton(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    OnlineResourcesHubSheet.show(
                      context,
                      mediaType: widget.mediaType,
                      currentSiteKey: activeSite.key,
                      onSelectSite: (key) {
                        _switchActiveSite(key);
                      },
                    );
                  },
                  child: LiquidGlass(
                    borderRadius: 24,
                    blur: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
                    fluidAuraColor: activeSite.color,
                    child: Icon(
                      CupertinoIcons.square_grid_2x2_fill,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                      size: 15.5,
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // My Favorites Button (⭐ 我的收藏)
                BouncingButton(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const FavoritesPage()),
                    );
                  },
                  child: LiquidGlass(
                    borderRadius: 24,
                    blur: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
                    fluidAuraColor: activeSite.color,
                    child: const Icon(
                      CupertinoIcons.star_fill,
                      color: Color(0xFFFFB300),
                      size: 15.5,
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Browsing History Button (🕒 浏览历史)
                BouncingButton(
                  onTap: () => BrowsingHistoryPage.open(context),
                  child: LiquidGlass(
                    borderRadius: 24,
                    blur: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
                    fluidAuraColor: activeSite.color,
                    child: Icon(
                      CupertinoIcons.clock_fill,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                      size: 15.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ],
    ),
  );
  }

  Widget _buildSegmentItem({
    required ResourceSiteItem site,
    required bool isSelected,
    required bool isDark,
  }) {
    return BouncingButton(
      key: _itemKeys[site.key],
      onTap: () => _switchActiveSite(site.key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
        decoration: BoxDecoration(
          color: isSelected ? site.color : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: site.color.withValues(alpha: 0.35),
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
              site.icon,
              size: 13.5,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 4.5),
            Text(
              site.label,
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
