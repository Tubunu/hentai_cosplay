import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/hanime1_category.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/hanime1_browse_provider.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'hanime1_detail_page.dart';
import 'widgets/hanime1_video_card.dart';

class Hanime1BrowsePage extends StatefulWidget {
  const Hanime1BrowsePage({super.key});

  @override
  State<Hanime1BrowsePage> createState() => _Hanime1BrowsePageState();
}

class _Hanime1BrowsePageState extends State<Hanime1BrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prov = context.read<Hanime1BrowseProvider>();
      if (prov.items.isEmpty && !prov.isLoading && prov.errorMessage == null) {
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

  void _showJumpPageDialog(BuildContext context, Hanime1BrowseProvider provider) {
    int selected = provider.currentPage;
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        const themeColor = Color(0xFFFF2E63);
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
    final provider = context.watch<Hanime1BrowseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFFFF2E63);

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

                  // 2. Search Bar & Actions (Scrolls WITH the page)
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
                                  hintText: '搜索动漫番剧、标签、CV、制作方...',
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
                            videoSite: VideoSiteType.hanime1,
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

                  // 3. Category Chips Selector (Scrolls WITH the page)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: Hanime1Category.values.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = Hanime1Category.values[index];
                          final isSelected = !provider.isSearchActive &&
                              !provider.isTagActive &&
                              !provider.isBroadcasterActive &&
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
                                        colors: [Color(0xFFFF2E63), Color(0xFFFF5722)],
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

                  // 4. Active Filter Indicator (Tag or Broadcaster or Search)
                  if (provider.isSearchActive || provider.isTagActive || provider.isBroadcasterActive)
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
                                        : '制作方: @${provider.selectedBroadcaster}'),
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
                            const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.amber, size: 40),
                            const SizedBox(height: 10),
                            Text(provider.errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => provider.loadPage(provider.currentPage),
                              style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                              child: const Text('重试加载', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (provider.items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          '暂无动漫视频',
                          style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = provider.items[index];
                            return Hanime1VideoCard(
                              item: item,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Hanime1DetailPage(item: item),
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
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Prev Button
                            BouncingButton(
                              onTap: provider.currentPage > 1 && !provider.isLoading
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
                              onTap: provider.currentPage < provider.totalPages && !provider.isLoading
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

                  // Bottom safe spacer for floating bottom navigation bar
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 220 : 140,
                    ),
                  ),
                ],
              ),
            ),

            // Floating Scroll to Top Button
            ScrollToTopButton(
              scrollController: _scrollController,
              color: themeColor,
            ),

            // Multi-select Bottom Action Bar
            if (provider.isSelectionMode)
              Positioned(
                bottom: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 145 : 85,
                left: 16,
                right: 16,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: isDark ? const Color(0x33FFFFFF) : const Color(0x22000000),
                    ),
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: provider.selectedCount == provider.items.length
                            ? provider.clearSelection
                            : provider.selectAll,
                        child: Text(
                          provider.selectedCount == provider.items.length ? '全不选' : '全选',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '已选 ${provider.selectedCount} 部',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: const Icon(CupertinoIcons.arrow_down_to_line, size: 16, color: Colors.white),
                        label: const Text('下载所选', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: provider.selectedCount > 0
                            ? () {
                                final selected = provider.selectedItems;
                                final downloadProv = context.read<DownloadProvider>();
                                for (final it in selected) {
                                  downloadProv.addVideoTask(it);
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('已将 ${selected.length} 部动漫加入下载队列'),
                                    backgroundColor: themeColor,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                provider.toggleSelectionMode();
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
    );
  }
}
