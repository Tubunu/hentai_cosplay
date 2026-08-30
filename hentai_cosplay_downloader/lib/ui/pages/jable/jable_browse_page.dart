import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/jable_video_item.dart';
import '../../../providers/jable_browse_provider.dart';
import '../../../providers/jable_download_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import 'widgets/jable_video_card.dart';

class JableBrowsePage extends StatefulWidget {
  const JableBrowsePage({super.key});

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
      if (browse.categories.isEmpty && !browse.loadingCategories && browse.errorMessage == null) {
        browse.loadCategories();
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
    final selected = List<VideoCardModel>.from(browseProvider.selectedBatchVideos);

    if (selected.isEmpty) return;

    browseProvider.toggleBatchMode();

    await downloadProvider.enqueueBatch(selected);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${selected.length} 个视频添加至 Jable 下载队列'),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final browse = context.watch<JableBrowseProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 8),

                // 1. Top Site Switcher (JableTV | MissAV | SupJav)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _buildSiteTab(0, 'JableTV', browse),
                        _buildSiteTab(1, 'MissAV', browse),
                        _buildSiteTab(2, 'SupJav', browse),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // 2. Search Bar & Batch Header
                if (browse.isBatchMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          "已选中 ${browse.selectedBatchVideos.length} 个影片",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => browse.selectAllVideos(),
                          child: Text(
                            browse.selectedBatchVideos.length == browse.videos.length ? "取消全选" : "全选",
                            style: const TextStyle(
                              color: IosTheme.primaryPink,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => browse.toggleBatchMode(),
                          child: const Text(
                            "取消",
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
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
                              onSubmitted: (val) => browse.search(val),
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
                                          browse.search('');
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
                        if (browse.currentScraper.siteName == 'MissAV') ...[
                          const SizedBox(width: 6),
                          PopupMenuButton<String>(
                            icon: Icon(
                              CupertinoIcons.arrow_up_arrow_down,
                              color: browse.selectedSort.isNotEmpty ? IosTheme.primaryPink : Colors.grey,
                              size: 20,
                            ),
                            tooltip: '排序选项',
                            onSelected: (val) => browse.setSort(val),
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
                        ] else if (browse.currentScraper.siteName == 'SupJav') ...[
                          const SizedBox(width: 6),
                          PopupMenuButton<String>(
                            icon: Icon(
                              CupertinoIcons.arrow_up_arrow_down,
                              color: browse.selectedSort.isNotEmpty ? IosTheme.primaryPink : Colors.grey,
                              size: 20,
                            ),
                            tooltip: '排序选项',
                            onSelected: (val) => browse.setSort(val),
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
                            color: browse.isBatchMode ? IosTheme.primaryPink : Colors.grey,
                            size: 22,
                          ),
                          tooltip: '批量下载选择',
                          onPressed: () => browse.toggleBatchMode(),
                        ),
                      ],
                    ),
                  ),

                // 3. Category Tags Horizontal List
                if (browse.loadingCategories && browse.categories.isEmpty)
                  const SizedBox(
                    height: 38,
                    child: Center(
                      child: CupertinoActivityIndicator(radius: 8),
                    ),
                  )
                else if (browse.categories.isNotEmpty)
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: browse.categories.length,
                      itemBuilder: (context, index) {
                        final cat = browse.categories[index];
                        final isSelected = browse.selectedCategoryUrl == cat.url && browse.searchQuery.isEmpty;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: BouncingButton(
                            onTap: () => browse.selectCategory(cat.url),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? IosTheme.primaryPink
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
                  ),

                const SizedBox(height: 10),

                // 4. Video Grid
                Expanded(
                  child: browse.loadingVideos
                      ? const Center(child: CupertinoActivityIndicator(radius: 14))
                      : browse.errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(CupertinoIcons.exclamationmark_circle, size: 48, color: Colors.grey),
                                    const SizedBox(height: 12),
                                    Text(
                                      browse.errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                    const SizedBox(height: 16),
                                    CupertinoButton.filled(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      onPressed: () {
                                        if (browse.categories.isEmpty) {
                                          browse.loadCategories();
                                        } else {
                                          browse.loadVideos();
                                        }
                                      },
                                      child: const Text('重新加载', style: TextStyle(fontSize: 14)),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : browse.videos.isEmpty
                              ? const Center(
                                  child: Text('未找到相关视频', style: TextStyle(color: Colors.grey)),
                                )
                              : RefreshIndicator(
                                  onRefresh: () async {
                                    await browse.loadVideos();
                                    HapticFeedback.lightImpact();
                                  },
                                  color: IosTheme.primaryPink,
                                  child: GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 0.78,
                                    ),
                                    itemCount: browse.videos.length,
                                    itemBuilder: (context, index) {
                                      final video = browse.videos[index];
                                      final isSelected = browse.selectedBatchVideos.contains(video);

                                      return JableVideoCard(
                                        video: video,
                                        scraper: browse.currentScraper,
                                        isBatchMode: browse.isBatchMode,
                                        isSelected: isSelected,
                                        onSelectionToggle: () => browse.toggleVideoSelection(video),
                                      );
                                    },
                                  ),
                                ),
                ),

                // 5. Pagination Bar
                if (browse.videos.isNotEmpty && !browse.loadingVideos && browse.errorMessage == null)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.white24,
                      border: Border(
                        top: BorderSide(color: isDark ? Colors.white12 : Colors.black12, width: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: browse.currentPage > 1 ? () => browse.gotoPage(1) : null,
                          child: Text(
                            "« 首页",
                            style: TextStyle(
                              color: browse.currentPage > 1 ? IosTheme.primaryPink : Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            CupertinoIcons.chevron_left,
                            size: 18,
                            color: browse.currentPage > 1 ? IosTheme.primaryPink : Colors.grey,
                          ),
                          onPressed: browse.currentPage > 1 ? () => browse.gotoPage(browse.currentPage - 1) : null,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "第 ${browse.currentPage} 页",
                            style: const TextStyle(
                              color: IosTheme.primaryPink,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            CupertinoIcons.chevron_right,
                            size: 18,
                            color: IosTheme.primaryPink,
                          ),
                          onPressed: () => browse.gotoPage(browse.currentPage + 1),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Floating Batch Download Confirmation Button
          if (browse.isBatchMode && browse.selectedBatchVideos.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 80,
              child: FloatingActionButton.extended(
                backgroundColor: IosTheme.primaryPink,
                elevation: 6,
                onPressed: () => _startBatchDownload(context),
                icon: const Icon(CupertinoIcons.arrow_down_circle_fill, color: Colors.white),
                label: Text(
                  "下载选中 (${browse.selectedBatchVideos.length})",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSiteTab(int index, String title, JableBrowseProvider browse) {
    final isSelected = browse.currentSiteIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (browse.currentSiteIndex != index) {
            browse.switchSite(index);
            _searchController.text = browse.searchQuery;
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? IosTheme.primaryPink : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: IosTheme.primaryPink.withAlpha(80),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
