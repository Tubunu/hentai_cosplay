import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/download_task.dart';
import '../../../../models/video_item.dart';
import '../../../../providers/cosplayporntube_browse_provider.dart';
import '../../../../providers/download_provider.dart';
import '../../../widgets/unified_media_card.dart';

class CosplayporntubeVideoCard extends StatelessWidget {
  final VideoItem item;
  final VoidCallback onTap;

  const CosplayporntubeVideoCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = context.select<CosplayporntubeBrowseProvider, bool>((p) => p.isSelected(item));
    final isSelectionMode = context.select<CosplayporntubeBrowseProvider, bool>((p) => p.isSelectionMode);
    const themeColor = Color(0xFFFF9800);

    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatus(slug: item.slug, detailUrl: item.detailUrl),
    );

    final duration = item.rawData['duration'] as String? ?? item.duration;
    final tag = item.tags.isNotEmpty ? item.tags.first : 'CPTube';

    return UnifiedMediaCard(
      title: item.title,
      coverUrl: item.coverUrl,
      mediaType: UnifiedMediaType.video,
      brandColor: themeColor,
      httpHeaders: const {
        'Referer': 'https://cosplayporntube.com/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      },
      duration: duration.isNotEmpty ? duration : null,
      tag: tag,
      author: item.author.isNotEmpty ? item.author : null,
      isSelected: isSelected,
      isSelectionMode: isSelectionMode,
      isDownloaded: taskStatus == TaskStatus.completed,
      isDownloading: taskStatus == TaskStatus.downloading ||
          taskStatus == TaskStatus.queued,
      heroTag: 'cosplayporntube_cover_${item.slug}_${item.detailUrl}',
      onTap: () {
        if (isSelectionMode) {
          context.read<CosplayporntubeBrowseProvider>().toggleItemSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        context.read<CosplayporntubeBrowseProvider>().toggleItemSelection(item);
      },
    );
  }
}

