import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/album_item.dart';
import '../../services/video_api_service.dart';
import '../theme/ios_theme.dart';
import 'bouncing_button.dart';
import 'page_navigation_bar.dart';

class VideoTagsSheet extends StatefulWidget {
  final void Function(RankingTagItem item) onSelect;

  const VideoTagsSheet({
    super.key,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(RankingTagItem item) onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VideoTagsSheet(onSelect: onSelect),
    );
  }

  @override
  State<VideoTagsSheet> createState() => _VideoTagsSheetState();
}

class _VideoTagsSheetState extends State<VideoTagsSheet> {
  int _currentPage = 1;
  int _totalPages = 1;
  List<RankingTagItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTags(_currentPage);
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _loadTags(int page) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await VideoApiService.fetchVideoTags(page: page);

      if (!mounted) return;

      if (res != null) {
        setState(() {
          _items = res.items;
          _currentPage = res.page;
          _totalPages = res.totalPages;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '加载失败，请检查网络连接';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '加载出错: $e';
        _isLoading = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filterText = _filterController.text.trim().toLowerCase();

    final filteredItems = filterText.isEmpty
        ? _items
        : _items.where((it) => it.name.toLowerCase().contains(filterText)).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: IosTheme.surfaceLayer1(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                const Icon(CupertinoIcons.tag_fill, color: IosTheme.primaryPink, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '热门视频标签',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                if (_totalPages > 1) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: IosTheme.primaryPink.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '第 $_currentPage / $_totalPages 页',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: IosTheme.primaryPink,
                      ),
                    ),
                  ),
                ],
                const Spacer(),

                // Refresh Button
                BouncingButton(
                  onTap: () => _loadTags(_currentPage),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: IosTheme.surfaceLayer2(isDark),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.refresh, size: 16),
                  ),
                ),
                const SizedBox(width: 8),

                // Close Button
                BouncingButton(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: IosTheme.surfaceLayer2(isDark),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.xmark, size: 16),
                  ),
                ),
              ],
            ),
          ),

          // Search / Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: CupertinoSearchTextField(
              controller: _filterController,
              placeholder: '快速在本页筛选视频标签...',
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              onChanged: (_) => setState(() {}),
            ),
          ),

          const SizedBox(height: 8),

          // Content Area
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: IosTheme.primaryPink,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _loadTags(_currentPage),
                              child: const Text('重新加载'),
                            ),
                          ],
                        ),
                      )
                    : filteredItems.isEmpty
                        ? const Center(
                            child: Text('没有找到匹配的内容', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            physics: const BouncingScrollPhysics(),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 10,
                              children: filteredItems.map((it) {
                                return BouncingButton(
                                  onTap: () {
                                    Navigator.pop(context);
                                    widget.onSelect(it);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: IosTheme.surfaceLayer2(isDark),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.08)
                                            : Colors.black.withValues(alpha: 0.05),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          it.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        if (it.count.isNotEmpty) ...[
                                          const SizedBox(width: 5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: IosTheme.primaryPink.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              it.count,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: IosTheme.primaryPink,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
          ),

          // Bottom Pagination Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.of(context).padding.bottom + 6),
            decoration: BoxDecoration(
              color: IosTheme.surfaceLayer1(isDark),
              border: Border(
                top: BorderSide(
                  color: IosTheme.borderSubtle(isDark),
                  width: 0.5,
                ),
              ),
            ),
            child: PageNavigationBar(
              currentPage: _currentPage,
              totalPages: _totalPages,
              isLoading: _isLoading,
              onPageSelected: (page) => _loadTags(page),
              brandColor: IosTheme.primaryPink,
            ),
          ),
        ],
      ),
    );
  }
}
