import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import '../../../models/album_item.dart';
import '../../../models/download_task.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/nsfwpub/nsfwpub_api_service.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';

class NsfwpubDetailPage extends StatefulWidget {
  final AlbumItem item;

  const NsfwpubDetailPage({super.key, required this.item});

  @override
  State<NsfwpubDetailPage> createState() => _NsfwpubDetailPageState();
}

class _NsfwpubDetailPageState extends State<NsfwpubDetailPage> {
  final ScrollController _scrollController = ScrollController();
  late AlbumItem _item;
  bool _isLoading = true;
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
    _loadDetail();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BrowsingHistoryProvider>().recordAlbum(
          _item,
          siteKey: 'nsfwpub',
          siteName: 'NSFWPub',
          siteColor: const Color(0xFFD63384),
        );
      }
    });
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final updated = await NsfwpubApiService.fetchAlbumDetail(_item);
      if (mounted) {
        setState(() {
          _item = updated;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载图集详情失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _openGallery(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _NsfwpubPhotoViewGallery(
          item: _item,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFFD63384);

    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == _item.slug || t.albumItem.detailUrl == _item.detailUrl) {
          return t;
        }
      }
      return null;
    });

    final photoCount = _item.imageUrls.isNotEmpty
        ? _item.imageUrls.length
        : (_item.rawData['photo_count'] as int? ?? 0);
    final model = _item.rawData['model'] as String? ?? _item.author;
    final cosplay = _item.rawData['cosplay'] as String? ?? '';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF7F8FA),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Immersive AppBar
              SliverAppBar(
                pinned: true,
                backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                foregroundColor: isDark ? Colors.white : Colors.black87,
                elevation: 0,
                title: Text(
                  _item.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  RandomActionButton.album(
                    albumSource: MediaSourceType.nsfwpub,
                    color: themeColor,
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Hero Banner / Cover Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_item.coverUrl != null && _item.coverUrl!.isNotEmpty)
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: CachedNetworkImage(
                                  imageUrl: _item.coverUrl!,
                                  fit: BoxFit.cover,
                                  httpHeaders: const {
                                    'Referer': 'https://nsfwpub.com/',
                                    'User-Agent':
                                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                                  },
                                  placeholder: (context, url) => Container(
                                    color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                                    child: const Center(
                                      child: CupertinoActivityIndicator(radius: 14),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                                    child: const Icon(CupertinoIcons.photo, size: 40, color: Colors.grey),
                                  ),
                                ),
                              ),

                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _item.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Badges
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (photoCount > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: themeColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 0.6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(CupertinoIcons.camera_fill, size: 12, color: themeColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$photoCount 张照片',
                                                style: const TextStyle(
                                                  color: themeColor,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (model.isNotEmpty && model != 'NSFWPub')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '模特: $model',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      if (cosplay.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '角色: $cosplay',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Colors.purpleAccent,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Download Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: Icon(
                                        existingTask != null
                                            ? CupertinoIcons.check_mark_circled_solid
                                            : CupertinoIcons.cloud_download,
                                        size: 18,
                                      ),
                                      label: Text(
                                        existingTask != null
                                            ? (existingTask.status == TaskStatus.completed
                                                ? '图集已下载完成'
                                                : '图集正在下载中...')
                                            : '下载整套图集 ($photoCount P)',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: themeColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: existingTask != null || _item.imageUrls.isEmpty
                                          ? null
                                          : () {
                                              final downloadProv = context.read<DownloadProvider>();
                                              downloadProv.addAlbumTask(_item);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('已添加整套图集到下载队列'),
                                                  backgroundColor: themeColor,
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Gallery Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.photo_fill_on_rectangle_fill, size: 16, color: themeColor),
                      const SizedBox(width: 6),
                      Text(
                        '图集照片 (${_item.imageUrls.length} P)',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_item.imageUrls.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(CupertinoIcons.eye, size: 14),
                          label: const Text('全屏看图', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(foregroundColor: themeColor),
                          onPressed: () => _openGallery(0),
                        ),
                    ],
                  ),
                ),
              ),

              // Loading / Error / Images Grid
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CupertinoActivityIndicator(radius: 16),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: Colors.orangeAccent),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(CupertinoIcons.refresh, size: 16),
                            label: const Text('重试'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _loadDetail,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 40),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final imgUrl = _item.imageUrls[index];
                        return GestureDetector(
                          onTap: () => _openGallery(index),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: imgUrl,
                                  fit: BoxFit.cover,
                                  httpHeaders: const {
                                    'Referer': 'https://nsfwpub.com/',
                                    'User-Agent':
                                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                                  },
                                  placeholder: (context, url) => Container(
                                    color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                                    child: const Center(
                                      child: CupertinoActivityIndicator(radius: 10),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                                    child: const Icon(CupertinoIcons.photo, size: 24, color: Colors.grey),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${index + 1}',
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
                      childCount: _item.imageUrls.length,
                    ),
                  ),
                ),
            ],
          ),

          ScrollToTopButton(scrollController: _scrollController),
        ],
      ),
    );
  }
}

class _NsfwpubPhotoViewGallery extends StatefulWidget {
  final AlbumItem item;
  final int initialIndex;

  const _NsfwpubPhotoViewGallery({
    required this.item,
    required this.initialIndex,
  });

  @override
  State<_NsfwpubPhotoViewGallery> createState() => _NsfwpubPhotoViewGalleryState();
}

class _NsfwpubPhotoViewGalleryState extends State<_NsfwpubPhotoViewGallery> {
  late PageController _pageController;
  late int _currentIndex;

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
    final images = widget.item.imageUrls;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            itemCount: images.length,
            pageController: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(
                  images[index],
                  headers: const {
                    'Referer': 'https://nsfwpub.com/',
                    'User-Agent':
                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                  },
                ),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3.0,
                heroAttributes: PhotoViewHeroAttributes(tag: images[index]),
              );
            },
            loadingBuilder: (context, event) => const Center(
              child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
            ),
          ),

          // Header Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        '${_currentIndex + 1} / ${images.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
