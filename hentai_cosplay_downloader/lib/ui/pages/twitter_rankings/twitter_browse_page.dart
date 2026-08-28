import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/video_item.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/twitter_browse_provider.dart';
import '../../../services/twitter_rankings/twitter_site_config.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'twitter_reel_player_page.dart';
import 'widgets/twitter_site_dropdown.dart';
import 'widgets/twitter_video_card.dart';

class TwitterBrowsePage extends StatefulWidget {
  const TwitterBrowsePage({super.key});

  @override
  State<TwitterBrowsePage> createState() => _TwitterBrowsePageState();
}

class _TwitterBrowsePageState extends State<TwitterBrowsePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 300) {
      context.read<TwitterBrowseProvider>().loadMore();
    }
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

  void _openReelPlayer(TwitterBrowseProvider prov, int initialIndex) {
    if (prov.items.isEmpty || initialIndex < 0 || initialIndex >= prov.items.length) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TwitterReelPlayerPage(
          playlist: List<VideoItem>.from(prov.items),
          initialIndex: initialIndex,
          site: prov.currentSite,
        ),
      ),
    );
  }

  void _showBatchRangeDialog(TwitterBrowseProvider prov) {
    final startController = TextEditingController(text: '1');
    final endController = TextEditingController(text: '3');

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('批量抓取下载 [${prov.currentSite.name}]'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Text(
                '按当前站点 "${prov.currentSite.name}"、周期 "${prov.currentRange}" 自动抓取指定页码范围内的所有视频加入下载队列：',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: startController,
                      placeholder: '起始页',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('至'),
                  ),
                  Expanded(
                    child: CupertinoTextField(
                      controller: endController,
                      placeholder: '结束页',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('开始下载'),
            onPressed: () {
              final start = int.tryParse(startController.text) ?? 1;
              final end = int.tryParse(endController.text) ?? start;
              Navigator.pop(ctx);

              if (start > end || start < 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('页码范围无效')),
                );
                return;
              }

              final downloadProv = context.read<DownloadProvider>();
              downloadProv.addTwitterPageRange(
                start,
                end,
                site: prov.currentSite,
                range: prov.currentRange,
                sort: prov.currentSort,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已开始抓取第 $start ~ $end 页视频并加入下载队列'),
                  backgroundColor: prov.currentSite.themeColor,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showJumpPageDialog(TwitterBrowseProvider prov) {
    final pageController = TextEditingController(text: prov.page.toString());

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('跳转页码'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: pageController,
            placeholder: '请输入页码',
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('跳转'),
            onPressed: () {
              final target = int.tryParse(pageController.text);
              Navigator.pop(ctx);
              if (target != null && target >= 1) {
                prov.jumpToPage(target);
                _scrollToTop();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TwitterBrowseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = prov.currentSite.themeColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                await prov.fetchData(refresh: true);
              },
              color: themeColor,
              child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Top Safe Spacing for Floating Capsule Bar (52px)
              const SliverToBoxAdapter(
                child: SizedBox(height: 52),
              ),

              // Header Title & Site Selector Row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                  child: Row(
                    children: [
                      // Site Dropdown Selector
                      TwitterSiteDropdown(
                        currentSite: prov.currentSite,
                        onSiteSelected: (TwitterSiteConfig site) {
                          prov.setSite(site);
                          _scrollToTop();
                        },
                      ),

                      const Spacer(),

                      // Jump Page Button
                      BouncingButton(
                        onTap: () => _showJumpPageDialog(prov),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'P${prov.page}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Batch Range Download Button
                      BouncingButton(
                        onTap: () => _showBatchRangeDialog(prov),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.square_stack_3d_down_right_fill, color: themeColor, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                '区间批量',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: themeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Selection Mode Toggle Button
                      BouncingButton(
                        onTap: () => prov.toggleSelectionMode(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: prov.isSelectionMode
                                ? themeColor
                                : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            prov.isSelectionMode ? '完成' : '选择',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: prov.isSelectionMode
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Filter Segment Rows (Range & Sort)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Range Pills
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: prov.currentSite.rangeOptions.map((opt) {
                            final isSelected = prov.currentRange == opt.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: BouncingButton(
                                onTap: () {
                                  prov.setRange(opt.id);
                                  _scrollToTop();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? themeColor
                                        : (isDark ? const Color(0xFF1E1E24) : Colors.white),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: themeColor.withValues(alpha: 0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    opt.label,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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

                      const SizedBox(height: 6),

                      // Sort Pills (if more than 1 option)
                      if (prov.currentSite.sortOptions.length > 1)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: prov.currentSite.sortOptions.map((opt) {
                              final isSelected = prov.currentSort == opt.id;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: BouncingButton(
                                  onTap: () {
                                    prov.setSort(opt.id);
                                    _scrollToTop();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? themeColor.withValues(alpha: 0.2)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: isSelected
                                          ? Border.all(color: themeColor, width: 1)
                                          : Border.all(color: isDark ? Colors.white12 : Colors.black12),
                                    ),
                                    child: Text(
                                      opt.label,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                        color: isSelected
                                          ? themeColor
                                          : (isDark ? Colors.white60 : Colors.black54),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Loading State
              if (prov.isLoading && prov.items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CupertinoActivityIndicator(radius: 14),
                  ),
                ),

              // Error State
              if (prov.errorMessage != null && prov.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.exclamationmark_circle, color: themeColor, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            prov.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => prov.fetchData(refresh: true),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Video Grid (2 Columns)
              if (prov.items.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final video = prov.items[index];
                        final isSelected = prov.selectedSlugs.contains(video.slug);

                        return TwitterVideoCard(
                          video: video,
                          site: prov.currentSite,
                          isSelectionMode: prov.isSelectionMode,
                          isSelected: isSelected,
                          onTap: () => _openReelPlayer(prov, index),
                          onSelectToggle: () => prov.toggleItemSelection(video.slug),
                        );
                      },
                      childCount: prov.items.length,
                    ),
                  ),
                ),

              // Bottom Loading More Indicator
              if (prov.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CupertinoActivityIndicator(radius: 12)),
                  ),
                ),
            ],
          ),
        ),
        ScrollToTopButton(
          scrollController: _scrollController,
          color: themeColor,
        ),
      ],
    ),
  ),

      // Multi-selection Action Bottom Bar
      bottomSheet: prov.isSelectionMode && prov.selectedCount > 0
          ? Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    '已选 ${prov.selectedCount} 个视频',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const Spacer(),
                  BouncingButton(
                    onTap: () => prov.selectAll(),
                    child: const Text('全选', style: TextStyle(color: CupertinoColors.activeBlue)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(CupertinoIcons.arrow_down_circle_fill, size: 16),
                    label: Text('批量下载 (${prov.selectedCount})'),
                    onPressed: () {
                      final selected = prov.selectedItems;
                      final downloadProv = context.read<DownloadProvider>();
                      downloadProv.addBatchVideoTasks(selected);
                      prov.clearSelection();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已添加 ${selected.length} 个推特视频到下载队列'),
                          backgroundColor: themeColor,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
