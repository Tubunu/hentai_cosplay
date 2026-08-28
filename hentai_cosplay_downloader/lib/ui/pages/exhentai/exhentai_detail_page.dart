import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import '../../../models/album_item.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/exhentai_browse_provider.dart';
import '../../../services/exhentai/exhentai_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';

class ExDetailPage extends StatefulWidget {
  final AlbumItem item;

  const ExDetailPage({
    super.key,
    required this.item,
  });

  @override
  State<ExDetailPage> createState() => _ExDetailPageState();
}

class _ExDetailPageState extends State<ExDetailPage> {
  final ScrollController _scrollController = ScrollController();
  late AlbumItem _item;
  bool _isLoading = false;
  String? _errorMessage;

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
      final detailed = await ExHentaiApiService.fetchGalleryDetail(_item);
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
          _errorMessage = '获取画廊详情失败: $e';
        });
      }
    }
  }

  Color _getCategoryColor(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('doujinshi')) return const Color(0xFFE53935);
    if (lower.contains('manga')) return const Color(0xFFFB8C00);
    if (lower.contains('artist')) return const Color(0xFFF57F17);
    if (lower.contains('game')) return const Color(0xFF43A047);
    if (lower.contains('western')) return const Color(0xFF6D4C41);
    if (lower.contains('non-h')) return const Color(0xFF00ACC1);
    if (lower.contains('image')) return const Color(0xFF1E88E5);
    if (lower.contains('cosplay')) return const Color(0xFF8E24AA);
    if (lower.contains('asian')) return const Color(0xFFD81B60);
    return const Color(0xFF757575);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = const Color(0xFF9C27B0);
    final category = _item.author.isNotEmpty ? _item.author : 'ExHentai';
    final catColor = _getCategoryColor(category);

    final titleEn = _item.rawData['title_en']?.toString() ?? _item.title;
    final titleJpn = _item.rawData['title_jpn']?.toString() ?? '';
    final rating = _item.rawData['rating']?.toString() ?? '';
    final gddFileCount = int.tryParse(_item.rawData['filecount']?.toString() ?? '');
    final totalPreviewImages = _item.previewUrls.isNotEmpty ? _item.previewUrls.length : _item.imageUrls.length;
    final pagesCount = (gddFileCount != null && gddFileCount > 0 && gddFileCount < 5000)
        ? gddFileCount
        : (totalPreviewImages > 0 ? totalPreviewImages : 1);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F6F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          RandomActionButton.album(
            albumSource: MediaSourceType.exhentai,
            replace: true,
            color: themeColor,
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_clockwise),
            onPressed: _fetchDetail,
          ),
        ],
      ),
      body: _isLoading && _item.imageUrls.isEmpty
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : _errorMessage != null && _item.imageUrls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchDetail,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                    // Header Card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cover
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 110,
                                  height: 155,
                                  child: _item.coverUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: _item.coverUrl!,
                                          fit: BoxFit.cover,
                                          httpHeaders: const {
                                            'Referer': 'https://e-hentai.org/',
                                            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                                          },
                                          placeholder: (_, __) => Container(
                                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                            child: const Center(child: CupertinoActivityIndicator(radius: 8)),
                                          ),
                                          errorWidget: (_, __, ___) => Container(
                                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                            child: const Icon(CupertinoIcons.photo, size: 30),
                                          ),
                                        )
                                      : Container(
                                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                          child: const Icon(CupertinoIcons.book_fill, size: 30),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Info Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Category & Rating
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: catColor,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            category,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (rating.isNotEmpty) ...[
                                          const Icon(CupertinoIcons.star_fill, size: 14, color: Color(0xFFFFD54F)),
                                          const SizedBox(width: 4),
                                          Text(
                                            rating,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Titles
                                    Text(
                                      titleJpn.isNotEmpty ? titleJpn : titleEn,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        height: 1.3,
                                      ),
                                    ),
                                    if (titleJpn.isNotEmpty && titleEn.isNotEmpty && titleEn != titleJpn) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        titleEn,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),

                                    // Page count & Date
                                    Text(
                                      '总页数: $pagesCount P   发布: ${_item.date.split(' ').first}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white54 : Colors.black45,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Tags Chips Section
                    if (_item.tags.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(CupertinoIcons.tag_fill, size: 14, color: Color(0xFF9C27B0)),
                                    SizedBox(width: 6),
                                    Text(
                                      '标签与分类',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _item.tags.map((tag) {
                                    return GestureDetector(
                                      onTap: () {
                                        context.read<ExHentaiBrowseProvider>().search(tag);
                                        Navigator.of(context).pop();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: themeColor.withValues(alpha: isDark ? 0.18 : 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: themeColor.withValues(alpha: 0.3),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          tag,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFFCE93D8) : themeColor,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Gallery Thumbnails Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.photo_on_rectangle, size: 16, color: Color(0xFF9C27B0)),
                            const SizedBox(width: 8),
                            Text(
                              '全本画廊页码预览 ($pagesCount P)',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (_isLoading)
                              const CupertinoActivityIndicator(radius: 8),
                          ],
                        ),
                      ),
                    ),

                    // Gallery Page Thumbnails Grid
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final pageNum = index + 1;
                            final hasDirectThumb = index < _item.previewUrls.length &&
                                _item.previewUrls[index].isNotEmpty;
                            final thumbUrl = hasDirectThumb
                                ? _item.previewUrls[index]
                                : (_item.coverUrl != null && _item.coverUrl!.isNotEmpty ? _item.coverUrl : null);

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _ExPhotoGalleryViewer(
                                      item: _item,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                                    width: 0.5,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (thumbUrl != null)
                                      _ExThumbnailTile(
                                        thumbData: thumbUrl,
                                        pageNum: pageNum,
                                      )
                                    else
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: isDark
                                                ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]
                                                : [const Color(0xFFF2F2F7), const Color(0xFFE5E5EA)],
                                          ),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                CupertinoIcons.photo,
                                                size: 26,
                                                color: Color(0xFF9C27B0),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '第 $pageNum 页',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                '点击高清浏览',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      right: 4,
                                      bottom: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '#$pageNum',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: pagesCount,
                        ),
                      ),
                    ),
                  ],
                ),
                ScrollToTopButton(
                  scrollController: _scrollController,
                  color: const Color(0xFF673AB7),
                  bottomOffset: 24.0,
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: BouncingButton(
            onTap: () {
              context.read<DownloadProvider>().addBatchAlbumTasks([_item]);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已添加至下载队列: ${_item.title}'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFAB47BC), Color(0xFF8E24AA)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8E24AA).withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.arrow_down_to_line, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '一键下载全本画廊',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExPhotoGalleryViewer extends StatefulWidget {
  final AlbumItem item;
  final int initialIndex;

  const _ExPhotoGalleryViewer({
    required this.item,
    required this.initialIndex,
  });

  @override
  State<_ExPhotoGalleryViewer> createState() => _ExPhotoGalleryViewerState();
}

class _ExPhotoGalleryViewerState extends State<_ExPhotoGalleryViewer> {
  late int _currentIndex;
  late PageController _pageController;
  final Map<int, String> _resolvedImageMap = {};
  final Set<int> _resolvingIndices = {};
  final Set<int> _precachedIndices = {};
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        _preloadSurroundingImages(_currentIndex);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pageController.dispose();
    super.dispose();
  }

  /// Automatically preload upcoming 8 images and preceding 2 images in background
  void _preloadSurroundingImages(int centerIndex) {
    if (_isDisposed) return;

    final rawCount = int.tryParse(widget.item.rawData['filecount']?.toString() ?? '') ?? 0;
    final totalCount = widget.item.imageUrls.isNotEmpty
        ? widget.item.imageUrls.length
        : (widget.item.previewUrls.isNotEmpty
            ? widget.item.previewUrls.length
            : (rawCount > 0 ? rawCount : 1));

    final targetIndices = <int>[];
    for (int step = 0; step <= 8; step++) {
      final forward = centerIndex + step;
      if (forward < totalCount && !targetIndices.contains(forward)) {
        targetIndices.add(forward);
      }
    }
    for (int step = 1; step <= 2; step++) {
      final backward = centerIndex - step;
      if (backward >= 0 && !targetIndices.contains(backward)) {
        targetIndices.add(backward);
      }
    }

    _processPreloadQueue(targetIndices);
  }

  Future<void> _processPreloadQueue(List<int> indices) async {
    for (final index in indices) {
      if (_isDisposed) return;
      try {
        String? directUrl = _resolvedImageMap[index];
        if (directUrl == null || directUrl.isEmpty) {
          if (_resolvingIndices.contains(index)) continue;
          _resolvingIndices.add(index);
          directUrl = await _resolveImageForPage(index);
          _resolvingIndices.remove(index);
        }

        if (directUrl != null && directUrl.isNotEmpty && !_precachedIndices.contains(index) && mounted) {
          _precachedIndices.add(index);
          precacheImage(
            CachedNetworkImageProvider(
              directUrl,
              headers: const {
                'Referer': 'https://e-hentai.org/',
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
              },
            ),
            context,
          ).catchError((_) {});
        }
      } catch (_) {}
    }
  }

  Future<String?> _resolveImageForPage(int index) async {
    if (_resolvedImageMap.containsKey(index)) {
      return _resolvedImageMap[index];
    }

    String? pageUrl;
    if (index < widget.item.imageUrls.length) {
      pageUrl = widget.item.imageUrls[index];
    } else if (index < widget.item.previewUrls.length) {
      final pThumb = widget.item.previewUrls[index];
      if (pThumb.startsWith('sprite:')) {
        final parts = pThumb.substring(7).split('#');
        pageUrl = parts[0];
      } else {
        pageUrl = pThumb;
      }
    } else if (widget.item.coverUrl != null && widget.item.coverUrl!.isNotEmpty) {
      pageUrl = widget.item.coverUrl;
    }

    if (pageUrl == null || pageUrl.isEmpty) return null;

    // If it's already a direct image URL (png/jpg/webp/hath.network/810114.xyz)
    if (pageUrl.contains('.jpg') ||
        pageUrl.contains('.png') ||
        pageUrl.contains('.webp') ||
        pageUrl.contains('.jpeg') ||
        pageUrl.contains('.hath.network') ||
        pageUrl.contains('810114.xyz/image/s/')) {
      _resolvedImageMap[index] = pageUrl;
      return pageUrl;
    }

    // Resolve direct Hath original URL
    final direct = await ExHentaiApiService.resolveDirectImageUrl(pageUrl);
    if (direct != null && direct.isNotEmpty) {
      _resolvedImageMap[index] = direct;
      return direct;
    }

    // Fallback to cover if resolution fails
    if (widget.item.coverUrl != null && widget.item.coverUrl!.isNotEmpty) {
      _resolvedImageMap[index] = widget.item.coverUrl!;
      return widget.item.coverUrl;
    }

    return null;
  }

  Widget _buildPhotoView(String imageUrl, int index) {
    return PhotoView(
      imageProvider: CachedNetworkImageProvider(
        imageUrl,
        headers: const {
          'Referer': 'https://e-hentai.org/',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        },
      ),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3.0,
      loadingBuilder: (context, event) => const Center(
        child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
      ),
      errorBuilder: (context, error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.white70, size: 36),
            const SizedBox(height: 8),
            const Text('图片加载失败，点击重试', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _resolvedImageMap.remove(index);
                  _precachedIndices.remove(index);
                });
                _preloadSurroundingImages(index);
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawCount = int.tryParse(widget.item.rawData['filecount']?.toString() ?? '') ?? 0;
    final pagesCount = widget.item.imageUrls.isNotEmpty
        ? widget.item.imageUrls.length
        : (widget.item.previewUrls.isNotEmpty
            ? widget.item.previewUrls.length
            : (rawCount > 0 ? rawCount : 1));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // PageView with background preloading
          PageView.builder(
            itemCount: pagesCount > 0 ? pagesCount : 1,
            controller: _pageController,
            onPageChanged: (idx) {
              setState(() => _currentIndex = idx);
              _preloadSurroundingImages(idx);
            },
            itemBuilder: (context, index) {
              if (_resolvedImageMap.containsKey(index)) {
                return _buildPhotoView(_resolvedImageMap[index]!, index);
              }

              return FutureBuilder<String?>(
                future: _resolveImageForPage(index),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                    return const Center(
                      child: CupertinoActivityIndicator(color: Colors.white, radius: 16),
                    );
                  }

                  final realImageUrl = snapshot.data;
                  if (realImageUrl != null && realImageUrl.isNotEmpty) {
                    return _buildPhotoView(realImageUrl, index);
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('解析画廊原图失败', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _resolvedImageMap.remove(index);
                              _precachedIndices.remove(index);
                            });
                            _preloadSurroundingImages(index);
                          },
                          child: const Text('重新解析'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          // Top Navigation Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 16,
                bottom: 12,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / $pagesCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExThumbnailTile extends StatefulWidget {
  final String thumbData;
  final int pageNum;

  const _ExThumbnailTile({
    required this.thumbData,
    required this.pageNum,
  });

  @override
  State<_ExThumbnailTile> createState() => _ExThumbnailTileState();
}

class _ExThumbnailTileState extends State<_ExThumbnailTile> {
  ui.Image? _loadedImage;
  ImageStream? _imageStream;
  ImageStreamListener? _streamListener;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant _ExThumbnailTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thumbData != widget.thumbData) {
      _loadImage();
    }
  }

  void _loadImage() {
    if (!widget.thumbData.startsWith('sprite:')) return;

    final parts = widget.thumbData.substring(7).split('#');
    final imageUrl = parts[0];

    final provider = CachedNetworkImageProvider(
      imageUrl,
      headers: const {
        'Referer': 'https://e-hentai.org/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      },
    );

    if (_imageStream != null && _streamListener != null) {
      _imageStream!.removeListener(_streamListener!);
    }

    _imageStream = provider.resolve(const ImageConfiguration());
    _streamListener = ImageStreamListener(
      (info, _) {
        if (mounted) {
          setState(() {
            _loadedImage = info.image;
          });
        }
      },
      onError: (_, __) {},
    );
    _imageStream!.addListener(_streamListener!);
  }

  @override
  void dispose() {
    if (_imageStream != null && _streamListener != null) {
      _imageStream!.removeListener(_streamListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.thumbData.startsWith('sprite:')) {
      final parts = widget.thumbData.substring(7).split('#');
      final coords = parts.length > 1 ? parts[1].split(',') : <String>[];
      final offsetX = coords.isNotEmpty ? (double.tryParse(coords[0]) ?? 0.0) : 0.0;
      final offsetY = coords.length > 1 ? (double.tryParse(coords[1]) ?? 0.0) : 0.0;
      final itemW = coords.length > 2 ? (double.tryParse(coords[2]) ?? 200.0) : 200.0;
      final itemH = coords.length > 3 ? (double.tryParse(coords[3]) ?? 280.0) : 280.0;

      if (_loadedImage != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CustomPaint(
            size: Size.infinite,
            painter: _SpriteCustomPainter(
              image: _loadedImage!,
              srcRect: Rect.fromLTWH(offsetX, offsetY, itemW, itemH),
            ),
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(child: CupertinoActivityIndicator(radius: 8)),
      );
    }

    // Normal direct image URL
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: widget.thumbData,
        fit: BoxFit.cover,
        httpHeaders: const {
          'Referer': 'https://e-hentai.org/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
        placeholder: (_, __) => Container(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          child: const Center(child: CupertinoActivityIndicator(radius: 8)),
        ),
        errorWidget: (_, __, ___) => Container(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          child: Center(
            child: Text(
              'P ${widget.pageNum}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpriteCustomPainter extends CustomPainter {
  final ui.Image image;
  final Rect srcRect;

  _SpriteCustomPainter({required this.image, required this.srcRect});

  @override
  void paint(Canvas canvas, Size size) {
    final destRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(
      image,
      srcRect,
      destRect,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_SpriteCustomPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.srcRect != srcRect;
}
