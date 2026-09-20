import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/unified_photo_viewer.dart';
import '../../../models/album_item.dart';
import '../../../models/download_task.dart';
import '../../../providers/browse_provider.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/favorite_provider.dart';
import '../../../services/hc_api_service.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'package:hentai_cosplay_downloader/utils/app_share.dart';

class AlbumDetailPage extends StatefulWidget {
  final AlbumItem initialItem;

  const AlbumDetailPage({super.key, required this.initialItem});

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  final ScrollController _scrollController = ScrollController();
  late AlbumItem _item;
  bool _isLoading = true;
  String? _errorMessage;

  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _item = widget.initialItem;
    _loadAlbumDetails();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          context.read<BrowsingHistoryProvider>().recordAlbum(
            _item,
            siteKey: 'hc_gallery',
            siteName: 'HC 图集',
            siteColor: IosTheme.primaryPink,
          );
        } catch (e) {
          debugPrint('[AlbumDetail] History recording error: $e');
        }
      }
    });
  }

  Future<void> _loadAlbumDetails() async {
    if (!_isLoading || _errorMessage != null) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
    }

    try {
      final detailed = await HCApiService.fetchAlbumDetail(_item);
      if (detailed != null) {
        if (mounted) {
          setState(() {
            _item = detailed;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = '获取相册图片详情失败，请检查网络。';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载出错: $e';
        });
      }
    }
  }

  void _openGalleryViewer(BuildContext context, int initialIndex) {
    UnifiedPhotoViewer.open(
      context,
      imageUrls: _item.imageUrls,
      initialIndex: initialIndex,
      title: _item.title,
      author: _item.author,
      httpHeaders: const {
        'Referer': 'https://hentai-cosplay-xxx.com/',
      },
    );
  }

  void _downloadSelectedImages() {
    if (_selectedIndices.isEmpty) {
      setState(() => _isSelectionMode = false);
      return;
    }
    final sortedIndices = _selectedIndices.toList()..sort();
    final selectedUrls = sortedIndices.map((i) => _item.imageUrls[i]).toList();
    final customItem = _item.copyWith(
      title: '${_item.title} (精选${selectedUrls.length}张)',
      imageUrls: selectedUrls,
    );
    context.read<DownloadProvider>().addAlbumTask(customItem);
    setState(() {
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加入下载: ${customItem.title}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFav = context.select<FavoriteProvider, bool>(
      (p) => p.isFavoriteItem(
        id: 'hc_${_item.slug.isNotEmpty ? _item.slug : _item.detailUrl.hashCode}',
        detailUrl: _item.detailUrl,
      ),
    );
    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatus(slug: _item.slug, detailUrl: _item.detailUrl),
    );
    final isDownloaded = taskStatus == TaskStatus.completed;
    final isDownloading = taskStatus == TaskStatus.downloading ||
        taskStatus == TaskStatus.queued;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedIndices.clear();
          });
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
            // Parallax Header
            SliverAppBar(
              backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
              expandedHeight: 320,
              pinned: true,
              stretch: true,
              leading: Semantics(
                button: true,
                label: '返回',
                child: Tooltip(
                  message: '返回',
                  child: BouncingButton(
                    onTap: () {
                      if (_isSelectionMode) {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedIndices.clear();
                        });
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 0.5),
                    ),
                    child: const Icon(CupertinoIcons.back, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
            actions: [
              Semantics(
                button: true,
                label: isFav ? '取消收藏' : '收藏图集',
                child: Tooltip(
                  message: isFav ? '取消收藏' : '收藏图集',
                  child: BouncingButton(
                    onTap: () {
                      context.read<FavoriteProvider>().toggleAlbum(_item, siteKey: 'hc', siteName: 'Hentai Cosplay');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isFav ? '已从我的收藏中移除' : '已收藏图集: ${_item.title}'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Icon(
                        isFav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                        color: isFav ? const Color(0xFFFF2D55) : Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const RandomActionButton.album(
                albumSource: MediaSourceType.hc,
                replace: true,
                color: IosTheme.primaryPink,
              ),
              Builder(
                builder: (btnCtx) => Semantics(
                  button: true,
                  label: '分享图集',
                  child: Tooltip(
                    message: '分享图集',
                    child: BouncingButton(
                      onTap: () {
                        final box = btnCtx.findRenderObject() as RenderBox?;
                        AppShare.share(context, 
                          '【Cosplay图集】${_item.title}\n${_item.detailUrl}',
                          subject: _item.title,
                          sharePositionOrigin: box != null ? (box.localToGlobal(Offset.zero) & box.size) : null,
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: const Icon(CupertinoIcons.share, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _item.coverUrl != null && _item.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _item.coverUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 600,
                          httpHeaders: const {
                            'Referer': 'https://hentai-cosplay-xxx.com/',
                          },
                        )
                      : Container(color: Colors.grey[900]),
                  // Dark Vignette Gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  // Title & Info at Bottom of Header
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: IosTheme.primaryPink,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _item.author,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (_item.date.isNotEmpty) ...[
                              Icon(CupertinoIcons.calendar, size: 13, color: Colors.white.withValues(alpha: 0.8)),
                              const SizedBox(width: 4),
                              Text(
                                _item.date,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Icon(CupertinoIcons.photo, size: 13, color: Colors.white.withValues(alpha: 0.8)),
                            const SizedBox(width: 4),
                            Text(
                              '${_item.imageUrls.isNotEmpty ? _item.imageUrls.length : (_isLoading ? "加载中..." : "0")} 张图片',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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

          // Action Button Row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  // One-click Download All Button
                  Expanded(
                    flex: 3,
                    child: BouncingButton(
                      onTap: isDownloaded || isDownloading
                          ? null
                          : () {
                              context.read<DownloadProvider>().addAlbumTask(_item);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('已加入下载队列: ${_item.title}'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isDownloaded
                              ? IosTheme.primaryGreen
                              : (isDownloading
                                  ? IosTheme.primaryPink.withValues(alpha: 0.6)
                                  : IosTheme.primaryPink),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (isDownloaded ? IosTheme.primaryGreen : IosTheme.primaryPink)
                                  .withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isDownloaded
                                  ? CupertinoIcons.checkmark_alt
                                  : (isDownloading
                                      ? CupertinoIcons.arrow_down_circle
                                      : CupertinoIcons.arrow_down_circle_fill),
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isDownloaded
                                  ? '图集已下载完成'
                                  : (isDownloading
                                      ? '正在下载中...'
                                      : '一键下载全集'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Select Multiple Images Button
                  Expanded(
                    flex: 2,
                    child: BouncingButton(
                      onTap: () {
                        if (_isSelectionMode) {
                          _downloadSelectedImages();
                        } else {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedIndices.clear();
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isSelectionMode ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.square_grid_2x2,
                              size: 17,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isSelectionMode
                                  ? (_selectedIndices.isEmpty ? '退出多选' : '下载 (${_selectedIndices.length})')
                                  : '多选下载',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Album Tags Chips (if loaded)
          if (_item.tags.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _item.tags.map((tag) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: BouncingButton(
                          onTap: () {
                            context.read<BrowseProvider>().setTag(tag);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.tag_fill, size: 11, color: IosTheme.primaryPink),
                                const SizedBox(width: 4),
                                Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
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
              ),
            ),

          // Loading or Error State
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Column(
                    children: [
                      CupertinoActivityIndicator(radius: 14),
                      SizedBox(height: 12),
                      Text('正在解析相册原图链接...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            )
          else if (_errorMessage != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_circle, color: Colors.orange, size: 36),
                      const SizedBox(height: 10),
                      Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 14),
                      BouncingButton(
                        onTap: _loadAlbumDetails,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: IosTheme.primaryPink,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('重试', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            // Grid of Images in Album
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final previewUrl = index < _item.previewUrls.length
                        ? _item.previewUrls[index]
                        : _item.imageUrls[index];
                    final isSelected = _selectedIndices.contains(index);

                    return BouncingButton(
                      onTap: () {
                        if (_isSelectionMode) {
                          setState(() {
                            if (isSelected) {
                              _selectedIndices.remove(index);
                            } else {
                              _selectedIndices.add(index);
                            }
                          });
                        } else {
                          _openGalleryViewer(context, index);
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              color: isDark ? const Color(0xFF242426) : const Color(0xFFE5E5EA),
                              child: CachedNetworkImage(
                                imageUrl: previewUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 350,
                                httpHeaders: const {
                                  'Referer': 'https://hentai-cosplay-xxx.com/',
                                },
                                placeholder: (_, __) => const Center(
                                  child: CupertinoActivityIndicator(radius: 8),
                                ),
                                errorWidget: (_, __, ___) => const Icon(
                                  CupertinoIcons.photo,
                                  color: Colors.grey,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          // Index Number Badge
                          Positioned(
                            left: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          // Selection Indicator
                          if (_isSelectionMode)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isSelected ? IosTheme.primaryPink : Colors.black54,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: isSelected
                                    ? const Icon(CupertinoIcons.checkmark, size: 14, color: Colors.white)
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                  childCount: _item.imageUrls.length,
                ),
              ),
            ),
          ],
        ),
        ScrollToTopButton(
          scrollController: _scrollController,
          color: IosTheme.primaryPink,
          bottomOffset: 30.0,
        ),
      ],
    ),
  ),
  );
  }
}

