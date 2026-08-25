import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/jable_video_item.dart';
import '../../../../services/jable/scrapers/base_scraper.dart';
import '../../../theme/ios_theme.dart';
import '../../../widgets/bouncing_button.dart';
import '../../video/video_player_page.dart';
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

  void _quickPlay(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在解析在线播放流...'),
          duration: Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final detail = await scraper.parseVideoDetail(video.url);
      if (context.mounted) {
        VideoPlayerPage.openRemote(
          context,
          url: detail.m3u8Url,
          title: detail.title.isNotEmpty ? detail.title : video.title,
          headers: detail.headers,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('在线播放解析失败: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BouncingButton(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Poster Cover Image
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: video.thumbnail,
                    fit: BoxFit.cover,
                    memCacheWidth: 450,
                    placeholder: (_, __) => Container(
                      color: isDark ? Colors.white10 : Colors.black12,
                      child: const Center(
                        child: CupertinoActivityIndicator(radius: 10),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark ? Colors.white10 : Colors.black12,
                      child: const Center(
                        child: Icon(CupertinoIcons.video_camera, color: Colors.grey, size: 36),
                      ),
                    ),
                  ),

                  // Duration Badge
                  if (video.duration.isNotEmpty)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(180),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          video.duration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Quick Play Button (direct stream)
                  if (!isBatchMode)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: GestureDetector(
                        onTap: () => _quickPlay(context),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: IosTheme.primaryPink.withAlpha(220),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(100),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.play_fill,
                            color: Colors.white,
                            size: 13,
                          ),
                        ),
                      ),
                    ),

                  // Batch Selection Overlay
                  if (isBatchMode)
                    Positioned.fill(
                      child: Container(
                        color: isSelected
                            ? IosTheme.primaryPink.withAlpha(80)
                            : Colors.black.withAlpha(60),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? IosTheme.primaryPink : Colors.black45,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                isSelected ? Icons.check : Icons.add,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. Video Title
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.25,
            ),
          ),

          // 3. Date / Site Tag
          if (video.date.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                video.date,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
