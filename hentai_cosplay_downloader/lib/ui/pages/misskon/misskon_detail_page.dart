import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/album_item.dart';
import '../../../models/download_task.dart';
import '../../../providers/download_provider.dart';
import '../../../services/misskon/misskon_api_service.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';

class MisskonDetailPage extends StatefulWidget {
  final AlbumItem item;

  const MisskonDetailPage({super.key, required this.item});

  @override
  State<MisskonDetailPage> createState() => _MisskonDetailPageState();
}

class _MisskonDetailPageState extends State<MisskonDetailPage> {
  final ScrollController _scrollController = ScrollController();
  late AlbumItem _item;
  bool _isLoading = true;
  String? _errorMessage;

  final Set<int> _selectedIndices = {};
  bool _isSelectionMode = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detailed = await MisskonApiService.fetchAlbumDetail(_item);
      if (mounted) {
        setState(() {
          if (detailed != null) {
            _item = detailed;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '获取相册详情失败: $e';
        });
      }
    }
  }

  void _downloadAlbum() {
    final downloadProv = context.read<DownloadProvider>();
    downloadProv.addAlbumTask(_item);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 "${_item.title}" 到下载队列'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _downloadSelected() {
    if (_selectedIndices.isEmpty) return;

    final selectedUrls = _selectedIndices.map((i) => _item.imageUrls[i]).toList();
    final customAlbum = _item.copyWith(
      title: '${_item.title} (选定${selectedUrls.length}张)',
      imageUrls: selectedUrls,
      previewUrls: selectedUrls,
    );

    final downloadProv = context.read<DownloadProvider>();
    downloadProv.addAlbumTask(customAlbum);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加选中的 ${selectedUrls.length} 张图片到下载队列'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
  }

  void _openImageViewer(int initialIndex) {
    if (_item.imageUrls.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MisskonGalleryViewer(
          item: _item,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final views = _item.rawData['views']?.toString() ?? '';
    final unrarPassword = _item.rawData['unrarPassword']?.toString() ?? 'misskon.com';
    final fileSize = _item.rawData['fileSize']?.toString() ?? '';
    final dimensions = _item.rawData['dimensions']?.toString() ?? '';
    final modelName = _item.rawData['modelName']?.toString() ?? _item.author;

    // Check if task exists in download queue
    final downloadTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == _item.slug || t.albumItem.detailUrl == _item.detailUrl) {
          return t;
        }
      }
      return null;
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
          // Cupertino Large Header Navigation Bar
          SliverAppBar(
            pinned: true,
            expandedHeight: 0,
            backgroundColor: isDark ? const Color(0xCC1A1A1E) : const Color(0xCCFFFFFF),
            elevation: 0,
            leading: BouncingButton(
              onTap: () => Navigator.pop(context),
              child: const Icon(CupertinoIcons.back, size: 24),
            ),
            title: Text(
              _item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            actions: [
              const RandomActionButton.album(
                albumSource: MediaSourceType.misskon,
                replace: true,
                color: Color(0xFFE74C3C),
              ),
              if (_item.imageUrls.isNotEmpty)
                IconButton(
                  icon: Icon(
                    _isSelectionMode ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.checkmark_circle,
                    color: _isSelectionMode ? IosTheme.primaryPink : null,
                  ),
                  tooltip: '多选下载',
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = !_isSelectionMode;
                      if (!_isSelectionMode) _selectedIndices.clear();
                    });
                  },
                ),
              IconButton(
                icon: const Icon(CupertinoIcons.share),
                tooltip: '分享',
                onPressed: () {
                  if (_item.detailUrl.isNotEmpty) {
                    Share.share('${_item.title}\n${_item.detailUrl}');
                  }
                },
              ),
            ],
          ),

          // Header Info Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: FrostedGlass(
                borderRadius: 20,
                blur: 20,
                padding: const EdgeInsets.all(16),
                backgroundColor: isDark ? const Color(0x991E1E24) : Colors.white.withValues(alpha: 0.8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 80,
                            height: 110,
                            child: _item.coverUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: _item.coverUrl!,
                                    fit: BoxFit.cover,
                                    httpHeaders: const {'Referer': 'https://misskon.com/'},
                                    placeholder: (_, __) => Container(color: Colors.black12),
                                    errorWidget: (_, __, ___) => const Icon(CupertinoIcons.photo),
                                  )
                                : Container(color: Colors.black12),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Title & Meta details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _item.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (modelName.isNotEmpty)
                                Text(
                                  '模特: $modelName',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: IosTheme.primaryPink,
                                  ),
                                ),
                              if (fileSize.isNotEmpty || dimensions.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    [if (fileSize.isNotEmpty) fileSize, if (dimensions.isNotEmpty) dimensions].join(' · '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ),
                              if (views.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '浏览量: $views',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ),
                              if (unrarPassword.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '解压密码: $unrarPassword',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Tags
                    if (_item.tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _item.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 14),

                    // Action Buttons (Download Full Set / Progress)
                    Row(
                      children: [
                        Expanded(
                          child: BouncingButton(
                            onTap: _item.imageUrls.isNotEmpty
                                ? (_isSelectionMode ? _downloadSelected : _downloadAlbum)
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF2D55), Color(0xFFFF5277)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: IosTheme.primaryPink.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isSelectionMode
                                        ? CupertinoIcons.arrow_down_to_line
                                        : (downloadTask?.status == TaskStatus.completed
                                            ? CupertinoIcons.checkmark_alt
                                            : CupertinoIcons.arrow_down_circle_fill),
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isSelectionMode
                                        ? '下载选中 (${_selectedIndices.length}张)'
                                        : (downloadTask?.status == TaskStatus.completed
                                            ? '已在本地 (重新下载)'
                                            : '下载全套相册 (${_item.imageUrls.length}张)'),
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      CupertinoActivityIndicator(radius: 14),
                      SizedBox(height: 12),
                      Text('正在解析相册高清大图...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),

          // Error message
          if (_errorMessage != null && !_isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.amber, size: 36),
                      const SizedBox(height: 8),
                      Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchDetail,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Photos Grid
          if (_item.imageUrls.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.68,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final imgUrl = _item.imageUrls[index];
                    final isSelected = _selectedIndices.contains(index);

                    return GestureDetector(
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
                          _openImageViewer(index);
                        }
                      },
                      onLongPress: () {
                        setState(() {
                          _isSelectionMode = true;
                          _selectedIndices.add(index);
                        });
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 350,
                              httpHeaders: const {'Referer': 'https://misskon.com/'},
                              placeholder: (_, __) => Container(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                child: const Center(child: CupertinoActivityIndicator(radius: 8)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                child: const Icon(CupertinoIcons.photo, size: 20, color: Colors.grey),
                              ),
                            ),

                            // Index badge
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            // Selection overlay
                            if (_isSelectionMode)
                              Positioned.fill(
                                child: Container(
                                  color: isSelected
                                      ? IosTheme.primaryPink.withValues(alpha: 0.3)
                                      : Colors.black.withValues(alpha: 0.2),
                                  alignment: Alignment.topRight,
                                  padding: const EdgeInsets.all(6),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected ? IosTheme.primaryPink : Colors.black54,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      isSelected ? CupertinoIcons.checkmark_alt : null,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
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
          bottomOffset: 24.0,
        ),
      ],
    ),
  );
  }
}

class _MisskonGalleryViewer extends StatefulWidget {
  final AlbumItem item;
  final int initialIndex;

  const _MisskonGalleryViewer({
    required this.item,
    required this.initialIndex,
  });

  @override
  State<_MisskonGalleryViewer> createState() => _MisskonGalleryViewerState();
}

class _MisskonGalleryViewerState extends State<_MisskonGalleryViewer> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            itemCount: widget.item.imageUrls.length,
            pageController: _pageController,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (context, index) {
              final url = widget.item.imageUrls[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(
                  url,
                  headers: const {'Referer': 'https://misskon.com/'},
                ),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3.5,
              );
            },
            loadingBuilder: (context, event) => const Center(
              child: CupertinoActivityIndicator(radius: 14, color: Colors.white),
            ),
          ),

          // Top Header Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BouncingButton(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.clear, color: Colors.white, size: 20),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.item.imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
