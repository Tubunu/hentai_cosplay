import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/wallpaper_item.dart';
import '../../../services/network_client.dart';
import '../../../services/storage_service.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/liquid_glass.dart';
import 'package:hentai_cosplay_downloader/utils/app_share.dart';

class WallpaperDetailPage extends StatefulWidget {
  final WallpaperItem item;
  final VoidCallback? onBack;

  const WallpaperDetailPage({
    super.key,
    required this.item,
    this.onBack,
  });

  static void open(BuildContext context, WallpaperItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
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
  bool _showChrome = true;
  bool _showLockMock = false;
  String? _downloadedFilePath;

  void _toggleChrome() {
    setState(() {
      _showChrome = !_showChrome;
      if (_showChrome) {
        _showLockMock = false;
      }
    });
  }

  void _toggleLockMock() {
    HapticFeedback.selectionClick();
    setState(() {
      _showLockMock = !_showLockMock;
      if (_showLockMock) {
        _showChrome = false;
      }
    });
  }

  Future<void> _downloadWallpaper() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    HapticFeedback.lightImpact();

    try {
      await StorageService.requestStoragePermissions();

      Directory? targetDir;
      if (Platform.isAndroid) {
        final pictures = Directory('/storage/emulated/0/Pictures/SomeACG');
        try {
          if (!await pictures.exists()) {
            await pictures.create(recursive: true);
          }
          targetDir = pictures;
        } catch (_) {
          final downloads = Directory('/storage/emulated/0/Download/SomeACG');
          try {
            if (!await downloads.exists()) {
              await downloads.create(recursive: true);
            }
            targetDir = downloads;
          } catch (_) {
            final ext = await getExternalStorageDirectory();
            if (ext != null) {
              final sub = Directory(p.join(ext.path, 'SomeACG'));
              if (!await sub.exists()) await sub.create(recursive: true);
              targetDir = sub;
            }
          }
        }
      }

      if (targetDir == null) {
        final doc = await getApplicationDocumentsDirectory();
        final sub = Directory(p.join(doc.path, 'SomeACG'));
        if (!await sub.exists()) await sub.create(recursive: true);
        targetDir = sub;
      }

      final ext = widget.item.rawUrl.endsWith('.png') ? 'png' : 'jpg';
      final fileName = 'SomeACG_${widget.item.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final savePath = p.join(targetDir.path, fileName);

      final dio = NetworkClient.createDio(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 40),
      );

      final headers = widget.item.rawUrl.contains('pixiv') || widget.item.rawUrl.contains('pximg')
          ? {'Referer': 'https://www.pixiv.net/'}
          : null;

      await dio.download(
        widget.item.rawUrl,
        savePath,
        options: headers != null ? Options(headers: headers) : null,
      );
      _downloadedFilePath = savePath;

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('壁纸已保存至: $savePath', maxLines: 2, overflow: TextOverflow.ellipsis)),
            ],
          ),
          backgroundColor: IosTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: '分享',
            textColor: Colors.white,
            onPressed: () {
              AppShare.shareXFiles(context, [XFile(savePath)], text: widget.item.title);
            },
          ),
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
        title: const Text('设为壁纸指南'),
        content: const Text('已准备好超高清原图！\n\n点击【立即下载】将原画保存至手机相册，随后打开系统「设置 -> 壁纸」即可一键应用为桌面或锁屏壁纸。'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _downloadWallpaper();
            },
            child: const Text('立即下载'),
          ),
          CupertinoDialogAction(
            child: const Text('关闭'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _shareWallpaper() {
    if (_downloadedFilePath != null && File(_downloadedFilePath!).existsSync()) {
      AppShare.shareXFiles(context, [XFile(_downloadedFilePath!)], text: '${widget.item.title} - SomeACG 高清壁纸');
    } else {
      AppShare.share(context, '${widget.item.title}\n壁纸原图: ${widget.item.rawUrl}\n来自 SomeACG 高清二次元壁纸站');
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final weekdayStr = '星期${weekdays[now.weekday - 1]}';
    final dateStr = '${now.month}月${now.day}日 $weekdayStr';

    return PopScope(
      canPop: widget.onBack == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.onBack != null) {
          widget.onBack!();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Gesture detector for tapping background to toggle chrome
          GestureDetector(
            onTap: _toggleChrome,
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.5,
                child: CachedNetworkImage(
                  imageUrl: item.rawUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  httpHeaders: item.rawUrl.contains('pixiv') || item.rawUrl.contains('pximg')
                      ? const {'Referer': 'https://www.pixiv.net/'}
                      : null,
                  placeholder: (context, url) => Center(
                    child: CachedNetworkImage(
                      imageUrl: item.previewUrl,
                      fit: BoxFit.contain,
                      httpHeaders: item.previewUrl.contains('pixiv') || item.previewUrl.contains('pximg')
                          ? const {'Referer': 'https://www.pixiv.net/'}
                          : null,
                      placeholder: (_, __) => const CupertinoActivityIndicator(color: Colors.white),
                    ),
                  ),
                  errorWidget: (context, url, error) => CachedNetworkImage(
                    imageUrl: item.previewUrl,
                    fit: BoxFit.contain,
                    httpHeaders: item.previewUrl.contains('pixiv') || item.previewUrl.contains('pximg')
                        ? const {'Referer': 'https://www.pixiv.net/'}
                        : null,
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
          ),

          // 2. Lock Screen Mock Overlay (to preview as phone lock screen)
          if (_showLockMock)
            GestureDetector(
              onTap: _toggleLockMock,
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
                padding: const EdgeInsets.only(top: 80),
                child: Column(
                  children: [
                    const Icon(CupertinoIcons.lock_fill, color: Colors.white70, size: 22),
                    const SizedBox(height: 12),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 76,
                        fontWeight: FontWeight.w200,
                        color: Colors.white,
                        letterSpacing: -2,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 16),
                        ],
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 10),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      margin: const EdgeInsets.only(bottom: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '点击屏幕任意位置退出锁屏预览',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Top Navigation Bar (Animated)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            top: _showChrome ? MediaQuery.of(context).padding.top + 8 : -80,
            left: 16,
            right: 16,
            child: Row(
              children: [
                LiquidGlass(
                  blur: 16,
                  backgroundColor: Colors.black,
                  opacity: 0.45,
                  borderRadius: 20,
                  child: IconButton(
                    icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 20),
                    onPressed: () {
                      if (widget.onBack != null) {
                        widget.onBack!();
                      } else {
                        Navigator.maybePop(context);
                      }
                    },
                  ),
                ),
                const Spacer(),
                // Lock screen mock toggle
                LiquidGlass(
                  blur: 16,
                  backgroundColor: Colors.black,
                  opacity: 0.45,
                  borderRadius: 20,
                  child: IconButton(
                    icon: const Icon(CupertinoIcons.device_phone_portrait, color: Colors.white, size: 20),
                    tooltip: '锁屏预览',
                    onPressed: _toggleLockMock,
                  ),
                ),
                const SizedBox(width: 8),
                // Like button
                LiquidGlass(
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
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isLiked = !_isLiked);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Share button
                LiquidGlass(
                  blur: 16,
                  backgroundColor: Colors.black,
                  opacity: 0.45,
                  borderRadius: 20,
                  child: IconButton(
                    icon: const Icon(CupertinoIcons.share, color: Colors.white, size: 20),
                    onPressed: _shareWallpaper,
                  ),
                ),
              ],
            ),
          ),

          // 4. Bottom Glass Panel with Info & Actions (Animated)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            left: 16,
            right: 16,
            bottom: _showChrome ? MediaQuery.of(context).padding.bottom + 16 : -250,
            child: LiquidGlass(
              blur: 24,
              backgroundColor: const Color(0xFF141416),
              opacity: 0.85,
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
                      '来源: ${item.author}  •  分辨率: ${item.width} × ${item.height}',
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

                        // Set as Wallpaper / Guide Button
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
                                    Icon(CupertinoIcons.wand_stars, color: Colors.white, size: 16),
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
    ),
    );
  }
}
