import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/album_item.dart';
import '../../services/hc_api_service.dart';
import '../theme/ios_theme.dart';
import 'bouncing_button.dart';

class RankingTagsSheet extends StatefulWidget {
  final bool isTag; // true for 热门标签, false for 热门搜索词
  final void Function(RankingTagItem item) onSelect;

  const RankingTagsSheet({
    super.key,
    required this.isTag,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isTag,
    required void Function(RankingTagItem item) onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RankingTagsSheet(
        isTag: isTag,
        onSelect: onSelect,
      ),
    );
  }

  @override
  State<RankingTagsSheet> createState() => _RankingTagsSheetState();
}

class _RankingTagsSheetState extends State<RankingTagsSheet> {
  int _currentPage = 1;
  int _totalPages = 1;
  List<RankingTagItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _filterController = TextEditingController();
  final TextEditingController _jumpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTags(_currentPage);
  }

  @override
  void dispose() {
    _filterController.dispose();
    _jumpController.dispose();
    super.dispose();
  }

  Future<void> _loadTags(int page) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await HCApiService.fetchRankingTags(
        isTag: widget.isTag,
        page: page,
      );

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
      setState(() {
        _errorMessage = '加载出错: $e';
        _isLoading = false;
      });
    }
  }

  void _showJumpDialog() {
    _jumpController.text = _currentPage.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          widget.isTag ? '跳转热门标签页码' : '跳转热门搜索词页码',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('请输入 1 ~ $_totalPages 之间的页码：', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: _jumpController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final p = int.tryParse(_jumpController.text.trim());
              if (p != null && p >= 1 && p <= _totalPages) {
                Navigator.pop(ctx);
                _loadTags(p);
              }
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
    final title = widget.isTag ? '热门标签' : '热门搜索词';
    final filterText = _filterController.text.trim().toLowerCase();

    final filteredItems = filterText.isEmpty
        ? _items
        : _items.where((it) => it.name.toLowerCase().contains(filterText)).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
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
                Icon(
                  widget.isTag ? CupertinoIcons.tag_fill : CupertinoIcons.search,
                  color: IosTheme.primaryPink,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
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
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
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
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.xmark, size: 16),
                  ),
                ),
              ],
            ),
          ),

          // Search / Filter inside sheet
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: CupertinoSearchTextField(
              controller: _filterController,
              placeholder: '快速在本页筛选标签 / 词汇...',
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
                                      color: isDark
                                          ? const Color(0xFF2C2C2E)
                                          : const Color(0xFFF2F2F7),
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
            padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF242426) : const Color(0xFFF9F9FB),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // Prev Page Button
                Expanded(
                  child: BouncingButton(
                    onTap: _currentPage > 1 && !_isLoading
                        ? () => _loadTags(_currentPage - 1)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _currentPage > 1
                            ? (isDark ? const Color(0xFF3A3A3C) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _currentPage > 1 ? IosTheme.primaryPink.withValues(alpha: 0.3) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.chevron_left,
                            size: 14,
                            color: _currentPage > 1 ? IosTheme.primaryPink : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '上一页',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _currentPage > 1 ? IosTheme.primaryPink : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Jump Page Button
                BouncingButton(
                  onTap: _totalPages > 1 && !_isLoading ? _showJumpDialog : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3A3A3C) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_currentPage / $_totalPages',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Next Page Button
                Expanded(
                  child: BouncingButton(
                    onTap: _currentPage < _totalPages && !_isLoading
                        ? () => _loadTags(_currentPage + 1)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _currentPage < _totalPages
                            ? (isDark ? const Color(0xFF3A3A3C) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _currentPage < _totalPages ? IosTheme.primaryPink.withValues(alpha: 0.3) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '下一页',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _currentPage < _totalPages ? IosTheme.primaryPink : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 14,
                            color: _currentPage < _totalPages ? IosTheme.primaryPink : Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
