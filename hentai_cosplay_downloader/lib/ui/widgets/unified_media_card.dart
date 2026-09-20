import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/ios_theme.dart';
import 'bouncing_button.dart';

/// Media type determining default card aspect ratio and fallback icons
enum UnifiedMediaType {
  /// 16:9 widescreen video thumbnail
  video,
  /// 3:4 portrait gallery thumbnail
  gallery,
}

/// Card display style
enum UnifiedMediaCardStyle {
  /// MZT-style: full-bleed image with multi-stop dark gradient scrim,
  /// floating badges, and title/author/duration overlaid directly on the cover.
  /// Space-efficient, modern, and prevents vertical height clipping/wasted whitespace.
  overlay,

  /// Classic stacked style: image container on top with separate text area below.
  stacked,
}

/// Unified, highly optimized, declarative media card widget.
/// Decoupled from specific providers and replaces 35+ redundant card files.
class UnifiedMediaCard extends StatelessWidget {
  final String title;
  final String? coverUrl;
  final UnifiedMediaType mediaType;
  final UnifiedMediaCardStyle style;
  final double? customAspectRatio;
  final double minAspectRatio;
  final double maxAspectRatio;
  final Color brandColor;
  final Map<String, String>? httpHeaders;
  final String? duration;
  final int? imageCount;
  final String? author;
  final String? date;
  final String? tag;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onDownloadTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final bool isSelected;
  final bool isSelectionMode;
  final bool isDownloaded;
  final bool isDownloading;
  final String? heroTag;

  const UnifiedMediaCard({
    super.key,
    required this.title,
    required this.coverUrl,
    required this.onTap,
    this.mediaType = UnifiedMediaType.video,
    this.style = UnifiedMediaCardStyle.overlay,
    this.customAspectRatio,
    this.minAspectRatio = 0.55,
    this.maxAspectRatio = 1.95,
    this.brandColor = IosTheme.primaryPink,
    this.httpHeaders,
    this.duration,
    this.imageCount,
    this.author,
    this.date,
    this.tag,
    this.onLongPress,
    this.onAuthorTap,
    this.onDownloadTap,
    this.isFavorite = false,
    this.onFavoriteTap,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.heroTag,
  });

  /// Computes the clamped effective aspect ratio for this media item
  double get effectiveAspectRatio {
    if (customAspectRatio != null) {
      return customAspectRatio!.clamp(minAspectRatio, maxAspectRatio);
    }
    final defaultRatio = mediaType == UnifiedMediaType.video ? 1.45 : 0.72;
    return defaultRatio.clamp(minAspectRatio, maxAspectRatio);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: BouncingButton(
        onTap: () {
          try {
            HapticFeedback.selectionClick();
          } catch (_) {}
          onTap();
        },
        onLongPress: () {
          if (onLongPress != null) {
            try {
              HapticFeedback.mediumImpact();
            } catch (_) {}
            onLongPress!();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: IosTheme.surfaceLayer1(isDark),
            borderRadius: BorderRadius.circular(IosTheme.radiusCard),
            border: Border.all(
              color: isSelected ? brandColor : IosTheme.borderSubtle(isDark),
              width: isSelected ? 2.0 : 0.6,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: brandColor.withValues(alpha: isDark ? 0.35 : 0.20),
                      blurRadius: 10,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: style == UnifiedMediaCardStyle.overlay
              ? _buildOverlayCard(context, isDark)
              : _buildStackedCard(context, isDark),
        ),
      ),
    );
  }

  /// MZT-style overlay: Full-bleed image with gradient scrim and overlaid info
  Widget _buildOverlayCard(BuildContext context, bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Full-bleed Cover Image
        Positioned.fill(
          child: _buildCoverImage(isDark),
        ),

        // 2. Multi-stop bottom shadow gradient scrim
        Positioned.fill(
          child: DecoratedBox(
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
        ),

        // 3. Top Left Tag Chip (e.g. 4K, 无码, HC)
        if (tag != null && tag!.isNotEmpty)
          Positioned(
            top: 7,
            left: 7,
            child: _buildTopLeftTag(),
          ),

        // 4. Top Right Status Badges (Selection / Downloaded / Downloading)
        Positioned(
          top: 6,
          right: 6,
          child: _buildTopRightBadge(),
        ),

        // 5. Bottom Overlay: Title, Author, Date, Duration/ImageCount Badge
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  if (author != null && author!.isNotEmpty)
                    Expanded(
                      child: onAuthorTap != null
                          ? GestureDetector(
                              onTap: onAuthorTap,
                              child: Text(
                                author!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: brandColor,
                                  shadows: const [
                                    Shadow(color: Colors.black54, blurRadius: 2),
                                  ],
                                ),
                              ),
                            )
                          : Text(
                              author!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.85),
                                shadows: const [
                                  Shadow(color: Colors.black54, blurRadius: 2),
                                ],
                              ),
                            ),
                    )
                  else if (date != null && date!.isNotEmpty)
                    Expanded(
                      child: Text(
                        date!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.0,
                          color: Colors.white.withValues(alpha: 0.75),
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 2),
                          ],
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 4),
                  _buildBottomBadge(),
                  if (onFavoriteTap != null && !isSelectionMode) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        try {
                          HapticFeedback.selectionClick();
                        } catch (_) {}
                        onFavoriteTap!();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: isFavorite ? const Color(0xFFFF2D55) : Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                  if (onDownloadTap != null && !isSelectionMode) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        try {
                          HapticFeedback.selectionClick();
                        } catch (_) {}
                        onDownloadTap!();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: isDownloaded ? const Color(0xFF34C759) : brandColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDownloaded ? CupertinoIcons.check_mark : CupertinoIcons.arrow_down_to_line,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Classic stacked style: image container on top with separate text area below
  Widget _buildStackedCard(BuildContext context, bool isDark) {
    final imageRatio = mediaType == UnifiedMediaType.video ? (16 / 9) : (3 / 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: imageRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCoverImage(isDark),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 38,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.70),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              if (tag != null && tag!.isNotEmpty)
                Positioned(
                  top: 7,
                  left: 7,
                  child: _buildTopLeftTag(),
                ),
              Positioned(
                top: 6,
                right: 6,
                child: _buildTopRightBadge(),
              ),
              Positioned(
                bottom: 6,
                right: 6,
                child: _buildBottomBadge(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: isDark ? Colors.white : IosTheme.darkSurface,
                ),
              ),
              if (author != null || date != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (author != null && author!.isNotEmpty)
                      Expanded(
                        child: Text(
                          author!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                    if (date != null && date!.isNotEmpty)
                      Text(
                        date!,
                        style: TextStyle(
                          fontSize: 10.0,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    if (onFavoriteTap != null && !isSelectionMode) ...[
                      const SizedBox(width: 4),
                      BouncingButton(
                        onTap: onFavoriteTap,
                        child: Icon(
                          isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                          color: isFavorite ? const Color(0xFFFF2D55) : (isDark ? Colors.white54 : Colors.black45),
                          size: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCoverImage(bool isDark) {
    final imageWidget = (coverUrl != null && coverUrl!.isNotEmpty)
        ? CachedNetworkImage(
            imageUrl: coverUrl!,
            fit: BoxFit.cover,
            memCacheWidth: 420,
            fadeInDuration: const Duration(milliseconds: 150),
            fadeOutDuration: const Duration(milliseconds: 150),
            httpHeaders: httpHeaders,
            errorListener: (value) {
              debugPrint('[UnifiedMediaCard] Image load failed: $coverUrl, reason: $value');
            },
            placeholder: (context, url) => Container(
              color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFE8E8ED),
              child: Center(
                child: Icon(
                  mediaType == UnifiedMediaType.video
                      ? CupertinoIcons.film
                      : CupertinoIcons.photo,
                  size: 24,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFE8E8ED),
              child: Icon(
                mediaType == UnifiedMediaType.video
                    ? CupertinoIcons.film
                    : CupertinoIcons.photo,
                size: 26,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
          )
        : Container(
            color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFE8E8ED),
            child: Icon(
              mediaType == UnifiedMediaType.video
                  ? CupertinoIcons.film
                  : CupertinoIcons.photo,
              size: 26,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          );

    if (heroTag != null && heroTag!.isNotEmpty) {
      return Hero(
        tag: heroTag!,
        child: imageWidget,
      );
    }
    return imageWidget;
  }

  Widget _buildTopRightBadge() {
    if (isSelectionMode) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isSelected ? brandColor : Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: isSelected
            ? const Icon(CupertinoIcons.checkmark, size: 13, color: Colors.white)
            : null,
      );
    }

    if (isDownloaded) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFF34C759),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF34C759).withValues(alpha: 0.4),
              blurRadius: 6,
            ),
          ],
        ),
        child: const Icon(CupertinoIcons.checkmark_alt, size: 12, color: Colors.white),
      );
    }

    if (isDownloading) {
      return Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: CupertinoActivityIndicator(radius: 6, color: Colors.white),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTopLeftTag() {
    if (tag == null || tag!.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Text(
        tag!,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildBottomBadge() {
    final text = duration ?? (imageCount != null && imageCount! > 0 ? '$imageCount P' : null);
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mediaType == UnifiedMediaType.video) ...[
            const Icon(CupertinoIcons.play_fill, size: 8.5, color: Colors.white70),
            const SizedBox(width: 3),
          ] else ...[
            const Icon(CupertinoIcons.photo_fill_on_rectangle_fill, size: 8.5, color: Colors.white70),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
