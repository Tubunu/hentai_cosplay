import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/album_item.dart';
import '../../../models/download_task.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../services/coomer/coomer_api_service.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/random_action_button.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../../widgets/unified_photo_viewer.dart';
import '../../../utils/referer_helper.dart';
import 'package:hentai_cosplay_downloader/utils/app_share.dart';

class CoomerDetailPage extends StatefulWidget {
  final AlbumItem item;

  const CoomerDetailPage({super.key, required this.item});

  @override
  State<CoomerDetailPage> createState() => _CoomerDetailPageState();
}

class _CoomerDetailPageState extends State<CoomerDetailPage> {
  final ScrollController _scrollController = ScrollController();
  late AlbumItem _item;
  final Set<int> _selectedIndices = {};
  bool _isSelectionMode = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _item = widget.item;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BrowsingHistoryProvider>().recordAlbum(
          _item,
          siteKey: 'coomer',
          siteName: 'Coomer',
          siteColor: const Color(0xFF00AFF0),
        );
      }
    });
  }

  void _downloadFullPost() {
    final downloadProv = context.read<DownloadProvider>();
    downloadProv.addAlbumTask(_item);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 "${_item.title}" 到下载队列'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _downloadSelected() {
    if (_selectedIndices.isEmpty) return;

    final selectedUrls = _selectedIndices.map((i) => _item.imageUrls[i]).toList();
    final customAlbum = _item.copyWith(
      title: '${_item.title} (选定${selectedUrls.length}个文件)',
      imageUrls: selectedUrls,
      previewUrls: selectedUrls,
    );

    final downloadProv = context.read<DownloadProvider>();
    downloadProv.addAlbumTask(customAlbum);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加选中的 ${selectedUrls.length} 个文件到下载队列'),
        backgroundColor: IosTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
  }

  void _openImageViewer(int initialIndex) {
    if (_item.imageUrls.isEmpty) return;
    UnifiedPhotoViewer.open(
      context,
      imageUrls: _item.imageUrls,
      initialIndex: initialIndex,
      title: _item.title,
      author: _item.author,
      sourceType: MediaSourceType.coomer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final raw = _item.rawData;
    final service = raw['service']?.toString() ?? 'onlyfans';
    final user = raw['user']?.toString() ?? _item.author;
    final content = raw['content']?.toString() ?? '';

    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatus(slug: _item.slug, detailUrl: _item.detailUrl),
    );
    final isDownloaded = taskStatus == TaskStatus.completed;

    final platformColor = _getServiceColor(service);

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedIndices.clear();
          });
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
            // Cupertino Navigation Bar
            SliverAppBar(
              pinned: true,
              expandedHeight: 0,
              backgroundColor: isDark ? const Color(0xCC1A1A1E) : const Color(0xCCFFFFFF),
              elevation: 0,
              leading: BouncingButton(
                onTap: () {
                  if (_isSelectionMode) {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedIndices.clear();
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: const Icon(CupertinoIcons.back, size: 24),
              ),
            title: Text(
              '$user 的动态',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            actions: [
              const RandomActionButton.album(
                albumSource: MediaSourceType.coomer,
                replace: true,
                color: Color(0xFF00AFF0),
              ),
              if (_item.imageUrls.isNotEmpty)
                IconButton(
                  icon: Icon(
                    _isSelectionMode ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.checkmark_circle,
                    color: _isSelectionMode ? IosTheme.primaryPink : null,
                  ),
                  tooltip: '多选下载',
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = !_isSelectionMode;
                      if (!_isSelectionMode) _selectedIndices.clear();
                    });
                  },
                ),
              IconButton(
                icon: const Icon(CupertinoIcons.share),
                tooltip: '分享',
                onPressed: () {
                  if (_item.detailUrl.isNotEmpty) {
                    AppShare.share(context, '${_item.title}\n${_item.detailUrl}');
                  }
                },
              ),
            ],
          ),

          // Post Header & Text Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: FrostedGlass(
                borderRadius: 20,
                blur: 20,
                padding: const EdgeInsets.all(16),
                backgroundColor: isDark ? const Color(0x991E1E24) : Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Creator Info Row
                    Row(
                      children: [
                        ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: CoomerApiService.resolveAvatarUrl(service, user),
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            httpHeaders: RefererHelper.buildImageHeaders(CoomerApiService.resolveAvatarUrl(service, user), sourceType: MediaSourceType.coomer),
                            errorWidget: (_, __, ___) => Icon(CupertinoIcons.person_fill, color: platformColor, size: 36),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    user,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: platformColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      service.toUpperCase(),
                                      style: TextStyle(
                                        color: platformColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              if (_item.date.isNotEmpty)
                                Text(
                                  '发布于 ${_item.date}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (_item.title.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ],

                    if (content.isNotEmpty && content != _item.title) ...[
                      const SizedBox(height: 8),
                      Text(
                        content.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim(),
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Download Action Button
                    Row(
                      children: [
                        Expanded(
                          child: BouncingButton(
                            onTap: _item.imageUrls.isNotEmpty
                                ? (_isSelectionMode ? _downloadSelected : _downloadFullPost)
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [platformColor, platformColor.withValues(alpha: 0.8)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: platformColor.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isSelectionMode
                                        ? CupertinoIcons.arrow_down_to_line
                                        : (isDownloaded
                                            ? CupertinoIcons.checkmark_alt
                                            : CupertinoIcons.arrow_down_circle_fill),
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isSelectionMode
                                        ? '下载选中 (${_selectedIndices.length}个)'
                                        : (isDownloaded
                                            ? '已在本地 (重新下载)'
                                            : '下载本条动态全套媒体 (${_item.imageUrls.length}个)'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
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

          // Media Attachments Grid
          if (_item.imageUrls.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final mediaUrl = _item.imageUrls[index];
                    final isVideo = _isVideoUrl(mediaUrl);
                    final isSelected = _selectedIndices.contains(index);

                    return GestureDetector(
                      onTap: () {
                        if (_isSelectionMode) {
                          setState(() {
                            if (isSelected) {
                              _selectedIndices.remove(index);
                            } else {
                              _selectedIndices.add(index);
                            }
                          });
                        } else {
                          _openImageViewer(index);
                        }
                      },
                      onLongPress: () {
                        setState(() {
                          _isSelectionMode = true;
                          _selectedIndices.add(index);
                        });
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: mediaUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 450,
                              httpHeaders: RefererHelper.buildImageHeaders(mediaUrl, sourceType: MediaSourceType.coomer),
                              placeholder: (_, __) => Container(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                child: const Center(child: CupertinoActivityIndicator(radius: 8)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                child: Center(
                                  child: Icon(
                                    isVideo ? CupertinoIcons.play_circle_fill : CupertinoIcons.photo,
                                    size: 32,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),

                            // Video icon badge
                            if (isVideo)
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 24),
                                ),
                              ),

                            // Index badge
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            // Selection overlay
                            if (_isSelectionMode)
                              Positioned.fill(
                                child: Container(
                                  color: isSelected
                                      ? IosTheme.primaryPink.withValues(alpha: 0.3)
                                      : Colors.black.withValues(alpha: 0.2),
                                  alignment: Alignment.topRight,
                                  padding: const EdgeInsets.all(8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected ? IosTheme.primaryPink : Colors.black54,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      isSelected ? CupertinoIcons.checkmark_alt : null,
                                      size: 14,
                                      color: Colors.white,
                                    ),
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
          color: const Color(0xFF00AFF0),
          bottomOffset: 24.0,
        ),
      ],
    ),
  ),
  );
  }

  static bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') || lower.contains('.mov') || lower.contains('.webm') || lower.contains('.m4v');
  }

  Color _getServiceColor(String service) {
    switch (service.toLowerCase()) {
      case 'onlyfans':
        return const Color(0xFF00AFF0);
      case 'fansly':
        return const Color(0xFF3399FF);
      case 'patreon':
        return const Color(0xFFFF424D);
      case 'candfans':
        return const Color(0xFFFF8C00);
      default:
        return const Color(0xFF9B51E0);
    }
  }
}


