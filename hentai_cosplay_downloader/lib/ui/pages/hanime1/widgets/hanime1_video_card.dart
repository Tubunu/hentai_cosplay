import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/download_task.dart';
import '../../../../models/video_item.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/hanime1_browse_provider.dart';
import '../../../widgets/unified_media_card.dart';

class Hanime1VideoCard extends StatelessWidget {
  final VideoItem item;
  final VoidCallback onTap;

  const Hanime1VideoCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = context.select<Hanime1BrowseProvider, bool>((p) => p.isSelected(item));
    final isSelectionMode = context.select<Hanime1BrowseProvider, bool>((p) => p.isSelectionMode);
    const themeColor = Color(0xFFFF2E63);

    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatus(slug: item.slug, detailUrl: item.detailUrl),
    );

    final broadcaster = item.author.isNotEmpty ? item.author : 'Hanime1';

    return UnifiedMediaCard(
      title: item.title,
      coverUrl: item.coverUrl,
      mediaType: UnifiedMediaType.video,
      brandColor: themeColor,
      httpHeaders: const {
        'Referer': 'https://hanime1.me/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      },
      duration: item.duration.isNotEmpty ? item.duration : null,
      tag: '1080P',
      author: broadcaster,
      date: item.date.isNotEmpty ? item.date : null,
      isSelected: isSelected,
      isSelectionMode: isSelectionMode,
      isDownloaded: taskStatus == TaskStatus.completed,
      isDownloading: taskStatus == TaskStatus.downloading ||
          taskStatus == TaskStatus.queued,
      heroTag: 'hanime1_cover_${item.slug}_${item.detailUrl}',
      onTap: () {
        if (isSelectionMode) {
          context.read<Hanime1BrowseProvider>().toggleItemSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        context.read<Hanime1BrowseProvider>().toggleItemSelection(item);
      },
    );
  }
}
