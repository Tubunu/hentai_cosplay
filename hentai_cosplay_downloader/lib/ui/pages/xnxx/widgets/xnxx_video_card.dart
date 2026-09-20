import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/download_task.dart';
import '../../../../models/video_item.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/xnxx_browse_provider.dart';
import '../../../widgets/unified_media_card.dart';

class XnxxVideoCard extends StatelessWidget {
  final VideoItem item;
  final VoidCallback onTap;

  const XnxxVideoCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = context.select<XnxxBrowseProvider, bool>((p) => p.isSelected(item));
    final isSelectionMode = context.select<XnxxBrowseProvider, bool>((p) => p.isSelectionMode);
    const themeColor = Color(0xFF0275D8);

    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatus(slug: item.slug, detailUrl: item.detailUrl),
    );

    final rawDuration = item.rawData['duration'] as String? ?? item.duration;
    final cleanDuration = rawDuration.replaceAll(RegExp(r'^[-—\s]+|[-—\s]+$'), '').trim();
    final tag = item.tags.isNotEmpty ? item.tags.first : 'XNXX';

    return UnifiedMediaCard(
      title: item.title,
      coverUrl: item.coverUrl,
      mediaType: UnifiedMediaType.video,
      brandColor: themeColor,
      httpHeaders: const {
        'Referer': 'https://www.xnxx.com/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      },
      duration: cleanDuration.isNotEmpty ? cleanDuration : null,
      tag: tag,
      author: item.author.isNotEmpty ? item.author : null,
      isSelected: isSelected,
      isSelectionMode: isSelectionMode,
      isDownloaded: taskStatus == TaskStatus.completed,
      isDownloading: taskStatus == TaskStatus.downloading ||
          taskStatus == TaskStatus.queued,
      heroTag: 'xnxx_cover_${item.slug}_${item.detailUrl}',
      onTap: () {
        if (isSelectionMode) {
          context.read<XnxxBrowseProvider>().toggleItemSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        context.read<XnxxBrowseProvider>().toggleItemSelection(item);
      },
    );
  }
}
