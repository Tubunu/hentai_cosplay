import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/jable_video_item.dart';
import '../../../providers/jable_browse_provider.dart';
import '../../../providers/jable_download_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/chrome_insets_coordinator.dart';
import '../../widgets/page_navigation_bar.dart';
import 'widgets/jable_video_card.dart';

class JableBrowsePage extends StatefulWidget {
  final int initialSiteIndex;

  const JableBrowsePage({super.key, this.initialSiteIndex = 0});

  @override
  State<JableBrowsePage> createState() => _JableBrowsePageState();
}

class _JableBrowsePageState extends State<JableBrowsePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final browse = context.read<JableBrowseProvider>();
      final state = browse.getStateFor(widget.initialSiteIndex);
      if (state.categories.isEmpty && !state.loadingCategories && state.errorMessage == null) {
        browse.loadCategories(siteIndex: widget.initialSiteIndex);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startBatchDownload(BuildContext context) async {
    final browseProvider = context.read<JableBrowseProvider>();
    final downloadProvider = context.read<JableDownloadProvider>();
    final state = browseProvider.getStateFor(widget.initialSiteIndex);
    final selected = List<VideoCardModel>.from(state.selectedBatchVideos);

    if (selected.isEmpty) return;

    browseProvider.toggleBatchMode(siteIndex: widget.initialSiteIndex);

    await downloadProvider.enqueueBatch(selected);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${selected.length} 个视频添加至下载队列'),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildBatchHeader(
    BuildContext context,
    JableBrowseProvider browse,
    dynamic state,
    bool isDark,
    Color brandColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Text(
            "已选中 ${state.selectedBatchVideos.length} 个影片",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => browse.selectAllVideos(siteIndex: widget.initialSiteIndex),
            child: Text(
              state.selectedBatchVideos.length == state.videos.length ? "取消全选" : "全选",
              style: TextStyle(
                color: brandColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () => browse.toggleBatchMode(siteIndex: widget.initialSiteIndex),
            child: const Text(
              "取消",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    JableBrowseProvider browse,
    dynamic state,
    dynamic scraper,
    bool isDark,
    Color brandColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          // Search Input
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: (val) => browse.search(val, siteIndex: widget.initialSiteIndex),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: '搜索片名、番号或演员...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13.5),
                  prefixIcon: const Icon(CupertinoIcons.search, color: Colors.grey, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.grey, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            browse.search('', siteIndex: widget.initialSiteIndex);
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // Sort Menu (for MissAV & SupJav)
          if (scraper.siteName == 'MissAV') ...[
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              icon: Icon(
                CupertinoIcons.arrow_up_arrow_down,
                color: state.selectedSort.isNotEmpty ? brandColor : Colors.grey,
                size: 20,
              ),
              tooltip: '排序选项',
              onSelected: (val) => browse.setSort(val, siteIndex: widget.initialSiteIndex),
              itemBuilder: (_) => [
                const PopupMenuItem(value: '', child: Text('默认排序 (发行日期)')),
                const PopupMenuItem(value: 'published_at', child: Text('最近更新')),
                const PopupMenuItem(value: 'today_views', child: Text('今日浏览最多')),
                const PopupMenuItem(value: 'weekly_views', child: Text('本周浏览最多')),
                const PopupMenuItem(value: 'monthly_views', child: Text('本月浏览最多')),
                const PopupMenuItem(value: 'views', child: Text('总浏览最多')),
                const PopupMenuItem(value: 'saved', child: Text('收藏数最多')),
              ],
            ),
          ] else if (scraper.siteName == 'SupJav') ...[
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              icon: Icon(
                CupertinoIcons.arrow_up_arrow_down,
                color: state.selectedSort.isNotEmpty ? brandColor : Colors.grey,
                size: 20,
              ),
              tooltip: '排序选项',
              onSelected: (val) => browse.setSort(val, siteIndex: widget.initialSiteIndex),
              itemBuilder: (_) => [
                const PopupMenuItem(value: '', child: Text('最新发布 (Date)')),
                const PopupMenuItem(value: 'views', child: Text('观看最多 (Views)')),
              ],
            ),
          ],

          // Batch Mode Trigger
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(
              CupertinoIcons.checkmark_rectangle,
              color: browse.isBatchMode ? brandColor : Colors.grey,
              size: 22,
            ),
            tooltip: '批量下载选择',
            onPressed: () => browse.toggleBatchMode(siteIndex: widget.initialSiteIndex),
          ),
        ],
      ),
    );
  }

  Widget? _buildCategoryList(
    BuildContext context,
    JableBrowseProvider browse,
    dynamic state,
    bool isDark,
    Color brandColor,
  ) {
    if (state.loadingCategories && state.categories.isEmpty) {
      return const SizedBox(
        height: 38,
        child: Center(
          child: CupertinoActivityIndicator(radius: 8),
        ),
      );
    } else if (state.categories.isNotEmpty) {
      return SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: state.categories.length,
          itemBuilder: (context, index) {
            final cat = state.categories[index];
            final isSelected = state.selectedCategoryUrl == cat.url && state.searchQuery.isEmpty;

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: BouncingButton(
                onTap: () => browse.selectCategory(cat.url, siteIndex: widget.initialSiteIndex),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? brandColor
                        : (isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final browse = context.watch<JableBrowseProvider>();
    final state = browse.getStateFor(widget.initialSiteIndex);
    final scraper = browse.getScraperFor(widget.initialSiteIndex);

    final brandColor = scraper.siteName == 'MissAV'
        ? const Color(0xFFFF2D55)
        : (scraper.siteName == 'SupJav' ? const Color(0xFF5856D6) : const Color(0xFFFF9900));

    final categoryWidget = _buildCategoryList(context, browse, state, isDark, brandColor);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          RefreshIndicator(
            edgeOffset: ChromeInsets.top(context, extra: 4),
            displacement: 36.0,
            onRefresh: () async {
              HapticFeedback.lightImpact();
              await browse.loadVideos(siteIndex: widget.initialSiteIndex);
            },
            color: brandColor,
            child: CustomScrollView(
              cacheExtent: 600.0,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // 1. Top safe spacing for floating site selector pill
                SliverToBoxAdapter(
                  child: SizedBox(height: ChromeInsets.top(context, extra: 4)),
                ),

                // 2. Search Bar & Batch Header (scrolls with page)
                SliverToBoxAdapter(
                  child: browse.isBatchMode
                      ? _buildBatchHeader(context, browse, state, isDark, brandColor)
                      : _buildSearchBar(context, browse, state, scraper, isDark, brandColor),
                ),

                // 3. Category Tags Horizontal List (scrolls with page)
                if (categoryWidget != null)
                  SliverToBoxAdapter(child: categoryWidget),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // 4. Video Grid or State Feedback
                if (state.loadingVideos && state.videos.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CupertinoActivityIndicator(radius: 14)),
                  )
                else if (state.errorMessage != null && state.videos.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.exclamationmark_circle, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              state.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              onPressed: () {
                                if (state.categories.isEmpty) {
                                  browse.loadCategories(siteIndex: widget.initialSiteIndex);
                                } else {
                                  browse.loadVideos(siteIndex: widget.initialSiteIndex);
                                }
                              },
                              child: const Text('重新加载', style: TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (state.videos.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('未找到相关视频', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.crossAxisExtent;
                        final crossAxisCount = width < 500 ? 2 : (width < 800 ? 3 : (width < 1200 ? 4 : 5));

                        return SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 12,
                            childAspectRatio: IosTheme.cardAspectRatio(isVideo: true),
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final video = state.videos[index];
                              final isSelected = state.selectedBatchVideos.contains(video);

                              return JableVideoCard(
                                video: video,
                                scraper: scraper,
                                isBatchMode: browse.isBatchMode,
                                isSelected: isSelected,
                                onSelectionToggle: () => browse.toggleVideoSelection(video, siteIndex: widget.initialSiteIndex),
                              );
                            },
                            childCount: state.videos.length,
                          ),
                        );
                      },
                    ),
                  ),
                  // Flowing Pagination Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: PageNavigationBar(
                        currentPage: state.currentPage,
                        totalPages: 999,
                        isLoading: state.loadingVideos,
                        onPageSelected: (page) => browse.gotoPage(page, siteIndex: widget.initialSiteIndex),
                        brandColor: brandColor,
                      ),
                    ),
                  ),
                ],

                // 5. Adaptive Bottom Spacing (Collapses when auto-hide is on, expands when off)
                const ChromeSliverBottomSpacing(extra: 12),
              ],
            ),
          ),

          // Floating Batch Download Confirmation Button
          if (browse.isBatchMode && state.selectedBatchVideos.isNotEmpty)
            Positioned(
              right: 16,
              bottom: ChromeInsets.floatingBottom(context, extra: 12),
              child: FloatingActionButton.extended(
                backgroundColor: brandColor,
                elevation: 6,
                onPressed: () => _startBatchDownload(context),
                icon: const Icon(CupertinoIcons.arrow_down_circle_fill, color: Colors.white),
                label: Text(
                  "下载选中 (${state.selectedBatchVideos.length})",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
