import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../site_registry.dart';
import '../../../providers/settings_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';

class ResourceOrderSettingPage extends StatefulWidget {
  const ResourceOrderSettingPage({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => const ResourceOrderSettingPage(),
      ),
    );
  }

  @override
  State<ResourceOrderSettingPage> createState() => _ResourceOrderSettingPageState();
}

class _ResourceOrderSettingPageState extends State<ResourceOrderSettingPage> {
  late List<String> _currentOrderKeys;
  ResourceMediaType _selectedMediaType = ResourceMediaType.image;
  ResourceCategory? _categoryFilter;

  @override
  void initState() {
    super.initState();
    final settingsProv = context.read<SettingsProvider>();
    _currentOrderKeys = List.from(
      ResourceSiteRegistry.getAllOrderedSites(settingsProv.config.onlineResourceSortOrder)
          .map((s) => s.key),
    );
  }

  void _onReorder(List<String> visibleKeys, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    final movingKey = visibleKeys[oldIndex];
    final targetKey = visibleKeys[newIndex];

    setState(() {
      final actualOld = _currentOrderKeys.indexOf(movingKey);
      _currentOrderKeys.removeAt(actualOld);
      final actualNew = _currentOrderKeys.indexOf(targetKey);
      _currentOrderKeys.insert(newIndex > oldIndex ? actualNew + 1 : actualNew, movingKey);
    });

    HapticFeedback.mediumImpact();
    context.read<SettingsProvider>().updateOnlineResourceSortOrder(_currentOrderKeys);
  }

  void _showResetDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('恢复默认设置'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text('确定要将【在线图片】与【在线视频】所有站点的排序与显示状态重置为官方默认吗？所有隐藏站点都将重新显示。'),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: false,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentOrderKeys = List.from(ResourceSiteRegistry.defaultOrder);
              });
              context.read<SettingsProvider>().resetOnlineResourceOrderAndVisibility();
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已恢复默认站点排序与全部显示'),
                  backgroundColor: IosTheme.primaryPink,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(milliseconds: 1500),
                ),
              );
            },
            child: const Text('恢复默认'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsProv = context.watch<SettingsProvider>();
    final hiddenKeys = settingsProv.config.hiddenResourceSites.toSet();

    // Pull ordered site items matching the current media type
    final mediaTypeSites = _currentOrderKeys
        .map((k) => ResourceSiteRegistry.allSites[k])
        .whereType<ResourceSiteItem>()
        .where((s) => s.mediaType == _selectedMediaType)
        .toList();

    // Further filtered by category if selected
    final displayedSites = mediaTypeSites.where((s) {
      if (_categoryFilter != null && s.category != _categoryFilter) {
        return false;
      }
      return true;
    }).toList();

    final displayedKeys = displayedSites.map((s) => s.key).toList();

    final visibleCount = mediaTypeSites.where((s) => !hiddenKeys.contains(s.key)).length;
    final hiddenCount = mediaTypeSites.length - visibleCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '站点排序与显示管理',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          TextButton.icon(
            onPressed: _showResetDialog,
            icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 15),
            label: const Text('恢复默认', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Media Type Segmented Control (图片 11 | 视频 24)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CupertinoSlidingSegmentedControl<ResourceMediaType>(
              groupValue: _selectedMediaType,
              thumbColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
              children: {
                ResourceMediaType.image: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.photo_on_rectangle,
                        size: 15,
                        color: _selectedMediaType == ResourceMediaType.image
                            ? IosTheme.primaryPink
                            : (isDark ? Colors.white60 : Colors.black54),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '图片站点 (11)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selectedMediaType == ResourceMediaType.image
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _selectedMediaType == ResourceMediaType.image
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
                ResourceMediaType.video: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.play_rectangle_fill,
                        size: 15,
                        color: _selectedMediaType == ResourceMediaType.video
                            ? IosTheme.primaryPink
                            : (isDark ? Colors.white60 : Colors.black54),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '视频站点 (24)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selectedMediaType == ResourceMediaType.video
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _selectedMediaType == ResourceMediaType.video
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              },
              onValueChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedMediaType = val;
                    _categoryFilter = null; // reset subcategory filter
                  });
                  HapticFeedback.selectionClick();
                }
              },
            ),
          ),

          // 2. Subcategory Filter Chips (for video: JAV, Anime, Video, Creator)
          if (_selectedMediaType == ResourceMediaType.video)
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildFilterChip(
                    label: '全部 (24)',
                    isSelected: _categoryFilter == null,
                    onTap: () => setState(() => _categoryFilter = null),
                    isDark: isDark,
                  ),
                  _buildFilterChip(
                    label: '🌸 日本 JAV (6)',
                    isSelected: _categoryFilter == ResourceCategory.jav,
                    onTap: () => setState(() => _categoryFilter = ResourceCategory.jav),
                    isDark: isDark,
                  ),
                  _buildFilterChip(
                    label: '✨ 动漫 3D (3)',
                    isSelected: _categoryFilter == ResourceCategory.anime,
                    onTap: () => setState(() => _categoryFilter = ResourceCategory.anime),
                    isDark: isDark,
                  ),
                  _buildFilterChip(
                    label: '🎬 综合影视 (13)',
                    isSelected: _categoryFilter == ResourceCategory.video,
                    onTap: () => setState(() => _categoryFilter = ResourceCategory.video),
                    isDark: isDark,
                  ),
                  _buildFilterChip(
                    label: '💎 创作者 (2)',
                    isSelected: _categoryFilter == ResourceCategory.creator,
                    onTap: () => setState(() => _categoryFilter = ResourceCategory.creator),
                    isDark: isDark,
                  ),
                ],
              ),
            ),

          // 3. Header description banner & quick action row
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      CupertinoIcons.slider_horizontal_3,
                      size: 18,
                      color: IosTheme.primaryPink.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '上下拖拽右侧把手可自定义排列顺序；点击眼睛图标可显示或隐藏站点。隐藏后不会出现在顶栏胶囊中。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Count Pill & Category Batch Actions
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '当前专区显示 $visibleCount · 隐藏 $hiddenCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Category batch hide / show actions
                    if (_categoryFilter != null) ...[
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          final catKeys = displayedSites.map((s) => s.key).toList();
                          settingsProv.batchSetCategoryVisibility(catKeys, true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已显示【${_categoryFilter!.label}】下的全部站点'),
                              backgroundColor: IosTheme.primaryPink,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(milliseconds: 1200),
                            ),
                          );
                        },
                        child: Text(
                          '全部显示此类',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: IosTheme.primaryPink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          final catKeys = displayedSites.map((s) => s.key).toList();
                          settingsProv.batchSetCategoryVisibility(catKeys, false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已隐藏【${_categoryFilter!.label}】下的全部站点'),
                              backgroundColor: Colors.orangeAccent,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(milliseconds: 1200),
                            ),
                          );
                        },
                        child: Text(
                          '一键隐藏此类',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ),
                    ] else if (hiddenCount > 0) ...[
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          final allKeys = mediaTypeSites.map((s) => s.key).toList();
                          settingsProv.batchSetCategoryVisibility(allKeys, true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已取消当前专区所有站点的隐藏'),
                              backgroundColor: IosTheme.primaryPink,
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(milliseconds: 1200),
                            ),
                          );
                        },
                        child: const Text(
                          '全部显示',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: IosTheme.primaryPink,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 4. Reorderable list of sites
          Expanded(
            child: ReorderableListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              itemCount: displayedSites.length,
              // ignore: deprecated_member_use
              onReorder: (oldIndex, newIndex) => _onReorder(displayedKeys, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final site = displayedSites[index];
                final rank = index + 1;
                final isHidden = hiddenKeys.contains(site.key);

                return AnimatedOpacity(
                  key: ValueKey(site.key),
                  duration: const Duration(milliseconds: 200),
                  opacity: isHidden ? 0.55 : 1.0,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? (isHidden ? const Color(0xFF151517) : const Color(0xFF1C1C1E))
                          : (isHidden ? const Color(0xFFF9F9FB) : Colors.white),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? (isHidden ? const Color(0x11FFFFFF) : const Color(0x22FFFFFF))
                            : (isHidden ? const Color(0x0C000000) : const Color(0x18000000)),
                        width: 0.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Rank badge
                          Container(
                            width: 22,
                            alignment: Alignment.center,
                            child: Text(
                              '$rank',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isHidden
                                    ? (isDark ? Colors.white24 : Colors.black26)
                                    : (rank <= 3
                                        ? IosTheme.primaryPink
                                        : (isDark ? Colors.white38 : Colors.black38)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Site Icon Badge
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isHidden
                                  ? (isDark ? Colors.white10 : Colors.black12)
                                  : site.color.withValues(alpha: isDark ? 0.22 : 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isHidden
                                    ? Colors.transparent
                                    : site.color.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Icon(
                              site.icon,
                              color: isHidden
                                  ? (isDark ? Colors.white38 : Colors.black38)
                                  : site.color,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              site.label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isHidden
                                    ? (isDark ? Colors.white54 : Colors.black45)
                                    : (isDark ? Colors.white : Colors.black87),
                                decoration: isHidden ? TextDecoration.lineThrough : null,
                                decorationColor: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Category tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: site.category.color.withValues(alpha: isDark ? 0.18 : 0.12),
                              borderRadius: BorderRadius.circular(4),
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
                          if (isHidden) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '已隐藏',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        site.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Visibility Toggle Eye Button
                          IconButton(
                            tooltip: isHidden ? '点击显示' : '点击隐藏',
                            icon: Icon(
                              isHidden ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
                              size: 19,
                              color: isHidden
                                  ? (isDark ? Colors.white24 : Colors.black26)
                                  : IosTheme.primaryPink,
                            ),
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              final success = await settingsProv.toggleHideResourceSite(
                                site.key,
                                totalSitesCount: _currentOrderKeys.length,
                              );
                              if (!success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('至少需要保留一个可见站点'),
                                    backgroundColor: Colors.orangeAccent,
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(milliseconds: 1500),
                                  ),
                                );
                              }
                            },
                          ),

                          // Drag Reorder Handle
                          ReorderableDragStartListener(
                            index: index,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              child: Icon(
                                CupertinoIcons.bars,
                                color: isDark ? Colors.white38 : Colors.black38,
                                size: 19,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return BouncingButton(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? IosTheme.primaryPink
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? IosTheme.primaryPink
                : (isDark ? const Color(0x1FFFFFFF) : const Color(0x10000000)),
            width: 0.6,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
