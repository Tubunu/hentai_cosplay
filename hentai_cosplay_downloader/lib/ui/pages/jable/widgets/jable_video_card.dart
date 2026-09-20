import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/jable_video_item.dart';
import '../../../../providers/favorite_provider.dart';
import '../../../../services/jable/scrapers/base_scraper.dart';
import '../../../widgets/unified_media_card.dart';
import 'jable_video_detail_sheet.dart';

class JableVideoCard extends StatelessWidget {
  final VideoCardModel video;
  final BaseScraper scraper;
  final bool isBatchMode;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;

  const JableVideoCard({
    super.key,
    required this.video,
    required this.scraper,
    this.isBatchMode = false,
    this.isSelected = false,
    this.onSelectionToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isFav = context.select<FavoriteProvider, bool>(
      (p) => p.isFavoriteItem(detailUrl: video.url),
    );

    return UnifiedMediaCard(
      title: video.title,
      coverUrl: video.thumbnail,
      duration: video.duration,
      date: video.date.isNotEmpty ? video.date : null,
      mediaType: UnifiedMediaType.video,
      brandColor: const Color(0xFFFF9900),
      isFavorite: isFav,
      onFavoriteTap: () {
        context.read<FavoriteProvider>().toggleVideo(
          video.toVideoItem(),
          siteKey: scraper.siteName.toLowerCase(),
          siteName: scraper.siteName,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFav ? '已取消收藏: ${video.title}' : '已加入收藏: ${video.title}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      isSelected: isSelected,
      isSelectionMode: isBatchMode,
      onTap: () {
        if (isBatchMode) {
          onSelectionToggle?.call();
        } else {
          JableVideoDetailSheet.show(context, video, scraper);
        }
      },
      onLongPress: () {
        if (isBatchMode) {
          onSelectionToggle?.call();
        } else {
          JableVideoDetailSheet.show(context, video, scraper);
        }
      },
    );
  }
}
