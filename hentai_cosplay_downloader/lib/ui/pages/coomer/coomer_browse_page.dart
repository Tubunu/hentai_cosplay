import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/coomer_browse_provider.dart';
import '../../../providers/download_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'coomer_detail_page.dart';
import 'widgets/coomer_creator_card.dart';
import 'widgets/coomer_post_card.dart';

class CoomerBrowsePage extends StatefulWidget {
  const CoomerBrowsePage({super.key});

  @override
  State<CoomerBrowsePage> createState() => _CoomerBrowsePageState();
}

class _CoomerBrowsePageState extends State<CoomerBrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<Map<String, String>> _services = [
    {'key': 'all', 'label': '全部平台'},
    {'key': 'onlyfans', 'label': 'OnlyFans'},
    {'key': 'fansly', 'label': 'Fansly'},
    {'key': 'patreon', 'label': 'Patreon'},
    {'key': 'candfans', 'label': 'Candfans'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      final prov = context.read<CoomerBrowseProvider>();
      if (prov.viewMode == CoomerViewMode.posts && !prov.isLoading && prov.hasMore) {
        prov.loadNextPage();
      }
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

  void _onSearchSubmitted(String val) {
    context.read<CoomerBrowseProvider>().setSearchQuery(val);
    _scrollToTop();
  }

  void _downloadSelected(CoomerBrowseProvider prov) {
    final selected = prov.selectedItems;
    if (selected.isEmpty) return;

    final downloadProv = context.read<DownloadProvider>();
    downloadProv.addBatchAlbumTasks(selected);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${selected.length} 条动态加入下载队列'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );
    prov.clearSelection();
  }

  void _showBatchRangeDialog(CoomerBrowseProvider prov) {
    final startController = TextEditingController(text: '${prov.currentPage}');
    final endController = TextEditingController(text: '${prov.currentPage + 2}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(CupertinoIcons.layers_alt_fill, color: IosTheme.primaryPink, size: 22),
            SizedBox(width: 8),
            Text('Coomer 区间批量下载', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('自动解析并下载所选页码区间内的所有动态媒体附件：', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                downloadProv.addCoomerPageRange(
                  start,
                  end,
                  service: prov.selectedService,
                  query: prov.searchQuery,
                  creator: prov.selectedCreator,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已添加第 $start 到 $end 页 Coomer 动态至下载队列'),
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
    final prov = context.watch<CoomerBrowseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: IosTheme.primaryPink,
              edgeOffset: 58.0,
              displacement: 40.0,
              onRefresh: () async {
                await prov.loadData(reset: true);
                HapticFeedback.lightImpact();
              },
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
                            'COOMER.ST',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: const Color(0xFF00AFF0).withValues(alpha: 0.9),
                            ),
                          ),
                          const Text(
                            '创作者专区',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          Text(
                            prov.selectedCreator != null
                                ? '创作者: ${prov.selectedCreator!.name}'
                                : (prov.viewMode == CoomerViewMode.posts ? '全网创作者最新动态与媒体' : '认证创作者名录库'),
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
                          albumSource: MediaSourceType.coomer,
                          isCapsule: true,
                          color: Color(0xFF00AFF0),
                        ),
                        const SizedBox(width: 8),

                        // Batch Range Download Button
                      if (prov.viewMode == CoomerViewMode.posts) ...[
                        BouncingButton(
                          onTap: () => _showBatchRangeDialog(prov),
                          child: FrostedGlass(
                            borderRadius: 16,
                            blur: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            backgroundColor: isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF),
                            child: const Row(
                              children: [
                                Icon(CupertinoIcons.layers_alt_fill, color: Color(0xFF00AFF0), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  '区间批量',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Color(0xFF00AFF0),
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
                    ],
                  ),
                ),
              ),

              // View Mode Selector (Posts / Creators) & Platforms Toolbar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Posts / Creators View Mode Toggle
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0x882C2C2E) : const Color(0x18000000),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: CoomerViewMode.values.map((mode) {
                              final isSel = prov.viewMode == mode;
                              return BouncingButton(
                                onTap: () {
                                  prov.setViewMode(mode);
                                  _scrollToTop();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isSel ? IosTheme.primaryPink : Colors.transparent,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Text(
                                    mode.label,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                      color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Platform Filter Chips
                        ..._services.map((svc) {
                          final isSelected = prov.selectedService == svc['key'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: BouncingButton(
                              onTap: () {
                                _searchController.clear();
                                prov.setService(svc['key']!);
                                _scrollToTop();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF00AFF0)
                                      : (isDark ? const Color(0x662C2C2E) : const Color(0xEEFFFFFF)),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF00AFF0)
                                        : (isDark ? Colors.white12 : Colors.black12),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  svc['label']!,
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

              // Active Creator Filter Pill
              if (prov.selectedCreator != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00AFF0).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00AFF0).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.person_crop_circle_fill, size: 16, color: Color(0xFF00AFF0)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '已筛选创作者: ${prov.selectedCreator!.name} (${prov.selectedCreator!.service.toUpperCase()})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF00AFF0),
                              ),
                            ),
                          ),
                          BouncingButton(
                            onTap: () => prov.clearCreatorFilter(),
                            child: const Icon(CupertinoIcons.clear_circled_solid, size: 16, color: Color(0xFF00AFF0)),
                          ),
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
                        hintText: prov.viewMode == CoomerViewMode.posts ? '搜索动态标题、正文关键词...' : '搜索创作者名称、ID...',
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
              if (prov.isLoading && prov.posts.isEmpty && prov.creators.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CupertinoActivityIndicator(radius: 14),
                    ),
                  ),
                ),

              // Error State
              if (prov.errorMessage != null && !prov.isLoading && prov.posts.isEmpty && prov.creators.isEmpty)
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
                              backgroundColor: const Color(0xFF00AFF0),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => prov.loadData(reset: true),
                            child: const Text('重新加载'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Posts Grid View
              if (prov.viewMode == CoomerViewMode.posts && prov.posts.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.68,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = prov.posts[index];
                        return CoomerPostCard(
                          item: item,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CoomerDetailPage(item: item),
                              ),
                            );
                          },
                        );
                      },
                      childCount: prov.posts.length,
                    ),
                  ),
                ),

              // Creators List View
              if (prov.viewMode == CoomerViewMode.creators && prov.creators.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final creator = prov.creators[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: CoomerCreatorCard(
                            creator: creator,
                            onTap: () => prov.selectCreator(creator),
                          ),
                        );
                      },
                      childCount: prov.creators.length,
                    ),
                  ),
                ),

              // Bottom Loading indicator for infinite scroll
              if (prov.viewMode == CoomerViewMode.posts && prov.isLoading && prov.posts.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CupertinoActivityIndicator(radius: 12),
                    ),
                  ),
                ),

              // End of posts buffer
              if (prov.viewMode == CoomerViewMode.posts && !prov.isLoading && prov.posts.isNotEmpty)
                const SliverToBoxAdapter(
                  child: SizedBox(height: 90),
                ),
            ],
          ),
        ),
        ScrollToTopButton(
          scrollController: _scrollController,
          color: const Color(0xFF00AFF0),
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
