import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/pack_item.dart';
import '../../../providers/browse_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/batch_download_dialog.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/pack_card.dart';
import 'pack_detail_page.dart';

class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pageJumpController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _pageJumpController.dispose();
    super.dispose();
  }

  void _downloadSingle(PackItem item) {
    final downloadProv = context.read<DownloadProvider>();
    final settingsProv = context.read<SettingsProvider>();
    downloadProv.updateConfig(settingsProv.config);
    downloadProv.addSinglePack(item);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 "${item.title}" 到下载队列'),
        backgroundColor: IosTheme.primaryPink,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _downloadSelected(BrowseProvider browseProv) {
    final selected = browseProv.selectedItems;
    if (selected.isEmpty) return;

    final downloadProv = context.read<DownloadProvider>();
    final settingsProv = context.read<SettingsProvider>();
    downloadProv.updateConfig(settingsProv.config);
    downloadProv.addBatchPacks(selected);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${selected.length} 个选中图包加入下载队列'),
        backgroundColor: IosTheme.primaryPink,
      ),
    );
    browseProv.clearSelection();
  }

  void _showJumpPageDialog(BrowseProvider browseProv) {
    _pageJumpController.text = browseProv.currentPage.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('跳转页码', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('请输入 1 ~ ${browseProv.totalPages} 之间的页码：'),
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
    final browseProv = context.watch<BrowseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Ambient Mesh Glow
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Container(
              decoration: const BoxDecoration(gradient: IosTheme.ambientMesh),
            ),
          ),

          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              cacheExtent: 600,
              slivers: [
                // Apple Music Hero Large Title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EXPLORE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: IosTheme.primaryPink.withOpacity(0.9),
                              ),
                            ),
                            const Text(
                              '在线浏览',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),

                        // Batch Page Range Download Button
                        BouncingButton(
                          onTap: () => BatchDownloadDialog.show(
                            context,
                            initialStart: browseProv.currentPage,
                            initialEnd: (browseProv.currentPage + 4).clamp(1, browseProv.totalPages),
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

                        // Selection Mode Toggle Button
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

                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: FrostedGlass(
                      borderRadius: 16,
                      blur: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      backgroundColor: isDark ? const Color(0x7728282E) : const Color(0xCCFFFFFF),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.search, color: IosTheme.secondaryText(context), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: browseProv.setSearchQuery,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: '搜索当前页面图包或作者...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: IosTheme.secondaryText(context),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16),
                              color: IosTheme.secondaryText(context),
                              onPressed: () {
                                _searchController.clear();
                                browseProv.setSearchQuery('');
                              },
                            ),
                        ],
                      ),
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
                        backgroundColor: IosTheme.primaryPink.withOpacity(0.12),
                        border: Border.all(color: IosTheme.primaryPink.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            Text(
                              '已选择 ${browseProv.selectedCount} 个图包',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: IosTheme.primaryPink,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: browseProv.selectAllCurrentPage,
                              child: const Text('全选本页', style: TextStyle(fontSize: 12)),
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

                // Content Grid or Loading / Error
                if (browseProv.isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CupertinoActivityIndicator(radius: 16),
                    ),
                  )
                else if (browseProv.errorMessage != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: Colors.orange),
                          const SizedBox(height: 12),
                          Text(browseProv.errorMessage!),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => browseProv.loadPage(browseProv.currentPage),
                            child: const Text('重新加载'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (browseProv.items.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('没有找到相关图包'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = browseProv.items[index];
                          final isSelected = browseProv.isPackSelected(item);

                          return PackCard(
                            item: item,
                            isSelected: isSelected,
                            isSelectionMode: browseProv.isSelectionMode,
                            onTap: () {
                              if (browseProv.isSelectionMode) {
                                browseProv.togglePackSelection(item);
                              } else {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (_) => PackDetailPage(item: item),
                                  ),
                                );
                              }
                            },
                            onLongPress: () {
                              browseProv.toggleSelectionMode(true);
                              browseProv.togglePackSelection(item);
                            },
                            onDownload: () => _downloadSingle(item),
                          );
                        },
                        childCount: browseProv.items.length,
                        addAutomaticKeepAlives: true,
                        addRepaintBoundaries: true,
                      ),
                    ),
                  ),

                // Pagination Bar (Bottom)
                if (!browseProv.isLoading && browseProv.items.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Previous Page Button
                          BouncingButton(
                            onTap: browseProv.currentPage > 1 ? browseProv.previousPage : null,
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
                                    '第 ${browseProv.currentPage} / ${browseProv.totalPages} 页',
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

                          // Next Page Button
                          BouncingButton(
                            onTap: browseProv.currentPage < browseProv.totalPages ? browseProv.nextPage : null,
                            child: FrostedGlass(
                              borderRadius: 16,
                              blur: 20,
                              padding: const EdgeInsets.all(12),
                              backgroundColor: browseProv.currentPage < browseProv.totalPages
                                  ? (isDark ? const Color(0x9928282E) : const Color(0xDDFFFFFF))
                                  : Colors.transparent,
                              child: Icon(
                                CupertinoIcons.chevron_right,
                                size: 18,
                                color: browseProv.currentPage < browseProv.totalPages
                                    ? IosTheme.primaryPink
                                    : Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Dynamic bottom spacer to prevent obstruction by bottom navigation & mini download bar
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: context.watch<DownloadProvider>().hasActiveOrPausedTasks ? 210 : 130,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
