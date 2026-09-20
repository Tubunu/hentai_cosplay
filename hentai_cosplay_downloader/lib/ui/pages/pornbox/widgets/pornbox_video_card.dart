import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/download_task.dart';
import '../../../../models/video_item.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/pornbox_browse_provider.dart';
import '../../../../services/pornbox/pornbox_api_service.dart';
import '../../../widgets/unified_media_card.dart';

class PornboxVideoCard extends StatelessWidget {
  final VideoItem item;
  final VoidCallback onTap;

  const PornboxVideoCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = context.select<PornboxBrowseProvider, bool>((p) => p.isSelected(item));
    final isSelectionMode = context.select<PornboxBrowseProvider, bool>((p) => p.isSelectionMode);
    const themeColor = Color(0xFF8E24AA);

    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatus(slug: item.slug, detailUrl: item.detailUrl),
    );

    final is4K = item.tags.contains('4K') || item.views.contains('4K');
    final isHD = is4K || item.tags.contains('HD') || item.views.contains('高清');
    final tag = is4K ? '4K' : (isHD ? 'HD' : (item.tags.isNotEmpty ? item.tags.first : 'Pornbox'));

    return UnifiedMediaCard(
      title: item.title,
      coverUrl: item.coverUrl,
      mediaType: UnifiedMediaType.video,
      brandColor: themeColor,
      httpHeaders: const {
        'Referer': PornboxApiService.kBaseUrl,
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
      heroTag: 'pornbox_cover_${item.slug}_${item.detailUrl}',
      onTap: () {
        if (isSelectionMode) {
          context.read<PornboxBrowseProvider>().toggleItemSelection(item);
        } else {
          onTap();
        }
      },
      onLongPress: () {
        context.read<PornboxBrowseProvider>().toggleItemSelection(item);
      },
    );
  }
}
