import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../widgets/unified_photo_viewer.dart';
import 'package:provider/provider.dart';
import '../../../models/album_item.dart';
import '../../../models/download_task.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/pixibb/pixibb_api_service.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';

class PixibbDetailPage extends StatefulWidget {
  final AlbumItem item;

  const PixibbDetailPage({super.key, required this.item});

  @override
  State<PixibbDetailPage> createState() => _PixibbDetailPageState();
}

class _PixibbDetailPageState extends State<PixibbDetailPage> {
  final ScrollController _scrollController = ScrollController();
  late AlbumItem _item;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadDetail();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BrowsingHistoryProvider>().recordAlbum(
          _item,
          siteKey: 'pixibb',
          siteName: 'PixiBB',
          siteColor: const Color(0xFFFF4081),
        );
      }
    });
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detailed = await PixibbApiService.fetchAlbumDetail(_item);
      if (detailed != null && mounted) {
        setState(() {
          _item = detailed;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载相册详情失败: $e';
          _isLoading = false;
        });
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openGallery(int initialIndex) {
    if (_item.imageUrls.isEmpty) return;
    UnifiedPhotoViewer.open(
      context,
      imageUrls: _item.imageUrls,
      initialIndex: initialIndex,
      title: _item.title,
      author: _item.author,
      sourceType: MediaSourceType.pixibb,
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatus(slug: _item.slug, detailUrl: _item.detailUrl),
    );

    final isDownloaded = taskStatus == TaskStatus.completed;
    final isDownloading = taskStatus == TaskStatus.downloading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          const RandomActionButton.album(
            albumSource: MediaSourceType.pixibb,
            replace: true,
            color: Color(0xFFFF4081),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            onPressed: _loadDetail,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadDetail, child: const Text('重试')),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _item.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(CupertinoIcons.person, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(_item.author, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                const SizedBox(width: 16),
                                const Icon(CupertinoIcons.photo_on_rectangle, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('${_item.imageUrls.length} P', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF4081).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'PixiBB 4K',
                                    style: TextStyle(color: Color(0xFFFF4081), fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _item.tags.map((t) {
                                return Chip(
                                  label: Text(t, style: const TextStyle(fontSize: 11)),
                                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDownloaded
                                      ? Colors.green
                                      : const Color(0xFFFF4081),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: Icon(
                                  isDownloaded
                                      ? CupertinoIcons.checkmark_alt
                                      : isDownloading
                                          ? CupertinoIcons.arrow_2_circlepath
                                          : CupertinoIcons.arrow_down_to_line,
                                ),
                                label: Text(
                                  isDownloaded
                                      ? '图集已下载'
                                      : isDownloading
                                          ? '正在下载中...'
                                          : '下载整本高清图集 (${_item.imageUrls.length}P)',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: isDownloaded || isDownloading
                                    ? null
                                    : () {
                                        context.read<DownloadProvider>().addAlbumTask(_item);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('已添加下载任务: ${_item.title}'),
                                            backgroundColor: const Color(0xFFFF4081),
                                          ),
                                        );
                                      },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.all(12),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final imgUrl = _item.imageUrls[index];
                            return GestureDetector(
                              onTap: () => _openGallery(index),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: imgUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[900],
                                        child: const Center(child: CupertinoActivityIndicator()),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey[900],
                                        child: const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.white24),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(color: Colors.white, fontSize: 10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: _item.imageUrls.length,
                        ),
                      ),
                    ),
                  ],
                ),
                ScrollToTopButton(
                  scrollController: _scrollController,
                  color: const Color(0xFFFF4081),
                  bottomOffset: 24.0,
                ),
              ],
            ),
    );
  }
}


