import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/favorite_item.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/favorite_provider.dart';
import '../../../providers/jable_download_provider.dart';
import '../../../services/history_router.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/chrome_insets_coordinator.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../../widgets/unified_media_card.dart';

/// Full-featured cross-site favorites page supporting album & video bookmarks,
/// real-time search, category/site filtering, one-click playback/routing, and batch management.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<FavoriteItem> items) {
    setState(() {
      if (_selectedIds.length == items.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(items.map((i) => i.id));
      }
    });
  }

  void _batchDelete(FavoriteProvider favProv, List<FavoriteItem> items) {
    if (_selectedIds.isEmpty) return;

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('确认删除收藏'),
        content: Text('确定要将选中的 ${_selectedIds.length} 个项目从收藏夹中移除吗？'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () {
              Navigator.pop(ctx);
              final deletedItems = items.where((i) => _selectedIds.contains(i.id)).toList();
              favProv.removeFavorites(_selectedIds);
              setState(() {
                _selectedIds.clear();
                _isSelectionMode = false;
              });

              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已删除 ${deletedItems.length} 个收藏'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                  action: SnackBarAction(
                    label: '撤销',
                    textColor: IosTheme.primaryPink,
                    onPressed: () {
                      for (final item in deletedItems.reversed) {
                        favProv.addFavorite(item);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _batchDownload(List<FavoriteItem> items) {
    final toDownload = items.where((i) => _selectedIds.contains(i.id)).toList();
    if (toDownload.isEmpty) return;

    final downloadProv = context.read<DownloadProvider>();
    final jableDownloadProv = context.read<JableDownloadProvider>();

    int albumCount = 0;
    int videoCount = 0;

    for (final item in toDownload) {
      if (item.isVideo) {
        if (item.siteKey == 'jable') {
          jableDownloadProv.enqueue(
            item.detailUrl,
            initialTitle: item.title,
            initialThumbnail: item.coverUrl,
            duration: item.duration ?? '',
          );
        } else {
          downloadProv.addVideoTask(item.toVideoItem());
        }
        videoCount++;
      } else {
        downloadProv.addAlbumTask(item.toAlbumItem());
        albumCount++;
      }
    }

    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('批量下载任务已添加 ($albumCount套图集, $videoCount个视频)'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showClearAllDialog(FavoriteProvider favProv) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('清空全部收藏'),
        content: const Text('确定要清空所有收藏夹内容吗？此操作不可恢复。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('清空'),
            onPressed: () {
              Navigator.pop(ctx);
              favProv.clearAll();
              setState(() {
                _selectedIds.clear();
                _isSelectionMode = false;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favProv = context.watch<FavoriteProvider>();
    final items = favProv.filteredFavorites;
    final siteMap = favProv.siteMap;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedIds.clear();
          });
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text(
                          '我的收藏',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2D55).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${favProv.totalCount} 项',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF2D55),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Search Bar & Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoSearchTextField(
                            controller: _searchController,
                            placeholder: '搜索收藏的图集、视频或作者...',
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            onChanged: (val) {
                              if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
                              _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                                if (mounted) {
                                  favProv.setSearchQuery(val);
                                }
                              });
                            },
                          ),
                        ),

                        // Batch Selection Toggle Button
                        if (items.isNotEmpty || _isSelectionMode) ...[
                          const SizedBox(width: 8),
                          BouncingButton(
                          onTap: () {
                            setState(() {
                              _isSelectionMode = !_isSelectionMode;
                              if (!_isSelectionMode) _selectedIds.clear();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                            decoration: BoxDecoration(
                              color: _isSelectionMode
                                  ? const Color(0xFFFF2D55)
                                  : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _isSelectionMode ? '完成' : '选择',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _isSelectionMode ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Clear All Menu Button
                      if (favProv.totalCount > 0) ...[
                        const SizedBox(width: 6),
                        BouncingButton(
                          onTap: () => _showClearAllDialog(favProv),
                          child: Container(
                            padding: const EdgeInsets.all(7.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.trash,
                              size: 15,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Category & Site Capsule Filters (Horizontal Scroll)
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Media Type: 全部
                        _buildFilterCapsule(
                          label: '全部',
                          isSelected: favProv.mediaTypeFilter == 'all',
                          onTap: () => favProv.setMediaTypeFilter('all'),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 6),
                        // Media Type: 图集
                        _buildFilterCapsule(
                          label: '图集',
                          icon: CupertinoIcons.photo_fill_on_rectangle_fill,
                          isSelected: favProv.mediaTypeFilter == 'album',
                          onTap: () => favProv.setMediaTypeFilter('album'),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 6),
                        // Media Type: 视频
                        _buildFilterCapsule(
                          label: '视频',
                          icon: CupertinoIcons.play_circle_fill,
                          isSelected: favProv.mediaTypeFilter == 'video',
                          onTap: () => favProv.setMediaTypeFilter('video'),
                          isDark: isDark,
                        ),

                        // Site Filters if multiple sites exist
                        if (siteMap.isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            width: 1,
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                          _buildFilterCapsule(
                            label: '全站',
                            isSelected: favProv.siteFilter == null,
                            onTap: () => favProv.setSiteFilter(null),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          ...siteMap.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _buildFilterCapsule(
                                label: entry.value,
                                isSelected: favProv.siteFilter == entry.key,
                                onTap: () => favProv.setSiteFilter(entry.key),
                                isDark: isDark,
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content Grid
            Expanded(
              child: Stack(
                children: [
                  items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.heart,
                                size: 52,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                favProv.totalCount == 0 ? '暂无收藏内容' : '没有匹配的收藏项',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                favProv.totalCount == 0
                                    ? '在浏览图集或视频时，点击爱心即可收藏到此处。'
                                    : '请尝试更换搜索词或筛选条件。',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white24 : Colors.black26,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Builder(
                          builder: (ctx) {
                            final isOnlyVideos = favProv.mediaTypeFilter == 'video';
                            final screenWidth = MediaQuery.of(ctx).size.width;
                            final crossAxisCount = screenWidth > 900 ? 4 : (screenWidth > 600 ? 3 : 2);
                            final childAspectRatio = isOnlyVideos ? 1.25 : 0.72;

                            return GridView.builder(
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 140),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: childAspectRatio,
                              ),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                            final item = items[index];
                            final isSelected = _selectedIds.contains(item.id);

                            return UnifiedMediaCard(
                              title: item.title,
                              coverUrl: item.coverUrl,
                              mediaType: item.isVideo ? UnifiedMediaType.video : UnifiedMediaType.gallery,
                              brandColor: item.siteColor,
                              duration: item.duration,
                              imageCount: item.imageCount,
                              author: item.author.isNotEmpty ? item.author : null,
                              date: item.date.isNotEmpty ? item.date : null,
                              tag: item.siteName,
                              isFavorite: true,
                              isSelected: isSelected,
                              isSelectionMode: _isSelectionMode,
                              onFavoriteTap: () {
                                favProv.removeFavorite(item.id, detailUrl: item.detailUrl);
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('已取消收藏: ${item.title}'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 3),
                                    action: SnackBarAction(
                                      label: '撤销',
                                      textColor: IosTheme.primaryPink,
                                      onPressed: () {
                                        favProv.addFavorite(item);
                                      },
                                    ),
                                  ),
                                );
                              },
                              onDownloadTap: () {
                                if (item.isVideo) {
                                  if (item.siteKey == 'jable') {
                                    context.read<JableDownloadProvider>().enqueue(
                                      item.detailUrl,
                                      initialTitle: item.title,
                                      initialThumbnail: item.coverUrl,
                                      duration: item.duration ?? '',
                                    );
                                  } else {
                                    context.read<DownloadProvider>().addVideoTask(item.toVideoItem());
                                  }
                                } else {
                                  context.read<DownloadProvider>().addAlbumTask(item.toAlbumItem());
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('已加入下载队列: ${item.title}'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSelection(item.id);
                                } else {
                                  HistoryRouter.openRecord(context, item.toHistoryRecord());
                                }
                              },
                              onLongPress: () {
                                if (!_isSelectionMode) {
                                  setState(() {
                                    _isSelectionMode = true;
                                    _selectedIds.add(item.id);
                                  });
                                } else {
                                  _toggleSelection(item.id);
                                }
                              },
                            );
                          },
                        );
                      },
                    ),

                  // Floating Multi-Select Action Bar
                  if (_isSelectionMode)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: ChromeInsets.floatingBottom(context, extra: 16),
                      child: FrostedGlass(
                        borderRadius: 24,
                        blur: 25,
                        backgroundColor: isDark
                            ? const Color(0xDD1C1C1E)
                            : const Color(0xDDFFFFFF),
                        borderColor: isDark ? Colors.white12 : Colors.black12,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Text(
                              '已选 ${_selectedIds.length} 项',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            BouncingButton(
                              onTap: () => _selectAll(items),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  _selectedIds.length == items.length ? '取消全选' : '全选',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            BouncingButton(
                              onTap: _selectedIds.isEmpty ? null : () => _batchDownload(items),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: IosTheme.primaryCyan,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(CupertinoIcons.arrow_down_to_line, size: 12, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text('下载', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            BouncingButton(
                              onTap: _selectedIds.isEmpty ? null : () => _batchDelete(favProv, items),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF3B30),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(CupertinoIcons.trash, size: 12, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text('删除', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Scroll to Top
                  ScrollToTopButton(
                    scrollController: _scrollController,
                    color: const Color(0xFFFF2D55),
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

  Widget _buildFilterCapsule({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return BouncingButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF2D55)
              : (isDark ? const Color(0xFF1E1E22) : const Color(0xFFE5E5EA)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF2D55).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
