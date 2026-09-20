import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/album_item.dart';
import '../../models/download_task.dart';
import '../../providers/browse_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/favorite_provider.dart';
import '../theme/ios_theme.dart';
import 'unified_media_card.dart';

class AlbumCard extends StatelessWidget {
  final AlbumItem item;
  final VoidCallback onTap;

  const AlbumCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = context.select<BrowseProvider, bool>((p) => p.isAlbumSelected(item));
    final isSelectionMode = context.select<BrowseProvider, bool>((p) => p.isSelectionMode);

    // Check if album is favorited
    final favId = 'hc_${item.slug.isNotEmpty ? item.slug : item.detailUrl.hashCode}';
    final isFav = context.select<FavoriteProvider, bool>(
      (p) => p.isFavoriteItem(id: favId, detailUrl: item.detailUrl),
    );

    // Check if album is in download queue or completed
    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatusForAlbum(item),
    );

    return UnifiedMediaCard(
      title: item.title,
      coverUrl: item.coverUrl,
      mediaType: UnifiedMediaType.gallery,
      brandColor: IosTheme.primaryPink,
      imageCount: item.imageCount,
      author: item.author,
      httpHeaders: const {
        'Referer': 'https://hentai-cosplay-xxx.com/',
      },
      heroTag: null,
      date: item.date.isNotEmpty ? item.date : null,
      tag: item.tags.isNotEmpty ? item.tags.first : null,
      isSelected: isSelected,
      isSelectionMode: isSelectionMode,
      isDownloaded: taskStatus == TaskStatus.completed,
      isDownloading: taskStatus == TaskStatus.downloading ||
          taskStatus == TaskStatus.queued,
      isFavorite: isFav,
      onFavoriteTap: () {
        context.read<FavoriteProvider>().toggleAlbum(item, siteKey: 'hc', siteName: 'Hentai Cosplay');
      },
      onDownloadTap: () {
        context.read<DownloadProvider>().addAlbumTask(item);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已加入下载队列: ${item.title}'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onTap: () {
        if (isSelectionMode) {
          context.read<BrowseProvider>().toggleAlbumSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        context.read<BrowseProvider>().toggleAlbumSelection(item);
      },
    );
  }
}
