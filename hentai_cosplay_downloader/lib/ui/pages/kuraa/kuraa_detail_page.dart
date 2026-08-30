import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/album_item.dart';
import '../../../models/download_task.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/kuraa/kuraa_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';

class KuraaDetailPage extends StatefulWidget {
  final KuraaFileItem folderItem;
  final String? token;
  final AlbumItem? initialAlbum;

  const KuraaDetailPage({
    super.key,
    required this.folderItem,
    this.token,
    this.initialAlbum,
  });

  @override
  State<KuraaDetailPage> createState() => _KuraaDetailPageState();
}

class _KuraaDetailPageState extends State<KuraaDetailPage> {
  final ScrollController _scrollController = ScrollController();
  AlbumItem? _album;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _recordHistory(AlbumItem item) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BrowsingHistoryProvider>().recordAlbum(
          item,
          siteKey: 'kuraa',
          siteName: 'Kuraa',
          siteColor: const Color(0xFF00897B),
          extra: {'folderId': widget.folderItem.id},
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialAlbum != null) {
      _album = widget.initialAlbum;
      _isLoading = false;
      _recordHistory(_album!);
    } else {
      _fetchDetail();
    }
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detailed = await KuraaApiService.fetchAlbumDetail(
        widget.folderItem,
        token: widget.token,
      );
      if (mounted) {
        setState(() {
          _album = detailed;
          _isLoading = false;
        });
        if (detailed != null) {
          _recordHistory(detailed);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '获取相册内容失败: $e';
        });
      }
    }
  }

  void _downloadAlbum() {
    if (_album == null || _album!.imageUrls.isEmpty) return;

    final downloadProv = context.read<DownloadProvider>();
    downloadProv.addBatchAlbumTasks([_album!]);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 "${_album!.title}" (${_album!.imageUrls.length} 张原图) 到下载队列'),
        backgroundColor: const Color(0xFF00897B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openGallery(int initialIndex) {
    if (_album == null || _album!.imageUrls.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KuraaPhotoGalleryView(
          imageUrls: _album!.imageUrls,
          initialIndex: initialIndex,
          title: _album!.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFF00897B);

    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      if (_album == null) return null;
      for (final t in p.allTasks) {
        if (t.albumItem.slug == _album!.slug) {
          return t;
        }
      }
      return null;
    });

    final imageUrls = _album?.imageUrls ?? [];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
          // Cupertino Navigation Bar
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
              widget.folderItem.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            actions: [
              const RandomActionButton.album(
                albumSource: MediaSourceType.kuraa,
                replace: true,
                color: Color(0xFF6C5CE7),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.share),
                tooltip: '分享',
                onPressed: () {
                  final shareUrl = 'https://p.kuraa.cc/?storageLocationId=${widget.folderItem.storageLocationId}&folderId=${widget.folderItem.id}';
                  Share.share('${widget.folderItem.name}\n$shareUrl');
                },
              ),
            ],
          ),

          // Header Info Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: FrostedGlass(
                borderRadius: 20,
                blur: 20,
                padding: const EdgeInsets.all(16),
                backgroundColor: isDark ? const Color(0x991E1E24) : Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.folderItem.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Stats row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.photo_fill_on_rectangle_fill, color: themeColor, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                _isLoading ? '解析中...' : '${imageUrls.length} 张图片',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: themeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white12 : Colors.black12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.folderItem.storageLocationId == '4' ? '🔒 内板独家' : '☁️ 公开资源',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Download Action Button
                    Row(
                      children: [
                        Expanded(
                          child: BouncingButton(
                            onTap: imageUrls.isNotEmpty ? _downloadAlbum : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF26A69A), Color(0xFF00897B)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: themeColor.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    existingTask?.status == TaskStatus.completed
                                        ? CupertinoIcons.checkmark_alt
                                        : CupertinoIcons.arrow_down_circle_fill,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    existingTask?.status == TaskStatus.completed
                                        ? '已下载至相册 (重新下载)'
                                        : '一键下载全部原图 (${imageUrls.length}P)',
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

          // Loading Indicator
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CupertinoActivityIndicator(radius: 14),
                ),
              ),
            ),

          // Error State
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
                        style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white),
                        onPressed: _fetchDetail,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Images Grid
          if (!_isLoading && imageUrls.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final imgUrl = imageUrls[index];
                    return BouncingButton(
                      onTap: () => _openGallery(index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 350,
                              placeholder: (_, __) => Container(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                child: const Center(child: CupertinoActivityIndicator(radius: 8)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                child: const Icon(CupertinoIcons.photo, color: Colors.grey),
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#${index + 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: imageUrls.length,
                ),
              ),
            ),
          ],
        ),
        ScrollToTopButton(
          scrollController: _scrollController,
          color: const Color(0xFF00897B),
          bottomOffset: 24.0,
        ),
      ],
    ),
  );
  }
}

class KuraaPhotoGalleryView extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String title;

  const KuraaPhotoGalleryView({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    required this.title,
  });

  @override
  State<KuraaPhotoGalleryView> createState() => _KuraaPhotoGalleryViewState();
}

class _KuraaPhotoGalleryViewState extends State<KuraaPhotoGalleryView> {
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
            itemCount: widget.imageUrls.length,
            pageController: _pageController,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (context, index) {
              final url = widget.imageUrls[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(url),
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
                    '${_currentIndex + 1} / ${widget.imageUrls.length}',
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
