import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/download_task.dart';
import '../../../../models/video_item.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/spankbang_browse_provider.dart';
import '../../../widgets/unified_media_card.dart';

class SpankbangVideoCard extends StatelessWidget {
  final VideoItem item;
  final VoidCallback onTap;

  const SpankbangVideoCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = context.select<SpankbangBrowseProvider, bool>((p) => p.isSelected(item));
    final isSelectionMode = context.select<SpankbangBrowseProvider, bool>((p) => p.isSelectionMode);
    const themeColor = Color(0xFFD32F2F);

    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatus(slug: item.slug, detailUrl: item.detailUrl),
    );

    final tag = item.tags.isNotEmpty ? item.tags.first : 'SpankBang';

    return UnifiedMediaCard(
      title: item.title,
      coverUrl: item.coverUrl,
      mediaType: UnifiedMediaType.video,
      brandColor: themeColor,
      httpHeaders: const {
        'Referer': 'https://spankbang.com/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      },
      duration: item.duration.isNotEmpty ? item.duration : null,
      tag: tag,
      author: item.author.isNotEmpty ? item.author : null,
      date: item.date.isNotEmpty ? item.date : null,
      isSelected: isSelected,
      isSelectionMode: isSelectionMode,
      isDownloaded: taskStatus == TaskStatus.completed,
      isDownloading: taskStatus == TaskStatus.downloading ||
          taskStatus == TaskStatus.queued,
      heroTag: 'spankbang_cover_${item.slug}_${item.detailUrl}',
      onTap: () {
        if (isSelectionMode) {
          context.read<SpankbangBrowseProvider>().toggleItemSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        context.read<SpankbangBrowseProvider>().toggleItemSelection(item);
      },
    );
  }
}
