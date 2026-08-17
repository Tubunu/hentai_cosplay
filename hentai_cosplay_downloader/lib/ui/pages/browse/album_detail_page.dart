import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/album_item.dart';
import '../../../providers/download_provider.dart';
import '../../../services/hc_api_service.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';

class AlbumDetailPage extends StatefulWidget {
  final AlbumItem initialItem;

  const AlbumDetailPage({super.key, required this.initialItem});

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  late AlbumItem _item;
  bool _isLoading = true;
  String? _errorMessage;

  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _item = widget.initialItem;
    _loadAlbumDetails();
  }

  Future<void> _loadAlbumDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoGalleryViewer(
          item: _item,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _downloadSelectedImages() {
    if (_selectedIndices.isEmpty) return;
    final selectedUrls = _selectedIndices.map((i) => _item.imageUrls[i]).toList();
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
    final downloadProv = context.watch<DownloadProvider>();

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Parallax Header
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            leading: BouncingButton(
              onTap: () => Navigator.pop(context),
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
            actions: [
              Builder(
                builder: (btnCtx) => BouncingButton(
                  onTap: () {
                    final box = btnCtx.findRenderObject() as RenderBox?;
                    Share.share(
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
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _item.coverUrl != null && _item.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _item.coverUrl!,
                          fit: BoxFit.cover,
                          httpHeaders: const {
                            'Referer': 'https://zh.hentai-cosplay-xxx.com/',
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
                      onTap: () {
                        downloadProv.addAlbumTask(_item);
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
                          color: IosTheme.primaryPink,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: IosTheme.primaryPink.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.arrow_down_circle_fill, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              '一键下载全集',
                              style: TextStyle(
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
                                httpHeaders: const {
                                  'Referer': 'https://zh.hentai-cosplay-xxx.com/',
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
    );
  }
}

class _PhotoGalleryViewer extends StatefulWidget {
  final AlbumItem item;
  final int initialIndex;

  const _PhotoGalleryViewer({
    required this.item,
    required this.initialIndex,
  });

  @override
  State<_PhotoGalleryViewer> createState() => _PhotoGalleryViewerState();
}

class _PhotoGalleryViewerState extends State<_PhotoGalleryViewer> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.item.imageUrls;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // PhotoView Gallery
          PhotoViewGallery.builder(
            itemCount: images.length,
            pageController: _pageController,
            onPageChanged: (idx) {
              setState(() => _currentIndex = idx);
            },
            builder: (context, index) {
              final url = images[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(
                  url,
                  headers: const {
                    'Referer': 'https://zh.hentai-cosplay-xxx.com/',
                  },
                ),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3.0,
                heroAttributes: PhotoViewHeroAttributes(tag: 'img_$index'),
              );
            },
            loadingBuilder: (context, event) => const Center(
              child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
            ),
          ),

          // Top App Bar Controls
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
                    // Close Button
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

                    // Page counter indicator
                    FrostedGlass(
                      borderRadius: 16,
                      blur: 16,
                      backgroundColor: Colors.black45,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Text(
                        '${_currentIndex + 1} / ${images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    // Copy Image URL Button
                    BouncingButton(
                      onTap: () {
                        final currentUrl = images[_currentIndex];
                        Clipboard.setData(ClipboardData(text: currentUrl));
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
