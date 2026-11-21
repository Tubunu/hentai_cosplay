import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/ygjgl_browse_provider.dart';
import '../../../widgets/bouncing_button.dart';
import '../../../widgets/page_navigation_bar.dart';
import '../widgets/ygjgl_audio_card.dart';
import '../widgets/ygjgl_rank_row.dart';

class YgjglAudioSubPage extends StatefulWidget {
  const YgjglAudioSubPage({super.key});

  @override
  State<YgjglAudioSubPage> createState() => _YgjglAudioSubPageState();
}

class _YgjglAudioSubPageState extends State<YgjglAudioSubPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<YgjglBrowseProvider>();
      if (prov.audioItems.isEmpty && !prov.isAudioLoading) {
        prov.loadAudioMeta();
        prov.loadAudioPage(page: 1);
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
    const accentPurple = Color(0xFF5856D6);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final sorts = [
          {'label': '最新发布', 'val': 'new'},
          {'label': '近期最热', 'val': 'hot'},
          {'label': '最多浏览', 'val': 'views'},
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('电台排序', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sorts.map((s) {
                    final isSel = prov.audioSort == s['val'];
                    return ChoiceChip(
                      label: Text(s['label']!),
                      selected: isSel,
                      selectedColor: accentPurple,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) {
                          prov.setAudioSort(s['val']!);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentPurple = Color(0xFF5856D6);
    final prov = context.watch<YgjglBrowseProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: accentPurple,
        onRefresh: () async {
          if (prov.isAudioRankView) {
            await prov.loadAudioRank();
          } else {
            await prov.loadAudioPage(page: prov.audioCurrentPage);
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
                                hintText: '搜索电台主播、ASMR、作品名...',
                                hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                                prefixIcon: Icon(CupertinoIcons.search, size: 18, color: isDark ? Colors.white38 : Colors.black45),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16),
                                        onPressed: () {
                                          _searchController.clear();
                                          prov.setAudioKeyword('');
                                          _scrollToTop();
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                              ),
                              onSubmitted: (val) {
                                prov.setAudioKeyword(val.trim());
                                _scrollToTop();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Rank Mode Toggle
                        BouncingButton(
                          onTap: () {
                            prov.toggleAudioRankView();
                            _scrollToTop();
                          },
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: prov.isAudioRankView
                                  ? accentPurple
                                  : (isDark ? const Color(0xFF222226) : const Color(0xFFEBEBF0)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  prov.isAudioRankView ? CupertinoIcons.list_bullet : CupertinoIcons.rosette,
                                  size: 16,
                                  color: prov.isAudioRankView ? Colors.white : null,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  prov.isAudioRankView ? '列表' : '排行榜',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: prov.isAudioRankView ? Colors.white : null,
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
                    if (prov.isAudioRankView) ...[
                      // Rank Window Chips (日榜, 周榜, 月榜, 总榜)
                      Row(
                        children: [
                          _buildChip('周榜', prov.audioRankWindow == 'week', () => prov.setAudioRankWindow('week'), isDark),
                          const SizedBox(width: 6),
                          _buildChip('月榜', prov.audioRankWindow == 'month', () => prov.setAudioRankWindow('month'), isDark),
                          const SizedBox(width: 6),
                          _buildChip('日榜', prov.audioRankWindow == 'day', () => prov.setAudioRankWindow('day'), isDark),
                          const SizedBox(width: 6),
                          _buildChip('总榜', prov.audioRankWindow == 'all', () => prov.setAudioRankWindow('all'), isDark),
                          const Spacer(),
                          const Text('TOP 30', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentPurple)),
                        ],
                      ),
                    ] else ...[
                      // Filter row
                      Row(
                        children: [
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
                                    prov.audioSort == 'new' ? '最新' : (prov.audioSort == 'hot' ? '最热' : '浏览量'),
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
                          if (prov.audioTotalCount > 0)
                            Text(
                              '共 ${prov.audioTotalCount} 首',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tags Bar (scrollable)
                      if (prov.audioTags.isNotEmpty)
                        SizedBox(
                          height: 28,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: prov.audioTags.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 6),
                            itemBuilder: (context, idx) {
                              final tg = prov.audioTags[idx];
                              final tagStr = tg['tag']?.toString() ?? '';
                              final count = tg['n'] ?? 0;
                              final isSel = prov.audioSelectedTag == tagStr;

                              return BouncingButton(
                                onTap: () {
                                  prov.setAudioTag(tagStr);
                                  _scrollToTop();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? accentPurple
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

            // 2. Body: Rank or List
            if (prov.isAudioRankView) ...[
              if (prov.isAudioLoading && prov.audioRankItems.isEmpty)
                const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator(radius: 16)))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = prov.audioRankItems[index];
                      return YgjglRankRow(item: item, index: index);
                    },
                    childCount: prov.audioRankItems.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ] else ...[
              if (prov.isAudioLoading && prov.audioItems.isEmpty)
                const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator(radius: 16)))
              else if (prov.audioErrorMessage != null && prov.audioItems.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle, size: 42, color: Colors.amber),
                        const SizedBox(height: 12),
                        Text(prov.audioErrorMessage!),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: () => prov.loadAudioPage(page: prov.audioCurrentPage), child: const Text('重试')),
                      ],
                    ),
                  ),
                )
              else if (prov.audioItems.isEmpty)
                const SliverFillRemaining(child: Center(child: Text('没有找到匹配的电台音频', style: TextStyle(color: Colors.grey))))
              else ...[
                // List of Audios
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = prov.audioItems[index];
                      return YgjglAudioCard(item: item);
                    },
                    childCount: prov.audioItems.length,
                  ),
                ),

                // Pagination
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 90),
                    child: PageNavigationBar(
                      currentPage: prov.audioCurrentPage,
                      totalPages: prov.audioTotalPages,
                      isLoading: prov.isAudioLoading,
                      brandColor: const Color(0xFFFF5A8A),
                      onPageSelected: (p) {
                        prov.loadAudioPage(page: p);
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
    const accentPurple = Color(0xFF5856D6);
    return BouncingButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? accentPurple : (isDark ? const Color(0xFF222226) : const Color(0xFFEBEBF0)),
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
