import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/exhentai_browse_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/exhentai/exhentai_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../exhentai/widgets/ex_gallery_card.dart';
import '../exhentai/exhentai_detail_page.dart';

class ExHentaiBrowsePage extends StatefulWidget {
  const ExHentaiBrowsePage({super.key});

  @override
  State<ExHentaiBrowsePage> createState() => _ExHentaiBrowsePageState();
}

class _ExHentaiBrowsePageState extends State<ExHentaiBrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isGrid = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<ExHentaiBrowseProvider>();
      if (prov.items.isEmpty) {
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
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _showSourceDialog(BuildContext context, ExHentaiBrowseProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(CupertinoIcons.globe, color: Color(0xFF9C27B0), size: 22),
                        SizedBox(width: 8),
                        Text(
                          '选择 ExHentai 线路 / 镜像站',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...ExSourceServer.values.map((source) {
                  final isSelected = provider.currentSource == source && provider.customSourceUrl.isEmpty;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF9C27B0).withValues(alpha: isDark ? 0.2 : 0.1)
                          : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF9C27B0).withValues(alpha: 0.5) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: Icon(
                        isSelected ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                        color: isSelected ? const Color(0xFF9C27B0) : Colors.grey,
                      ),
                      title: Text(
                        source.label,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? const Color(0xFF9C27B0) : null,
                        ),
                      ),
                      subtitle: Text(
                        source == ExSourceServer.mirror810114 ? '${source.baseUrl} (国内推荐/免翻墙)' : source.baseUrl,
                        style: TextStyle(
                          fontSize: 12,
                          color: source == ExSourceServer.mirror810114 ? Colors.green : Colors.grey,
                          fontWeight: source == ExSourceServer.mirror810114 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        provider.setSource(source);
                        Navigator.pop(ctx);
                        _scrollToTop();
                      },
                    ),
                  );
                }),
                const Divider(),
                Container(
                  decoration: BoxDecoration(
                    color: provider.customSourceUrl.isNotEmpty
                        ? const Color(0xFF9C27B0).withValues(alpha: isDark ? 0.2 : 0.1)
                        : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: const Icon(CupertinoIcons.link, color: Color(0xFF9C27B0)),
                    title: const Text('自定义镜像站 URL', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      provider.customSourceUrl.isNotEmpty ? provider.customSourceUrl : '点击设置自定义代理/镜像地址',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCustomMirrorDialog(context, provider);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCustomMirrorDialog(BuildContext context, ExHentaiBrowseProvider provider) {
    final c = TextEditingController(text: provider.customSourceUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置自定义镜像站'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
            hintText: 'https://ex.example.com',
            labelText: '镜像站 URL (支持 http/https)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = c.text.trim();
              if (url.isNotEmpty) {
                provider.setSource(ExSourceServer.mirror810114, customUrl: url);
                _scrollToTop();
              }
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showJumpPageDialog(BuildContext context, ExHentaiBrowseProvider provider) {
    final c = TextEditingController(text: '${provider.page}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('跳转页码'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '输入目标页码 (当前第 ${provider.page} 页)',
            hintText: '1 ~ ${provider.totalPages > 1 ? provider.totalPages : 100}',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(c.text.trim());
              if (val != null && val >= 1) {
                provider.jumpToPage(val);
                _scrollToTop();
              }
              Navigator.pop(ctx);
            },
            child: const Text('跳转'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFF9C27B0);
    final provider = context.watch<ExHentaiBrowseProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: themeColor,
              edgeOffset: 58.0,
              displacement: 40.0,
              onRefresh: () async {
                await provider.refresh();
                HapticFeedback.lightImpact();
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // 1. Top Safe Spacing for Floating Segmented Capsule Bar (54px)
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 54),
                  ),

                  // 2. Header Title & Mirror Switcher (Scrolls WITH the page)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          const Text(
                            'ExHentai 画廊',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),

                          // Mirror Switcher Capsule
                          BouncingButton(
                            onTap: () => _showSourceDialog(context, provider),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: isDark ? 0.25 : 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: themeColor.withValues(alpha: 0.45), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(CupertinoIcons.globe, size: 13, color: themeColor),
                                  const SizedBox(width: 5),
                                  Text(
                                    provider.customSourceUrl.isNotEmpty
                                        ? '自定义镜像'
                                        : provider.currentSource.label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: themeColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(CupertinoIcons.chevron_down, size: 11, color: themeColor),
                                ],
                              ),
                            ),
                          ),

                          const Spacer(),

                          // Random discovery button
                          RandomActionButton.album(
                            albumSource: MediaSourceType.exhentai,
                            isCapsule: true,
                            color: themeColor,
                          ),
                          const SizedBox(width: 4),

                          // Grid/List toggle
                          IconButton(
                            icon: Icon(_isGrid ? CupertinoIcons.list_bullet : CupertinoIcons.square_grid_2x2),
                            onPressed: () => setState(() => _isGrid = !_isGrid),
                          ),
                          // Multi-select toggle
                          IconButton(
                            icon: Icon(
                              provider.isSelectionMode ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.checkmark_circle,
                              color: provider.isSelectionMode ? themeColor : null,
                            ),
                            onPressed: () => provider.toggleSelectionMode(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Search Bar (Scrolls WITH the page)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                            width: 0.5,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              provider.search(val.trim());
                              _scrollToTop();
                            }
                          },
                          decoration: InputDecoration(
                            hintText: '搜索同人志 / 漫画 / 画师 / 标签...',
                            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                            prefixIcon: const Icon(CupertinoIcons.search, size: 18, color: Colors.grey),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16, color: Colors.grey),
                                    onPressed: () {
                                      _searchController.clear();
                                      provider.clearSearch();
                                      _scrollToTop();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 4. Category Chips (Scrolls WITH the page)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        children: [
                          // Popular chip
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FilterChip(
                              selected: provider.isPopular,
                              label: const Text('今日热门 🔥'),
                              selectedColor: Colors.orange.withValues(alpha: 0.25),
                              checkmarkColor: Colors.orange,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: provider.isPopular ? FontWeight.bold : FontWeight.normal,
                                color: provider.isPopular ? Colors.orange : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              onSelected: (selected) {
                                provider.setPopular(selected);
                                _scrollToTop();
                              },
                            ),
                          ),
                          ...ExCategory.values.map((cat) {
                            final isSelected = !provider.isPopular && provider.currentCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FilterChip(
                                selected: isSelected,
                                label: Text(cat.label),
                                selectedColor: themeColor.withValues(alpha: 0.25),
                                checkmarkColor: themeColor,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? themeColor : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                onSelected: (_) {
                                  provider.setCategory(cat);
                                  _scrollToTop();
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  // 5. Content Area
                  _buildContentSliver(context, provider, isDark),

                  // 6. Pagination Bar
                  if (provider.items.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Prev Button
                            BouncingButton(
                              onTap: provider.page > 1
                                  ? () {
                                      provider.prevPage();
                                      _scrollToTop();
                                    }
                                  : () {},
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: provider.page > 1
                                      ? (isDark ? const Color(0xFF1C1C1E) : Colors.white)
                                      : (isDark ? Colors.black26 : Colors.black12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  '上一页',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: provider.page > 1 ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Jump Page Indicator
                            BouncingButton(
                              onTap: () => _showJumpPageDialog(context, provider),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: themeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 0.8),
                                ),
                                child: Text(
                                  '第 ${provider.page} / ${provider.totalPages} 页',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF9C27B0),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Next Button
                            BouncingButton(
                              onTap: (provider.page < provider.totalPages || provider.hasMore)
                                  ? () {
                                      provider.nextPage();
                                      _scrollToTop();
                                    }
                                  : () {},
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: (provider.page < provider.totalPages || provider.hasMore)
                                      ? (isDark ? const Color(0xFF1C1C1E) : Colors.white)
                                      : (isDark ? Colors.black26 : Colors.black12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  '下一页',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: (provider.page < provider.totalPages || provider.hasMore)
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Bottom safe spacer for floating bottom navigation bar
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 220 : 140,
                    ),
                  ),
                ],
              ),
            ),

            // Floating Scroll to Top Button
            ScrollToTopButton(
              scrollController: _scrollController,
              color: themeColor,
            ),

            // Bottom Batch Download Bar
            if (provider.isSelectionMode && provider.selectedCount > 0)
              Positioned(
                left: 16,
                right: 16,
                bottom: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 145 : 85,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        '已选 ${provider.selectedCount} 项',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => provider.selectAll(),
                        child: const Text('全选本页'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                        icon: const Icon(CupertinoIcons.cloud_download, size: 18, color: Colors.white),
                        label: const Text('批量下载', style: TextStyle(color: Colors.white)),
                        onPressed: () {
                          final items = provider.selectedItems;
                          final dlProv = context.read<DownloadProvider>();
                          dlProv.addBatchAlbumTasks(items);
                          provider.clearSelection();
                          provider.toggleSelectionMode();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已添加 ${items.length} 个画廊到下载队列')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSliver(BuildContext context, ExHentaiBrowseProvider provider, bool isDark) {
    if (provider.isLoading && provider.items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CupertinoActivityIndicator(radius: 16),
        ),
      );
    }

    if (provider.errorMessage != null && provider.items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: Colors.orange),
                const SizedBox(height: 12),
                Text(
                  provider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.loadPage(1),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (provider.items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text('没有找到相关画廊', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: _isGrid
          ? SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.68,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = provider.items[index];
                  return ExGalleryCard(
                    item: item,
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => ExDetailPage(item: item),
                        ),
                      );
                    },
                  );
                },
                childCount: provider.items.length,
              ),
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = provider.items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ExGalleryCard(
                      item: item,
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => ExDetailPage(item: item),
                          ),
                        );
                      },
                    ),
                  );
                },
                childCount: provider.items.length,
              ),
            ),
    );
  }
}
