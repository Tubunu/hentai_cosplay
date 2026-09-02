import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/resource_site_item.dart';
import '../../../providers/browse_provider.dart';
import '../../../providers/coomer_browse_provider.dart';
import '../../../providers/cosplaytele_browse_provider.dart';
import '../../../providers/eporner_browse_provider.dart';
import '../../../providers/exhentai_browse_provider.dart';
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
import '../../widgets/bouncing_button.dart';
import '../../widgets/liquid_glass.dart';
import '../history/browsing_history_page.dart';

class OnlineResourcesPage extends StatefulWidget {
  const OnlineResourcesPage({super.key});

  @override
  State<OnlineResourcesPage> createState() => _OnlineResourcesPageState();
}

class _OnlineResourcesPageState extends State<OnlineResourcesPage> {
  int _currentIndex = 0;
  final ScrollController _navScrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};
  final Set<String> _visitedSiteKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settingsProv = context.read<SettingsProvider>();
      final orderedSites = ResourceSiteRegistry.getOrderedSites(
        settingsProv.config.onlineResourceSortOrder,
      );
      if (orderedSites.isNotEmpty) {
        final initialKey = orderedSites[_currentIndex.clamp(0, orderedSites.length - 1)].key;
        _activateAndLoadSite(initialKey);
      }
    });
  }

  @override
  void dispose() {
    _navScrollController.dispose();
    super.dispose();
  }

  void _activateAndLoadSite(String siteKey) {
    if (!_visitedSiteKeys.contains(siteKey)) {
      setState(() {
        _visitedSiteKeys.add(siteKey);
      });
    }
    _ensureSiteDataLoaded(siteKey);
  }

  void _ensureSiteDataLoaded(String siteKey) {
    switch (siteKey) {
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
    }
  }

  void _onTabSelected(int index, List<ResourceSiteItem> sites) {
    if (_currentIndex == index) return;

    final targetSite = sites[index];
    setState(() {
      _currentIndex = index;
    });

    _activateAndLoadSite(targetSite.key);

    // Auto-scroll the selected pill to center
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index >= 0 && index < sites.length) {
        final key = _itemKeys[sites[index].key];
        final context = key?.currentContext;
        if (context != null && _navScrollController.hasClients) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: 0.5,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final settingsProv = context.watch<SettingsProvider>();
    final orderedSites = ResourceSiteRegistry.getOrderedSites(
      settingsProv.config.onlineResourceSortOrder,
    );

    // Ensure _currentIndex is within valid bounds if list changed
    if (_currentIndex >= orderedSites.length) {
      _currentIndex = 0;
    }

    final activeSite = orderedSites[_currentIndex];

    // Ensure key exists for every site item
    for (final s in orderedSites) {
      _itemKeys.putIfAbsent(s.key, () => GlobalKey());
    }

    // Ensure current active site is marked visited
    _visitedSiteKeys.add(activeSite.key);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Indexed pages with lazy mounting and persistent caching
          IndexedStack(
            index: _currentIndex,
            children: orderedSites.map((site) {
              if (!_visitedSiteKeys.contains(site.key)) {
                return const SizedBox.shrink();
              }
              return site.builder(context);
            }).toList(),
          ),

          // Floating Adaptive Liquid Glass Segmented Capsule Bar & History Button
          Positioned(
            top: topPadding + 6,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: LiquidGlass(
                    borderRadius: 24,
                    blur: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                    fluidAuraColor: activeSite.color,
                    child: SingleChildScrollView(
                      controller: _navScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(orderedSites.length, (index) {
                          return _buildSegmentItem(
                            index,
                            orderedSites[index],
                            isDark,
                            orderedSites,
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Browsing History Button
                BouncingButton(
                  onTap: () => BrowsingHistoryPage.open(context),
                  child: LiquidGlass(
                    borderRadius: 24,
                    blur: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9.5),
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
        ],
      ),
    );
  }

  Widget _buildSegmentItem(
    int index,
    ResourceSiteItem site,
    bool isDark,
    List<ResourceSiteItem> sites,
  ) {
    final isSelected = _currentIndex == index;

    return BouncingButton(
      key: _itemKeys[site.key],
      onTap: () => _onTabSelected(index, sites),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? site.color : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
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
              size: 14.5,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 5),
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
