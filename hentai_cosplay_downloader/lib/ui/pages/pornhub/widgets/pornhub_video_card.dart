import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/download_task.dart';
import '../../../../models/video_item.dart';
import '../../../../providers/download_provider.dart';
import '../../../../providers/pornhub_browse_provider.dart';
import '../../../widgets/unified_media_card.dart';
import '../pornhub_author_page.dart';

class PornhubVideoCard extends StatelessWidget {
  final VideoItem item;
  final VoidCallback onTap;
  final bool? isSelected;
  final bool? isSelectionMode;
  final VoidCallback? onToggleSelect;

  const PornhubVideoCard({
    super.key,
    required this.item,
    required this.onTap,
    this.isSelected,
    this.isSelectionMode,
    this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve selection state from props if passed (e.g. in AuthorPage) or fallback to BrowseProvider
    final effectiveSelected = isSelected ??
        context.select<PornhubBrowseProvider, bool>((p) => p.isSelected(item));
    final effectiveSelectionMode = isSelectionMode ??
        context.select<PornhubBrowseProvider, bool>((p) => p.isSelectionMode);
    const themeColor = Color(0xFFFF9900);

    final taskStatus = context.select<DownloadProvider, TaskStatus?>(
      (p) => p.getTaskStatus(slug: item.slug, detailUrl: item.detailUrl),
    );

    final tag = item.tags.isNotEmpty ? item.tags.first : 'Pornhub';

    return UnifiedMediaCard(
      title: item.title,
      coverUrl: item.coverUrl,
      mediaType: UnifiedMediaType.video,
      brandColor: themeColor,
      httpHeaders: const {
        'Referer': 'https://www.pornhub.com/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      },
      duration: item.duration.isNotEmpty ? item.duration : null,
      tag: tag,
      author: item.author.isNotEmpty ? item.author : null,
      isSelected: effectiveSelected,
      isSelectionMode: effectiveSelectionMode,
      isDownloaded: taskStatus == TaskStatus.completed,
      isDownloading: taskStatus == TaskStatus.downloading ||
          taskStatus == TaskStatus.queued,
      heroTag: 'pornhub_cover_${item.slug}_${item.detailUrl}',
      onTap: () {
        if (effectiveSelectionMode) {
          if (onToggleSelect != null) {
            onToggleSelect!();
          } else {
            context.read<PornhubBrowseProvider>().toggleSelect(item);
          }
        } else {
          onTap();
        }
      },
      onLongPress: () {
        if (onToggleSelect != null) {
          onToggleSelect!();
        } else {
          context.read<PornhubBrowseProvider>().toggleSelect(item);
        }
      },
      onAuthorTap: (item.author.isNotEmpty && item.author != 'Pornhub')
          ? () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => PornhubAuthorPage(
                    authorName: item.author,
                    authorUrl: item.rawData['authorUrl']?.toString(),
                  ),
                ),
              );
            }
          : null,
      onDownloadTap: () {
        context.read<DownloadProvider>().addVideoTask(item);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已添加视频到下载队列'),
            backgroundColor: themeColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}
