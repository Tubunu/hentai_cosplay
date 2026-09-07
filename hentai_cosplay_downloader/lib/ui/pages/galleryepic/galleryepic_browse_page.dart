import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/galleryepic_browse_provider.dart';
import '../../../services/galleryepic/galleryepic_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/jump_page_dialog.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'galleryepic_detail_page.dart';
import 'widgets/galleryepic_card.dart';

class GalleryepicBrowsePage extends StatefulWidget {
  const GalleryepicBrowsePage({super.key});

  @override
  State<GalleryepicBrowsePage> createState() => _GalleryepicBrowsePageState();
}

class _GalleryepicBrowsePageState extends State<GalleryepicBrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prov = context.read<GalleryepicBrowseProvider>();
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
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _showRangeDownloadDialog(BuildContext context, GalleryepicBrowseProvider provider) {
    int startPage = provider.currentPage;
    int endPage = (provider.currentPage + 2).clamp(1, provider.totalPages > 0 ? provider.totalPages : 50);

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        const themeColor = Color(0xFFE11D48);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(CupertinoIcons.square_stack_3d_down_right_fill, color: themeColor, size: 22),
                  SizedBox(width: 8),
                  Text('区间批量抓取下载', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.selectedCreator != null
                        ? '当前创作者: ${provider.selectedCreator!.name}'
                        : '当前分类: ${provider.mainCategory.label} · ${provider.subCategory.label}',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('起始页码: ', style: TextStyle(fontSize: 14)),
                      const Spacer(),
                      DropdownButton<int>(
                        value: startPage,
                        dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                        items: List.generate(
                          provider.totalPages > 0 ? provider.totalPages : 50,
                          (i) => DropdownMenuItem(value: i + 1, child: Text('第 ${i + 1} 页')),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              startPage = val;
                              if (endPage < startPage) endPage = startPage;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('结束页码: ', style: TextStyle(fontSize: 14)),
                      const Spacer(),
                      DropdownButton<int>(
                        value: endPage,
                        dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                        items: List.generate(
                          provider.totalPages > 0 ? provider.totalPages : 50,
                          (i) => DropdownMenuItem(value: i + 1, child: Text('第 ${i + 1} 页')),
                        ),
                        onChanged: (val) {
                          if (val != null && val >= startPage) {
                            setModalState(() {
                              endPage = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '将连续抓取第 $startPage 页到第 $endPage 页的所有相册，并自动添加至下载队列中。',
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.3),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('正在后台批量抓取 GalleryEpic 第 $startPage ~ $endPage 页...'),
                        backgroundColor: themeColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );

                    final downloadProv = context.read<DownloadProvider>();
                    int totalQueued = 0;

                    for (int p = startPage; p <= endPage; p++) {
                      final data = await GalleryepicApiService.fetchPageData(
                        page: p,
                        category: provider.currentCategory,
                        keyword: provider.searchKeyword,
                        customPath: provider.selectedCreator?.detailPath,
                      );
                      if (data != null && data.items.isNotEmpty) {
                        for (final item in data.items) {
                          downloadProv.addAlbumTask(item);
                          totalQueued++;
                        }
                      }
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('区间抓取完成，共添加 $totalQueued 个相册至下载队列！'),
                          backgroundColor: const Color(0xFF34C759),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('开始批量抓取', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showJumpPageDialog(BuildContext context, GalleryepicBrowseProvider provider) {
    final isCreatorPage = provider.selectedCreator == null &&
        (provider.subCategory == GalleryEpicSubCategory.cosers ||
            provider.subCategory == GalleryEpicSubCategory.models);

    final curPage = isCreatorPage ? provider.creatorPage : provider.currentPage;
    final maxPage = isCreatorPage ? provider.creatorTotalPages : provider.totalPages;

    JumpPageDialog.show(
      context,
      currentPage: curPage,
      totalPages: maxPage,
      themeColor: const Color(0xFFE11D48),
      onPageSelected: (selected) {
        if (isCreatorPage) {
          provider.loadCreators(page: selected);
        } else {
          provider.loadPage(selected);
        }
        _scrollToTop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GalleryepicBrowseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFFE11D48);

    // Subcategory buttons per MainCategory (Matching the user screenshot!)
    final List<Map<String, dynamic>> subButtons = provider.mainCategory == GalleryEpicMainCategory.cosplay
        ? [
            {'sub': GalleryEpicSubCategory.lists, 'label': 'Lists', 'icon': CupertinoIcons.photo_on_rectangle},
            {'sub': GalleryEpicSubCategory.cosers, 'label': 'Cosers', 'icon': CupertinoIcons.person_2_fill},
            {'sub': GalleryEpicSubCategory.parodies, 'label': 'Parodies', 'icon': Icons.palette},
          ]
        : [
            {'sub': GalleryEpicSubCategory.lists, 'label': 'Lists', 'icon': CupertinoIcons.photo_on_rectangle},
            {'sub': GalleryEpicSubCategory.models, 'label': 'Models', 'icon': CupertinoIcons.person_crop_circle_fill},
          ];

    final isShowingCreators = provider.selectedCreator == null &&
        (provider.subCategory == GalleryEpicSubCategory.cosers ||
            provider.subCategory == GalleryEpicSubCategory.models);

    final isShowingParodies = provider.selectedParody == null &&
        provider.subCategory == GalleryEpicSubCategory.parodies;

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
                  // 1. Top Safe Spacing for Floating Header
                  const SliverToBoxAdapter(child: SizedBox(height: 54)),

                  // 2. Main Category Tabs (Cosplay vs Album) & 5 Sub-Buttons (From Uploaded Image)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Level 1: Category Segmented Switch
                          Row(
                            children: GalleryEpicMainCategory.values.map((cat) {
                              final isSelected = provider.mainCategory == cat;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(right: cat == GalleryEpicMainCategory.cosplay ? 8 : 0),
                                  child: BouncingButton(
                                    onTap: () {
                                      provider.switchMainCategory(cat);
                                      _scrollToTop();
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? themeColor
                                            : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? themeColor
                                              : (isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
                                          width: 0.8,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: themeColor.withValues(alpha: 0.35),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        cat.label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),

                          // Level 2: Subcategory Action Buttons (Lists / Cosers / Parodies / Models)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: subButtons.map((btn) {
                                final sub = btn['sub'] as GalleryEpicSubCategory;
                                final label = btn['label'] as String;
                                final icon = btn['icon'] as IconData;
                                final isSelected = provider.subCategory == sub;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: BouncingButton(
                                    onTap: () {
                                      provider.switchSubCategory(sub);
                                      _scrollToTop();
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? themeColor.withValues(alpha: isDark ? 0.3 : 0.15)
                                            : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? themeColor : (isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
                                          width: isSelected ? 1.4 : 0.6,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            icon,
                                            size: 15,
                                            color: isSelected ? themeColor : (isDark ? Colors.white60 : Colors.black54),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                              color: isSelected ? themeColor : (isDark ? Colors.white70 : Colors.black87),
                                            ),
                                          ),
                                        ],
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

                  // 3. Search Bar & Toolbar Actions Row
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                      child: Column(
                        children: [
                          // Search Input Box
                          Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                                width: 0.5,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (text) {
                                if (text.trim().isNotEmpty) {
                                  provider.search(text);
                                  _scrollToTop();
                                }
                              },
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: '搜索 GalleryEpic 相册、模特或作品...',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_searchController.text.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          provider.clearActiveFilter();
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4),
                                          child: Icon(CupertinoIcons.clear_circled_solid, size: 16, color: Colors.grey),
                                        ),
                                      ),
                                    GestureDetector(
                                      onTap: () {
                                        if (_searchController.text.trim().isNotEmpty) {
                                          provider.search(_searchController.text);
                                          _scrollToTop();
                                        }
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: themeColor,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          '搜索',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Toolbar Action Buttons Row (🎲 全库随机 / 区间抓取 / 多选)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                // 全库随机 Button
                                RandomActionButton.album(
                                  albumSource: MediaSourceType.galleryepic,
                                  isCapsule: true,
                                  color: themeColor,
                                ),
                                const SizedBox(width: 8),

                                // 区间抓取 Button
                                BouncingButton(
                                  onTap: () => _showRangeDownloadDialog(context, provider),
                                  child: Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: themeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 0.8),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(CupertinoIcons.square_stack_3d_down_right_fill, size: 15, color: themeColor),
                                        SizedBox(width: 4),
                                        Text(
                                          '区间抓取',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: themeColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // 多选 Toggle Button
                                BouncingButton(
                                  onTap: () => provider.setSelectionMode(!provider.isSelectionMode),
                                  child: Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: provider.isSelectionMode
                                          ? themeColor
                                          : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: provider.isSelectionMode
                                            ? themeColor
                                            : (isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          provider.isSelectionMode
                                              ? CupertinoIcons.checkmark_circle_fill
                                              : CupertinoIcons.checkmark_circle,
                                          size: 15,
                                          color: provider.isSelectionMode
                                              ? Colors.white
                                              : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '多选',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: provider.isSelectionMode
                                                ? Colors.white
                                                : (isDark ? Colors.white70 : Colors.black87),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Active Filter Banner (Creator / Parody / Character / Search)
                  if (provider.hasActiveFilter)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(14, 2, 14, 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 0.6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              provider.selectedCreator != null
                                  ? CupertinoIcons.person_crop_circle_fill
                                  : (provider.selectedParody != null
                                      ? Icons.palette
                                      : CupertinoIcons.search),
                              size: 15,
                              color: themeColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                provider.selectedCreator != null
                                    ? '创作者: "${provider.selectedCreator!.name}"'
                                    : (provider.selectedParody != null
                                        ? (provider.selectedCharacter != null
                                            ? '原作: "${provider.selectedParody!.name}" · 角色: "${provider.selectedCharacter!.name}"'
                                            : '原作分类: "${provider.selectedParody!.name}"')
                                        : '搜索: "${provider.searchKeyword}"'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: themeColor),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                provider.clearActiveFilter();
                              },
                              child: const Text('清除', style: TextStyle(fontSize: 12, color: themeColor, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Parody Characters Horizontal Chips Bar
                  if (provider.selectedParody != null && provider.parodyCharacters.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        height: 38,
                        margin: const EdgeInsets.fromLTRB(0, 2, 0, 8),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          physics: const BouncingScrollPhysics(),
                          itemCount: provider.parodyCharacters.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final char = provider.parodyCharacters[idx];
                            final isSel = provider.selectedCharacter?.detailPath == char.detailPath;
                            return BouncingButton(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                provider.selectCharacter(char);
                                _scrollToTop();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? themeColor : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel ? themeColor : (isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
                                    width: 0.8,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  char.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // Multi-Selection Action Header (Inline inside scroll view, never blocked)
                  if (provider.isSelectionMode)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: themeColor.withValues(alpha: 0.35), width: 0.8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '已选 ${provider.selectedCount} 项',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: themeColor),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: provider.selectedCount == provider.items.length
                                  ? provider.deselectAll
                                  : provider.selectAll,
                              child: Text(
                                provider.selectedCount == provider.items.length ? '取消全选' : '全选本页',
                                style: const TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                            ),
                            const SizedBox(width: 4),
                            ElevatedButton.icon(
                              icon: const Icon(CupertinoIcons.cloud_download, size: 14),
                              label: const Text('下载选中', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: provider.selectedCount > 0
                                  ? () {
                                      final selected = provider.selectedItems;
                                      final downloadProv = context.read<DownloadProvider>();
                                      for (final it in selected) {
                                        downloadProv.addAlbumTask(it);
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('已添加 ${selected.length} 个相册到下载队列'),
                                          backgroundColor: themeColor,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      provider.setSelectionMode(false);
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 4. Content Rendering (Creators, Parodies, or Albums)
                  if (isShowingCreators)
                    // Showing Cosers or Models Grid
                    if (provider.isLoading && provider.displayedCreators.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CupertinoActivityIndicator(radius: 16)),
                      )
                    else if (provider.displayedCreators.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text('暂无相关数据', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.6,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final creator = provider.displayedCreators[index];
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  provider.selectCreator(creator);
                                  _scrollToTop();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipOval(
                                        child: SizedBox(
                                          width: 36,
                                          height: 36,
                                          child: creator.avatarUrl != null
                                              ? CachedNetworkImage(
                                                  imageUrl: creator.avatarUrl!,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) => const Icon(
                                                    CupertinoIcons.person_fill,
                                                    size: 20,
                                                    color: Colors.grey,
                                                  ),
                                                )
                                              : const Icon(
                                                  CupertinoIcons.person_fill,
                                                  size: 20,
                                                  color: Colors.grey,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          creator.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      const Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: provider.displayedCreators.length,
                          ),
                        ),
                      )
                  else if (isShowingParodies)
                    // Showing Parodies List / Chips
                    if (provider.isLoading && provider.displayedParodies.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CupertinoActivityIndicator(radius: 16)),
                      )
                    else if (provider.displayedParodies.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text('暂无原作数据', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.8,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final parody = provider.displayedParodies[index];
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  provider.selectParody(parody);
                                  _scrollToTop();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: themeColor.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.palette, size: 14, color: themeColor),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          parody.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      const Icon(CupertinoIcons.chevron_right, size: 13, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: provider.displayedParodies.length,
                          ),
                        ),
                      )
                  else
                    // Showing Albums Grid
                    if (provider.isLoading && provider.items.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CupertinoActivityIndicator(radius: 16),
                        ),
                      )
                    else if (provider.errorMessage != null && provider.items.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: Colors.orangeAccent),
                                const SizedBox(height: 12),
                                Text(
                                  provider.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                                  onPressed: () => provider.loadPage(provider.currentPage),
                                  child: const Text('重试', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (provider.items.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.photo_on_rectangle, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                              const SizedBox(height: 12),
                              Text(
                                '未找到相关相册',
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.68,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = provider.items[index];

                              return GalleryepicCard(
                                item: item,
                                onTap: () {
                                  if (provider.isSelectionMode) {
                                    provider.toggleItemSelection(item);
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => GalleryepicDetailPage(item: item),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                            childCount: provider.items.length,
                          ),
                        ),
                      ),

                  // 5. Inline Bottom Pagination Bar (Inside CustomScrollView so never blocked!)
                  if ((!isShowingCreators && !isShowingParodies && provider.items.isNotEmpty && provider.totalPages > 1) ||
                      (isShowingCreators && provider.creators.isNotEmpty && provider.creatorTotalPages > 1))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Previous Page Button
                            BouncingButton(
                              onTap: (isShowingCreators ? provider.creatorPage > 1 : provider.currentPage > 1)
                                  ? () {
                                      provider.prevPage();
                                      _scrollToTop();
                                    }
                                  : () {},
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: (isShowingCreators ? provider.creatorPage > 1 : provider.currentPage > 1)
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
                                    color: (isShowingCreators ? provider.creatorPage > 1 : provider.currentPage > 1)
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Jump Page Dialog Button
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
                                  isShowingCreators
                                      ? '第 ${provider.creatorPage} / ${provider.creatorTotalPages} 页'
                                      : '第 ${provider.currentPage} / ${provider.totalPages} 页',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: themeColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Next Page Button
                            BouncingButton(
                              onTap: (isShowingCreators
                                      ? provider.creatorPage < provider.creatorTotalPages
                                      : provider.currentPage < provider.totalPages)
                                  ? () {
                                      provider.nextPage();
                                      _scrollToTop();
                                    }
                                  : () {},
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: (isShowingCreators
                                          ? provider.creatorPage < provider.creatorTotalPages
                                          : provider.currentPage < provider.totalPages)
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
                                    color: (isShowingCreators
                                            ? provider.creatorPage < provider.creatorTotalPages
                                            : provider.currentPage < provider.totalPages)
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

                  // 6. Bottom Safe Spacer for Floating Navigation Bar
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 220 : 140,
                    ),
                  ),
                ],
              ),
            ),

            // Selection Mode Bottom Action Bar (Safely floating above bottom navigation bar)
            if (provider.isSelectionMode)
              Positioned(
                bottom: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 140 : 80,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: isDark ? const Color(0x33FFFFFF) : const Color(0x18000000),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '已选择 ${provider.selectedCount} 项',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: provider.selectedCount == provider.items.length
                            ? provider.deselectAll
                            : provider.selectAll,
                        child: Text(
                          provider.selectedCount == provider.items.length ? '取消全选' : '全选',
                          style: const TextStyle(color: themeColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(CupertinoIcons.cloud_download, size: 16),
                        label: const Text('下载选中'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: provider.selectedCount > 0
                            ? () {
                                final selected = provider.selectedItems;
                                final downloadProv = context.read<DownloadProvider>();
                                for (final it in selected) {
                                  downloadProv.addAlbumTask(it);
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('已添加 ${selected.length} 个相册到下载队列'),
                                    backgroundColor: themeColor,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                provider.setSelectionMode(false);
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),

            ScrollToTopButton(scrollController: _scrollController),
          ],
        ),
      ),
    );
  }
}
