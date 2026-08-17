import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'frosted_glass.dart';

class PhotoViewerPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String title;
  final bool isLocalFile;
  final void Function(int index)? onDelete;

  const PhotoViewerPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
    required this.title,
    this.isLocalFile = false,
    this.onDelete,
  });

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late int _currentIndex;
  late final PageController _pageController;
  bool _showControls = true;

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

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _shareImage() async {
    final currentPath = widget.images[_currentIndex];
    if (widget.isLocalFile) {
      await Share.shareXFiles([XFile(currentPath)], text: widget.title);
    } else {
      await Share.share(currentPath, subject: widget.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PhotoViewGallery Area
          GestureDetector(
            onTap: _toggleControls,
            child: PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              pageController: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              builder: (context, index) {
                final item = widget.images[index];
                return PhotoViewGalleryPageOptions(
                  imageProvider: widget.isLocalFile
                      ? FileImage(File(item)) as ImageProvider
                      : CachedNetworkImageProvider(item),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3.0,
                  heroAttributes: PhotoViewHeroAttributes(tag: '$item-$index'),
                );
              },
              loadingBuilder: (context, event) => const Center(
                child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
              ),
            ),
          ),

          // Top Header Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            top: _showControls ? MediaQuery.of(context).padding.top + 8 : -100,
            left: 16,
            right: 16,
            child: FrostedGlass(
              borderRadius: 20,
              blur: 25,
              backgroundColor: Colors.black54,
              border: Border.all(color: Colors.white12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.chevron_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${_currentIndex + 1} / ${widget.images.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.share, color: Colors.white, size: 20),
                    onPressed: _shareImage,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Quick Actions
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            bottom: _showControls ? MediaQuery.of(context).padding.bottom + 16 : -100,
            left: 36,
            right: 36,
            child: FrostedGlass(
              borderRadius: 24,
              blur: 25,
              backgroundColor: Colors.black54,
              border: Border.all(color: Colors.white12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Share Button
                  IconButton(
                    icon: const Icon(CupertinoIcons.square_arrow_up, color: Colors.white),
                    tooltip: '分享',
                    onPressed: _shareImage,
                  ),

                  // Delete Button (if local)
                  if (widget.isLocalFile && widget.onDelete != null)
                    IconButton(
                      icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
                      tooltip: '删除此图片',
                      onPressed: () {
                        widget.onDelete?.call(_currentIndex);
                        if (widget.images.length <= 1) {
                          Navigator.pop(context);
                        } else {
                          setState(() {
                            widget.images.removeAt(_currentIndex);
                            if (_currentIndex >= widget.images.length) {
                              _currentIndex = widget.images.length - 1;
                            }
                          });
                        }
                      },
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
