import 'package:flutter/material.dart';
import 'package:hentai_cosplay_downloader/ui/theme/ios_theme.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/unified_media_card.dart';

class UnifiedMediaCardSkeleton extends StatefulWidget {
  final UnifiedMediaType mediaType;
  final UnifiedMediaCardStyle style;

  const UnifiedMediaCardSkeleton({
    super.key,
    required this.mediaType,
    this.style = UnifiedMediaCardStyle.overlay,
  });

  @override
  State<UnifiedMediaCardSkeleton> createState() => _UnifiedMediaCardSkeletonState();
}

class _UnifiedMediaCardSkeletonState extends State<UnifiedMediaCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVideo = widget.mediaType == UnifiedMediaType.video;

    final baseColor = isDark ? const Color(0xFF242426) : const Color(0xFFE5E5EA);
    final highlightColor = isDark ? const Color(0xFF323236) : const Color(0xFFF2F2F7);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final shimmerColor = Color.lerp(baseColor, highlightColor, _animation.value)!;

        return Container(
          decoration: BoxDecoration(
            color: IosTheme.surfaceLayer1(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: IosTheme.borderSubtle(isDark),
              width: 0.6,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: widget.style == UnifiedMediaCardStyle.overlay
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    // Shimmer cover
                    Container(color: shimmerColor),
                    // Gradient scrim
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.12),
                            Colors.black.withValues(alpha: 0.88),
                          ],
                          stops: const [0.35, 0.65, 1.0],
                        ),
                      ),
                    ),
                    // Bottom title & info placeholders
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 11,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            height: 9,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover placeholder
                    AspectRatio(
                      aspectRatio: isVideo ? 16 / 9 : 3 / 4,
                      child: Container(color: shimmerColor),
                    ),
                    // Meta info placeholder
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 12,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: shimmerColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 10,
                              width: 70,
                              decoration: BoxDecoration(
                                color: shimmerColor,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
