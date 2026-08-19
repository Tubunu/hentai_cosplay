import 'dart:io';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../providers/gallery_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/storage_service.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/liquid_glass.dart';

class LocalGalleryPage extends StatefulWidget {
  const LocalGalleryPage({super.key});

  @override
  State<LocalGalleryPage> createState() => _LocalGalleryPageState();
}

class _LocalGalleryPageState extends State<LocalGalleryPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final savePath = context.read<SettingsProvider>().config.savePath;
      context.read<GalleryProvider>().scanLocalDirectory(savePath);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSortSheet(BuildContext context, GalleryProvider galleryProv) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择相册排序方式'),
        actions: GallerySortMode.values.map((mode) {
          final isSelected = galleryProv.sortMode == mode;
          return CupertinoActionSheetAction(
            onPressed: () {
              galleryProv.setSortMode(mode);
              Navigator.pop(ctx);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected) ...[
                  const Icon(CupertinoIcons.checkmark_alt, color: IosTheme.primaryPink, size: 18),
                  const SizedBox(width: 6),
                ],
                Text(
                  mode.label,
                  style: TextStyle(
                    color: isSelected ? IosTheme.primaryPink : null,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _openRandomAlbum(BuildContext context, List<LocalAlbumFolder> albums) {
    if (albums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('本地图库暂无相册，快去在线图片下载吧～'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final randomIndex = Random().nextInt(albums.length);
    final randomAlbum = albums[randomIndex];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎲 随机进入: ${randomAlbum.title}'),
        duration: const Duration(milliseconds: 1500),
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LocalAlbumViewer(initialIndex: randomIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final galleryProv = context.watch<GalleryProvider>();
    final settingsProv = context.watch<SettingsProvider>();
    final albums = galleryProv.localAlbums;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        '本地图库',
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
                          color: IosTheme.primaryCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${galleryProv.albumCount} 套 / ${galleryProv.totalImages} 张',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: IosTheme.primaryCyan,
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Random Pick Button
                      BouncingButton(
                        onTap: () => _openRandomAlbum(context, albums),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF2D55), Color(0xFFFF5E3A)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF2D55).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Text('🎲', style: TextStyle(fontSize: 13)),
                              SizedBox(width: 4),
                              Text(
                                '随机图包',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sort Mode Button
                      BouncingButton(
                        onTap: () => _showSortSheet(context, galleryProv),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.arrow_up_arrow_down,
                            size: 16,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Scan / Refresh Button
                      BouncingButton(
                        onTap: galleryProv.isScanning
                            ? null
                            : () => galleryProv.scanLocalDirectory(settingsProv.config.savePath),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            shape: BoxShape.circle,
                          ),
                          child: galleryProv.isScanning
                              ? const CupertinoActivityIndicator(radius: 8)
                              : Icon(
                                  CupertinoIcons.refresh,
                                  size: 16,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search Bar & Current Sort Status
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          placeholder: '搜索本地相册或作者...',
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          onChanged: (val) {
                            galleryProv.setSearchQuery(val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      BouncingButton(
                        onTap: () => _showSortSheet(context, galleryProv),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            galleryProv.sortMode.label.split(' ').first,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Album Grid
            Expanded(
              child: albums.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.photo_on_rectangle,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            galleryProv.isScanning ? '正在扫描本地相册...' : '暂无本地下载的相册',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.76,
                      ),
                      itemCount: albums.length,
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        return _buildLocalAlbumCard(album, index, isDark, galleryProv);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Widget _buildLocalAlbumCard(LocalAlbumFolder album, int index, bool isDark, GalleryProvider galleryProv) {
    return BouncingButton(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _LocalAlbumViewer(initialIndex: index),
          ),
        );
      },
      onLongPress: () {
        showCupertinoModalPopup(
          context: context,
          builder: (ctx) => CupertinoActionSheet(
            title: Text(album.title),
            actions: [
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  galleryProv.deleteLocalAlbum(album);
                },
                child: const Text('删除本地图集'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              child: const Text('取消'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
            width: 0.6,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  album.coverPath != null
                      ? Image.file(
                          File(album.coverPath!),
                          cacheWidth: 400,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo, color: Colors.grey),
                        )
                      : const Icon(CupertinoIcons.photo, color: Colors.grey),
                  // Count & Size pill
                  Positioned(
                    right: 8,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        album.totalBytes > 0
                            ? '${album.imageCount} 张 • ${formatBytes(album.totalBytes)}'
                            : '${album.imageCount} 张',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Title & Author
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    album.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: IosTheme.primaryPink, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalAlbumViewer extends StatefulWidget {
  final int initialIndex;

  const _LocalAlbumViewer({required this.initialIndex});

  @override
  State<_LocalAlbumViewer> createState() => _LocalAlbumViewerState();
}

class _LocalAlbumViewerState extends State<_LocalAlbumViewer> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _prevAlbum(List<LocalAlbumFolder> albums) {
    if (albums.isEmpty) return;
    setState(() {
      if (_currentIndex > 0) {
        _currentIndex--;
      } else {
        _currentIndex = albums.length - 1; // wrap around to last
      }
    });
  }

  void _nextAlbum(List<LocalAlbumFolder> albums) {
    if (albums.isEmpty) return;
    setState(() {
      if (_currentIndex < albums.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = 0; // wrap around to first
      }
    });
  }

  void _randomAlbum(List<LocalAlbumFolder> albums) {
    if (albums.length <= 1) return;
    int nextIdx;
    do {
      nextIdx = Random().nextInt(albums.length);
    } while (nextIdx == _currentIndex && albums.length > 1);

    setState(() {
      _currentIndex = nextIdx;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎲 切换至: ${albums[_currentIndex].title}'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final galleryProv = context.watch<GalleryProvider>();
    final settingsProv = context.watch<SettingsProvider>();
    final albums = galleryProv.localAlbums;

    if (albums.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('相册已清空')),
        body: const Center(child: Text('没有更多本地相册')),
      );
    }

    // Clamp index in case albums were deleted
    _currentIndex = _currentIndex.clamp(0, albums.length - 1);
    final album = albums[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              '${album.author} • 第 ${_currentIndex + 1}/${albums.length} 套 (${album.imageCount}张 • ${_LocalGalleryPageState.formatBytes(album.totalBytes)})',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (btnCtx) => IconButton(
              icon: const Icon(CupertinoIcons.share),
              onPressed: () {
                if (album.imagePaths.isNotEmpty) {
                  final box = btnCtx.findRenderObject() as RenderBox?;
                  Share.shareXFiles(
                    album.imagePaths.map((p) => XFile(p)).toList(),
                    text: album.title,
                    sharePositionOrigin: box != null ? (box.localToGlobal(Offset.zero) & box.size) : null,
                  );
                }
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Image Grid
          GridView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: album.imagePaths.length,
            itemBuilder: (context, index) {
              final path = album.imagePaths[index];

              return BouncingButton(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _LocalPhotoGalleryViewer(
                        album: album,
                        initialIndex: index,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    color: isDark ? const Color(0xFF242426) : const Color(0xFFE5E5EA),
                    child: Image.file(
                      File(path),
                      cacheWidth: 360,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo, color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
          ),

          // Bottom Floating Navigation Capsule (上一个 / 随机 / 下一个)
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: LiquidGlass(
                borderRadius: 24,
                blur: 20,
                opacity: settingsProv.config.navBarOpacity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                fluidAuraColor: IosTheme.primaryPink,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // 1. Previous Album Button
                    BouncingButton(
                      onTap: () => _prevAlbum(albums),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x33FFFFFF) : const Color(0x18000000),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.chevron_left,
                              size: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '上一个',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 2. Random Album Button
                    BouncingButton(
                      onTap: () => _randomAlbum(albums),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF2D55), Color(0xFFFF5E3A)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF2D55).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Text('🎲', style: TextStyle(fontSize: 13)),
                            SizedBox(width: 4),
                            Text(
                              '随机图包',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. Next Album Button
                    BouncingButton(
                      onTap: () => _nextAlbum(albums),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x33FFFFFF) : const Color(0x18000000),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '下一个',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ],
                        ),
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

class _LocalPhotoGalleryViewer extends StatefulWidget {
  final LocalAlbumFolder album;
  final int initialIndex;

  const _LocalPhotoGalleryViewer({
    required this.album,
    required this.initialIndex,
  });

  @override
  State<_LocalPhotoGalleryViewer> createState() => _LocalPhotoGalleryViewerState();
}

class _LocalPhotoGalleryViewerState extends State<_LocalPhotoGalleryViewer> {
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
    final paths = widget.album.imagePaths;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PhotoViewGallery.builder(
            itemCount: paths.length,
            pageController: _pageController,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: ResizeImage(
                  FileImage(File(paths[index])),
                  width: 1800,
                ),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3.0,
              );
            },
          ),
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
                        '${_currentIndex + 1} / ${paths.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Builder(
                      builder: (btnCtx) => BouncingButton(
                        onTap: () {
                          final box = btnCtx.findRenderObject() as RenderBox?;
                          Share.shareXFiles(
                            [XFile(paths[_currentIndex])],
                            sharePositionOrigin: box != null ? (box.localToGlobal(Offset.zero) & box.size) : null,
                          );
                        },
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
          ),
        ],
      ),
    );
  }
}
