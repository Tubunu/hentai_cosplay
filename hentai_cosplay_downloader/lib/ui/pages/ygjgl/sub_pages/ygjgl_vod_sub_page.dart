import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/ygjgl_browse_provider.dart';
import '../../../widgets/bouncing_button.dart';
import '../../../widgets/page_navigation_bar.dart';
import '../widgets/ygjgl_vod_card.dart';

class YgjglVodSubPage extends StatefulWidget {
  const YgjglVodSubPage({super.key});

  @override
  State<YgjglVodSubPage> createState() => _YgjglVodSubPageState();
}

class _YgjglVodSubPageState extends State<YgjglVodSubPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<YgjglBrowseProvider>();
      if (prov.vodItems.isEmpty && !prov.isVodLoading) {
        prov.loadVodMeta();
        prov.loadVodPage(page: 1);
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

  void _showSortAndFilterSheet(BuildContext context, YgjglBrowseProvider prov) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentPink = Color(0xFFFF5A8A);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final sorts = [
              {'label': '发布日 ↓', 'val': 'pub_desc'},
              {'label': '发布日 ↑', 'val': 'pub_asc'},
              {'label': '近期热度 ↓', 'val': 'hot_recent'},
              {'label': '总热度 ↓', 'val': 'hot_desc'},
              {'label': '播放量 ↓', 'val': 'views_desc'},
            ];

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('排序方式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sorts.map((s) {
                        final isSel = prov.vodSort == s['val'];
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
                              setSheetState(() => prov.setVodSort(s['val']!));
                              Navigator.pop(ctx);
                              _scrollToTop();
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    if (prov.years.isNotEmpty) ...[
                      const Text('年份筛选', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('全部年份'),
                              selected: prov.vodSelectedYear == null,
                              selectedColor: accentPink,
                              labelStyle: TextStyle(
                                color: prov.vodSelectedYear == null ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              onSelected: (val) {
                                prov.setVodDate(null, null);
                                Navigator.pop(ctx);
                                _scrollToTop();
                              },
                            ),
                            const SizedBox(width: 8),
                            ...prov.years.map((y) {
                              final isSel = prov.vodSelectedYear == y;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text('$y年'),
                                  selected: isSel,
                                  selectedColor: accentPink,
                                  labelStyle: TextStyle(
                                    color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  onSelected: (val) {
                                    prov.setVodDate(val ? y : null, prov.vodSelectedMonth);
                                    Navigator.pop(ctx);
                                    _scrollToTop();
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            prov.resetVodFilters();
                            _searchController.clear();
                            Navigator.pop(ctx);
                            _scrollToTop();
                          },
                          child: const Text('重置全部筛选'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
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
          await prov.loadVodPage(page: prov.vodCurrentPage);
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // 1. Search Bar & Filter Toolbar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Column(
                  children: [
                    // Search Bar
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
                              style: TextStyle(
                                fontSize: 13.5,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: '搜索点播番号、女优、片名...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                                prefixIcon: Icon(
                                  CupertinoIcons.search,
                                  size: 18,
                                  color: isDark ? Colors.white38 : Colors.black45,
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16),
                                        onPressed: () {
                                          _searchController.clear();
                                          prov.setVodKeyword('');
                                          _scrollToTop();
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                              ),
                              onSubmitted: (val) {
                                prov.setVodKeyword(val.trim());
                                _scrollToTop();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Sort & Filter Button
                        BouncingButton(
                          onTap: () => _showSortAndFilterSheet(context, prov),
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF222226) : const Color(0xFFEBEBF0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(CupertinoIcons.slider_horizontal_3, size: 16),
                                SizedBox(width: 4),
                                Text('排序', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Region Tags (全部, 国产, 日本, 免费区)
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _buildRegionChip('全部', prov.vodSelectedRegion == null, () {
                                  prov.setVodRegion(null);
                                  _scrollToTop();
                                }, isDark),
                                const SizedBox(width: 6),
                                _buildRegionChip('国产', prov.vodSelectedRegion == '国产', () {
                                  prov.setVodRegion('国产');
                                  _scrollToTop();
                                }, isDark),
                                const SizedBox(width: 6),
                                _buildRegionChip('日本', prov.vodSelectedRegion == '日本', () {
                                  prov.setVodRegion('日本');
                                  _scrollToTop();
                                }, isDark),
                                const SizedBox(width: 6),
                                _buildRegionChip('免费区', prov.vodSelectedRegion == '免费区', () {
                                  prov.setVodRegion('免费区');
                                  _scrollToTop();
                                }, isDark),
                              ],
                            ),
                          ),
                        ),
                        if (prov.vodTotalCount > 0)
                          Text(
                            '共 ${prov.vodTotalCount} 部',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 2. Loading / Error / Empty States
            if (prov.isVodLoading && prov.vodItems.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CupertinoActivityIndicator(radius: 16),
                ),
              )
            else if (prov.vodErrorMessage != null && prov.vodItems.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle, size: 42, color: Colors.amber),
                      const SizedBox(height: 12),
                      Text(prov.vodErrorMessage!, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => prov.loadVodPage(page: prov.vodCurrentPage),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              )
            else if (prov.vodItems.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.tray, size: 48, color: Colors.grey),
                      SizedBox(height: 10),
                      Text('没有找到匹配的视频', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              // 3. Responsive VOD Grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.88,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = prov.vodItems[index];
                      return YgjglVodCard(item: item);
                    },
                    childCount: prov.vodItems.length,
                  ),
                ),
              ),

            // 4. Bottom Pagination
            if (prov.vodItems.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 90),
                  child: PageNavigationBar(
                    currentPage: prov.vodCurrentPage,
                    totalPages: prov.vodTotalPages,
                    isLoading: prov.isVodLoading,
                    brandColor: const Color(0xFFFF5A8A),
                    onPageSelected: (p) {
                      prov.loadVodPage(page: p);
                      _scrollToTop();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionChip(String label, bool isSelected, VoidCallback onTap, bool isDark) {
    const accentPink = Color(0xFFFF5A8A);

    return BouncingButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? accentPink
              : (isDark ? const Color(0xFF222226) : const Color(0xFFEBEBF0)),
          borderRadius: BorderRadius.circular(16),
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
