import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/app_logger.dart';
import 'bouncing_button.dart';

class LogViewerModal extends StatefulWidget {
  final String? initialFilter;

  const LogViewerModal({super.key, this.initialFilter});

  static void show(BuildContext context, {String? initialFilter}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogViewerModal(initialFilter: initialFilter),
    );
  }

  @override
  State<LogViewerModal> createState() => _LogViewerModalState();
}

class _LogViewerModalState extends State<LogViewerModal> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedTag = '全部';
  String _searchQuery = '';

  static const List<String> _tags = [
    '全部',
    '91品色',
    'Hanime1',
    'ApiClient',
    'CfHarvester',
    'ExHentai',
    'Download',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null && _tags.contains(widget.initialFilter)) {
      _selectedTag = widget.initialFilter!;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return const Color(0xFFFF453A);
      case LogLevel.warn:
        return const Color(0xFFFFD60A);
      case LogLevel.success:
        return const Color(0xFF30D158);
      case LogLevel.info:
        return const Color(0xFF0A84FF);
      case LogLevel.debug:
        return const Color(0xFF8E8E93);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(CupertinoIcons.doc_text_search, color: Color(0xFF0A84FF), size: 22),
                const SizedBox(width: 8),
                const Text(
                  '网络诊断与运行日志',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const Spacer(),
                // Copy Button
                BouncingButton(
                  onTap: () {
                    final logs = AppLogger().getAllLogsFormatted(_selectedTag);
                    if (logs.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('当前无日志内容'), behavior: SnackBarBehavior.floating),
                      );
                      return;
                    }
                    Clipboard.setData(ClipboardData(text: logs));
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已复制全部日志到剪贴板 📋'),
                        backgroundColor: Color(0xFF30D158),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.doc_on_clipboard, size: 14, color: Color(0xFF0A84FF)),
                        SizedBox(width: 4),
                        Text('复制', style: TextStyle(color: Color(0xFF0A84FF), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Share Button
                BouncingButton(
                  onTap: () {
                    final logs = AppLogger().getAllLogsFormatted(_selectedTag);
                    if (logs.isNotEmpty) {
                      Share.share(logs, subject: 'App网络诊断日志');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.share, size: 16),
                  ),
                ),
                const SizedBox(width: 6),
                // Clear Button
                BouncingButton(
                  onTap: () {
                    AppLogger().clear();
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.trash, size: 16, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: '搜索日志关键词...',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),

          // Tag Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: _tags.map((tag) {
                final isSelected = _selectedTag == tag;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(tag, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0A84FF),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedTag = tag;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1),

          // Log Content List
          Expanded(
            child: ListenableBuilder(
              listenable: AppLogger(),
              builder: (context, _) {
                final allLogs = AppLogger().logs;
                final filteredLogs = allLogs.where((l) {
                  if (_selectedTag != '全部') {
                    if (!l.tag.contains(_selectedTag) && !l.message.contains(_selectedTag)) {
                      return false;
                    }
                  }
                  if (_searchQuery.isNotEmpty) {
                    if (!l.message.toLowerCase().contains(_searchQuery) &&
                        !l.tag.toLowerCase().contains(_searchQuery) &&
                        !(l.error?.toString().toLowerCase().contains(_searchQuery) ?? false)) {
                      return false;
                    }
                  }
                  return true;
                }).toList().reversed.toList();

                if (filteredLogs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.square_stack_3d_up, size: 40, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        const Text('暂无相关运行日志', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filteredLogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final entry = filteredLogs[index];
                    final color = _getLevelColor(entry.level);

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: color.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Tag, Level, Time
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  entry.level.name.toUpperCase(),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '[${entry.tag}]',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                entry.formattedTime,
                                style: const TextStyle(color: Colors.grey, fontSize: 10.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Message
                          SelectableText(
                            entry.message,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.35,
                              color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                            ),
                          ),

                          // Error detail
                          if (entry.error != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: SelectableText(
                                'Error: ${entry.error}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Color(0xFFFF453A),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
