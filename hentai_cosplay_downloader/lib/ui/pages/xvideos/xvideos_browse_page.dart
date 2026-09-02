import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/download_provider.dart';
import '../../../providers/xvideos_browse_provider.dart';
import '../../../services/xvideos/xvideos_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'widgets/xvideos_video_card.dart';
import 'xvideos_detail_page.dart';

class XVideosBrowsePage extends StatefulWidget {
  const XVideosBrowsePage({super.key});

  @override
  State<XVideosBrowsePage> createState() => _XVideosBrowsePageState();
}

class _XVideosBrowsePageState extends State<XVideosBrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<XVideosBrowseProvider>();
      if (provider.items.isEmpty && !provider.isLoading) {
        provider.loadPage(1);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showCategoryPicker(BuildContext context, XVideosBrowseProvider provider) {
    String filterText = '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFFE50914);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCategories = XVideosApiService.defaultCategories.where((cat) {
              if (filterText.isEmpty) return true;
              return cat.name.toLowerCase().contains(filterText.toLowerCase()) ||
                  cat.path.toLowerCase().contains(filterText.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Modal Handle & Header
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.square_grid_2x2, color: themeColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '选择 XVideos 分类',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 22, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Search filter input inside category picker
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        style: const TextStyle(fontSize: 13),
                        onChanged: (val) {
                          setModalState(() {
                            filterText = val.trim();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: '筛选分类，例如: 亚洲、Cosplay、巨乳...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          prefixIcon: const Icon(CupertinoIcons.search, size: 16, color: themeColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Categories Grid
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.8,
                      ),
                      itemCount: filteredCategories.length,
                      itemBuilder: (context, index) {
                        final cat = filteredCategories[index];
                        final isSelected = provider.currentCategory.id == cat.id && !provider.isSearchMode;

                        return BouncingButton(
                          onTap: () {
                            Navigator.pop(ctx);
                            _searchController.clear();
                            provider.switchCategory(cat);
                            _scrollToTop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? themeColor
                                  : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? themeColor
                                    : (isDark ? const Color(0x18FFFFFF) : const Color(0x12000000)),
                                width: isSelected ? 1.5 : 0.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: themeColor.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                if (cat.icon != null) ...[
                                  Text(cat.icon!, style: const TextStyle(fontSize: 15)),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    cat.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(CupertinoIcons.checkmark_alt, size: 14, color: Colors.white),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMonthPicker(BuildContext context, XVideosBrowseProvider provider) {
    final months = XVideosApiService.getAvailableBestMonths(count: 36);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFFE50914);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Modal Handle & Header
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.calendar, color: themeColor, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      '选择最佳影片月份',
                      style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 22, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: months.length,
                  itemBuilder: (context, index) {
                    final month = months[index];
                    final isSelected = provider.selectedMonth == month && provider.mainMode == XVideosMainMode.best;
                    return BouncingButton(
                      onTap: () {
                        Navigator.pop(ctx);
                        provider.switchMonth(month);
                        _scrollToTop();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? themeColor
                              : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? themeColor
                                : (isDark ? const Color(0x18FFFFFF) : const Color(0x12000000)),
                            width: isSelected ? 1.5 : 0.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: themeColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          month,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white : Colors.black87),
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
      },
    );
  }

  void _showJumpPageDialog(BuildContext context, XVideosBrowseProvider provider) {
    int selected = provider.currentPage;
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        const themeColor = Color(0xFFE50914);
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('跳转页码', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          content: SizedBox(
            height: 150,
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(initialItem: provider.currentPage - 1),
              onSelectedItemChanged: (index) {
                selected = index + 1;
              },
              children: List.generate(
                provider.totalPages > 0 ? provider.totalPages : 50,
                (index) => Center(child: Text('第 ${index + 1} 页')),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                provider.loadPage(selected, clearItems: true);
                _scrollToTop();
              },
              child: const Text('确定', style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required Color themeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: BouncingButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? themeColor
                : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: isSelected
                  ? themeColor
                  : (isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<XVideosBrowseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFFE50914);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0E) : const Color(0xFFF6F7F9),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: themeColor,
              onRefresh: provider.refresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // 1. Top Safe Spacing for Floating Segmented Capsule Bar (54px)
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 54),
                  ),

                  // 2. Search Bar & Action Buttons
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? const Color(0x22FFFFFF) : const Color(0x15000000),
                                  width: 0.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Icon(CupertinoIcons.search, size: 16, color: themeColor),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: '在 XVideos 中搜索...',
                                        hintStyle: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      onSubmitted: (val) {
                                        provider.search(val);
                                        _scrollToTop();
                                      },
                                    ),
                                  ),
                                  if (_searchController.text.isNotEmpty || provider.isSearchMode)
                                    IconButton(
                                      icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16, color: Colors.grey),
                                      onPressed: () {
                                        _searchController.clear();
                                        provider.clearSearch();
                                        _scrollToTop();
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 🎲 Random Video Button
                          RandomActionButton.video(
                            videoSite: VideoSiteType.xvideos,
                            isCapsule: true,
                            color: themeColor,
                          ),
                          const SizedBox(width: 8),

                          // 📋 Multi-select Toggle Button
                          BouncingButton(
                            onTap: () => provider.setSelectionMode(!provider.isSelectionMode),
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: provider.isSelectionMode
                                    ? themeColor
                                    : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: provider.isSelectionMode
                                      ? themeColor
                                      : (isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    provider.isSelectionMode
                                        ? CupertinoIcons.checkmark_circle_fill
                                        : CupertinoIcons.checkmark_circle,
                                    size: 15,
                                    color: provider.isSelectionMode
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    provider.isSelectionMode ? '取消' : '多选',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: provider.isSelectionMode
                                          ? Colors.white
                                          : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Category Dropdown Button & Modes / SubSort Bar
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // 🏷️ Category Dropdown Button
                          BouncingButton(
                            onTap: () => _showCategoryPicker(context, provider),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: isDark ? 0.22 : 0.15),
                                borderRadius: BorderRadius.circular(19),
                                border: Border.all(
                                  color: themeColor.withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (provider.isSearchMode) ...[
                                    const Icon(CupertinoIcons.search, size: 12, color: themeColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      '搜索: ${provider.searchQuery}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: themeColor),
                                    ),
                                  ] else ...[
                                    if (provider.currentCategory.icon != null) ...[
                                      Text(provider.currentCategory.icon!, style: const TextStyle(fontSize: 12.5)),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      provider.currentCategory.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: themeColor,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 3),
                                  const Icon(CupertinoIcons.chevron_down, size: 11, color: themeColor),
                                ],
                              ),
                            ),
                          ),

                          // Case A: Browsing All Categories (Not Searching and Category is All)
                          if (!provider.isCategoryOrSearchActive) ...[
                            // 最新发布
                            _buildChip(
                              label: '最新发布',
                              isSelected: provider.mainMode == XVideosMainMode.latest,
                              themeColor: themeColor,
                              isDark: isDark,
                              onTap: () {
                                _searchController.clear();
                                provider.switchMainMode(XVideosMainMode.latest);
                                _scrollToTop();
                              },
                            ),
                            // 最佳影片
                            _buildChip(
                              label: '最佳影片',
                              isSelected: provider.mainMode == XVideosMainMode.best,
                              themeColor: themeColor,
                              isDark: isDark,
                              onTap: () {
                                _searchController.clear();
                                provider.switchMainMode(XVideosMainMode.best);
                                _scrollToTop();
                              },
                            ),
                            // If 最佳影片 is active -> Month Selector Button
                            if (provider.mainMode == XVideosMainMode.best) ...[
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: BouncingButton(
                                  onTap: () => _showMonthPicker(context, provider),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                                      borderRadius: BorderRadius.circular(19),
                                      border: Border.all(
                                        color: themeColor.withValues(alpha: 0.6),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(CupertinoIcons.calendar, size: 13, color: themeColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          provider.selectedMonth,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: themeColor,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(CupertinoIcons.chevron_down, size: 10, color: themeColor),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ] else ...[
                            // Case B: A specific Category is selected OR Search is active
                            // SubSort chips: 默认 (关闭), 最新, 评级, 观看次数, (随机 - Type 2/Search only)
                            ...XVideosSubSort.values.where((sort) {
                              if (sort == XVideosSubSort.random) {
                                return provider.isSearchMode || provider.currentCategory.type == XVideosCategoryType.searchTag;
                              }
                              return true;
                            }).map((sort) {
                              final isSelected = provider.subSort == sort;
                              return _buildChip(
                                label: sort.label,
                                isSelected: isSelected,
                                themeColor: themeColor,
                                isDark: isDark,
                                onTap: () {
                                  provider.switchSubSort(sort);
                                  _scrollToTop();
                                },
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // 4. Multi-Selection Action Header
                  if (provider.isSelectionMode)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '已选择 ${provider.selectedCount} 个视频',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: provider.selectAll,
                              child: const Text('全选', style: TextStyle(fontSize: 12, color: themeColor)),
                            ),
                            TextButton(
                              onPressed: provider.deselectAll,
                              child: const Text('清空', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ),
                            if (provider.selectedCount > 0) ...[
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  final selected = provider.selectedItems;
                                  final downloadProv = context.read<DownloadProvider>();
                                  for (final it in selected) {
                                    downloadProv.addVideoTask(it);
                                  }
                                  provider.setSelectionMode(false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('已批量添加 ${selected.length} 个视频至下载队列'),
                                      backgroundColor: themeColor,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: const Text('下载选中', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // 5. Content Grid
                  if (provider.isLoading && provider.items.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CupertinoActivityIndicator(radius: 14)),
                    )
                  else if (provider.errorMessage != null && provider.items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.exclamationmark_circle, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                provider.errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: provider.refresh,
                              icon: const Icon(CupertinoIcons.refresh, size: 15),
                              label: const Text('重试'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (provider.items.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text('暂无视频', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.76,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = provider.items[index];
                            return XVideosVideoCard(
                              item: item,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (_) => XVideosDetailPage(item: item),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: provider.items.length,
                        ),
                      ),
                    ),

                  // 6. Inline Bottom Pagination Bar
                  if (provider.items.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Prev Button
                            BouncingButton(
                              onTap: provider.currentPage > 1
                                  ? () {
                                      provider.prevPage();
                                      _scrollToTop();
                                    }
                                  : () {},
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: provider.currentPage > 1
                                      ? (isDark ? const Color(0xFF1C1C1E) : Colors.white)
                                      : (isDark ? Colors.black26 : Colors.black12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  '上一页',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: provider.currentPage > 1
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Jump Page Button
                            BouncingButton(
                              onTap: () => _showJumpPageDialog(context, provider),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: themeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 0.8),
                                ),
                                child: Text(
                                  '第 ${provider.currentPage} / ${provider.totalPages} 页',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: themeColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Next Button
                            BouncingButton(
                              onTap: provider.currentPage < provider.totalPages
                                  ? () {
                                      provider.nextPage();
                                      _scrollToTop();
                                    }
                                  : () {},
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: provider.currentPage < provider.totalPages
                                      ? (isDark ? const Color(0xFF1C1C1E) : Colors.white)
                                      : (isDark ? Colors.black26 : Colors.black12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  '下一页',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: provider.currentPage < provider.totalPages
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 7. Bottom Safe Margin for bottom nav bar & download bar
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 220 : 140,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 8. Floating Scroll to Top Button (Standard)
          ScrollToTopButton(
            scrollController: _scrollController,
            color: themeColor,
          ),
        ],
      ),
    );
  }
}
