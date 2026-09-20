import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/memojav_browse_provider.dart';
import '../../../services/memojav/memojav_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'memojav_detail_page.dart';
import 'widgets/memojav_video_card.dart';

class MemojavBrowsePage extends StatefulWidget {
  const MemojavBrowsePage({super.key});

  @override
  State<MemojavBrowsePage> createState() => _MemojavBrowsePageState();
}

class _MemojavBrowsePageState extends State<MemojavBrowsePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  static const _themeColor = Color(0xFF6C5CE7);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MemojavBrowseProvider>();
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
    final provider = context.watch<MemojavBrowseProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF7F8FA),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: _themeColor,
              edgeOffset: 58.0,
              displacement: 40.0,
              onRefresh: () async {
                await provider.loadPage(provider.currentPage);
              },
              child: CustomScrollView(
                controller: _scrollController,
                cacheExtent: 600.0,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Top Safe Spacing
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 54),
                  ),

                  // Search Bar + Random Button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? const Color(0x22FFFFFF) : const Color(0x15000000),
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
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                textInputAction: TextInputAction.search,
                                onSubmitted: (val) {
                                  provider.search(val);
                                  _scrollToTop();
                                },
                                decoration: InputDecoration(
                                  hintText: '搜索 MemoJAV 番号、女优...',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                  prefixIcon: const Icon(
                                    CupertinoIcons.search,
                                    size: 18,
                                    color: _themeColor,
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16),
                                          onPressed: () {
                                            _searchController.clear();
                                            provider.clearSearch();
                                            _scrollToTop();
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Random Action Button
                          RandomActionButton.video(
                            videoSite: VideoSiteType.memojav,
                            isCapsule: true,
                            color: _themeColor,
                          ),
                          const SizedBox(width: 8),

                          // Multi-select Toggle Button
                          BouncingButton(
                            onTap: () => provider.setSelectionMode(!provider.isSelectionMode),
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: provider.isSelectionMode
                                    ? _themeColor
                                    : (isDark ? const Color(0xFF1E1E22) : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: provider.isSelectionMode
                                      ? _themeColor
                                      : (isDark ? const Color(0x22FFFFFF) : const Color(0x15000000)),
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
                    ),
                  ),

                  // Category Selector Chips
                  if (provider.searchKeyword == null)
                    SliverToBoxAdapter(
                      child: Container(
                        height: 44,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: MemojavCategory.values.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final cat = MemojavCategory.values[idx];
                            final isCurrent = provider.currentCategory == cat;
                            return Center(
                              child: BouncingButton(
                                onTap: () {
                                  if (!isCurrent) {
                                    provider.setCategory(cat);
                                    _scrollToTop();
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? _themeColor
                                        : (isDark ? const Color(0xFF1E1E22) : Colors.white),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isCurrent
                                          ? _themeColor
                                          : (isDark ? const Color(0x22FFFFFF) : const Color(0x15000000)),
                                    ),
                                    boxShadow: isCurrent
                                        ? [
                                            BoxShadow(
                                              color: _themeColor.withValues(alpha: 0.35),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    cat.label,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                      color: isCurrent
                                          ? Colors.white
                                          : (isDark ? Colors.white70 : const Color(0xFF333333)),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // Search Keyword Active Bar
                  if (provider.searchKeyword != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            const Text(
                              '搜索结果: ',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              provider.searchKeyword!,
                              style: const TextStyle(fontSize: 13, color: _themeColor, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                provider.clearSearch();
                                _scrollToTop();
                              },
                              child: const Text(
                                '清除搜索',
                                style: TextStyle(fontSize: 12, color: Colors.blueAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Content States
                  if (provider.isLoading && provider.items.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CupertinoActivityIndicator(radius: 14),
                      ),
                    )
                  else if (provider.errorMessage != null && provider.items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.exclamationmark_circle, size: 42, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text('加载失败: ${provider.errorMessage}'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => provider.loadPage(provider.currentPage),
                              style: ElevatedButton.styleFrom(backgroundColor: _themeColor),
                              child: const Text('重试', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (provider.items.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text('没有找到相关视频内容'),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.45,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = provider.items[index];
                            return MemojavVideoCard(
                              item: item,
                              onTap: () {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (_) => MemojavDetailPage(item: item),
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
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                              onPressed: provider.currentPage > 1 ? () {
                                provider.prevPage();
                                _scrollToTop();
                              } : null,
                              child: Icon(
                                CupertinoIcons.chevron_left,
                                size: 18,
                                color: provider.currentPage > 1 ? _themeColor : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '${provider.currentPage} / ${provider.totalPages}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 16),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                              onPressed: provider.currentPage < provider.totalPages ? () {
                                provider.nextPage();
                                _scrollToTop();
                              } : null,
                              child: Icon(
                                CupertinoIcons.chevron_right,
                                size: 18,
                                color: provider.currentPage < provider.totalPages ? _themeColor : Colors.grey,
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
                          '已选择 ${provider.selectedCount} 个视频',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            if (provider.selectedCount == provider.items.length) {
                              provider.clearSelection();
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
                            backgroundColor: _themeColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            final selected = provider.getSelectedItems();
                            final dp = context.read<DownloadProvider>();
                            for (final v in selected) {
                              dp.addVideoTask(v);
                            }
                            provider.clearSelection();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已将 ${selected.length} 个视频加入下载队列'),
                                backgroundColor: _themeColor,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Scroll to Top
            ScrollToTopButton(
              scrollController: _scrollController,
              threshold: 400,
              color: _themeColor,
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
