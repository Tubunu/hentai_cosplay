import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/iwara_category.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/iwara_browse_provider.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'iwara_detail_page.dart';
import 'widgets/iwara_video_card.dart';

class IwaraBrowsePage extends StatefulWidget {
  const IwaraBrowsePage({super.key});

  @override
  State<IwaraBrowsePage> createState() => _IwaraBrowsePageState();
}

class _IwaraBrowsePageState extends State<IwaraBrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<IwaraBrowseProvider>();
      if (prov.items.isEmpty) {
        prov.loadPage(1);
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
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _showJumpPageDialog(BuildContext context, IwaraBrowseProvider provider) {
    int selected = provider.currentPage;
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        const themeColor = Color(0xFF00A8FF);
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
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                provider.loadPage(selected);
                _scrollToTop();
              },
              child: const Text('跳转', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IwaraBrowseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFF00A8FF);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: themeColor,
              edgeOffset: 58.0,
              displacement: 40.0,
              onRefresh: () async {
                await provider.loadPage(1);
                HapticFeedback.lightImpact();
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // 1. Top Safe Spacing for Floating Segmented Capsule Bar (54px)
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 54),
                  ),

                  // 2. Search Bar & Actions
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                                  width: 0.5,
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(fontSize: 13.5),
                                textInputAction: TextInputAction.search,
                                onSubmitted: (val) {
                                  if (val.trim().isNotEmpty) {
                                    provider.setSearchKeyword(val.trim());
                                    _scrollToTop();
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: '搜索 3D 动画、MMD、角色、作者...',
                                  hintStyle: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                  prefixIcon: const Icon(CupertinoIcons.search, size: 18, color: themeColor),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16, color: Colors.grey),
                                          onPressed: () {
                                            _searchController.clear();
                                            provider.resetToLatest();
                                            _scrollToTop();
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 全库随机 Button
                          RandomActionButton.video(
                            videoSite: VideoSiteType.iwara,
                            isCapsule: true,
                            color: themeColor,
                          ),
                          const SizedBox(width: 8),

                          // 多选 Toggle Button
                          BouncingButton(
                            onTap: () => provider.toggleSelectionMode(),
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
                                    provider.isSelectionMode ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.checkmark_circle,
                                    size: 16,
                                    color: provider.isSelectionMode ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    provider.isSelectionMode ? '取消' : '多选',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: provider.isSelectionMode ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
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

                  // 3. Category Chips Selector
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: IwaraCategory.values.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = IwaraCategory.values[index];
                          final isSelected = !provider.isSearchActive &&
                              !provider.isTagActive &&
                              !provider.isUserActive &&
                              provider.category == cat;

                          return BouncingButton(
                            onTap: () {
                              _searchController.clear();
                              provider.setCategory(cat);
                              _scrollToTop();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? const LinearGradient(
                                        colors: [Color(0xFF00A8FF), Color(0xFF0055FF)],
                                      )
                                    : null,
                                color: isSelected
                                    ? null
                                    : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : (isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
                                  width: 0.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: themeColor.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  cat.label,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : const Color(0xFF3A3A3C)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // 4. Active Filter Indicator
                  if (provider.isSearchActive || provider.isTagActive || provider.isUserActive)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 0.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.slider_horizontal_3, size: 14, color: themeColor),
                              const SizedBox(width: 6),
                              Text(
                                provider.isSearchActive
                                    ? '搜索: "${provider.searchKeyword}"'
                                    : (provider.isTagActive
                                        ? '标签: #${provider.selectedTag}'
                                        : '作者: ${provider.selectedUserId}'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: themeColor),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  provider.resetToLatest();
                                  _scrollToTop();
                                },
                                child: const Text('重置全部', style: TextStyle(fontSize: 11, color: themeColor)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // 5. Main Video Content Sliver
                  if (provider.isLoading && provider.items.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CupertinoActivityIndicator(radius: 16)),
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
                            Text(
                              provider.errorMessage!,
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => provider.loadPage(1),
                              child: const Text('重试', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.76,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = provider.items[index];
                            return IwaraVideoCard(
                              item: item,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (_) => IwaraDetailPage(item: item),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: provider.items.length,
                        ),
                      ),
                    ),

                  // 6. Pagination Bar
                  if (provider.items.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(CupertinoIcons.chevron_left_2),
                              onPressed: provider.currentPage > 1
                                  ? () {
                                      provider.loadPage(provider.currentPage - 1);
                                      _scrollToTop();
                                    }
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            BouncingButton(
                              onTap: () => _showJumpPageDialog(context, provider),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  '第 ${provider.currentPage} / ${provider.totalPages > 0 ? provider.totalPages : 1} 页',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(CupertinoIcons.chevron_right_2),
                              onPressed: provider.currentPage < provider.totalPages
                                  ? () {
                                      provider.loadPage(provider.currentPage + 1);
                                      _scrollToTop();
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Floating Multi-Selection Action Bar
            if (provider.isSelectionMode)
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        '已选 ${provider.selectedCount} 项',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => provider.selectAll(),
                        child: const Text('全选', style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: provider.selectedCount > 0
                            ? () {
                                final sel = provider.selectedItems;
                                final dl = context.read<DownloadProvider>();
                                for (final it in sel) {
                                  dl.addVideoTask(it);
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('已将 ${sel.length} 个视频加入下载队列'),
                                    backgroundColor: themeColor,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                provider.clearSelection();
                              }
                            : null,
                        child: const Text('批量下载', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            // Scroll To Top Button
            ScrollToTopButton(
              scrollController: _scrollController,
              color: themeColor,
            ),
          ],
        ),
      ),
    );
  }
}
