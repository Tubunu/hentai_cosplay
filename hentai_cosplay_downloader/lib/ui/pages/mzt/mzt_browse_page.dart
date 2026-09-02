import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/album_item.dart';
import '../../../models/download_task.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/history_provider.dart';
import '../../../providers/mzt_browse_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'mzt_detail_page.dart';

class MztBrowsePage extends StatefulWidget {
  const MztBrowsePage({super.key});

  @override
  State<MztBrowsePage> createState() => _MztBrowsePageState();
}

class _MztBrowsePageState extends State<MztBrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pageJumpController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prov = context.read<MztBrowseProvider>();
      if (prov.items.isEmpty && !prov.isLoading && prov.errorMessage == null) {
        prov.loadPage(1);
      }
    });
  }

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

  void _downloadSingle(AlbumItem item) {
    final downloadProv = context.read<DownloadProvider>();
    downloadProv.addAlbumTask(item);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 "${item.title}" 到下载队列'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _downloadSelected(MztBrowseProvider mztProv) {
    final selected = mztProv.selectedItems;
    if (selected.isEmpty) return;

    final downloadProv = context.read<DownloadProvider>();
    downloadProv.addBatchAlbumTasks(selected);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${selected.length} 个选中妹子图包加入下载队列'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );
    mztProv.clearSelection();
  }

  void _showJumpPageDialog(MztBrowseProvider mztProv) {
    _pageJumpController.text = mztProv.currentPage.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('跳转页码', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('请输入 1 ~ ${mztProv.totalPages} 之间的页码：'),
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
                mztProv.loadPage(page);
                _scrollToTop();
              }
            },
            child: const Text('跳转'),
          ),
        ],
      ),
    );
  }

  void _showBatchDownloadDialog(MztBrowseProvider mztProv) {
    final startCtrl = TextEditingController(text: mztProv.currentPage.toString());
    final endCtrl = TextEditingController(
      text: (mztProv.currentPage + 4).clamp(1, mztProv.totalPages > 0 ? mztProv.totalPages : 1).toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(CupertinoIcons.layers_alt_fill, color: IosTheme.primaryPink, size: 22),
            SizedBox(width: 8),
            Text('妹子图区间批量下载', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '将自动抓取指定起止页码内的所有图包并加入下载队列：',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '起始页',
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('至', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: TextField(
                    controller: endCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '结束页',
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final start = int.tryParse(startCtrl.text.trim());
              final end = int.tryParse(endCtrl.text.trim());
              if (start != null && end != null && start > 0 && end >= start) {
                Navigator.pop(ctx);
                context.read<DownloadProvider>().addMztPageRange(start, end);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已启动第 $start 页到第 $end 页的妹子图批量抓取...'),
                    backgroundColor: IosTheme.primaryPink,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('开始批量抓取'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mztProv = context.watch<MztBrowseProvider>();
    final settingsProv = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final proxyDomains = settingsProv.config.mztProxyDomains;

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
                await mztProv.loadPage(mztProv.currentPage);
                HapticFeedback.lightImpact();
              },
              child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Hero Header
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
                            'MZITU MEIZITU',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: IosTheme.primaryPink.withValues(alpha: 0.9),
                            ),
                          ),
                          const Text(
                            '妹子图库',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          if (mztProv.totalPages > 1)
                            Text(
                              '共收录 ${mztProv.totalPages} 页图包 (${mztProv.totalItems} 套)',
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
                        albumSource: MediaSourceType.mzt,
                        isCapsule: true,
                        color: IosTheme.primaryPink,
                      ),
                      const SizedBox(width: 8),

                      // Batch Range Download Button
                      BouncingButton(
                        onTap: () => _showBatchDownloadDialog(mztProv),
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
                        onTap: () => mztProv.toggleSelectionMode(),
                        child: FrostedGlass(
                          borderRadius: 16,
                          blur: 15,
                          padding: const EdgeInsets.all(8),
                          backgroundColor: mztProv.isSelectionMode
                              ? IosTheme.primaryPink
                              : (isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF)),
                          child: Icon(
                            mztProv.isSelectionMode
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.checkmark_circle,
                            color: mztProv.isSelectionMode ? Colors.white : IosTheme.primaryPink,
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: '在当前页搜索图包或作者...',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    onChanged: mztProv.setSearchQuery,
                    onSuffixTap: () {
                      _searchController.clear();
                      mztProv.setSearchQuery('');
                    },
                  ),
                ),
              ),

              // Selection Mode Action Bar
              if (mztProv.isSelectionMode)
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
                            '已选择 ${mztProv.selectedCount} 个图包',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: IosTheme.primaryPink,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: mztProv.selectAllCurrentPage,
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
                            onPressed: mztProv.selectedCount > 0
                                ? () => _downloadSelected(mztProv)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Content Grid or Loading / Error
              if (mztProv.isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CupertinoActivityIndicator(radius: 16),
                        SizedBox(height: 14),
                        Text('正在加载妹子图列表...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else if (mztProv.errorMessage != null)
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
                            mztProv.errorMessage!,
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
                            onPressed: () => mztProv.loadPage(mztProv.currentPage),
                            child: const Text('重新加载'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (mztProv.items.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text('没有找到相关妹子图包', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = mztProv.items[index];
                        final isSelected = mztProv.isPackSelected(item);

                        // Resolve cover URL using proxy domain if relative
                        String? coverUrl = item.coverUrl;
                        if (coverUrl != null && coverUrl.startsWith('/')) {
                          final domain = proxyDomains.isNotEmpty
                              ? proxyDomains.first.replaceAll(RegExp(r'/+$'), '')
                              : 'https://tgproxy.1258012.xyz';
                          coverUrl = '$domain$coverUrl';
                        }

                        return _MztPackCard(
                          item: item,
                          resolvedCoverUrl: coverUrl,
                          isSelected: isSelected,
                          isSelectionMode: mztProv.isSelectionMode,
                          onTap: () {
                            if (mztProv.isSelectionMode) {
                              mztProv.togglePackSelection(item);
                            } else {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => MztDetailPage(item: item),
                                ),
                              );
                            }
                          },
                          onLongPress: () {
                            mztProv.toggleSelectionMode(true);
                            mztProv.togglePackSelection(item);
                          },
                          onDownload: () => _downloadSingle(item),
                        );
                      },
                      childCount: mztProv.items.length,
                      addAutomaticKeepAlives: true,
                      addRepaintBoundaries: true,
                    ),
                  ),
                ),

              // Pagination Bar
              if (!mztProv.isLoading && mztProv.items.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BouncingButton(
                          onTap: mztProv.currentPage > 1
                              ? () {
                                  mztProv.previousPage();
                                  _scrollToTop();
                                }
                              : null,
                          child: FrostedGlass(
                            borderRadius: 16,
                            blur: 20,
                            padding: const EdgeInsets.all(12),
                            backgroundColor: mztProv.currentPage > 1
                                ? (isDark ? const Color(0x9928282E) : const Color(0xDDFFFFFF))
                                : Colors.transparent,
                            child: Icon(
                              CupertinoIcons.chevron_left,
                              size: 18,
                              color: mztProv.currentPage > 1
                                  ? IosTheme.primaryPink
                                  : Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                        ),

                        const SizedBox(width: 14),

                        BouncingButton(
                          onTap: () => _showJumpPageDialog(mztProv),
                          child: FrostedGlass(
                            borderRadius: 18,
                            blur: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            backgroundColor: isDark ? const Color(0x9928282E) : const Color(0xDDFFFFFF),
                            child: Row(
                              children: [
                                Text(
                                  '第 ${mztProv.currentPage} / ${mztProv.totalPages} 页',
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

                        BouncingButton(
                          onTap: mztProv.currentPage < mztProv.totalPages
                              ? () {
                                  mztProv.nextPage();
                                  _scrollToTop();
                                }
                              : null,
                          child: FrostedGlass(
                            borderRadius: 16,
                            blur: 20,
                            padding: const EdgeInsets.all(12),
                            backgroundColor: mztProv.currentPage < mztProv.totalPages
                                ? (isDark ? const Color(0x9928282E) : const Color(0xDDFFFFFF))
                                : Colors.transparent,
                            child: Icon(
                              CupertinoIcons.chevron_right,
                              size: 18,
                              color: mztProv.currentPage < mztProv.totalPages
                                  ? IosTheme.primaryPink
                                  : Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Dynamic Bottom Spacer
              SliverToBoxAdapter(
                child: SizedBox(
                  height: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 210 : 130,
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
);
  }
}

class _MztPackCard extends StatelessWidget {
  final AlbumItem item;
  final String? resolvedCoverUrl;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDownload;

  const _MztPackCard({
    required this.item,
    required this.resolvedCoverUrl,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if album is in download queue or already in completed history
    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == item.slug || t.albumItem.title == item.title) {
          return t;
        }
      }
      return null;
    });

    final isHistoryRecorded = context.select<HistoryProvider, bool>((p) {
      return p.records.any((r) => r.id == item.slug || r.title == item.title);
    });

    final isCompleted = existingTask?.status == TaskStatus.completed || isHistoryRecorded;

    return BouncingButton(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDark ? const Color(0xFF1E1E22) : Colors.white,
          border: Border.all(
            color: isSelected
                ? IosTheme.primaryPink
                : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
            width: isSelected ? 2.0 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? IosTheme.primaryPink.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover Image
              if (resolvedCoverUrl != null && resolvedCoverUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: resolvedCoverUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 450,
                  httpHeaders: const {'Referer': 'https://mzt.111404.xyz/'},
                  placeholder: (_, __) => Container(
                    color: isDark ? const Color(0xFF242428) : const Color(0xFFECECF0),
                    child: const Center(child: CupertinoActivityIndicator(radius: 10)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: isDark ? const Color(0xFF242428) : const Color(0xFFECECF0),
                    child: const Center(child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 28)),
                  ),
                )
              else
                Container(
                  color: isDark ? const Color(0xFF242428) : const Color(0xFFECECF0),
                  child: const Center(child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 28)),
                ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.88),
                      ],
                      stops: const [0.4, 0.65, 1.0],
                    ),
                  ),
                ),
              ),

              // Image Count Badge (Top Left)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.photo, size: 10, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        '${item.imageUrls.length}P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Top Right: Selection checkmark OR Download Status Badge / MZT Tag
              Positioned(
                top: 8,
                right: 8,
                child: isSelectionMode
                    ? Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected ? IosTheme.primaryPink : Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: isSelected
                            ? const Icon(CupertinoIcons.checkmark, size: 14, color: Colors.white)
                            : null,
                      )
                    : (isCompleted
                        ? Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: IosTheme.primaryGreen.withValues(alpha: 0.95),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: IosTheme.primaryGreen.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(CupertinoIcons.checkmark_alt, size: 14, color: Colors.white),
                          )
                        : (existingTask != null
                            ? _buildTaskStatusBadge(existingTask)
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: IosTheme.primaryPink,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'MZT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ))),
              ),

              // Bottom Title & Action
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!isSelectionMode)
                          BouncingButton(
                            onTap: onDownload,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: isCompleted ? IosTheme.primaryGreen : IosTheme.primaryPink,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isCompleted ? IosTheme.primaryGreen : IosTheme.primaryPink)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isCompleted ? CupertinoIcons.check_mark : CupertinoIcons.arrow_down_to_line,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskStatusBadge(AlbumDownloadTask task) {
    Color bg;
    IconData icon;

    switch (task.status) {
      case TaskStatus.completed:
        bg = IosTheme.primaryGreen;
        icon = CupertinoIcons.checkmark_alt;
        break;
      case TaskStatus.downloading:
        bg = IosTheme.primaryPink;
        icon = CupertinoIcons.arrow_down;
        break;
      case TaskStatus.queued:
        bg = IosTheme.primaryBlue;
        icon = CupertinoIcons.clock;
        break;
      case TaskStatus.failed:
        bg = Colors.red;
        icon = CupertinoIcons.exclamationmark;
        break;
      case TaskStatus.paused:
        bg = Colors.orange;
        icon = CupertinoIcons.pause;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.5),
            blurRadius: 6,
          ),
        ],
      ),
      child: Icon(icon, size: 14, color: Colors.white),
    );
  }
}
