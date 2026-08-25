import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/video_item.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/video_browse_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/video_batch_download_dialog.dart';
import '../../widgets/video_card.dart';
import '../../widgets/video_tags_sheet.dart';
import 'video_detail_page.dart';

class VideoBrowsePage extends StatefulWidget {
  const VideoBrowsePage({super.key});

  @override
  State<VideoBrowsePage> createState() => _VideoBrowsePageState();
}

class _VideoBrowsePageState extends State<VideoBrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pageJumpController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _pageJumpController.dispose();
    _scrollController.dispose();
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

  void _onSearchSubmitted(String val) {
    context.read<VideoBrowseProvider>().setSearchKeyword(val);
    _scrollToTop();
  }

  void _downloadSelected(VideoBrowseProvider browseProv) {
    final selected = browseProv.selectedItems;
    if (selected.isEmpty) return;

    final downloadProv = context.read<DownloadProvider>();
    downloadProv.addBatchVideoTasks(selected);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${selected.length} 个选中视频加入下载队列'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );
    browseProv.clearSelection();
  }

  void _showJumpPageDialog(VideoBrowseProvider browseProv) {
    _pageJumpController.text = browseProv.currentPage.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('跳转视频页码', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请输入要跳转的目标页码：'),
            const SizedBox(height: 12),
            TextField(
              controller: _pageJumpController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: IosTheme.primaryPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final page = int.tryParse(_pageJumpController.text.trim());
              if (page != null && page >= 1) {
                Navigator.pop(ctx);
                browseProv.loadPage(page);
                _scrollToTop();
              }
            },
            child: const Text('跳转'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final browseProv = context.watch<VideoBrowseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: IosTheme.primaryPink,
          onRefresh: () async {
            await browseProv.loadPage(browseProv.currentPage);
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Hero Large Title & Action Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PORN VIDEO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: IosTheme.primaryPink.withValues(alpha: 0.9),
                            ),
                          ),
                          const Text(
                            '在线视频',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          Text(
                            browseProv.searchKeyword.isNotEmpty
                                ? '搜索: "${browseProv.searchKeyword}" • 第 ${browseProv.currentPage} 页'
                                : browseProv.currentTag != null
                                    ? '标签: ${browseProv.currentTag} • 第 ${browseProv.currentPage} 页'
                                    : '海量高清视频 • 第 ${browseProv.currentPage} 页',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Batch Page Range Download Button (区间批量)
                      BouncingButton(
                        onTap: () => VideoBatchDownloadDialog.show(
                          context,
                          initialStart: browseProv.currentPage,
                          initialEnd: browseProv.currentPage + 4,
                          category: browseProv.category,
                          keyword: browseProv.searchKeyword.isNotEmpty ? browseProv.searchKeyword : null,
                          tag: browseProv.currentTag,
                        ),
                        child: FrostedGlass(
                          borderRadius: 16,
                          blur: 15,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          backgroundColor: isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF),
                          child: const Row(
                            children: [
                              Icon(CupertinoIcons.layers_alt_fill, color: IosTheme.primaryPink, size: 16),
                              SizedBox(width: 6),
                              Text(
                                '区间批量',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: IosTheme.primaryPink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Selection Mode Toggle Button (批量选择)
                      BouncingButton(
                        onTap: () => browseProv.toggleSelectionMode(),
                        child: FrostedGlass(
                          borderRadius: 16,
                          blur: 15,
                          padding: const EdgeInsets.all(8),
                          backgroundColor: browseProv.isSelectionMode
                              ? IosTheme.primaryPink
                              : (isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF)),
                          child: Icon(
                            browseProv.isSelectionMode
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.checkmark_circle,
                            color: browseProv.isSelectionMode ? Colors.white : IosTheme.primaryPink,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Category Dropdown and TAG Button Toolbar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Category Dropdown (分类排行)
                        PopupMenuButton<VideoCategory>(
                          initialValue: browseProv.category,
                          tooltip: '选择视频排行与分类',
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                          onSelected: (cat) {
                            _searchController.clear();
                            browseProv.setCategory(cat);
                            _scrollToTop();
                          },
                          itemBuilder: (context) => VideoCategory.values.map((cat) {
                            final isSelected = browseProv.category == cat && !browseProv.isTagActive && !browseProv.isSearchActive;
                            return PopupMenuItem<VideoCategory>(
                              value: cat,
                              child: Row(
                                children: [
                                  Icon(
                                    cat == VideoCategory.latest
                                        ? CupertinoIcons.sparkles
                                        : cat == VideoCategory.ranking
                                            ? CupertinoIcons.flame_fill
                                            : cat == VideoCategory.rankingPlay
                                                ? CupertinoIcons.play_circle_fill
                                                : cat == VideoCategory.rankingDownload
                                                    ? CupertinoIcons.arrow_down_circle_fill
                                                    : cat == VideoCategory.rankingBookmark
                                                        ? CupertinoIcons.bookmark_fill
                                                        : CupertinoIcons.hand_thumbsup_fill,
                                    size: 16,
                                    color: isSelected ? IosTheme.primaryPink : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    cat.label,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? IosTheme.primaryPink : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const Spacer(),
                                    const Icon(CupertinoIcons.checkmark, size: 14, color: IosTheme.primaryPink),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                          child: FrostedGlass(
                            borderRadius: 14,
                            blur: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                            backgroundColor: browseProv.isTagActive || browseProv.isSearchActive
                                ? (isDark ? const Color(0x6624242A) : const Color(0xBBFFFFFF))
                                : IosTheme.primaryPink.withValues(alpha: 0.15),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.slider_horizontal_3,
                                  size: 13,
                                  color: browseProv.isTagActive || browseProv.isSearchActive
                                      ? (isDark ? Colors.white70 : Colors.black87)
                                      : IosTheme.primaryPink,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  browseProv.isTagActive
                                      ? '分类: ${browseProv.category.label}'
                                      : browseProv.category.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: browseProv.isTagActive || browseProv.isSearchActive
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : IosTheme.primaryPink,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  CupertinoIcons.chevron_down,
                                  size: 11,
                                  color: browseProv.isTagActive || browseProv.isSearchActive
                                      ? Colors.grey
                                      : IosTheme.primaryPink,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Hot Tags Button (TAG 标签)
                        BouncingButton(
                          onTap: () {
                            VideoTagsSheet.show(
                              context,
                              onSelect: (tag) {
                                _searchController.clear();
                                browseProv.setTag(tag.name);
                                _scrollToTop();
                              },
                            );
                          },
                          child: FrostedGlass(
                            borderRadius: 14,
                            blur: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                            backgroundColor: isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.tag_fill, size: 13, color: IosTheme.primaryPink),
                                SizedBox(width: 5),
                                Text(
                                  'TAG 标签',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: IosTheme.primaryPink,
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
              ),

              // Active Tag Filter Chip (if filtering by tag)
              if (browseProv.isTagActive)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: IosTheme.primaryPink.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: IosTheme.primaryPink.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.tag_fill, size: 12, color: IosTheme.primaryPink),
                              const SizedBox(width: 5),
                              Text(
                                '标签: ${browseProv.currentTag}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: IosTheme.primaryPink,
                                ),
                              ),
                              const SizedBox(width: 6),
                              BouncingButton(
                                onTap: () {
                                  browseProv.clearTag();
                                  _scrollToTop();
                                },
                                child: const Icon(CupertinoIcons.xmark_circle_fill, size: 14, color: IosTheme.primaryPink),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          placeholder: '搜索 视频名称、角色或关键词...',
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          onSubmitted: _onSearchSubmitted,
                          onSuffixTap: () {
                            _searchController.clear();
                            browseProv.clearSearch();
                            _scrollToTop();
                          },
                        ),
                      ),
                      if (_searchController.text.isNotEmpty || browseProv.searchKeyword.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        BouncingButton(
                          onTap: () {
                            _onSearchSubmitted(_searchController.text);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: IosTheme.primaryPink,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '搜索',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Selection Mode Action Bar (if active)
              if (browseProv.isSelectionMode)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: FrostedGlass(
                      borderRadius: 16,
                      blur: 15,
                      backgroundColor: IosTheme.primaryPink.withValues(alpha: 0.12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            '已选择 ${browseProv.selectedCount} 个视频',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: IosTheme.primaryPink,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: browseProv.selectAllCurrentPage,
                            child: const Text('全选本页', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: IosTheme.primaryPink,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(CupertinoIcons.arrow_down_to_line, size: 14),
                            label: const Text('下载选中', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            onPressed: browseProv.selectedCount > 0
                                ? () => _downloadSelected(browseProv)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Video Content Grid or Loading / Error
              if (browseProv.isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CupertinoActivityIndicator(radius: 16),
                        SizedBox(height: 14),
                        Text('正在加载在线视频列表...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else if (browseProv.errorMessage != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.wifi_slash, size: 48, color: Colors.orange),
                          const SizedBox(height: 12),
                          Text(
                            browseProv.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: IosTheme.primaryPink,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: () => browseProv.loadPage(browseProv.currentPage),
                            child: const Text('重新加载'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (browseProv.items.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text('没有找到相关视频', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.95,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = browseProv.items[index];

                        return VideoCard(
                          item: item,
                          onTap: () {
                            if (browseProv.isSelectionMode) {
                              browseProv.toggleVideoSelection(item);
                            } else {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => VideoDetailPage(initialItem: item),
                                ),
                              );
                            }
                          },
                        );
                      },
                      childCount: browseProv.items.length,
                      addAutomaticKeepAlives: true,
                      addRepaintBoundaries: true,
                    ),
                  ),
                ),

              // Prominent Pagination Bar (Bottom)
              if (!browseProv.isLoading && browseProv.items.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Previous Page Button
                        BouncingButton(
                          onTap: browseProv.currentPage > 1
                              ? () {
                                  browseProv.previousPage();
                                  _scrollToTop();
                                }
                              : null,
                          child: FrostedGlass(
                            borderRadius: 16,
                            blur: 20,
                            padding: const EdgeInsets.all(12),
                            backgroundColor: browseProv.currentPage > 1
                                ? (isDark ? const Color(0x9928282E) : const Color(0xDDFFFFFF))
                                : Colors.transparent,
                            child: Icon(
                              CupertinoIcons.chevron_left,
                              size: 18,
                              color: browseProv.currentPage > 1
                                  ? IosTheme.primaryPink
                                  : Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                        ),

                        const SizedBox(width: 14),

                        // Page Indicator with Click to Jump
                        BouncingButton(
                          onTap: () => _showJumpPageDialog(browseProv),
                          child: FrostedGlass(
                            borderRadius: 18,
                            blur: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            backgroundColor: isDark ? const Color(0x9928282E) : const Color(0xDDFFFFFF),
                            child: Row(
                              children: [
                                Text(
                                  '第 ${browseProv.currentPage} 页',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(CupertinoIcons.chevron_down, size: 12),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 14),

                        // Next Page Button (Allow continuous next page)
                        BouncingButton(
                          onTap: () {
                            browseProv.nextPage();
                            _scrollToTop();
                          },
                          child: FrostedGlass(
                            borderRadius: 16,
                            blur: 20,
                            padding: const EdgeInsets.all(12),
                            backgroundColor: isDark ? const Color(0x9928282E) : const Color(0xDDFFFFFF),
                            child: const Icon(
                              CupertinoIcons.chevron_right,
                              size: 18,
                              color: IosTheme.primaryPink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Dynamic bottom spacer
              SliverToBoxAdapter(
                child: SizedBox(
                  height: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 210 : 130,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
