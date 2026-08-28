import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/misskon_browse_provider.dart';
import '../../../services/misskon/misskon_api_service.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'misskon_detail_page.dart';
import 'widgets/misskon_album_card.dart';

class MisskonBrowsePage extends StatefulWidget {
  const MisskonBrowsePage({super.key});

  @override
  State<MisskonBrowsePage> createState() => _MisskonBrowsePageState();
}

class _MisskonBrowsePageState extends State<MisskonBrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pageJumpController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<String> _hotTags = [
    'DJAWA',
    'Pure Media',
    'BlueCake',
    'CreamSoda',
    'SAINT Photolife',
    'Loozy',
    'Espacia Korea',
    'Moon Night Snap',
    'Xiuren',
    'MyGirl',
    'Feilin',
    'HuaYang',
    'MFStar',
    'AI Enhanced',
  ];

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
    context.read<MisskonBrowseProvider>().setSearchKeyword(val);
    _scrollToTop();
  }

  void _downloadSelected(MisskonBrowseProvider prov) {
    final selected = prov.selectedItems;
    if (selected.isEmpty) return;

    final downloadProv = context.read<DownloadProvider>();
    downloadProv.addBatchAlbumTasks(selected);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${selected.length} 个选中写真集加入下载队列'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );
    prov.clearSelection();
  }

  void _showJumpPageDialog(MisskonBrowseProvider prov) {
    _pageJumpController.text = prov.currentPage.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('跳转页码', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('请输入 1 ~ ${prov.totalPages} 之间的页码：'),
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
                prov.loadPage(page);
                _scrollToTop();
              }
            },
            child: const Text('跳转'),
          ),
        ],
      ),
    );
  }

  void _showBatchRangeDialog(MisskonBrowseProvider prov) {
    final startController = TextEditingController(text: '${prov.currentPage}');
    final endController = TextEditingController(text: '${(prov.currentPage + 2).clamp(1, prov.totalPages)}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(CupertinoIcons.layers_alt_fill, color: IosTheme.primaryPink, size: 22),
            SizedBox(width: 8),
            Text('MissKon 区间批量下载', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('自动解析并下载所选页码区间内的所有写真相册：', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '起始页', border: OutlineInputBorder()),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('至'),
                ),
                Expanded(
                  child: TextField(
                    controller: endController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '结束页', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: IosTheme.primaryPink,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final start = int.tryParse(startController.text.trim());
              final end = int.tryParse(endController.text.trim());
              if (start != null && end != null && start <= end && start >= 1) {
                Navigator.pop(ctx);
                final downloadProv = context.read<DownloadProvider>();
                downloadProv.addMisskonPageRange(
                  start,
                  end,
                  category: prov.category,
                  tag: prov.currentTag,
                  keyword: prov.searchKeyword,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已添加第 $start 到 $end 页 MissKon 写真至下载队列'),
                    backgroundColor: IosTheme.primaryPink,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('加入下载队列'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MisskonBrowseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: IosTheme.primaryPink,
              onRefresh: () => prov.loadPage(prov.currentPage),
              child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Hero Title & Action Header (Padding top accommodates top segmented capsule)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 52, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MISSKON.COM',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: const Color(0xFFE74C3C).withValues(alpha: 0.9),
                            ),
                          ),
                          const Text(
                            '高清写真',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          if (prov.totalPages > 1)
                            Text(
                              '共收录 ${prov.totalPages} 页模特图集',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white54 : Colors.black45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),

                      // Random Discovery Button
                      const RandomActionButton.album(
                        albumSource: MediaSourceType.misskon,
                        isCapsule: true,
                        color: Color(0xFFE74C3C),
                      ),
                      const SizedBox(width: 8),

                      // Batch Range Download Button
                      BouncingButton(
                        onTap: () => _showBatchRangeDialog(prov),
                        child: FrostedGlass(
                          borderRadius: 16,
                          blur: 15,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          backgroundColor: isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF),
                          child: const Row(
                            children: [
                              Icon(CupertinoIcons.layers_alt_fill, color: Color(0xFFE74C3C), size: 16),
                              SizedBox(width: 6),
                              Text(
                                '区间批量',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Color(0xFFE74C3C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Selection Mode Toggle Button
                      BouncingButton(
                        onTap: () => prov.toggleSelectionMode(),
                        child: FrostedGlass(
                          borderRadius: 16,
                          blur: 15,
                          padding: const EdgeInsets.all(8),
                          backgroundColor: prov.isSelectionMode
                              ? IosTheme.primaryPink
                              : (isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF)),
                          child: Icon(
                            prov.isSelectionMode
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.checkmark_circle,
                            color: prov.isSelectionMode ? Colors.white : IosTheme.primaryPink,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Category Dropdown & Hot Tags Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Category Dropdown
                        PopupMenuButton<MisskonCategory>(
                          initialValue: prov.category,
                          tooltip: '选择分类与热门排行',
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                          onSelected: (cat) {
                            _searchController.clear();
                            prov.setCategory(cat);
                            _scrollToTop();
                          },
                          itemBuilder: (context) => MisskonCategory.values.map((cat) {
                            final isSel = prov.category == cat && !prov.isSearchActive && !prov.isTagActive;
                            return PopupMenuItem<MisskonCategory>(
                              value: cat,
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.flame_fill,
                                    color: isSel ? IosTheme.primaryPink : (isDark ? Colors.white60 : Colors.black45),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    cat.label,
                                    style: TextStyle(
                                      color: isSel ? IosTheme.primaryPink : null,
                                      fontWeight: isSel ? FontWeight.w800 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          child: FrostedGlass(
                            borderRadius: 14,
                            blur: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            backgroundColor: (prov.isTagActive || prov.isSearchActive)
                                ? (isDark ? const Color(0x662C2C2E) : const Color(0xEEFFFFFF))
                                : IosTheme.primaryPink.withValues(alpha: 0.15),
                            borderColor: (prov.isTagActive || prov.isSearchActive)
                                ? Colors.transparent
                                : IosTheme.primaryPink.withValues(alpha: 0.4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.flame_fill,
                                  size: 14,
                                  color: (prov.isTagActive || prov.isSearchActive)
                                      ? (isDark ? Colors.white70 : Colors.black87)
                                      : IosTheme.primaryPink,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  (prov.isTagActive || prov.isSearchActive)
                                      ? '热门分类'
                                      : prov.category.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: (prov.isTagActive || prov.isSearchActive)
                                        ? (isDark ? Colors.white70 : Colors.black87)
                                        : IosTheme.primaryPink,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  CupertinoIcons.chevron_down,
                                  size: 10,
                                  color: (prov.isTagActive || prov.isSearchActive)
                                      ? (isDark ? Colors.white54 : Colors.black45)
                                      : IosTheme.primaryPink,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Hot Tags
                        ..._hotTags.map((tag) {
                          final isSelected = prov.currentTag == tag;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: BouncingButton(
                              onTap: () {
                                _searchController.clear();
                                if (isSelected) {
                                  prov.clearTag();
                                } else {
                                  prov.setTag(tag);
                                }
                                _scrollToTop();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? IosTheme.primaryPink
                                      : (isDark ? const Color(0x662C2C2E) : const Color(0xEEFFFFFF)),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? IosTheme.primaryPink
                                        : (isDark ? Colors.white12 : Colors.black12),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _onSearchSubmitted,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '搜索模特名、写真机构、关键词...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        prefixIcon: const Icon(CupertinoIcons.search, size: 16, color: Colors.grey),
                        suffixIcon: _searchController.text.isNotEmpty || prov.isSearchActive
                            ? IconButton(
                                icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  prov.clearSearch();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ),
              ),

              // Loading indicator
              if (prov.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CupertinoActivityIndicator(radius: 14),
                    ),
                  ),
                ),

              // Error State
              if (prov.errorMessage != null && !prov.isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(CupertinoIcons.exclamationmark_circle, size: 42, color: Colors.amber),
                          const SizedBox(height: 12),
                          Text(prov.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: IosTheme.primaryPink,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => prov.loadPage(prov.currentPage),
                            child: const Text('重新加载'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Albums Grid
              if (!prov.isLoading && prov.items.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.65,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = prov.items[index];
                        return MisskonAlbumCard(
                          item: item,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MisskonDetailPage(item: item),
                              ),
                            );
                          },
                        );
                      },
                      childCount: prov.items.length,
                    ),
                  ),
                ),

              // Pagination Bar at Bottom
              if (!prov.isLoading && prov.items.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Previous Page
                        BouncingButton(
                          onTap: prov.currentPage > 1 ? () => prov.prevPage() : null,
                          child: FrostedGlass(
                            borderRadius: 14,
                            blur: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            backgroundColor: isDark ? const Color(0x991E1E24) : Colors.white,
                            child: Icon(
                              CupertinoIcons.chevron_left,
                              size: 16,
                              color: prov.currentPage > 1 ? IosTheme.primaryPink : Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Jump Page
                        BouncingButton(
                          onTap: () => _showJumpPageDialog(prov),
                          child: FrostedGlass(
                            borderRadius: 14,
                            blur: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            backgroundColor: isDark ? const Color(0x991E1E24) : Colors.white,
                            child: Text(
                              '第 ${prov.currentPage} / ${prov.totalPages} 页',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Next Page
                        BouncingButton(
                          onTap: prov.currentPage < prov.totalPages ? () => prov.nextPage() : null,
                          child: FrostedGlass(
                            borderRadius: 14,
                            blur: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            backgroundColor: isDark ? const Color(0x991E1E24) : Colors.white,
                            child: Icon(
                              CupertinoIcons.chevron_right,
                              size: 16,
                              color: prov.currentPage < prov.totalPages ? IosTheme.primaryPink : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        ScrollToTopButton(
          scrollController: _scrollController,
          color: IosTheme.primaryPink,
        ),
      ],
    ),
  ),

      // Selection Bottom Bar
      bottomSheet: prov.isSelectionMode
          ? Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    '已选 ${prov.selectedCount} 项',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => prov.selectAll(),
                    child: const Text('全选'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: IosTheme.primaryPink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: prov.selectedCount > 0 ? () => _downloadSelected(prov) : null,
                    child: Text('加入下载 (${prov.selectedCount})'),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
