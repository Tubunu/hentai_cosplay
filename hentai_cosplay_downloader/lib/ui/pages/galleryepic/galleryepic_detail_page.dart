import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import '../../../models/album_item.dart';
import '../../../models/download_task.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/galleryepic/galleryepic_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';

class GalleryepicDetailPage extends StatefulWidget {
  final AlbumItem item;

  const GalleryepicDetailPage({super.key, required this.item});

  @override
  State<GalleryepicDetailPage> createState() => _GalleryepicDetailPageState();
}

class _GalleryepicDetailPageState extends State<GalleryepicDetailPage> {
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
          siteKey: 'galleryepic',
          siteName: 'GalleryEpic',
          siteColor: const Color(0xFFE11D48),
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
      final detailed = await GalleryepicApiService.fetchAlbumDetail(_item);
      if (detailed != null && mounted) {
        setState(() {
          _item = detailed;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载相册详情失败: $e';
          _isLoading = false;
        });
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openGallery(int initialIndex) {
    if (_item.imageUrls.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _GalleryepicGalleryViewer(
          imageUrls: _item.imageUrls,
          initialIndex: initialIndex,
          title: _item.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existingTask = context.select<DownloadProvider, AlbumDownloadTask?>((p) {
      for (final t in p.allTasks) {
        if (t.albumItem.slug == _item.slug || t.albumItem.detailUrl == _item.detailUrl) {
          return t;
        }
      }
      return null;
    });

    final isDownloaded = existingTask?.status == TaskStatus.completed;
    final isDownloading = existingTask?.status == TaskStatus.downloading;
    const themeColor = Color(0xFFE11D48);

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          const RandomActionButton.album(
            albumSource: MediaSourceType.galleryepic,
            replace: true,
            color: themeColor,
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            onPressed: _loadDetail,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadDetail, child: const Text('重试')),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _item.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(CupertinoIcons.person_solid, size: 14, color: themeColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      _item.author.isNotEmpty ? _item.author : 'GalleryEpic',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 16),
                                    if (_item.date.isNotEmpty) ...[
                                      const Icon(CupertinoIcons.photo_on_rectangle, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        _item.date,
                                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                                if (_item.tags.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: _item.tags.map((t) {
                                      return Chip(
                                        label: Text(t, style: const TextStyle(fontSize: 11)),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      );
                                    }).toList(),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Text(
                                      '共 ${_item.imageUrls.length} 张高清原图',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const Spacer(),
                                    ElevatedButton.icon(
                                      icon: Icon(
                                        isDownloaded
                                            ? CupertinoIcons.check_mark_circled
                                            : isDownloading
                                                ? CupertinoIcons.arrow_2_circlepath
                                                : CupertinoIcons.cloud_download,
                                        size: 16,
                                      ),
                                      label: Text(
                                        isDownloaded
                                            ? '已下载'
                                            : isDownloading
                                                ? '下载中'
                                                : '下载全相册',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: themeColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      onPressed: isDownloaded
                                          ? null
                                          : () {
                                              context.read<DownloadProvider>().addAlbumTask(_item);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('已添加到下载队列'),
                                                  backgroundColor: themeColor,
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            },
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.72,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final url = _item.imageUrls[index];
                                return GestureDetector(
                                  onTap: () => _openGallery(index),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        CachedNetworkImage(
                                          imageUrl: url,
                                          fit: BoxFit.cover,
                                          memCacheWidth: 400,
                                          httpHeaders: const {
                                            'Referer': 'https://galleryepic.xyz/',
                                            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                                          },
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey.withValues(alpha: 0.2),
                                            child: const Center(
                                              child: CupertinoActivityIndicator(radius: 10),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: Colors.grey.withValues(alpha: 0.2),
                                            child: const Icon(CupertinoIcons.photo, color: Colors.grey),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 4,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '#${index + 1}',
                                              style: const TextStyle(color: Colors.white, fontSize: 10),
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
                        const SliverToBoxAdapter(child: SizedBox(height: 50)),
                      ],
                    ),
                    ScrollToTopButton(scrollController: _scrollController),
                  ],
                ),
    );
  }
}

class _GalleryepicGalleryViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String title;

  const _GalleryepicGalleryViewer({
    required this.imageUrls,
    required this.initialIndex,
    required this.title,
  });

  @override
  State<_GalleryepicGalleryViewer> createState() => _GalleryepicGalleryViewerState();
}

class _GalleryepicGalleryViewerState extends State<_GalleryepicGalleryViewer> {
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
        fit: StackFit.expand,
        children: [
          // Fullscreen Photo View Gallery
          PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(
                  widget.imageUrls[index],
                  headers: const {
                    'Referer': 'https://galleryepic.xyz/',
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                  },
                ),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 3,
              );
            },
            itemCount: widget.imageUrls.length,
            loadingBuilder: (context, event) => const Center(
              child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
            ),
            pageController: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),

          // Top Floating Overlay Controls with Prominent Counter
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back / Close Button
                    BouncingButton(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 18),
                      ),
                    ),

                    // Prominent Floating Counter Capsule
                    FrostedGlass(
                      borderRadius: 16,
                      blur: 16,
                      backgroundColor: Colors.black54,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.imageUrls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    // Copy Image URL Button
                    BouncingButton(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.imageUrls[_currentIndex]));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已复制高清原图链接'),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: const Icon(CupertinoIcons.link, color: Colors.white, size: 18),
                      ),
                    ),
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
