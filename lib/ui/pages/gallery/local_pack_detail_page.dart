import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../providers/gallery_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/storage_service.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/photo_viewer_page.dart';

class LocalPackDetailPage extends StatefulWidget {
  final LocalPackInfo pack;

  const LocalPackDetailPage({super.key, required this.pack});

  @override
  State<LocalPackDetailPage> createState() => _LocalPackDetailPageState();
}

class _LocalPackDetailPageState extends State<LocalPackDetailPage> {
  late List<String> _images;

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.pack.imagePaths);
  }

  void _sharePack() async {
    if (_images.isEmpty) return;
    final xfiles = _images.take(10).map((p) => XFile(p)).toList();
    await Share.shareXFiles(xfiles, text: widget.pack.title);
  }

  void _deletePack() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除此本地图包？'),
        content: Text('将彻底删除文件夹: ${widget.pack.dirPath} 及其所有本地图片。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final dir = Directory(widget.pack.dirPath);
                if (await dir.exists()) {
                  await dir.delete(recursive: true);
                }
                if (mounted) {
                  final settingsProv = context.read<SettingsProvider>();
                  context.read<GalleryProvider>().scanLocalDirectory(settingsProv.config.savePath);
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
              }
            },
            child: const Text('彻底删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF7F7FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Album Header with Ambient Blur
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? const Color(0xE61A1A1E) : const Color(0xF0FFFFFF),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: FrostedGlass(
                borderRadius: 20,
                blur: 15,
                backgroundColor: isDark ? Colors.black45 : Colors.white60,
                child: IconButton(
                  icon: const Icon(CupertinoIcons.chevron_back, size: 20),
                  color: isDark ? Colors.white : Colors.black,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FrostedGlass(
                  borderRadius: 20,
                  blur: 15,
                  backgroundColor: isDark ? Colors.black45 : Colors.white60,
                  child: IconButton(
                    icon: const Icon(CupertinoIcons.share, color: IosTheme.primaryPink, size: 18),
                    onPressed: _sharePack,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FrostedGlass(
                  borderRadius: 20,
                  blur: 15,
                  backgroundColor: isDark ? Colors.black45 : Colors.white60,
                  child: IconButton(
                    icon: const Icon(CupertinoIcons.trash, color: Colors.red, size: 18),
                    onPressed: _deletePack,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.pack.coverPath != null && File(widget.pack.coverPath!).existsSync())
                    Image.file(File(widget.pack.coverPath!), fit: BoxFit.cover),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      color: isDark
                          ? Colors.black.withOpacity(0.65)
                          : Colors.white.withOpacity(0.7),
                    ),
                  ),

                  // Center Album Artwork
                  Positioned(
                    top: 80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.6 : 0.2),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: widget.pack.coverPath != null && File(widget.pack.coverPath!).existsSync()
                              ? Image.file(File(widget.pack.coverPath!), fit: BoxFit.cover)
                              : const Icon(CupertinoIcons.photo),
                        ),
                      ),
                    ),
                  ),

                  // Metadata
                  Positioned(
                    bottom: 12,
                    left: 20,
                    right: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.pack.title,
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
                        Text(
                          '${widget.pack.author}  •  ${_images.length} 张本地图片',
                          style: TextStyle(
                            fontSize: 13,
                            color: IosTheme.secondaryText(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Images Grid Section
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final path = _images[index];
                  final file = File(path);

                  return BouncingButton(
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => PhotoViewerPage(
                            images: _images,
                            initialIndex: index,
                            title: widget.pack.title,
                            isLocalFile: true,
                            onDelete: (delIndex) async {
                              try {
                                final delFile = File(_images[delIndex]);
                                if (await delFile.exists()) {
                                  await delFile.delete();
                                }
                                setState(() {
                                  _images.removeAt(delIndex);
                                });
                              } catch (_) {}
                            },
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            file.existsSync()
                                ? Image.file(file, fit: BoxFit.cover)
                                : Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(CupertinoIcons.photo),
                                  ),
                            Positioned(
                              bottom: 4,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _images.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }
}
