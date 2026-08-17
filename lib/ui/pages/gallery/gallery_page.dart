import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/gallery_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/local_pack_card.dart';
import 'local_pack_detail_page.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settingsProv = context.read<SettingsProvider>();
      context.read<GalleryProvider>().scanLocalDirectory(settingsProv.config.savePath);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerArchive(BuildContext context) async {
    final settingsProv = context.read<SettingsProvider>();
    final galleryProv = context.read<GalleryProvider>();

    final count = await galleryProv.organizeAndArchive(
      settingsProv.config.savePath,
      strategy: settingsProv.config.archiveStrategy,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0 ? '整理归档完成！共归档 $count 个图包' : '没有需要归档的散落图包'),
          backgroundColor: IosTheme.primaryPink,
        ),
      );
    }
  }

  void _showSortSheet(BuildContext context, GalleryProvider galleryProv) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('图包排序方式'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              galleryProv.setSortMode(GallerySortMode.timeDesc);
              Navigator.pop(ctx);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (galleryProv.sortMode == GallerySortMode.timeDesc)
                  const Icon(CupertinoIcons.checkmark, size: 16, color: IosTheme.primaryPink),
                const SizedBox(width: 6),
                const Text('按时间降序（最新优先）'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              galleryProv.setSortMode(GallerySortMode.timeAsc);
              Navigator.pop(ctx);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (galleryProv.sortMode == GallerySortMode.timeAsc)
                  const Icon(CupertinoIcons.checkmark, size: 16, color: IosTheme.primaryPink),
                const SizedBox(width: 6),
                const Text('按时间升序（最早优先）'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              galleryProv.setSortMode(GallerySortMode.author);
              Navigator.pop(ctx);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (galleryProv.sortMode == GallerySortMode.author)
                  const Icon(CupertinoIcons.checkmark, size: 16, color: IosTheme.primaryPink),
                const SizedBox(width: 6),
                const Text('按作者名称排序'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final galleryProv = context.watch<GalleryProvider>();
    final settingsProv = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Ambient Mesh Glow
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Container(
              decoration: const BoxDecoration(gradient: IosTheme.ambientMesh),
            ),
          ),

          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              cacheExtent: 600,
              slivers: [
                // Large Hero Title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LIBRARY & ALBUMS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: IosTheme.primaryPink.withOpacity(0.9),
                              ),
                            ),
                            const Text(
                              '本地图库',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),

                        // Organize Archive Button
                        BouncingButton(
                          onTap: galleryProv.isArchiving ? null : () => _triggerArchive(context),
                          child: FrostedGlass(
                            borderRadius: 16,
                            blur: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            backgroundColor: isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF),
                            child: Row(
                              children: [
                                if (galleryProv.isArchiving)
                                  const CupertinoActivityIndicator(radius: 8)
                                else
                                  const Icon(CupertinoIcons.folder_fill_badge_plus, color: IosTheme.secondaryPurple, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  galleryProv.isArchiving ? '归档中...' : '一键归档',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: IosTheme.secondaryPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Refresh Button
                        BouncingButton(
                          onTap: () => galleryProv.scanLocalDirectory(settingsProv.config.savePath),
                          child: FrostedGlass(
                            borderRadius: 16,
                            blur: 15,
                            padding: const EdgeInsets.all(8),
                            backgroundColor: isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF),
                            child: const Icon(CupertinoIcons.arrow_clockwise, color: IosTheme.primaryPink, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search & Sort Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        // Search Box
                        Expanded(
                          child: FrostedGlass(
                            borderRadius: 16,
                            blur: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            backgroundColor: isDark ? const Color(0x7728282E) : const Color(0xCCFFFFFF),
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.search, color: IosTheme.secondaryText(context), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: galleryProv.setSearchQuery,
                                    style: const TextStyle(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: '搜索本地图包或作者...',
                                      hintStyle: TextStyle(
                                        fontSize: 13,
                                        color: IosTheme.secondaryText(context),
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16),
                                    color: IosTheme.secondaryText(context),
                                    onPressed: () {
                                      _searchController.clear();
                                      galleryProv.setSearchQuery('');
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Sort Button
                        BouncingButton(
                          onTap: () => _showSortSheet(context, galleryProv),
                          child: FrostedGlass(
                            borderRadius: 16,
                            blur: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            backgroundColor: isDark ? const Color(0x7728282E) : const Color(0xCCFFFFFF),
                            child: const Row(
                              children: [
                                Icon(CupertinoIcons.arrow_up_arrow_down, size: 16, color: IosTheme.primaryPink),
                                SizedBox(width: 4),
                                Text(
                                  '排序',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: IosTheme.primaryPink),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Archive Status notification if running
                if (galleryProv.isArchiving && galleryProv.archiveStatusText.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: IosTheme.secondaryPurple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          galleryProv.archiveStatusText,
                          style: const TextStyle(fontSize: 12, color: IosTheme.secondaryPurple, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),

                // Content
                if (galleryProv.isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CupertinoActivityIndicator(radius: 16),
                    ),
                  )
                else if (galleryProv.packs.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.photo_on_rectangle,
                            size: 64,
                            color: IosTheme.secondaryText(context).withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '本地图库为空',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: IosTheme.secondaryText(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '下载完成的图包将自动出现在此处',
                            style: TextStyle(
                              fontSize: 13,
                              color: IosTheme.secondaryText(context).withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final pack = galleryProv.packs[index];
                          return LocalPackCard(
                            pack: pack,
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => LocalPackDetailPage(pack: pack),
                                ),
                              );
                            },
                          );
                        },
                        childCount: galleryProv.packs.length,
                        addAutomaticKeepAlives: true,
                        addRepaintBoundaries: true,
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: context.watch<DownloadProvider>().hasActiveOrPausedTasks ? 210 : 130,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
