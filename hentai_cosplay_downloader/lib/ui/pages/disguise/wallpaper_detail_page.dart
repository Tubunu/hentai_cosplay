import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/wallpaper_item.dart';
import '../../../services/network_client.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/liquid_glass.dart';

class WallpaperDetailPage extends StatefulWidget {
  final WallpaperItem item;

  const WallpaperDetailPage({super.key, required this.item});

  static void open(BuildContext context, WallpaperItem item) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => WallpaperDetailPage(item: item),
      ),
    );
  }

  @override
  State<WallpaperDetailPage> createState() => _WallpaperDetailPageState();
}

class _WallpaperDetailPageState extends State<WallpaperDetailPage> {
  bool _isDownloading = false;
  bool _isLiked = false;

  Future<void> _downloadWallpaper() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final dio = NetworkClient.createDio();
      final dir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Pictures/SomeACG')
          : await getApplicationDocumentsDirectory();

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final fileName = 'SomeACG_${widget.item.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savePath = '${dir.path}/$fileName';

      await dio.download(widget.item.rawUrl, savePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('壁纸已保存至: $savePath')),
            ],
          ),
          backgroundColor: IosTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存壁纸失败: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showSetWallpaperTip() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('设为壁纸提示'),
        content: const Text('已将高清原图缓存。请点击【下载保存】将原图存入系统相册，随后可在手机「设置 - 壁纸」中设置为桌面或锁屏壁纸。'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _downloadWallpaper();
            },
            child: const Text('立即下载原图'),
          ),
          CupertinoDialogAction(
            child: const Text('知道了'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: LiquidGlass(
            blur: 16,
            backgroundColor: Colors.black,
            opacity: 0.45,
            borderRadius: 20,
            child: IconButton(
              icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: LiquidGlass(
              blur: 16,
              backgroundColor: Colors.black,
              opacity: 0.45,
              borderRadius: 20,
              child: IconButton(
                icon: Icon(
                  _isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  color: _isLiked ? Colors.redAccent : Colors.white,
                  size: 20,
                ),
                onPressed: () => setState(() => _isLiked = !_isLiked),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: LiquidGlass(
              blur: 16,
              backgroundColor: Colors.black,
              opacity: 0.45,
              borderRadius: 20,
              child: IconButton(
                icon: const Icon(CupertinoIcons.share, color: Colors.white, size: 20),
                onPressed: () => Share.share('${item.title} - SomeACG壁纸分享: ${item.rawUrl}'),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Pinch to zoom interactive photo viewer
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: item.rawUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Center(
                  child: CachedNetworkImage(
                    imageUrl: item.previewUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const CupertinoActivityIndicator(color: Colors.white),
                  ),
                ),
                errorWidget: (context, url, error) => CachedNetworkImage(
                  imageUrl: item.previewUrl,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.photo, color: Colors.white38, size: 50),
                        SizedBox(height: 8),
                        Text('壁纸加载失败', style: TextStyle(color: Colors.white60)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Bottom Glass Panel with Info & Actions
          Positioned(
            left: 16,
            right: 16,
            bottom: 36,
            child: LiquidGlass(
              blur: 24,
              backgroundColor: const Color(0xFF141416),
              opacity: 0.82,
              borderRadius: 24,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.8),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Resolution badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.5), width: 0.8),
                          ),
                          child: Text(
                            item.resolution,
                            style: const TextStyle(
                              color: Color(0xFF5AC8FA),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Author & Size Info
                    Text(
                      '来源: ${item.author}  •  尺寸: ${item.width} × ${item.height}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 10),

                    // Tags
                    if (item.tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: item.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#$tag',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Action Buttons
                    Row(
                      children: [
                        // Download Full-Res Button
                        Expanded(
                          flex: 3,
                          child: BouncingButton(
                            onTap: _downloadWallpaper,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF007AFF).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isDownloading
                                    ? const CupertinoActivityIndicator(color: Colors.white)
                                    : const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(CupertinoIcons.cloud_download, color: Colors.white, size: 18),
                                          SizedBox(width: 6),
                                          Text(
                                            '保存超清原图',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Set as Wallpaper Button
                        Expanded(
                          flex: 2,
                          child: BouncingButton(
                            onTap: _showSetWallpaperTip,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(CupertinoIcons.device_phone_portrait, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      '设为壁纸',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ],
                                ),
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
        ],
      ),
    );
  }
}
