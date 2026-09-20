import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/download_task.dart';
import '../../../../models/video_item.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/hohoj_browse_provider.dart';
import '../../../widgets/unified_media_card.dart';

class HohojVideoCard extends StatelessWidget {
  final VideoItem item;
  final VoidCallback onTap;

  const HohojVideoCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = context.select<HohojBrowseProvider, bool>((p) => p.isSelected(item));
    final isSelectionMode = context.select<HohojBrowseProvider, bool>((p) => p.isSelectionMode);
    const themeColor = Color(0xFFE74C3C);

    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatus(slug: item.slug, detailUrl: item.detailUrl),
    );

    final badge = item.rawData['badge'] as String? ?? '';
    final views = item.views.isNotEmpty ? item.views : (item.rawData['views'] as String? ?? '');

    return UnifiedMediaCard(
      title: item.title,
      coverUrl: item.coverUrl,
      mediaType: UnifiedMediaType.video,
      brandColor: themeColor,
      httpHeaders: const {
        'Referer': 'https://hohoj.tv/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      },
      duration: views.isNotEmpty ? '👁 $views' : null,
      tag: badge.isNotEmpty ? badge : 'HOHOJ',
      isSelected: isSelected,
      isSelectionMode: isSelectionMode,
      isDownloaded: taskStatus == TaskStatus.completed,
      isDownloading: taskStatus == TaskStatus.downloading ||
          taskStatus == TaskStatus.queued,
      heroTag: 'hohoj_cover_${item.slug}_${item.detailUrl}',
      onTap: () {
        if (isSelectionMode) {
          context.read<HohojBrowseProvider>().toggleItemSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        context.read<HohojBrowseProvider>().toggleItemSelection(item);
      },
    );
  }
}
