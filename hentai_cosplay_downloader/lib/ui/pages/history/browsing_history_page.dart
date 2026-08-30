import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/browsing_history_record.dart';
import '../../../models/resource_site_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../services/history_router.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';

class BrowsingHistoryPage extends StatefulWidget {
  const BrowsingHistoryPage({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => const BrowsingHistoryPage(),
      ),
    );
  }

  @override
  State<BrowsingHistoryPage> createState() => _BrowsingHistoryPageState();
}

class _BrowsingHistoryPageState extends State<BrowsingHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'album', 'video', or specific siteKey

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24 && now.day == time.day) {
      return '今天 ${DateFormat('HH:mm').format(time)}';
    } else if (diff.inDays < 2 || (diff.inHours < 48 && now.day - time.day == 1)) {
      return '昨天 ${DateFormat('HH:mm').format(time)}';
    } else if (now.year == time.year) {
      return DateFormat('MM-dd HH:mm').format(time);
    } else {
      return DateFormat('yyyy-MM-dd').format(time);
    }
  }

  void _showClearConfirmDialog(BrowsingHistoryProvider historyProv) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('清空浏览历史'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text('确定要清空全部在线资源浏览历史记录吗？此操作无法撤销。'),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              historyProv.clearAll();
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已清空全部浏览历史'),
                  backgroundColor: IosTheme.primaryPink,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(milliseconds: 1500),
                ),
              );
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final historyProv = context.watch<BrowsingHistoryProvider>();
    final allRecords = historyProv.records;

    // Filter by search & tag
    final filteredRecords = allRecords.where((r) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = r.title.toLowerCase().contains(q);
        final matchAuthor = r.author.toLowerCase().contains(q);
        final matchSite = r.siteName.toLowerCase().contains(q);
        if (!matchTitle && !matchAuthor && !matchSite) return false;
      }

      if (_selectedFilter == 'album') {
        return !r.isVideo;
      } else if (_selectedFilter == 'video') {
        return r.isVideo;
      } else if (_selectedFilter != 'all') {
        return r.siteKey == _selectedFilter;
      }
      return true;
    }).toList();

    // Get unique site keys present in history
    final activeSiteKeys = allRecords.map((r) => r.siteKey).toSet().toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '浏览历史',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            if (allRecords.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: IosTheme.primaryPink.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${allRecords.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: IosTheme.primaryPink,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (allRecords.isNotEmpty)
            TextButton.icon(
              onPressed: () => _showClearConfirmDialog(historyProv),
              icon: const Icon(CupertinoIcons.trash, size: 16, color: Colors.redAccent),
              label: const Text(
                '清空',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.redAccent),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: '搜索看过的标题、作者或站点...',
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13.5),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
            ),
          ),

          // Horizontal Filter Chips
          if (allRecords.isNotEmpty)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterChip('全部 (${allRecords.length})', 'all', isDark),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    '📸 图集 (${allRecords.where((r) => !r.isVideo).length})',
                    'album',
                    isDark,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    '🎬 视频 (${allRecords.where((r) => r.isVideo).length})',
                    'video',
                    isDark,
                  ),
                  ...activeSiteKeys.map((k) {
                    final site = ResourceSiteRegistry.allSites[k];
                    final siteCount = allRecords.where((r) => r.siteKey == k).length;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _buildFilterChip(
                        '${site?.label ?? k} ($siteCount)',
                        k,
                        isDark,
                      ),
                    );
                  }),
                ],
              ),
            ),

          const SizedBox(height: 6),

          // History Records List
          Expanded(
            child: filteredRecords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty
                              ? CupertinoIcons.search
                              : CupertinoIcons.clock_fill,
                          size: 54,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty ? '没有找到相关历史记录' : '暂无浏览历史',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isNotEmpty
                              ? '请尝试更换搜索关键词'
                              : '在【在线资源】中点开图集或播放视频后将自动记录于此处',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: filteredRecords.length,
                    itemBuilder: (context, index) {
                      final record = filteredRecords[index];
                      return _buildRecordCard(record, isDark, historyProv);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _selectedFilter == value;
    return BouncingButton(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? IosTheme.primaryPink
              : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard(
    BrowsingHistoryRecord record,
    bool isDark,
    BrowsingHistoryProvider historyProv,
  ) {
    final siteColor = Color(record.siteColorValue);

    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(CupertinoIcons.trash, color: Colors.white, size: 22),
      ),
      onDismissed: (_) {
        historyProv.removeRecord(record.id);
        HapticFeedback.lightImpact();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
            width: 0.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HistoryRouter.openRecord(context, record);
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover Thumbnail
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: (record.coverUrl != null && record.coverUrl!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: record.coverUrl!,
                                fit: BoxFit.cover,
                                httpHeaders: const {
                                  'User-Agent':
                                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
                                },
                                placeholder: (_, __) => Container(
                                  color: isDark ? Colors.white10 : Colors.black12,
                                  child: const Center(
                                    child: CupertinoActivityIndicator(radius: 8),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: isDark ? Colors.white10 : Colors.black12,
                                  child: Icon(
                                    record.isVideo ? CupertinoIcons.film : CupertinoIcons.photo,
                                    color: Colors.grey,
                                    size: 24,
                                  ),
                                ),
                              )
                            : Container(
                                color: isDark ? Colors.white10 : Colors.black12,
                                child: Icon(
                                  record.isVideo ? CupertinoIcons.film : CupertinoIcons.photo,
                                  color: Colors.grey,
                                  size: 24,
                                ),
                              ),
                      ),
                    ),
                    // Video Badge
                    if (record.isVideo)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(CupertinoIcons.play_fill, size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 12),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Site tag & relative time
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: siteColor.withValues(alpha: isDark ? 0.22 : 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: siteColor.withValues(alpha: 0.4),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              record.siteName,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: siteColor,
                              ),
                            ),
                          ),
                          if (record.duration != null && record.duration!.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                record.duration!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            _formatRelativeTime(record.viewedAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Title
                      Text(
                        record.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Author & Delete button
                      Row(
                        children: [
                          if (record.author.isNotEmpty)
                            Expanded(
                              child: Text(
                                record.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              historyProv.removeRecord(record.id);
                              HapticFeedback.lightImpact();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                CupertinoIcons.xmark,
                                size: 14,
                                color: isDark ? Colors.white38 : Colors.black38,
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
      ),
    );
  }
}
