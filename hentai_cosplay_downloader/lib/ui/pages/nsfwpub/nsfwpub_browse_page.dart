import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/nsfwpub_browse_provider.dart';
import '../../../services/nsfwpub/nsfwpub_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'nsfwpub_detail_page.dart';
import 'widgets/nsfwpub_album_card.dart';

class NsfwpubBrowsePage extends StatefulWidget {
  const NsfwpubBrowsePage({super.key});

  @override
  State<NsfwpubBrowsePage> createState() => _NsfwpubBrowsePageState();
}

class _NsfwpubBrowsePageState extends State<NsfwpubBrowsePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NsfwpubBrowseProvider>();
      if (provider.items.isEmpty) {
        provider.loadPage(1);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<NsfwpubBrowseProvider>();
    const themeColor = Color(0xFFD63384);

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

                  // Top Search Bar and Categories
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                      child: Column(
                        children: [
                          // Search Box Row
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                                      width: 0.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    textInputAction: TextInputAction.search,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '搜索 NSFWPub 模特、角色、关键词...',
                                      hintStyle: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white38 : Colors.black38,
                                      ),
                                      prefixIcon: const Icon(CupertinoIcons.search, size: 18, color: themeColor),
                                      suffixIcon: _searchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16, color: Colors.grey),
                                              onPressed: () {
                                                _searchController.clear();
                                                provider.search('');
                                              },
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                                    ),
                                    onSubmitted: (value) {
                                      provider.search(value);
                                      _scrollToTop();
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Random Discovery Action Button
                              RandomActionButton.album(
                                albumSource: MediaSourceType.nsfwpub,
                                isCapsule: true,
                                color: themeColor,
                              ),
                              const SizedBox(width: 8),

                              // Multi-select Toggle Button
                              BouncingButton(
                                onTap: () => provider.setSelectionMode(!provider.isSelectionMode),
                                child: Container(
                                  height: 42,
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
                                        size: 16,
                                        color: provider.isSelectionMode
                                            ? Colors.white
                                            : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        provider.isSelectionMode ? '取消' : '多选',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
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
                          const SizedBox(height: 10),

                          // Categories Horizontal Scroll List
                          SizedBox(
                            height: 36,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: NsfwpubCategory.values.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final cat = NsfwpubCategory.values[index];
                                final isSelected = provider.currentCategory == cat && provider.searchKeyword == null;
                                return BouncingButton(
                                  onTap: () {
                                    _searchController.clear();
                                    provider.switchCategory(cat);
                                    _scrollToTop();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? themeColor
                                          : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isSelected
                                            ? themeColor
                                            : (isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        cat.label,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected
                                              ? Colors.white
                                              : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Loading, Error, or Album Grid
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeColor,
                                  foregroundColor: Colors.white,
                                ),
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
                        child: Text('暂无相关图集', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    // Album Grid
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.68,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = provider.items[index];
                            return NsfwpubAlbumCard(
                              item: item,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NsfwpubDetailPage(item: item),
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
                                      provider.prevPage();
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
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.chevron_left,
                                      size: 14,
                                      color: provider.currentPage > 1 && !provider.isLoading
                                          ? themeColor
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '上一页',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: provider.currentPage > 1 && !provider.isLoading
                                            ? (isDark ? Colors.white : Colors.black87)
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Page Counter
                            Text(
                              '第 ${provider.currentPage} / ${provider.totalPages} 页',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Next Page
                            BouncingButton(
                              onTap: provider.currentPage < provider.totalPages && !provider.isLoading
                                  ? () {
                                      provider.nextPage();
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
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '下一页',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: provider.currentPage < provider.totalPages && !provider.isLoading
                                            ? (isDark ? Colors.white : Colors.black87)
                                            : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      CupertinoIcons.chevron_right,
                                      size: 14,
                                      color: provider.currentPage < provider.totalPages && !provider.isLoading
                                          ? themeColor
                                          : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Bottom padding
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 220 : 140,
                    ),
                  ),
                ],
              ),
            ),

            // Selection Floating Bar
            if (provider.isSelectionMode)
              Positioned(
                bottom: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 145 : 85,
                left: 20,
                right: 20,
                child: FrostedGlass(
                  borderRadius: 16,
                  blur: 16,
                  backgroundColor: (isDark ? const Color(0xFF1C1C1E) : Colors.white).withValues(alpha: 0.85),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          '已选择 ${provider.selectedCount} 个图集',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            if (provider.selectedCount == provider.items.length) {
                              provider.deselectAll();
                            } else {
                              provider.selectAll();
                            }
                          },
                          child: Text(
                            provider.selectedCount == provider.items.length ? '取消全选' : '全选',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(CupertinoIcons.cloud_download, size: 14),
                          label: const Text('批量下载', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: provider.selectedCount > 0
                              ? () {
                                  final downloadProv = context.read<DownloadProvider>();
                                  int count = 0;
                                  for (final it in provider.items) {
                                    if (provider.isSelected(it)) {
                                      downloadProv.addAlbumTask(it);
                                      count++;
                                    }
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('已添加 $count 个图集到下载队列'),
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
              ),

            ScrollToTopButton(
              scrollController: _scrollController,
              color: themeColor,
              bottomOffset: provider.isSelectionMode
                  ? (context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 215 : 155)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
