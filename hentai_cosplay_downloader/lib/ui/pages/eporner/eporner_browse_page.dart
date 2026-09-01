import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/eporner_browse_provider.dart';
import '../../../services/eporner/eporner_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'eporner_detail_page.dart';
import 'widgets/eporner_video_card.dart';

class EpornerBrowsePage extends StatefulWidget {
  const EpornerBrowsePage({super.key});

  @override
  State<EpornerBrowsePage> createState() => _EpornerBrowsePageState();
}

class _EpornerBrowsePageState extends State<EpornerBrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prov = context.read<EpornerBrowseProvider>();
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

  void _showJumpPageDialog(BuildContext context, EpornerBrowseProvider provider) {
    int selected = provider.currentPage;
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        const themeColor = Color(0xFFE91E63);
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
    final provider = context.watch<EpornerBrowseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFFE91E63);

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
                await provider.refresh();
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

                  // 2. Search Bar & Toolbar Actions (Scrolls WITH the page)
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
                                  provider.search(val);
                                  _scrollToTop();
                                },
                                decoration: InputDecoration(
                                  hintText: '搜索 EPorner 4K/VR/超清视频...',
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
                                            provider.clearSearch();
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
                            videoSite: VideoSiteType.eporner,
                            isCapsule: true,
                            color: themeColor,
                          ),
                          const SizedBox(width: 8),

                          // 多选 Toggle Button
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

                  // 3. Category Chips Bar (Scrolls WITH the page)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: EpornerCategory.values.map((cat) {
                          final isSelected = !provider.isSearchMode && provider.currentCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: BouncingButton(
                              onTap: () {
                                _searchController.clear();
                                provider.switchCategory(cat);
                                _scrollToTop();
                              },
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
                                  cat.label,
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
                        }).toList(),
                      ),
                    ),
                  ),

                  // 4. Multi-Selection Action Header (Scrolls WITH the page)
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
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: provider.selectedCount == 0
                                  ? null
                                  : () {
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
                              child: const Text('下载选中', style: TextStyle(fontSize: 12, color: Colors.white)),
                            ),
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
                            Text(provider.errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: provider.refresh,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = provider.items[index];
                            return EpornerVideoCard(
                              item: item,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EpornerDetailPage(item: item),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: provider.items.length,
                        ),
                      ),
                    ),

                  // 6. Bottom Pagination Controls
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
          ],
        ),
      ),
    );
  }
}
