import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/album_item.dart';
import '../../providers/settings_provider.dart';
import '../../services/network_client.dart';
import '../../services/storage_service.dart';
import '../theme/ios_theme.dart';
import 'bouncing_button.dart';
import 'frosted_glass.dart';
import 'package:hentai_cosplay_downloader/utils/app_share.dart';
import '../../utils/referer_helper.dart';

class UnifiedPhotoViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String title;
  final String author;
  final Map<String, String>? httpHeaders;
  final MediaSourceType? sourceType;
  final bool isLocal;

  const UnifiedPhotoViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.title = '',
    this.author = '',
    this.httpHeaders,
    this.sourceType,
    this.isLocal = false,
  });

  static void open(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
    String title = '',
    String author = '',
    Map<String, String>? httpHeaders,
    MediaSourceType? sourceType,
    bool isLocal = false,
  }) {
    if (imageUrls.isEmpty) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => UnifiedPhotoViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          title: title,
          author: author,
          httpHeaders: httpHeaders,
          sourceType: sourceType,
          isLocal: isLocal,
        ),
      ),
    );
  }

  @override
  State<UnifiedPhotoViewer> createState() => _UnifiedPhotoViewerState();
}

class _UnifiedPhotoViewerState extends State<UnifiedPhotoViewer> {
  late int _currentIndex;
  late PageController _pageController;
  final ScrollController _waterfallScrollController = ScrollController();
  bool _isWaterfallMode = false;
  final Set<int> _precachedIndices = {};
  bool _isDisposed = false;
  Timer? _preloadDebounce;
  bool _showControls = true;
  bool _isSavingImage = false;
  bool _isZoomed = false;
  double _dragOffsetY = 0.0;

  Map<String, String> _buildEffectiveHeaders(String url) {
    return RefererHelper.buildImageHeaders(
      url,
      sourceType: widget.sourceType,
      customHeaders: widget.httpHeaders,
    );
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.imageUrls.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        _preloadSurroundingImages(_currentIndex);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _preloadDebounce?.cancel();
    _pageController.dispose();
    _waterfallScrollController.dispose();
    super.dispose();
  }

  void _schedulePreload(int centerIndex) {
    _preloadDebounce?.cancel();
    _preloadDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!_isDisposed && mounted) {
        _preloadSurroundingImages(centerIndex);
      }
    });
  }

  void _preloadSurroundingImages(int centerIndex) {
    if (_isDisposed || !mounted || widget.isLocal) return;
    final images = widget.imageUrls;
    
    final int preloadCount = context.read<SettingsProvider>().config.photoPreloadCount;
    if (preloadCount <= 0) return;
    
    int forwardCount = (preloadCount * 0.7).ceil();
    int backwardCount = preloadCount - forwardCount;

    for (int step = 0; step <= forwardCount; step++) {
      if (!mounted) return;
      final forward = centerIndex + step;
      if (forward < images.length && !_precachedIndices.contains(forward)) {
        _precachedIndices.add(forward);
        final url = images[forward];
        precacheImage(
          CachedNetworkImageProvider(
            url,
            headers: _buildEffectiveHeaders(url),
          ),
          context,
        ).catchError((_) {});
      }
    }

    for (int step = 1; step <= backwardCount; step++) {
      if (!mounted) return;
      final backward = centerIndex - step;
      if (backward >= 0 && !_precachedIndices.contains(backward)) {
        _precachedIndices.add(backward);
        final url = images[backward];
        precacheImage(
          CachedNetworkImageProvider(
            url,
            headers: _buildEffectiveHeaders(url),
          ),
          context,
        ).catchError((_) {});
      }
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    if (details.delta.dy > 0 || _dragOffsetY > 0) {
      setState(() {
        _dragOffsetY = (_dragOffsetY + details.delta.dy).clamp(0.0, 350.0);
        if (_showControls && _dragOffsetY > 12) {
          _showControls = false;
        }
      });
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isZoomed) return;
    if (_dragOffsetY > 110 || (details.primaryVelocity != null && details.primaryVelocity! > 550)) {
      Navigator.pop(context);
    } else {
      setState(() {
        _dragOffsetY = 0.0;
      });
    }
  }

  void _handleVerticalDragCancel() {
    if (_dragOffsetY > 0) {
      setState(() {
        _dragOffsetY = 0.0;
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _toggleReadingMode() {
    setState(() {
      _isWaterfallMode = !_isWaterfallMode;
    });
    if (!_isWaterfallMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentIndex);
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_waterfallScrollController.hasClients || widget.imageUrls.length <= 1) {
          return;
        }
        final position = _waterfallScrollController.position;
        if (position.hasContentDimensions && position.maxScrollExtent > 0) {
          final targetOffset = (_currentIndex / (widget.imageUrls.length - 1)) * position.maxScrollExtent;
          _waterfallScrollController.jumpTo(targetOffset);
        }
      });
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isWaterfallMode ? '已切换为竖向长图模式（双击单图可进入高清翻页）' : '已切换为左右翻页模式'),
        duration: const Duration(milliseconds: 1200),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveSingleImage() async {
    if (_isSavingImage) return;
    final currentUrl = widget.imageUrls[_currentIndex];

    if (Platform.isAndroid) {
      final hasPerm = await StorageService.requestStoragePermissions();
      if (!hasPerm && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未授予存储权限，保存可能会失败'),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isSavingImage = true);

    try {
      final settings = context.read<SettingsProvider>();
      var saveBaseDir = settings.config.savePath.trim();
      if (saveBaseDir.isEmpty) {
        saveBaseDir = await StorageService.getDefaultDownloadPath();
      }
      final singlePicturesDir = Directory(p.join(saveBaseDir, 'SavedPictures'));
      if (!await singlePicturesDir.exists()) {
        await singlePicturesDir.create(recursive: true);
      }

      final ext = AlbumItem.resolveExt(currentUrl);
      final cleanTitle = AlbumItem.cleanFilename(
        widget.title.isNotEmpty ? widget.title : 'SavedImage',
      );
      final filename = '${cleanTitle}_p${_currentIndex + 1}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final targetFile = File(p.join(singlePicturesDir.path, filename));

      if (widget.isLocal) {
        final src = File(currentUrl);
        if (await src.exists()) {
          await src.copy(targetFile.path);
        }
      } else {
        final dio = NetworkClient.createDio();
        final headers = _buildEffectiveHeaders(currentUrl);
        await dio.download(
          currentUrl,
          targetFile.path,
          options: Options(headers: headers),
        );
      }

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存单张图片至: ${p.basename(targetFile.path)}'),
            backgroundColor: IosTheme.primaryPink,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: '分享',
              textColor: Colors.white,
              onPressed: () {
                AppShare.shareXFiles(context, [XFile(targetFile.path)]);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存图片失败: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingImage = false);
      }
    }
  }

  void _shareCurrentImage(BuildContext btnCtx) {
    final currentUrl = widget.imageUrls[_currentIndex];
    final box = btnCtx.findRenderObject() as RenderBox?;
    final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

    if (widget.isLocal) {
      AppShare.shareXFiles(context, 
        [XFile(currentUrl)],
        text: widget.title,
        sharePositionOrigin: origin,
      );
    } else {
      AppShare.share(context, 
        '${widget.title.isNotEmpty ? widget.title : '图集图片'} - $currentUrl',
        subject: widget.title,
        sharePositionOrigin: origin,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.imageUrls;
    final double dragFraction = (_dragOffsetY / 300.0).clamp(0.0, 1.0);
    final double bgOpacity = (1.0 - dragFraction * 0.7).clamp(0.0, 1.0);
    final double scale = 1.0 - dragFraction * 0.15;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: bgOpacity),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. PhotoView Gallery (PageView Mode) or Continuous Waterfall List
          _isWaterfallMode
              ? NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification || notification is ScrollEndNotification) {
                      final metrics = notification.metrics;
                      if (metrics.maxScrollExtent > 0 && images.length > 1) {
                        final progress = (metrics.pixels / metrics.maxScrollExtent).clamp(0.0, 1.0);
                        final estimated = (progress * (images.length - 1)).round().clamp(0, images.length - 1);
                        if (estimated != _currentIndex) {
                          setState(() {
                            _currentIndex = estimated;
                          });
                          _schedulePreload(estimated);
                        }
                      }
                    }
                    return false;
                  },
                  child: GestureDetector(
                    onTap: _toggleControls,
                    behavior: HitTestBehavior.opaque,
                    child: ListView.builder(
                      controller: _waterfallScrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 60,
                        bottom: MediaQuery.of(context).padding.bottom + 80,
                      ),
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        final url = images[index];
                        return GestureDetector(
                          onDoubleTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _currentIndex = index;
                              _isWaterfallMode = false;
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_pageController.hasClients) {
                                _pageController.jumpToPage(index);
                              }
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            child: widget.isLocal
                                ? Image.file(
                                    File(url),
                                    fit: BoxFit.fitWidth,
                                    cacheWidth: 2160,
                                    errorBuilder: (_, __, ___) => const SizedBox(
                                      height: 200,
                                      child: Center(child: Icon(CupertinoIcons.photo, color: Colors.grey)),
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: url,
                                    httpHeaders: _buildEffectiveHeaders(url),
                                    fit: BoxFit.fitWidth,
                                    placeholder: (context, url) => Container(
                                      height: 360,
                                      alignment: Alignment.center,
                                      child: const CupertinoActivityIndicator(color: Colors.white, radius: 14),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      height: 200,
                                      alignment: Alignment.center,
                                      child: const Icon(CupertinoIcons.exclamationmark_circle, color: Colors.grey),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: _toggleControls,
                  onVerticalDragUpdate: _isZoomed ? null : _handleVerticalDragUpdate,
                  onVerticalDragEnd: _isZoomed ? null : _handleVerticalDragEnd,
                  onVerticalDragCancel: _isZoomed ? null : _handleVerticalDragCancel,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: _dragOffsetY == 0 ? const Duration(milliseconds: 200) : Duration.zero,
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.diagonal3Values(scale, scale, 1.0)
                      ..setTranslationRaw(0.0, _dragOffsetY, 0.0),
                    transformAlignment: Alignment.center,
                    child: PhotoViewGallery.builder(
                      itemCount: images.length,
                      pageController: _pageController,
                      scaleStateChangedCallback: (state) {
                        final zoomed = state != PhotoViewScaleState.initial;
                        if (_isZoomed != zoomed && mounted) {
                          setState(() => _isZoomed = zoomed);
                        }
                      },
                      onPageChanged: (idx) {
                        setState(() => _currentIndex = idx);
                        _schedulePreload(idx);
                      },
                      builder: (context, index) {
                        final url = images[index];
                        final ImageProvider imageProvider;
                        if (widget.isLocal) {
                          imageProvider = ResizeImage(FileImage(File(url)), width: 2160);
                        } else {
                          imageProvider = CachedNetworkImageProvider(
                            url,
                            headers: _buildEffectiveHeaders(url),
                          );
                        }

                        return PhotoViewGalleryPageOptions(
                          imageProvider: imageProvider,
                          minScale: PhotoViewComputedScale.contained,
                          maxScale: PhotoViewComputedScale.covered * 3.5,
                          heroAttributes: PhotoViewHeroAttributes(tag: 'photo_viewer_${index}_$url'),
                        );
                      },
                      loadingBuilder: (context, event) => const Center(
                        child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
                      ),
                    ),
                  ),
                ),

          // 2. Animated Top Bar Controls
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            top: _showControls ? 0 : -120,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 14,
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
                  const SizedBox(width: 12),

                  // Title and Author
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.title.isNotEmpty)
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (widget.author.isNotEmpty)
                          Text(
                            widget.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Index badge
                  FrostedGlass(
                    borderRadius: 14,
                    blur: 16,
                    backgroundColor: Colors.black45,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text(
                      '${_currentIndex + 1}/${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Waterfall / PageView reading mode toggle
                  BouncingButton(
                    onTap: _toggleReadingMode,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isWaterfallMode ? IosTheme.primaryPink.withAlpha(220) : Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Icon(
                        _isWaterfallMode ? CupertinoIcons.rectangle_grid_1x2 : CupertinoIcons.book,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Save Single Picture Button
                  BouncingButton(
                    onTap: _isSavingImage ? null : _saveSingleImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: IosTheme.primaryPink.withAlpha(200),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: _isSavingImage
                          ? const CupertinoActivityIndicator(radius: 8, color: Colors.white)
                          : const Icon(CupertinoIcons.arrow_down_to_line, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Share / Link Button
                  Builder(
                    builder: (btnCtx) => BouncingButton(
                      onTap: () => _shareCurrentImage(btnCtx),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: const Icon(CupertinoIcons.share, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Animated Bottom Scrubber Slider Bar
          if (images.length > 1)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              bottom: _showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                  top: 16,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${_currentIndex + 1}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3.5,
                          activeTrackColor: IosTheme.primaryPink,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayColor: IosTheme.primaryPink.withAlpha(40),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        ),
                        child: Slider(
                          value: _currentIndex.toDouble().clamp(0.0, (images.length - 1).toDouble()),
                          min: 0.0,
                          max: (images.length - 1).toDouble(),
                          divisions: images.length > 1 ? images.length - 1 : 1,
                          onChanged: (val) {
                            final target = val.round();
                            if (target != _currentIndex) {
                              setState(() => _currentIndex = target);
                              if (!_isWaterfallMode) {
                                _pageController.jumpToPage(target);
                              } else if (_waterfallScrollController.hasClients) {
                                final maxScroll = _waterfallScrollController.position.maxScrollExtent;
                                if (maxScroll > 0) {
                                  final targetOffset = (target / (images.length - 1)) * maxScroll;
                                  _waterfallScrollController.jumpTo(targetOffset);
                                }
                                _schedulePreload(target);
                              }
                            }
                          },
                        ),
                      ),
                    ),
                    Text(
                      '${images.length}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
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
