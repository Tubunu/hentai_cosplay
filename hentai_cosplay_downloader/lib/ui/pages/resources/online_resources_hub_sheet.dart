import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/resource_site_item.dart';
import '../../../providers/settings_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../history/browsing_history_page.dart';
import '../settings/resource_order_setting_page.dart';

class OnlineResourcesHubSheet extends StatefulWidget {
  final ResourceMediaType mediaType;
  final String currentSiteKey;
  final ValueChanged<String> onSelectSite;

  const OnlineResourcesHubSheet({
    super.key,
    required this.mediaType,
    required this.currentSiteKey,
    required this.onSelectSite,
  });

  static void show(
    BuildContext context, {
    required ResourceMediaType mediaType,
    required String currentSiteKey,
    required ValueChanged<String> onSelectSite,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OnlineResourcesHubSheet(
        mediaType: mediaType,
        currentSiteKey: currentSiteKey,
        onSelectSite: onSelectSite,
      ),
    );
  }

  @override
  State<OnlineResourcesHubSheet> createState() => _OnlineResourcesHubSheetState();
}

class _OnlineResourcesHubSheetState extends State<OnlineResourcesHubSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  dynamic _selectedCategoryFilter; // null = all, 'favorites' = favorites, or ResourceCategory

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsProv = context.watch<SettingsProvider>();
    final hiddenKeys = settingsProv.config.hiddenResourceSites.toSet();
    final favoriteKeys = settingsProv.config.favoriteResourceSites.toSet();

    // Pull all sites for this media type in user-defined order
    final allCategorySites = ResourceSiteRegistry.getOrderedSites(
      settingsProv.config.onlineResourceSortOrder,
      hiddenKeys: null, // show hidden in hub or distinguish
      mediaType: widget.mediaType,
    );

    // Filter by category / favorites
    List<ResourceSiteItem> filtered = allCategorySites.where((site) {
      if (_selectedCategoryFilter == 'favorites') {
        if (!favoriteKeys.contains(site.key)) return false;
      } else if (_selectedCategoryFilter is ResourceCategory) {
        if (site.category != _selectedCategoryFilter) return false;
      }
      return true;
    }).toList();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((site) {
        return site.label.toLowerCase().contains(_searchQuery) ||
            site.description.toLowerCase().contains(_searchQuery) ||
            site.key.toLowerCase().contains(_searchQuery) ||
            site.category.label.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    final isImage = widget.mediaType == ResourceMediaType.image;
    final title = isImage ? '在线图片导航' : '在线视频导航';
    final subtitle = isImage
        ? '收录 ${allCategorySites.length} 个高清写真、Cosplay与画廊站点'
        : '收录 ${allCategorySites.length} 个 JAV、3D动漫与综合影视专区';

    final mediaHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: mediaHeight * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : const Color(0xFFF7F7FA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0x33FFFFFF) : const Color(0x18000000),
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header: Title, Subtitle, Close Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isImage
                                ? CupertinoIcons.photo_on_rectangle
                                : CupertinoIcons.play_rectangle_fill,
                            size: 20,
                            color: IosTheme.primaryPink,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                // Close button
                BouncingButton(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F1F23) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0x22FFFFFF) : const Color(0x14000000),
                  width: 0.6,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.search,
                    size: 17,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: isImage ? '搜索写真、画廊或站点名称...' : '搜索 JAV、动漫、视频站点...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () => _searchController.clear(),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          CupertinoIcons.clear_circled_solid,
                          size: 16,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Category Chips Bar
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip(
                  label: '全部 (${allCategorySites.length})',
                  isSelected: _selectedCategoryFilter == null,
                  onTap: () => setState(() => _selectedCategoryFilter = null),
                  isDark: isDark,
                ),
                _buildCategoryChip(
                  label: '⭐ 常用 (${allCategorySites.where((s) => favoriteKeys.contains(s.key)).length})',
                  isSelected: _selectedCategoryFilter == 'favorites',
                  onTap: () => setState(() => _selectedCategoryFilter = 'favorites'),
                  isDark: isDark,
                  activeColor: const Color(0xFFFFB300),
                ),
                if (!isImage) ...[
                  _buildCategoryChip(
                    label: '🌸 JAV (${allCategorySites.where((s) => s.category == ResourceCategory.jav).length})',
                    isSelected: _selectedCategoryFilter == ResourceCategory.jav,
                    onTap: () => setState(() => _selectedCategoryFilter = ResourceCategory.jav),
                    isDark: isDark,
                  ),
                  _buildCategoryChip(
                    label: '✨ 动漫3D (${allCategorySites.where((s) => s.category == ResourceCategory.anime).length})',
                    isSelected: _selectedCategoryFilter == ResourceCategory.anime,
                    onTap: () => setState(() => _selectedCategoryFilter = ResourceCategory.anime),
                    isDark: isDark,
                  ),
                  _buildCategoryChip(
                    label: '🎬 综合影视 (${allCategorySites.where((s) => s.category == ResourceCategory.video).length})',
                    isSelected: _selectedCategoryFilter == ResourceCategory.video,
                    onTap: () => setState(() => _selectedCategoryFilter = ResourceCategory.video),
                    isDark: isDark,
                  ),
                  _buildCategoryChip(
                    label: '💎 创作者 (${allCategorySites.where((s) => s.category == ResourceCategory.creator).length})',
                    isSelected: _selectedCategoryFilter == ResourceCategory.creator,
                    onTap: () => setState(() => _selectedCategoryFilter = ResourceCategory.creator),
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Grid Content
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.search,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '未找到匹配的站点',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 650 ? 3 : 2;
                      return GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16, 4, 16, 20 + bottomInset),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.38,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final site = filtered[index];
                          final isCurrent = site.key == widget.currentSiteKey;
                          final isFav = favoriteKeys.contains(site.key);
                          final isHidden = hiddenKeys.contains(site.key);

                          return _buildSiteCard(
                            site: site,
                            isCurrent: isCurrent,
                            isFav: isFav,
                            isHidden: isHidden,
                            isDark: isDark,
                            settingsProv: settingsProv,
                          );
                        },
                      );
                    },
                  ),
          ),

          // Bottom Quick Bar: Settings link + Browsing History link
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0x18FFFFFF) : const Color(0x10000000),
                  width: 0.6,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ResourceOrderSettingPage.open(context);
                      },
                      icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 14),
                      label: const Text(
                        '站点显示与排序',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.black87,
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        BrowsingHistoryPage.open(context);
                      },
                      icon: const Icon(CupertinoIcons.clock_fill, size: 14),
                      label: const Text(
                        '浏览历史',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IosTheme.primaryPink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    Color? activeColor,
  }) {
    final color = activeColor ?? IosTheme.primaryPink;

    return BouncingButton(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? const Color(0x1FFFFFFF) : const Color(0x10000000)),
            width: 0.6,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildSiteCard({
    required ResourceSiteItem site,
    required bool isCurrent,
    required bool isFav,
    required bool isHidden,
    required bool isDark,
    required SettingsProvider settingsProv,
  }) {
    return BouncingButton(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onSelectSite(site.key);
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? (isCurrent ? site.color.withValues(alpha: 0.16) : const Color(0xFF1E1E22))
              : (isCurrent ? site.color.withValues(alpha: 0.1) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent
                ? site.color.withValues(alpha: 0.8)
                : (isDark ? const Color(0x1FFFFFFF) : const Color(0x12000000)),
            width: isCurrent ? 1.6 : 0.6,
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: site.color.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Category Badge + Favorite Star
            Row(
              children: [
                // Site Icon with colored background
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: site.color.withValues(alpha: isDark ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: site.color.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    site.icon,
                    size: 16,
                    color: site.color,
                  ),
                ),
                const SizedBox(width: 8),

                // Category tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: site.category.color.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    site.category.label,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: site.category.color,
                    ),
                  ),
                ),

                const Spacer(),

                // Star Favorite Button
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    settingsProv.toggleFavoriteResourceSite(site.key);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      isFav ? CupertinoIcons.star_fill : CupertinoIcons.star,
                      size: 17,
                      color: isFav
                          ? const Color(0xFFFFB300)
                          : (isDark ? Colors.white24 : Colors.black26),
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Site Label + Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    site.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (isCurrent)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: site.color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '浏览中',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),

            // Site Description
            Text(
              site.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
