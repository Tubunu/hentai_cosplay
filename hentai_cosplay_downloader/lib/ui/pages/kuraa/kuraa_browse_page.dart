import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/kuraa_browse_provider.dart';
import '../../../services/kuraa/kuraa_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'kuraa_detail_page.dart';
import 'widgets/kuraa_item_card.dart';

class KuraaBrowsePage extends StatefulWidget {
  const KuraaBrowsePage({super.key});

  @override
  State<KuraaBrowsePage> createState() => _KuraaBrowsePageState();
}

class _KuraaBrowsePageState extends State<KuraaBrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _breadcrumbScrollController = ScrollController();

  static const Color _themeColor = Color(0xFF00897B);

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _breadcrumbScrollController.dispose();
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
    context.read<KuraaBrowseProvider>().setSearchKeyword(val);
    _scrollToTop();
  }

  void _downloadSelected(KuraaBrowseProvider prov) {
    final selected = prov.selectedItems;
    if (selected.isEmpty) return;

    final downloadProv = context.read<DownloadProvider>();
    for (final item in selected) {
      if (item.isFolder) {
        // Fetch and download album
        downloadProv.addKuraaAlbumTask(item, token: prov.activeToken);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将选中的 ${selected.length} 个项目加入下载队列'),
        backgroundColor: _themeColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
    prov.clearSelection();
  }

  void _showJumpPageDialog(KuraaBrowseProvider prov) {
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
            style: ElevatedButton.styleFrom(backgroundColor: _themeColor, foregroundColor: Colors.white),
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

  void _showUnlockDialog(KuraaBrowseProvider prov) {
    final controller = TextEditingController(text: KuraaApiService.defaultInnerPassword);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(CupertinoIcons.lock_shield_fill, color: _themeColor, size: 22),
            SizedBox(width: 8),
            Text('内板密码验证', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请输入 Kuraa 内板访问密码 (默认: kuraa.cc)：', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '内板密码',
                border: OutlineInputBorder(),
                prefixIcon: Icon(CupertinoIcons.lock, size: 16),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _themeColor, foregroundColor: Colors.white),
            onPressed: () async {
              final pwd = controller.text.trim();
              if (pwd.isNotEmpty) {
                Navigator.pop(ctx);
                final success = await prov.unlockLocation('4', pwd);
                if (success) {
                  prov.loadPage(1);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('内板解锁成功'),
                      backgroundColor: _themeColor,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('验证解锁'),
          ),
        ],
      ),
    );
  }

  void _showBatchRangeDialog(KuraaBrowseProvider prov) {
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
            Icon(CupertinoIcons.layers_alt_fill, color: _themeColor, size: 22),
            SizedBox(width: 8),
            Text('Kuraa 区间批量下载', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('自动扫描并下载所选页码区间内的所有相册套图：', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
            style: ElevatedButton.styleFrom(backgroundColor: _themeColor, foregroundColor: Colors.white),
            onPressed: () {
              final start = int.tryParse(startController.text.trim());
              final end = int.tryParse(endController.text.trim());
              if (start != null && end != null && start <= end && start >= 1) {
                Navigator.pop(ctx);
                final downloadProv = context.read<DownloadProvider>();
                downloadProv.addKuraaPageRange(
                  start,
                  end,
                  storageLocationId: prov.activeLocationId,
                  parentId: prov.currentFolder.id,
                  token: prov.activeToken,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已添加第 $start 到 $end 页 Kuraa 相册至下载队列'),
                    backgroundColor: _themeColor,
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

  void _onItemTap(KuraaBrowseProvider prov, KuraaFileItem item) {
    if (item.isFolder) {
      // If it looks like a leaf album with page count like 35P, open detail page
      final isLeafAlbum = RegExp(r'(\d+)\s*P', caseSensitive: false).hasMatch(item.name);
      if (isLeafAlbum) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => KuraaDetailPage(
              folderItem: item,
              token: prov.activeToken,
            ),
          ),
        );
      } else {
        // Enter directory
        _searchController.clear();
        prov.enterFolder(item);
        _scrollToTop();
      }
    } else if (item.isImage) {
      // Find all image items in current folder/view
      final imageItems = prov.items.where((i) => i.isImage).toList();
      final currentIndex = imageItems.indexOf(item);
      final validInitialIndex = currentIndex >= 0 ? currentIndex : 0;
      final imageUrls = imageItems
          .map((i) => i.downloadUrl.isNotEmpty ? i.downloadUrl : i.previewUrl)
          .where((u) => u.isNotEmpty)
          .toList();

      if (imageUrls.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => KuraaPhotoGalleryView(
              imageUrls: imageUrls,
              initialIndex: validInitialIndex,
              title: item.name,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<KuraaBrowseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: _themeColor,
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
                          const Text(
                            'KURAA.CC',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Color(0xFF26A69A),
                            ),
                          ),
                          const Text(
                            'Kuraa 云盘图库',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          Text(
                            prov.isInnerBoard ? '🔒 内板独家专区 (密码: kuraa.cc)' : '☁️ 公开资源 (公开浏览图库)',
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
                      RandomActionButton.album(
                        albumSource: MediaSourceType.kuraa,
                        isCapsule: true,
                        color: _themeColor,
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
                              Icon(CupertinoIcons.layers_alt_fill, color: _themeColor, size: 16),
                              SizedBox(width: 6),
                              Text(
                                '区间批量',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: _themeColor,
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
                              ? _themeColor
                              : (isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF)),
                          child: Icon(
                            prov.isSelectionMode
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.checkmark_circle,
                            color: prov.isSelectionMode ? Colors.white : _themeColor,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Location Switcher Segment (公开资源 vs 内板)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
                  child: Row(
                    children: [
                      // 公开资源 Pill
                      Expanded(
                        child: BouncingButton(
                          onTap: () {
                            _searchController.clear();
                            prov.switchLocation('2');
                            _scrollToTop();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !prov.isInnerBoard
                                  ? _themeColor
                                  : (isDark ? const Color(0x662C2C2E) : const Color(0xEEFFFFFF)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: !prov.isInnerBoard ? _themeColor : (isDark ? Colors.white12 : Colors.black12),
                                width: 0.5,
                              ),
                              boxShadow: !prov.isInnerBoard
                                  ? [
                                      BoxShadow(
                                        color: _themeColor.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.cloud_fill,
                                  size: 14,
                                  color: !prov.isInnerBoard ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '☁️ 公开资源',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: !prov.isInnerBoard ? FontWeight.w800 : FontWeight.w600,
                                    color: !prov.isInnerBoard ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 内板 Pill
                      Expanded(
                        child: BouncingButton(
                          onTap: () {
                            _searchController.clear();
                            prov.switchLocation('4');
                            _scrollToTop();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: prov.isInnerBoard
                                  ? _themeColor
                                  : (isDark ? const Color(0x662C2C2E) : const Color(0xEEFFFFFF)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: prov.isInnerBoard ? _themeColor : (isDark ? Colors.white12 : Colors.black12),
                                width: 0.5,
                              ),
                              boxShadow: prov.isInnerBoard
                                  ? [
                                      BoxShadow(
                                        color: _themeColor.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.lock_fill,
                                  size: 14,
                                  color: prov.isInnerBoard ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '🔒 内板 (达盖尔)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: prov.isInnerBoard ? FontWeight.w800 : FontWeight.w600,
                                    color: prov.isInnerBoard ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Unlock Key / Reset Password button for inner board
                      if (prov.isInnerBoard) ...[
                        const SizedBox(width: 6),
                        BouncingButton(
                          onTap: () => _showUnlockDialog(prov),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _themeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(CupertinoIcons.lock_shield_fill, color: _themeColor, size: 16),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Breadcrumb Path Navigation
              if (prov.navigationStack.length > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
                    child: SingleChildScrollView(
                      controller: _breadcrumbScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          // Back Arrow Button
                          BouncingButton(
                            onTap: () {
                              prov.navigateBack();
                              _scrollToTop();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: _themeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  Icon(CupertinoIcons.arrow_left, size: 12, color: _themeColor),
                                  SizedBox(width: 4),
                                  Text(
                                    '返回上级',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _themeColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Breadcrumb items
                          ...List.generate(prov.navigationStack.length, (idx) {
                            final nav = prov.navigationStack[idx];
                            final isLast = idx == prov.navigationStack.length - 1;
                            return Row(
                              children: [
                                if (idx > 0)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(CupertinoIcons.chevron_right, size: 10, color: Colors.grey),
                                  ),
                                BouncingButton(
                                  onTap: !isLast
                                      ? () {
                                          prov.navigateToIndex(idx);
                                          _scrollToTop();
                                        }
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isLast
                                          ? _themeColor.withValues(alpha: 0.2)
                                          : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      nav.name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
                                        color: isLast ? _themeColor : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
                        hintText: '搜索 ${prov.isInnerBoard ? "内板" : "公开资源"} 文件/相册名称...',
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
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _themeColor,
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

              // Items Grid View
              if (!prov.isLoading && prov.items.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.76,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = prov.items[index];
                        return KuraaItemCard(
                          item: item,
                          onTap: () => _onItemTap(prov, item),
                        );
                      },
                      childCount: prov.items.length,
                    ),
                  ),
                ),

              // Pagination Bar
              if (!prov.isLoading && prov.items.isNotEmpty && prov.totalPages > 1)
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
                                  color: prov.currentPage > 1 ? _themeColor : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '上一页',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: prov.currentPage > 1 ? _themeColor : Colors.grey,
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
                                    color: prov.currentPage < prov.totalPages ? _themeColor : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 14,
                                  color: prov.currentPage < prov.totalPages ? _themeColor : Colors.grey,
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
          color: _themeColor,
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
                      backgroundColor: _themeColor,
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
