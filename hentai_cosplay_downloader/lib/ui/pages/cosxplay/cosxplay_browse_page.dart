import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/cosxplay_browse_provider.dart';
import '../../../providers/download_provider.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/jump_page_dialog.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'cosxplay_detail_page.dart';
import 'widgets/cosxplay_video_card.dart';

class CosxplayBrowsePage extends StatefulWidget {
  const CosxplayBrowsePage({super.key});

  @override
  State<CosxplayBrowsePage> createState() => _CosxplayBrowsePageState();
}

class _CosxplayBrowsePageState extends State<CosxplayBrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CosxplayBrowseProvider>();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<CosxplayBrowseProvider>();
    const themeColor = Color(0xFFE91E63);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF7F8FA),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: themeColor,
              edgeOffset: 58.0,
              displacement: 40.0,
              onRefresh: () async {
                await provider.loadPage(provider.currentPage);
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Top Safe Spacing for Floating Segmented Capsule Bar
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 54),
                  ),

                  // Top Search Bar and Actions
                  SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: Column(
                      children: [
                        // Search Box
                        Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: isDark ? const Color(0x22FFFFFF) : const Color(0x15000000),
                              width: 0.8,
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: '搜索 CosXPlay 视频 (如 原神、2B、Nikke)...',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              prefixIcon: const Icon(CupertinoIcons.search, size: 16, color: themeColor),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_searchController.text.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                        provider.clearSearch();
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Icon(CupertinoIcons.clear_circled_solid, size: 16, color: Colors.grey),
                                      ),
                                    ),
                                  GestureDetector(
                                    onTap: () {
                                      if (_searchController.text.trim().isNotEmpty) {
                                        provider.search(_searchController.text);
                                        _scrollToTop();
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: themeColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '搜索',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onSubmitted: (val) {
                              provider.search(val);
                              _scrollToTop();
                            },
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Action Toolbar (全库随机 / 多选)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              // 全库随机 Button
                              RandomActionButton.video(
                                videoSite: VideoSiteType.cosxplay,
                                isCapsule: true,
                                color: themeColor,
                              ),
                              const SizedBox(width: 8),

                              // 多选模式 Button
                              BouncingButton(
                                onTap: () {
                                  provider.setSelectionMode(!provider.isSelectionMode);
                                },
                                child: Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: provider.isSelectionMode
                                        ? themeColor
                                        : themeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: themeColor.withValues(alpha: 0.3),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        provider.isSelectionMode
                                            ? CupertinoIcons.checkmark_circle_fill
                                            : CupertinoIcons.checkmark_circle,
                                        size: 16,
                                        color: provider.isSelectionMode ? Colors.white : themeColor,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        provider.isSelectionMode
                                            ? '已选 ${provider.selectedCount} 项'
                                            : '批量下载',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: provider.isSelectionMode ? Colors.white : themeColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Active Filter Banner
                if (provider.hasActiveFilter)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 0.6),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.search, size: 14, color: themeColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              provider.isSearchMode
                                  ? '搜索: "${provider.searchKeyword}"'
                                  : (provider.tagSlug != null
                                      ? '标签: "${provider.tagSlug}"'
                                      : '模特: "${provider.actorSlug}"'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: themeColor,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              provider.clearFilter();
                            },
                            child: const Text(
                              '清除',
                              style: TextStyle(fontSize: 12, color: themeColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Inline Multi-Selection Header (Never blocked)
                if (provider.isSelectionMode)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: themeColor.withValues(alpha: 0.35), width: 0.8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '已选 ${provider.selectedCount} 项',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: themeColor),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: provider.selectedCount == provider.items.length
                                ? provider.deselectAll
                                : provider.selectAll,
                            child: Text(
                              provider.selectedCount == provider.items.length ? '取消全选' : '全选本页',
                              style: const TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton.icon(
                            icon: const Icon(CupertinoIcons.cloud_download, size: 14),
                            label: const Text('下载选中', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: provider.selectedCount > 0
                                ? () {
                                    final selected = provider.selectedItems;
                                    final downloadProv = context.read<DownloadProvider>();
                                    for (final it in selected) {
                                      downloadProv.addAlbumTask(it.toAlbumItem());
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('已添加 ${selected.length} 个视频到下载队列'),
                                        backgroundColor: themeColor,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    provider.setSelectionMode(false);
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Content State Handling
                if (provider.isLoading && provider.items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CupertinoActivityIndicator(radius: 16),
                    ),
                  )
                else if (provider.errorMessage != null && provider.items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: Colors.orangeAccent),
                            const SizedBox(height: 12),
                            Text(
                              provider.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(CupertinoIcons.refresh, size: 16),
                              label: const Text('重试'),
                              style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white),
                              onPressed: () => provider.loadPage(provider.currentPage),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (provider.items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('暂无相关视频', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  // Video Grid
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.82,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = provider.items[index];
                          return CosxplayVideoCard(
                            item: item,
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => CosxplayDetailPage(item: item),
                                ),
                              );
                            },
                          );
                        },
                        childCount: provider.items.length,
                      ),
                    ),
                  ),

                // Pagination Controls
                if (provider.items.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Previous Page
                          BouncingButton(
                            onTap: provider.currentPage > 1 && !provider.isLoading
                                ? () {
                                    provider.loadPage(provider.currentPage - 1);
                                    _scrollToTop();
                                  }
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
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

                          // Page Indicator (Jump Dialog)
                          BouncingButton(
                            onTap: () {
                              JumpPageDialog.show(
                                context,
                                currentPage: provider.currentPage,
                                totalPages: provider.totalPages,
                                themeColor: themeColor,
                                onPageSelected: (p) {
                                  provider.loadPage(p);
                                  _scrollToTop();
                                },
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${provider.currentPage} / ${provider.totalPages} 页',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: themeColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Next Page
                          BouncingButton(
                            onTap: provider.currentPage < provider.totalPages && !provider.isLoading
                                ? () {
                                    provider.loadPage(provider.currentPage + 1);
                                    _scrollToTop();
                                  }
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
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

                // Safe spacer for floating navigation bar
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 220 : 140,
                  ),
                ),
              ],
            ),
          ),

          // Selection Mode Floating Action Bar
          if (provider.isSelectionMode)
            Positioned(
              bottom: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 140 : 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? const Color(0x33FFFFFF) : const Color(0x18000000),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '已选择 ${provider.selectedCount} 项',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: provider.selectedCount == provider.items.length
                          ? provider.deselectAll
                          : provider.selectAll,
                      child: Text(
                        provider.selectedCount == provider.items.length ? '取消全选' : '全选',
                        style: const TextStyle(color: themeColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(CupertinoIcons.cloud_download, size: 16),
                      label: const Text('下载选中'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: provider.selectedCount > 0
                          ? () {
                              final selected = provider.selectedItems;
                              final downloadProv = context.read<DownloadProvider>();
                              for (final it in selected) {
                                downloadProv.addAlbumTask(it.toAlbumItem());
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('已添加 ${selected.length} 个视频到下载队列'),
                                  backgroundColor: themeColor,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              provider.setSelectionMode(false);
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),

          ScrollToTopButton(scrollController: _scrollController),
        ],
      ),
    ),
  );
  }
}
