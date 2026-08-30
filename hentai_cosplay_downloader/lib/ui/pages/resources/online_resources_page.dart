import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/resource_site_item.dart';
import '../../../providers/settings_provider.dart';
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

  @override
  void dispose() {
    _navScrollController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index, List<ResourceSiteItem> sites) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });

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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Indexed pages preserving scroll and browse state across all customized resources
          IndexedStack(
            index: _currentIndex,
            children: orderedSites.map((site) => site.widget).toList(),
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
