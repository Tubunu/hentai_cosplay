import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/ygjgl_browse_provider.dart';
import '../../../widgets/bouncing_button.dart';
import '../../../widgets/page_navigation_bar.dart';
import '../widgets/ygjgl_post_card.dart';
import '../widgets/ygjgl_rank_row.dart';

class YgjglImageSubPage extends StatefulWidget {
  const YgjglImageSubPage({super.key});

  @override
  State<YgjglImageSubPage> createState() => _YgjglImageSubPageState();
}

class _YgjglImageSubPageState extends State<YgjglImageSubPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<YgjglBrowseProvider>();
      if (prov.imageItems.isEmpty && !prov.isImageLoading) {
        prov.loadImageMeta();
        prov.loadImagePage(page: 1);
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

  void _showSortSheet(BuildContext context, YgjglBrowseProvider prov) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentPink = Color(0xFFFF5A8A);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final sorts = [
          {'label': '最新发布', 'val': 'new'},
          {'label': '近期最热', 'val': 'hot'},
          {'label': '最多浏览', 'val': 'views'},
          {'label': '图片数量', 'val': 'images'},
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('排序方式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sorts.map((s) {
                    final isSel = prov.imageSort == s['val'];
                    return ChoiceChip(
                      label: Text(s['label']!),
                      selected: isSel,
                      selectedColor: accentPink,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) {
                          prov.setImageSort(s['val']!);
                          Navigator.pop(ctx);
                          _scrollToTop();
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSeriesSheet(BuildContext context, YgjglBrowseProvider prov) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentPink = Color(0xFFFF5A8A);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 380),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('合集筛选', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      ListTile(
                        title: const Text('全部合集'),
                        trailing: prov.imageSelectedSeries == 0 ? const Icon(Icons.check, color: accentPink) : null,
                        onTap: () {
                          prov.setImageSeries(0);
                          Navigator.pop(ctx);
                          _scrollToTop();
                        },
                      ),
                      ...prov.imageSeries.map((s) {
                        final sId = (s['series_id'] is num) ? (s['series_id'] as num).toInt() : 0;
                        final sTitle = s['series_title']?.toString() ?? '系列 $sId';
                        final sCount = s['n'] ?? 0;
                        final isSel = prov.imageSelectedSeries == sId;

                        return ListTile(
                          title: Text('$sTitle ($sCount)'),
                          trailing: isSel ? const Icon(Icons.check, color: accentPink) : null,
                          onTap: () {
                            prov.setImageSeries(sId);
                            Navigator.pop(ctx);
                            _scrollToTop();
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentPink = Color(0xFFFF5A8A);
    final prov = context.watch<YgjglBrowseProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: accentPink,
        onRefresh: () async {
          if (prov.isImageRankView) {
            await prov.loadImageRank();
          } else {
            await prov.loadImagePage(page: prov.imageCurrentPage);
          }
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // 1. Toolbar & Filters
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search bar & Mode toggle
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF222226) : const Color(0xFFEBEBF0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: '搜索写真作者、模特、标签...',
                                hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                                prefixIcon: Icon(CupertinoIcons.search, size: 18, color: isDark ? Colors.white38 : Colors.black45),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16),
                                        onPressed: () {
                                          _searchController.clear();
                                          prov.setImageKeyword('');
                                          _scrollToTop();
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                              ),
                              onSubmitted: (val) {
                                prov.setImageKeyword(val.trim());
                                _scrollToTop();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Rank Mode Toggle Button
                        BouncingButton(
                          onTap: () {
                            prov.toggleImageRankView();
                            _scrollToTop();
                          },
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: prov.isImageRankView
                                  ? accentPink
                                  : (isDark ? const Color(0xFF222226) : const Color(0xFFEBEBF0)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  prov.isImageRankView ? CupertinoIcons.list_bullet : CupertinoIcons.rosette,
                                  size: 16,
                                  color: prov.isImageRankView ? Colors.white : null,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  prov.isImageRankView ? '列表' : '排行榜',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: prov.isImageRankView ? Colors.white : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Controls depending on mode
                    if (prov.isImageRankView) ...[
                      // Rank Window Chips (日榜, 周榜, 月榜, 总榜)
                      Row(
                        children: [
                          _buildChip('周榜', prov.imageRankWindow == 'week', () => prov.setImageRankWindow('week'), isDark),
                          const SizedBox(width: 6),
                          _buildChip('月榜', prov.imageRankWindow == 'month', () => prov.setImageRankWindow('month'), isDark),
                          const SizedBox(width: 6),
                          _buildChip('日榜', prov.imageRankWindow == 'day', () => prov.setImageRankWindow('day'), isDark),
                          const SizedBox(width: 6),
                          _buildChip('总榜', prov.imageRankWindow == 'all', () => prov.setImageRankWindow('all'), isDark),
                          const Spacer(),
                          Text('TOP 30', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentPink)),
                        ],
                      ),
                    ] else ...[
                      // Filters Row: Series, Sort, Range
                      Row(
                        children: [
                          // Series button
                          BouncingButton(
                            onTap: () => _showSeriesSheet(context, prov),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: prov.imageSelectedSeries > 0
                                    ? accentPink
                                    : (isDark ? const Color(0xFF222226) : const Color(0xFFEBEBF0)),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    prov.imageSelectedSeries > 0 ? '已选合集' : '全部合集',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: prov.imageSelectedSeries > 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    CupertinoIcons.chevron_down,
                                    size: 11,
                                    color: prov.imageSelectedSeries > 0 ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Sort button
                          BouncingButton(
                            onTap: () => _showSortSheet(context, prov),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF222226) : const Color(0xFFEBEBF0),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    prov.imageSort == 'new'
                                        ? '最新'
                                        : (prov.imageSort == 'hot' ? '最热' : (prov.imageSort == 'views' ? '浏览量' : '图片数')),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(CupertinoIcons.chevron_down, size: 11, color: isDark ? Colors.white54 : Colors.black54),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (prov.imageTotalCount > 0)
                            Text(
                              '共 ${prov.imageTotalCount} 部',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tags Bar (scrollable)
                      if (prov.imageTags.isNotEmpty)
                        SizedBox(
                          height: 28,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: prov.imageTags.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 6),
                            itemBuilder: (context, idx) {
                              final tg = prov.imageTags[idx];
                              final tagStr = tg['tag']?.toString() ?? '';
                              final count = tg['n'] ?? 0;
                              final isSel = prov.imageSelectedTag == tagStr;

                              return BouncingButton(
                                onTap: () {
                                  prov.setImageTag(tagStr);
                                  _scrollToTop();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? accentPink
                                        : (isDark ? const Color(0xFF222226) : const Color(0xFFEBEBF0)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$tagStr $count',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                                      color: isSel ? Colors.white : (isDark ? Colors.white60 : Colors.black87),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),

            // 2. Body: Rank View or Grid View
            if (prov.isImageRankView) ...[
              if (prov.isImageLoading && prov.imageRankItems.isEmpty)
                const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator(radius: 16)))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = prov.imageRankItems[index];
                      return YgjglRankRow(item: item, index: index);
                    },
                    childCount: prov.imageRankItems.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ] else ...[
              if (prov.isImageLoading && prov.imageItems.isEmpty)
                const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator(radius: 16)))
              else if (prov.imageErrorMessage != null && prov.imageItems.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle, size: 42, color: Colors.amber),
                        const SizedBox(height: 12),
                        Text(prov.imageErrorMessage!),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: () => prov.loadImagePage(page: prov.imageCurrentPage), child: const Text('重试')),
                      ],
                    ),
                  ),
                )
              else if (prov.imageItems.isEmpty)
                const SliverFillRemaining(child: Center(child: Text('没有找到匹配的写真图集', style: TextStyle(color: Colors.grey))))
              else ...[
                // Grid of Albums
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.65,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = prov.imageItems[index];
                        return YgjglPostCard(item: item);
                      },
                      childCount: prov.imageItems.length,
                    ),
                  ),
                ),

                // Pagination
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 90),
                    child: PageNavigationBar(
                      currentPage: prov.imageCurrentPage,
                      totalPages: prov.imageTotalPages,
                      isLoading: prov.isImageLoading,
                      brandColor: const Color(0xFFFF5A8A),
                      onPageSelected: (p) {
                        prov.loadImagePage(page: p);
                        _scrollToTop();
                      },
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap, bool isDark) {
    const accentPink = Color(0xFFFF5A8A);
    return BouncingButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? accentPink : (isDark ? const Color(0xFF222226) : const Color(0xFFEBEBF0)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
