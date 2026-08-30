import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/album_item.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';

class MztDetailPage extends StatefulWidget {
  final AlbumItem item;

  const MztDetailPage({super.key, required this.item});

  @override
  State<MztDetailPage> createState() => _MztDetailPageState();
}

class _MztDetailPageState extends State<MztDetailPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BrowsingHistoryProvider>().recordAlbum(
          widget.item,
          siteKey: 'mzt',
          siteName: '妹子图',
          siteColor: const Color(0xFFFF4081),
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _resolvePreviewUrls(List<String> proxyDomains) {
    final domain = proxyDomains.isNotEmpty
        ? proxyDomains.first.replaceAll(RegExp(r'/+$'), '')
        : 'https://tgproxy.1258012.xyz';

    return widget.item.imageUrls.map((u) {
      if (u.startsWith('/')) {
        return '$domain$u';
      }
      return u;
    }).toList();
  }

  void _downloadAll(BuildContext context) {
    context.read<DownloadProvider>().addAlbumTask(widget.item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 "${widget.item.title}" 加入下载队列'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _downloadSelectedImages(List<String> resolvedUrls) {
    if (_selectedIndices.isEmpty) return;
    final selectedOriginalUrls = _selectedIndices.map((i) => widget.item.imageUrls[i]).toList();
    final customItem = widget.item.copyWith(
      title: '${widget.item.title} (精选${selectedOriginalUrls.length}张)',
      imageUrls: selectedOriginalUrls,
    );
    context.read<DownloadProvider>().addAlbumTask(customItem);
    setState(() {
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加入下载: ${customItem.title}'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openGalleryViewer(BuildContext context, List<String> previewUrls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MztPhotoViewer(
          title: widget.item.title,
          imageUrls: previewUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsProv = context.watch<SettingsProvider>();
    final previewUrls = _resolvePreviewUrls(settingsProv.config.mztProxyDomains);
    final coverUrl = previewUrls.isNotEmpty ? previewUrls.first : widget.item.coverUrl;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF7F7FA),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
          // Album Header with Parallax & Ambient Blur
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? const Color(0xE61A1A1E) : const Color(0xF0FFFFFF),
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
              const RandomActionButton.album(
                albumSource: MediaSourceType.mzt,
                replace: true,
                color: IosTheme.primaryPink,
              ),
              Builder(
                builder: (btnCtx) => BouncingButton(
                  onTap: () {
                    final box = btnCtx.findRenderObject() as RenderBox?;
                    Share.share(
                      '【妹子图包】${widget.item.title}\n共 ${widget.item.imageUrls.length} 张图片',
                      subject: widget.item.title,
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
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Ambient blurred background
                  if (coverUrl != null && coverUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      httpHeaders: const {'Referer': 'https://mzt.111404.xyz/'},
                    ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                    child: Container(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  ),

                  // Center Artwork
                  Positioned(
                    top: 80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: coverUrl != null && coverUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: coverUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 400,
                                  httpHeaders: const {'Referer': 'https://mzt.111404.xyz/'},
                                  placeholder: (_, __) => const Center(child: CupertinoActivityIndicator()),
                                  errorWidget: (_, __, ___) => const Icon(CupertinoIcons.photo, size: 40),
                                )
                              : const Icon(CupertinoIcons.photo),
                        ),
                      ),
                    ),
                  ),

                  // Metadata title & author
                  Positioned(
                    bottom: 12,
                    left: 20,
                    right: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.item.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: IosTheme.primaryPink,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'MZT 妹子图',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.item.author}  •  共 ${widget.item.imageUrls.length} 张图片',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black87,
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

          // Download Action Buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  // One-click Download All Button
                  Expanded(
                    flex: 3,
                    child: BouncingButton(
                      onTap: () => _downloadAll(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: IosTheme.musicGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: IosTheme.primaryPink.withValues(alpha: 0.35),
                              blurRadius: 14,
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
                              '一键下载整包',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Multi-select Button
                  Expanded(
                    flex: 2,
                    child: BouncingButton(
                      onTap: () {
                        if (_isSelectionMode) {
                          _downloadSelectedImages(previewUrls);
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

          // Images Grid Section
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final url = previewUrls[index];
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
                        _openGalleryViewer(context, previewUrls, index);
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            color: isDark ? const Color(0xFF222226) : const Color(0xFFEBEBF0),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              memCacheWidth: 350,
                              httpHeaders: const {'Referer': 'https://mzt.111404.xyz/'},
                              placeholder: (_, __) => const Center(
                                child: CupertinoActivityIndicator(radius: 8),
                              ),
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 24),
                              ),
                            ),
                          ),
                        ),
                        // Image Number Indicator
                        Positioned(
                          left: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        // Selection Checkmark
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
                childCount: previewUrls.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
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

class _MztPhotoViewer extends StatefulWidget {
  final String title;
  final List<String> imageUrls;
  final int initialIndex;

  const _MztPhotoViewer({
    required this.title,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_MztPhotoViewer> createState() => _MztPhotoViewerState();
}

class _MztPhotoViewerState extends State<_MztPhotoViewer> {
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
          PhotoViewGallery.builder(
            itemCount: widget.imageUrls.length,
            pageController: _pageController,
            onPageChanged: (idx) {
              setState(() => _currentIndex = idx);
            },
            builder: (context, index) {
              final url = widget.imageUrls[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(
                  url,
                  headers: const {'Referer': 'https://mzt.111404.xyz/'},
                ),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3.0,
              );
            },
            loadingBuilder: (context, event) => const Center(
              child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
            ),
          ),

          // Top Controls
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
                    FrostedGlass(
                      borderRadius: 16,
                      blur: 16,
                      backgroundColor: Colors.black45,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.imageUrls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
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
