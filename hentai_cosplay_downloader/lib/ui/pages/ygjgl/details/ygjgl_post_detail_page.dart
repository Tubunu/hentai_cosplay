import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/download_task.dart';
import '../../../../models/favorite_item.dart';
import '../../../../models/ygjgl/ygjgl_post_item.dart';
import '../../../../providers/browsing_history_provider.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/favorite_provider.dart';
import '../../../../services/ygjgl/ygjgl_api_service.dart';
import '../../../../utils/app_share.dart';
import '../../../widgets/bouncing_button.dart';
import '../../../widgets/unified_photo_viewer.dart';

class YgjglPostDetailPage extends StatefulWidget {
  final YgjglPostItem item;

  const YgjglPostDetailPage({super.key, required this.item});

  @override
  State<YgjglPostDetailPage> createState() => _YgjglPostDetailPageState();
}

class _YgjglPostDetailPageState extends State<YgjglPostDetailPage> {
  late YgjglPostItem _item;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadPostDetail();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BrowsingHistoryProvider>().recordAlbum(
              _item.toAlbumItem(),
              siteKey: 'ygjgl_image',
              siteName: '一个够了 · 写真',
              siteColor: const Color(0xFFFF5A8A),
            );
      }
    });
  }

  Future<void> _loadPostDetail() async {
    setState(() => _isLoading = true);
    final detail = await YgjglApiService.fetchPostDetail(_item.id, defaultKind: 'image');
    if (detail != null && mounted) {
      setState(() {
        _item = detail;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _openRandomPost() async {
    final randId = await YgjglApiService.fetchRandomPostId(kind: 'image');
    if (randId != null && randId != _item.id && mounted) {
      final post = await YgjglApiService.fetchPostDetail(randId, defaultKind: 'image');
      if (post != null && mounted) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (_) => YgjglPostDetailPage(item: post),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentPink = Color(0xFFFF5A8A);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        title: Text(
          _item.seriesTitle.isNotEmpty ? _item.seriesTitle : '写真图集',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          // Random button
          IconButton(
            icon: const Icon(CupertinoIcons.shuffle),
            tooltip: '随机换一部',
            onPressed: _openRandomPost,
          ),
          // Share button
          IconButton(
            icon: const Icon(CupertinoIcons.share),
            onPressed: () {
              AppShare.share(
                context,
                '【一个够了 · 写真】${_item.title}\nhttps://ygjgl.one/post?id=${_item.id}',
              );
            },
          ),
          // Favorite button
          Consumer<FavoriteProvider>(
            builder: (context, favProv, _) {
              final isFav = favProv.isFavoriteItem(
                id: _item.id,
                detailUrl: 'https://ygjgl.one/post?id=${_item.id}',
              );
              return IconButton(
                icon: Icon(
                  isFav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  color: isFav ? accentPink : null,
                ),
                onPressed: () {
                  final favItem = FavoriteItem(
                    id: _item.id,
                    title: _item.title,
                    coverUrl: _item.cover,
                    detailUrl: 'https://ygjgl.one/post?id=${_item.id}',
                    author: _item.seriesTitle,
                    date: _item.published,
                    mediaType: 'album',
                    siteKey: 'ygjgl_image',
                    siteName: '一个够了 · 写真',
                    imageCount: _item.imageCount,
                    tags: _item.tags,
                    addedAt: DateTime.now(),
                  );
                  favProv.toggleFavorite(favItem);
                },
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header Info
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          _item.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Sub info
                        Row(
                          children: [
                            if (_item.published.isNotEmpty)
                              Text(
                                _item.published,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white38 : Colors.black45,
                                ),
                              ),
                            if (_item.published.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text('·', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
                              ),
                            Text(
                              '共 ${_item.imageCount} 张图片',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accentPink,
                              ),
                            ),
                          ],
                        ),

                        // Text description
                        if (_item.text.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _item.text.trim(),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Download Entire Album Button
                        Consumer<DownloadProvider>(
                          builder: (context, downloadProv, _) {
                            final albumItem = _item.toAlbumItem();
                            final task = downloadProv.getTaskForAlbum(albumItem);
                            final isDownloaded = task?.status == TaskStatus.completed;
                            final isDownloading =
                                task?.status == TaskStatus.downloading || task?.status == TaskStatus.queued;

                            return BouncingButton(
                              onTap: () {
                                if (isDownloaded) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('该图集已在下载任务中完成')),
                                  );
                                } else if (!isDownloading) {
                                  downloadProv.addAlbumTask(albumItem);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('已加入下载任务: ${_item.title}')),
                                  );
                                }
                              },
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: isDownloaded
                                      ? const LinearGradient(colors: [Color(0xFF34C759), Color(0xFF30D158)])
                                      : const LinearGradient(colors: [Color(0xFFFF5A8A), Color(0xFFFF8FB3)]),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isDownloaded ? const Color(0xFF34C759) : accentPink).withOpacity(0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isDownloaded
                                          ? CupertinoIcons.check_mark_circled_solid
                                          : (isDownloading
                                              ? CupertinoIcons.arrow_down_circle_fill
                                              : CupertinoIcons.arrow_down_to_line),
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isDownloaded
                                          ? '图集已下载完成'
                                          : (isDownloading ? '正在下载图集中...' : '批量下载整套图集 (${_item.imageCount}P)'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Tags chips
                        if (_item.tags.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _item.tags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF222226) : const Color(0xFFF0F0F3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),

                // Grid of images
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final imgUrl = _item.images[index];
                        return GestureDetector(
                          onTap: () {
                            UnifiedPhotoViewer.open(
                              context,
                              imageUrls: _item.images,
                              initialIndex: index,
                              title: _item.title,
                              author: _item.seriesTitle,
                              httpHeaders: const {
                                'Referer': 'https://ygjgl.one/',
                              },
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.cover,
                              httpHeaders: const {
                                'Referer': 'https://ygjgl.one/',
                                'User-Agent':
                                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
                              },
                              placeholder: (_, __) => Container(
                                color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFF0F0F2),
                                child: const Center(child: CupertinoActivityIndicator()),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFF0F0F2),
                                child: const Icon(CupertinoIcons.photo, color: Colors.white24),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: _item.images.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 50)),
              ],
            ),
    );
  }
}
