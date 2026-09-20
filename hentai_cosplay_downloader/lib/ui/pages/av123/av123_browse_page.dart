import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/video_item.dart';
import '../../../providers/av123_browse_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/av123/av123_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'av123_detail_page.dart';
import 'widgets/av123_video_card.dart';

class Av123BrowsePage extends StatefulWidget {
  const Av123BrowsePage({super.key});

  @override
  State<Av123BrowsePage> createState() => _Av123BrowsePageState();
}

class _Av123BrowsePageState extends State<Av123BrowsePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  static const _themeColor = Color(0xFFE50914);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<Av123BrowseProvider>();
      if (provider.items.isEmpty && !provider.isLoading) {
        provider.loadVideos();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String keyword) {
    context.read<Av123BrowseProvider>().search(keyword);
  }

  void _onCategorySelected(Av123Category category) {
    _searchController.clear();
    context.read<Av123BrowseProvider>().setCategory(category);
  }

  void _batchDownload(List<VideoItem> selectedItems) {
    final downloadProvider = context.read<DownloadProvider>();
    downloadProvider.addBatchVideoTasks(selectedItems);

    context.read<Av123BrowseProvider>().clearSelection();

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('已添加到下载队列'),
        content: Text('已成功添加 ${selectedItems.length} 个任务到下载列表'),
        actions: [
          CupertinoDialogAction(
            child: const Text('确定'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<Av123BrowseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 1. Top Bar Spacing (54px) for capsule navbar
              const SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(height: 54),
                ),
              ),

              // 2. Search Box
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          placeholder: '搜索 123AV 影片番号、演员或关键词...',
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          onSubmitted: _onSearch,
                          onSuffixTap: () {
                            _searchController.clear();
                            provider.clearSearch();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Random Action Button
                      RandomActionButton.video(
                        videoSite: VideoSiteType.av123,
                        isCapsule: true,
                        color: _themeColor,
                      ),
                      const SizedBox(width: 8),

                      // Multi-select Toggle Button
                      BouncingButton(
                        onTap: () => provider.setSelectionMode(!provider.isSelectionMode),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: provider.isSelectionMode
                                ? _themeColor
                                : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: provider.isSelectionMode
                                  ? _themeColor
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
                ),
              ),

              // 3. Category Chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: Av123Category.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = Av123Category.values[index];
                      final isSelected =
                          provider.currentCategory == cat && provider.searchKeyword == null;
                      return ChoiceChip(
                        label: Text(cat.label),
                        selected: isSelected,
                        selectedColor: _themeColor,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor:
                            isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: isSelected
                                ? _themeColor
                                : (isDark
                                    ? const Color(0x33FFFFFF)
                                    : const Color(0x18000000)),
                          ),
                        ),
                        onSelected: (_) => _onCategorySelected(cat),
                      );
                    },
                  ),
                ),
              ),

              // 4. Loading / Error / Empty / Grid
              if (provider.isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CupertinoActivityIndicator(radius: 14),
                  ),
                )
              else if (provider.errorMessage != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_triangle,
                            size: 48,
                            color: CupertinoColors.systemRed,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            provider.errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          CupertinoButton.filled(
                            child: const Text('重试'),
                            onPressed: () => provider.refresh(),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (provider.items.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text('没有找到相关影片'),
                  ),
                )
              else ...[
                // Video Grid
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.45,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = provider.items[index];
                        return Av123VideoCard(
                          item: item,
                          onTap: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (_) => Av123DetailPage(item: item),
                              ),
                            );
                          },
                        );
                      },
                      childCount: provider.items.length,
                    ),
                  ),
                ),

                // Pagination bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          onPressed: provider.currentPage > 1 && !provider.isLoading
                              ? () => provider.previousPage()
                              : null,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.chevron_left, size: 16),
                              SizedBox(width: 4),
                              Text('上一页', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${provider.currentPage} / ${provider.totalPages}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          onPressed: provider.currentPage < provider.totalPages && !provider.isLoading
                              ? () => provider.nextPage()
                              : null,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('下一页', style: TextStyle(fontSize: 13)),
                              SizedBox(width: 4),
                              Icon(CupertinoIcons.chevron_right, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: SizedBox(
                  height: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 220 : 140,
                ),
              ),
            ],
          ),

          // Multi-selection floating bottom bar
          if (provider.isSelectionMode)
            Positioned(
              left: 16,
              right: 16,
              bottom: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 145 : 85,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xEE1C1C1E)
                      : const Color(0xEEFFFFFF),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: _themeColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => provider.clearSelection(),
                      child: const Icon(CupertinoIcons.xmark_circle_fill, size: 24),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '已选择 ${provider.selectedCount} 项',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      onPressed: () => provider.selectAll(),
                      child: const Text('全选', style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      onPressed: provider.selectedCount > 0
                          ? () => _batchDownload(provider.selectedItems)
                          : null,
                      child: const Text('下载', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),

          // Scroll to top button
          ScrollToTopButton(
            scrollController: _scrollController,
            color: _themeColor,
            bottomOffset: provider.isSelectionMode
                ? (context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 215 : 155)
                : null,
          ),
        ],
      ),
    );
  }
}
