import 'package:flutter/material.dart';
import '../../models/album_item.dart';
import '../../services/random_discovery_service.dart';
import 'bouncing_button.dart';

export '../../models/album_item.dart' show MediaSourceType;
export '../../services/random_discovery_service.dart' show VideoSiteType;

class RandomActionButton extends StatelessWidget {
  final MediaSourceType? albumSource;
  final VideoSiteType? videoSite;
  final bool replace;
  final bool isCapsule;
  final Color? color;

  const RandomActionButton.album({
    super.key,
    required this.albumSource,
    this.replace = false,
    this.isCapsule = false,
    this.color,
  }) : videoSite = null;

  const RandomActionButton.video({
    super.key,
    required this.videoSite,
    this.replace = false,
    this.isCapsule = false,
    this.color,
  }) : albumSource = null;

  void _triggerRandom(BuildContext context) {
    if (albumSource != null) {
      RandomDiscoveryService.openRandomAlbum(context, albumSource!, replace: replace);
    } else if (videoSite != null) {
      RandomDiscoveryService.openRandomVideo(context, videoSite!, replace: replace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? const Color(0xFFFF2D55);

    if (isCapsule) {
      return BouncingButton(
        onTap: () => _triggerRandom(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                themeColor,
                themeColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎲', style: TextStyle(fontSize: 12)),
              SizedBox(width: 4),
              Text(
                '全库随机',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return IconButton(
      tooltip: '🎲 全库随机穿梭',
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: themeColor.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: const Text('🎲', style: TextStyle(fontSize: 14)),
      ),
      onPressed: () => _triggerRandom(context),
    );
  }
}
