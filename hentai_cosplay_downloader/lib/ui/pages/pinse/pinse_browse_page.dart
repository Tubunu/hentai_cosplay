import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/pinse_browse_provider.dart';
import '../../../services/pinse/pinse_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/log_viewer_modal.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'pinse_detail_page.dart';
import 'widgets/pinse_video_card.dart';

class PinseBrowsePage extends StatefulWidget {
  const PinseBrowsePage({super.key});

  @override
  State<PinseBrowsePage> createState() => _PinseBrowsePageState();
}

class _PinseBrowsePageState extends State<PinseBrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<String> _hotTags = [
    '熟女', '巨乳', '高颜值', '少妇', '阿姨', '内射',
    '学生', '大奶', '偷情', '3P', '人妻', '黑人',
    '舞蹈', '露出', '丝袜', '良家', 'JK', '短发',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prov = context.read<PinseBrowseProvider>();
      if (prov.items.isEmpty && !prov.isLoading && prov.errorMessage == null) {
        prov.loadPage(1);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    context.read<PinseBrowseProvider>().setSearchKeyword(val);
    _scrollToTop();
  }

  void _downloadSelected(PinseBrowseProvider prov) {
    final selected = prov.selectedItems;
    if (selected.isEmpty) return;

    final downloadProv = context.read<DownloadProvider>();
    downloadProv.addBatchVideoTasks(selected);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${selected.length} 个 91品色 视频加入下载队列'),
        backgroundColor: const Color(0xFFFF8C00),
        behavior: SnackBarBehavior.floating,
      ),
    );
    prov.clearSelection();
  }

  void _showJumpPageDialog(PinseBrowseProvider prov) {
    final controller = TextEditingController(text: '${prov.currentPage}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('跳转页码', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '请输入页码 (1-${prov.totalPages})',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C00),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final page = int.tryParse(controller.text.trim());
              if (page != null && page >= 1 && page <= prov.totalPages) {
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

  void _showBatchRangeDialog(PinseBrowseProvider prov) {
    final startController = TextEditingController(text: '${prov.currentPage}');
    final endController = TextEditingController(
      text: '${(prov.currentPage + 2).clamp(1, prov.totalPages)}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(CupertinoIcons.layers_alt_fill, color: Color(0xFFFF8C00), size: 22),
            SizedBox(width: 8),
            Text('91品色 区间批量下载', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('自动解析并下载所选页码区间内的所有视频：', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
              backgroundColor: const Color(0xFFFF8C00),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final start = int.tryParse(startController.text.trim());
              final end = int.tryParse(endController.text.trim());
              if (start != null && end != null && start <= end && start >= 1) {
                Navigator.pop(ctx);
                final downloadProv = context.read<DownloadProvider>();
                downloadProv.addPinsePageRange(
                  start,
                  end,
                  category: prov.category,
                  keyword: prov.searchKeyword,
                  author: prov.selectedAuthor,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已添加第 $start 到 $end 页 91品色 视频至下载队列'),
                    backgroundColor: const Color(0xFFFF8C00),
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
    final prov = context.watch<PinseBrowseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: const Color(0xFFFF8C00),
              edgeOffset: 58.0,
              displacement: 40.0,
              onRefresh: () async {
                await prov.loadPage(prov.currentPage);
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
                            '91PINSE.COM',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: const Color(0xFFFF8C00).withValues(alpha: 0.9),
                            ),
                          ),
                          const Text(
                            '91品色原创',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          Text(
                            prov.isAuthorActive
                                ? '作者: ${prov.selectedAuthor}'
                                : (prov.isSearchActive ? '搜索: ${prov.searchKeyword}' : '华人高清原创成人视频分享社区'),
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
                      const RandomActionButton.video(
                        videoSite: VideoSiteType.pinse,
                        isCapsule: true,
                        color: Color(0xFFFF8C00),
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
                              Icon(CupertinoIcons.layers_alt_fill, color: Color(0xFFFF8C00), size: 16),
                              SizedBox(width: 6),
                              Text(
                                '区间批量',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Color(0xFFFF8C00),
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
                              ? const Color(0xFFFF8C00)
                              : (isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF)),
                          child: Icon(
                            prov.isSelectionMode
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.checkmark_circle,
                            color: prov.isSelectionMode ? Colors.white : const Color(0xFFFF8C00),
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Diagnostic Log Viewer Button
                      BouncingButton(
                        onTap: () => LogViewerModal.show(context, initialFilter: '91品色'),
                        child: FrostedGlass(
                          borderRadius: 16,
                          blur: 15,
                          padding: const EdgeInsets.all(8),
                          backgroundColor: isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF),
                          child: const Icon(
                            CupertinoIcons.doc_text_search,
                            color: Color(0xFF0A84FF),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Categories Selector & Hot Tags Toolbar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Category Dropdown Button
                        PopupMenuButton<PinseCategory>(
                          initialValue: prov.category,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          onSelected: (cat) {
                            _searchController.clear();
                            prov.setCategory(cat);
                            _scrollToTop();
                          },
                          itemBuilder: (ctx) => PinseCategory.values.map((cat) {
                            return PopupMenuItem<PinseCategory>(
                              value: cat,
                              child: Row(
                                children: [
                                  Icon(
                                    prov.category == cat ? CupertinoIcons.checkmark_alt : null,
                                    size: 16,
                                    color: const Color(0xFFFF8C00),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    cat.label,
                                    style: TextStyle(
                                      fontWeight: prov.category == cat ? FontWeight.w800 : FontWeight.w500,
                                      color: prov.category == cat ? const Color(0xFFFF8C00) : null,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          child: FrostedGlass(
                            borderRadius: 14,
                            blur: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            backgroundColor: const Color(0xFFFF8C00).withValues(alpha: 0.15),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.slider_horizontal_3, size: 14, color: Color(0xFFFF8C00)),
                                const SizedBox(width: 5),
                                Text(
                                  prov.category.label,
                                  style: const TextStyle(
                                    color: Color(0xFFFF8C00),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(CupertinoIcons.chevron_down, size: 12, color: Color(0xFFFF8C00)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Hot Tags
                        ..._hotTags.map((tag) {
                          final isSelected = prov.searchKeyword == tag;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: BouncingButton(
                              onTap: () {
                                _searchController.text = tag;
                                prov.setSearchKeyword(tag);
                                _scrollToTop();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFF8C00)
                                      : (isDark ? const Color(0x662C2C2E) : const Color(0xEEFFFFFF)),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFFFF8C00) : (isDark ? Colors.white12 : Colors.black12),
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

              // Active Author Filter Pill
              if (prov.isAuthorActive)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8C00).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF8C00).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.person_crop_circle_fill, size: 16, color: Color(0xFFFF8C00)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '已筛选作者: ${prov.selectedAuthor}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF8C00),
                              ),
                            ),
                          ),
                          BouncingButton(
                            onTap: () => prov.clearAuthor(),
                            child: const Icon(CupertinoIcons.clear_circled_solid, size: 16, color: Color(0xFFFF8C00)),
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
                        hintText: '搜索 91品色 视频标题、关键词...',
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

              // Loading State
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF8C00),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () => prov.loadPage(prov.currentPage),
                                icon: const Icon(CupertinoIcons.refresh, size: 15),
                                label: const Text('重新加载'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0A84FF),
                                  side: const BorderSide(color: Color(0xFF0A84FF)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () => LogViewerModal.show(context, initialFilter: '91品色'),
                                icon: const Icon(CupertinoIcons.doc_text_search, size: 15),
                                label: const Text('查看网络诊断日志'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Videos Grid View
              if (!prov.isLoading && prov.items.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = prov.items[index];
                        return PinseVideoCard(
                          item: item,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PinseDetailPage(item: item),
                              ),
                            );
                          },
                        );
                      },
                      childCount: prov.items.length,
                    ),
                  ),
                ),

              // Pagination Bar
              if (!prov.isLoading && prov.items.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Previous Page Button
                        BouncingButton(
                          onTap: prov.currentPage > 1
                              ? () {
                                  prov.prevPage();
                                  _scrollToTop();
                                }
                              : null,
                          child: FrostedGlass(
                            borderRadius: 14,
                            blur: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            backgroundColor: prov.currentPage > 1
                                ? (isDark ? const Color(0x9924242A) : Colors.white)
                                : (isDark ? const Color(0x3324242A) : const Color(0x88FFFFFF)),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.chevron_left,
                                  size: 14,
                                  color: prov.currentPage > 1 ? const Color(0xFFFF8C00) : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '上一页',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: prov.currentPage > 1 ? const Color(0xFFFF8C00) : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Jump to page pill
                        BouncingButton(
                          onTap: () => _showJumpPageDialog(prov),
                          child: FrostedGlass(
                            borderRadius: 14,
                            blur: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            backgroundColor: isDark ? const Color(0x9924242A) : Colors.white,
                            child: Text(
                              '${prov.currentPage} / ${prov.totalPages} 页',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Next Page Button
                        BouncingButton(
                          onTap: prov.currentPage < prov.totalPages
                              ? () {
                                  prov.nextPage();
                                  _scrollToTop();
                                }
                              : null,
                          child: FrostedGlass(
                            borderRadius: 14,
                            blur: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            backgroundColor: prov.currentPage < prov.totalPages
                                ? (isDark ? const Color(0x9924242A) : Colors.white)
                                : (isDark ? const Color(0x3324242A) : const Color(0x88FFFFFF)),
                            child: Row(
                              children: [
                                Text(
                                  '下一页',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: prov.currentPage < prov.totalPages ? const Color(0xFFFF8C00) : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 14,
                                  color: prov.currentPage < prov.totalPages ? const Color(0xFFFF8C00) : Colors.grey,
                                ),
                              ],
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
          color: const Color(0xFFFF8C00),
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
                      backgroundColor: const Color(0xFFFF8C00),
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
