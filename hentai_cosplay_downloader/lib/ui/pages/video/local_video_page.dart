import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/video_item.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/local_video_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import 'video_player_page.dart';

class LocalVideoPage extends StatefulWidget {
  const LocalVideoPage({super.key});

  @override
  State<LocalVideoPage> createState() => _LocalVideoPageState();
}

class _LocalVideoPageState extends State<LocalVideoPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final savePath = context.read<SettingsProvider>().config.savePath;
      context.read<LocalVideoProvider>().scanLocalVideos(savePath);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSortSheet(BuildContext context, LocalVideoProvider videoProv) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择视频排序方式'),
        actions: VideoSortOption.values.map((opt) {
          final isSelected = videoProv.sortOption == opt;
          return CupertinoActionSheetAction(
            onPressed: () {
              videoProv.setSortOption(opt);
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
                  opt.label,
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

  void _showVideoOptions(BuildContext context, LocalVideoItem video, LocalVideoProvider videoProv) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        message: Text('${video.author} • ${video.formattedSize} • ${video.duration}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              VideoPlayerPage.openLocal(
                context,
                video: video,
                playlist: videoProv.videos,
                initialIndex: videoProv.videos.indexOf(video),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.play_circle_fill, color: IosTheme.primaryPink, size: 20),
                SizedBox(width: 8),
                Text('播放视频', style: TextStyle(color: IosTheme.primaryPink, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles([XFile(video.filePath)], text: video.title);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.share, size: 18),
                SizedBox(width: 8),
                Text('分享视频文件'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(context, video, videoProv);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.trash, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('删除视频文件'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, LocalVideoItem video, LocalVideoProvider videoProv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认删除本地视频', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('确定要删除视频 “${video.title}” 吗？此操作将从存储介质中永久移除该文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await videoProv.deleteVideo(video);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final videoProv = context.watch<LocalVideoProvider>();
    final settingsProv = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: IosTheme.primaryPink,
          onRefresh: () async {
            await videoProv.scanLocalVideos(settingsProv.config.savePath);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Hero Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LOCAL VIDEOS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: IosTheme.primaryPink.withValues(alpha: 0.9),
                            ),
                          ),
                          const Text(
                            '本地视频',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          Text(
                            '共 ${videoProv.totalCount} 个视频 • ${videoProv.formattedTotalSize}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Search Bar & Action Buttons (Sort, Refresh)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          placeholder: '筛选本地视频...',
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          onChanged: (v) => videoProv.setSearchQuery(v),
                          onSuffixTap: () {
                            _searchController.clear();
                            videoProv.setSearchQuery('');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sort Button
                      BouncingButton(
                        onTap: () => _showSortSheet(context, videoProv),
                        child: FrostedGlass(
                          borderRadius: 14,
                          blur: 15,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          backgroundColor: isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF),
                          child: const Row(
                            children: [
                              Icon(CupertinoIcons.arrow_up_arrow_down, size: 14, color: IosTheme.primaryPink),
                              SizedBox(width: 4),
                              Text(
                                '排序',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: IosTheme.primaryPink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Refresh Button
                      BouncingButton(
                        onTap: () => videoProv.scanLocalVideos(settingsProv.config.savePath),
                        child: FrostedGlass(
                          borderRadius: 14,
                          blur: 15,
                          padding: const EdgeInsets.all(7.5),
                          backgroundColor: isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF),
                          child: const Icon(CupertinoIcons.refresh, size: 16, color: IosTheme.primaryPink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Video List / Grid
              if (videoProv.isScanning)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CupertinoActivityIndicator(radius: 16),
                        SizedBox(height: 12),
                        Text('正在扫描本地视频目录...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else if (videoProv.videos.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.film, size: 56, color: Colors.grey.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          videoProv.searchQuery.isNotEmpty ? '未匹配到相关本地视频' : '本地暂无已下载视频',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.95,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final video = videoProv.videos[index];

                        return BouncingButton(
                          onTap: () => VideoPlayerPage.openLocal(
                            context,
                            video: video,
                            playlist: videoProv.videos,
                            initialIndex: index,
                          ),
                          child: GestureDetector(
                            onLongPress: () => _showVideoOptions(context, video, videoProv),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                                  width: 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 16:9 Poster / Thumbnail
                                  AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        video.coverPath != null && File(video.coverPath!).existsSync()
                                            ? Image.file(
                                                File(video.coverPath!),
                                                fit: BoxFit.cover,
                                                cacheWidth: 480,
                                              )
                                            : Container(
                                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                                child: const Icon(CupertinoIcons.video_camera_solid, color: Colors.grey, size: 28),
                                              ),

                                        // Overlay
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withValues(alpha: 0.65),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Center Play Icon
                                        Center(
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.5),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white38, width: 1),
                                            ),
                                            child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 16),
                                          ),
                                        ),

                                        // Duration Badge
                                        if (video.duration.isNotEmpty)
                                          Positioned(
                                            left: 6,
                                            bottom: 6,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.75),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                video.duration,
                                                style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ),

                                        // File Size Badge
                                        Positioned(
                                          right: 6,
                                          bottom: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: IosTheme.primaryPink.withValues(alpha: 0.85),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              video.formattedSize,
                                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Metadata
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            video.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              height: 1.25,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  video.author,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    color: IosTheme.primaryPink,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                behavior: HitTestBehavior.opaque,
                                                onTap: () => _showVideoOptions(context, video, videoProv),
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                  child: Icon(CupertinoIcons.ellipsis, size: 16, color: Colors.grey),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: videoProv.videos.length,
                    ),
                  ),
                ),

              // Bottom Spacer
              SliverToBoxAdapter(
                child: SizedBox(
                  height: context.select<DownloadProvider, bool>((p) => p.isDownloading) ? 210 : 130,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
