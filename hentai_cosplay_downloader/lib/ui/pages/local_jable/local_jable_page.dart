import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/jable_video_item.dart';
import '../../../models/video_item.dart';
import '../../../providers/local_jable_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../video/video_player_page.dart';

class LocalJablePage extends StatefulWidget {
  const LocalJablePage({super.key});

  @override
  State<LocalJablePage> createState() => _LocalJablePageState();
}

class _LocalJablePageState extends State<LocalJablePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalJableProvider>().scanLocalVideos();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _playVideo(BuildContext context, JableLocalVideoItem item) {
    final localVideo = LocalVideoItem(
      id: item.id,
      title: item.title,
      author: item.siteName,
      filePath: item.filePath,
      coverPath: item.coverPath,
      fileSizeBytes: item.fileSizeBytes,
      createdAt: item.createdAt,
      duration: item.duration,
      sourceUrl: item.sourceUrl,
    );

    final provider = context.read<LocalJableProvider>();
    final allList = provider.filteredVideos.map((v) => LocalVideoItem(
      id: v.id,
      title: v.title,
      author: v.siteName,
      filePath: v.filePath,
      coverPath: v.coverPath,
      fileSizeBytes: v.fileSizeBytes,
      createdAt: v.createdAt,
      duration: v.duration,
      sourceUrl: v.sourceUrl,
    )).toList();

    VideoPlayerPage.openLocal(
      context,
      video: localVideo,
      playlist: allList,
    );
  }

  void _showSortSheet(BuildContext context, LocalJableProvider localProv) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择视频排序方式'),
        actions: [
          _buildSortAction(ctx, '最新下载', 'date_desc', localProv),
          _buildSortAction(ctx, '最早下载', 'date_asc', localProv),
          _buildSortAction(ctx, '文件最大', 'size_desc', localProv),
          _buildSortAction(ctx, '名称排序', 'name_asc', localProv),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  CupertinoActionSheetAction _buildSortAction(BuildContext ctx, String label, String value, LocalJableProvider localProv) {
    final isSelected = localProv.sortOption == value;
    return CupertinoActionSheetAction(
      onPressed: () {
        localProv.setSortOption(value);
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
            label,
            style: TextStyle(
              color: isSelected ? IosTheme.primaryPink : null,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showActionSheet(BuildContext context, JableLocalVideoItem item) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        message: Text("大小: ${item.formattedSize} · 格式: ${item.fileName.split('.').last.toUpperCase()}"),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _playVideo(context, item);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.play_circle, color: IosTheme.primaryPink, size: 20),
                SizedBox(width: 8),
                Text('播放视频', style: TextStyle(color: IosTheme.primaryPink)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Share.shareXFiles([XFile(item.filePath)], text: item.title);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.share, color: Colors.blueAccent, size: 20),
                SizedBox(width: 8),
                Text('分享视频文件'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(context, item);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.delete, color: CupertinoColors.destructiveRed, size: 20),
                SizedBox(width: 8),
                Text('删除视频文件'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, JableLocalVideoItem item) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('确认删除视频？'),
        content: Text('将彻底从设备中删除 "${item.title}" 及其封面海报与元数据，此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final success = await context.read<LocalJableProvider>().deleteVideo(item);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '视频已删除' : '删除失败'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('删除'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localProvider = context.watch<LocalJableProvider>();
    final videos = localProvider.filteredVideos;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Top Title & Actions Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Jable影视',
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
                          color: IosTheme.primaryPink.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${localProvider.totalCount} 部 / ${localProvider.totalFormattedSize}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: IosTheme.primaryPink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 2. Search Bar & Action Buttons (Sort, Refresh)
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          placeholder: '搜索本地 Jable 影视...',
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          onChanged: (val) {
                            localProvider.setSearchQuery(val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sort Mode Button
                      BouncingButton(
                        onTap: () => _showSortSheet(context, localProvider),
                        child: Container(
                          padding: const EdgeInsets.all(7.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.arrow_up_arrow_down,
                            size: 15,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Refresh Button
                      BouncingButton(
                        onTap: localProvider.isLoading ? null : () => localProvider.scanLocalVideos(),
                        child: Container(
                          padding: const EdgeInsets.all(7.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            shape: BoxShape.circle,
                          ),
                          child: localProvider.isLoading
                              ? const CupertinoActivityIndicator(radius: 7.5)
                              : Icon(
                                  CupertinoIcons.refresh,
                                  size: 15,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Grid of Videos
            Expanded(
              child: localProvider.isLoading
                  ? const Center(child: CupertinoActivityIndicator(radius: 14))
                  : videos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.videocam_fill, size: 54, color: Colors.grey.withAlpha(80)),
                              const SizedBox(height: 12),
                              const Text(
                                '暂无本地 Jable 影视',
                                style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '在【Jable】专区下载的视频将保存在 jabletv 目录并显示于此',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => localProvider.scanLocalVideos(),
                          color: IosTheme.primaryPink,
                          child: GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.82,
                            ),
                            itemCount: videos.length,
                            itemBuilder: (context, index) {
                              final item = videos[index];
                              return _buildLocalVideoCard(context, item, isDark);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalVideoCard(BuildContext context, JableLocalVideoItem item, bool isDark) {
    final hasCover = item.coverPath != null && File(item.coverPath!).existsSync();

    return BouncingButton(
      onTap: () => _playVideo(context, item),
      onLongPress: () => _showActionSheet(context, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasCover)
                    Image.file(
                      File(item.coverPath!),
                      fit: BoxFit.cover,
                      cacheWidth: 480,
                    )
                  else
                    Container(
                      color: isDark ? Colors.white12 : Colors.black12,
                      child: const Center(
                        child: Icon(CupertinoIcons.play_rectangle, color: Colors.grey, size: 40),
                      ),
                    ),

                  // Play overlay pill
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: IosTheme.primaryPink.withAlpha(220),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 12),
                    ),
                  ),

                  // File size badge
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(180),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.formattedSize,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Title
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.25,
            ),
          ),

          // Site tag / date
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Row(
              children: [
                Text(
                  item.siteName,
                  style: const TextStyle(color: IosTheme.primaryPink, fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                Text(
                  item.createdAt.toString().substring(0, 10),
                  style: const TextStyle(color: Colors.grey, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
