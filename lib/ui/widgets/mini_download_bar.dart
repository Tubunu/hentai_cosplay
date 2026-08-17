import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/download_provider.dart';
import '../theme/ios_theme.dart';
import 'download_expanded_sheet.dart';
import 'frosted_glass.dart';
import 'liquid_glass.dart';

class MiniDownloadBar extends StatefulWidget {
  const MiniDownloadBar({super.key});

  @override
  State<MiniDownloadBar> createState() => _MiniDownloadBarState();
}

class _MiniDownloadBarState extends State<MiniDownloadBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadProv = context.watch<DownloadProvider>();
    final activeTask = downloadProv.currentActiveTask;

    // Show when there are active, queued or paused tasks
    if (!downloadProv.hasActiveOrPausedTasks || activeTask == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = ((activeTask.progress) * 100).toInt();
    final isPaused = !downloadProv.isDownloading && downloadProv.pausedTasks.isNotEmpty;

    // Dynamic Liquid Aura
    final primaryAura = isPaused
        ? const Color(0xFFFF9500)
        : const Color(0xFFFA2D55);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: BouncingButton(
        onTap: () => DownloadExpandedSheet.show(context),
        child: AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            final shimmerVal = _shimmerController.value;

            return LiquidGlass(
              borderRadius: 24,
              blur: 16,
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 9),
              fluidAuraColor: primaryAura,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // 1. Crystal Waterdrop Thumbnail with Edge Refraction
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: primaryAura.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: SizedBox(
                            width: 46,
                            height: 46,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                activeTask.packItem.coverUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: activeTask.packItem.coverUrl!,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            Container(
                                          color: Colors.black12,
                                          child: const Icon(CupertinoIcons.photo, size: 20),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.black12,
                                        child: const Icon(CupertinoIcons.photo, size: 20),
                                      ),
                                // Liquid Specular Top Highlight
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.35),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 2. Title & Live Status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              activeTask.packItem.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                _buildLiquidIndicator(isPaused, primaryAura),
                                const SizedBox(width: 6),
                                Text(
                                  isPaused ? '已暂停' : downloadProv.formattedSpeed,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: isPaused ? Colors.orange : IosTheme.primaryPink,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: IosTheme.secondaryText(context).withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$percent%  (${activeTask.finishedImages}/${activeTask.totalImages})',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: IosTheme.secondaryText(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 3. Liquid Play / Pause Fluid Button
                      IconButton(
                        icon: Icon(
                          downloadProv.isDownloading
                              ? CupertinoIcons.pause_circle_fill
                              : CupertinoIcons.play_circle_fill,
                          color: isPaused ? Colors.orange : IosTheme.primaryPink,
                          size: 34,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (downloadProv.isDownloading) {
                            downloadProv.pauseAll();
                          } else {
                            downloadProv.resumeAll();
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 7),

                  // 4. Ultra-translucent Liquid Glass Fluid Progress Track
                  Container(
                    height: 4.5,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                    child: Stack(
                      children: [
                        // Fluid Progress Bar
                        FractionallySizedBox(
                          widthFactor: activeTask.progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: isPaused
                                    ? [const Color(0xFFFF9500), const Color(0xFFFF5E3A)]
                                    : [const Color(0xFFFA2D55), const Color(0xFF9E54E7)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryAura.withValues(alpha: 0.55),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            // Liquid Shimmer Overlay
                            child: !isPaused && downloadProv.isDownloading
                                ? ShaderMask(
                                    shaderCallback: (bounds) {
                                      return LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        stops: [
                                          (shimmerVal - 0.25).clamp(0.0, 1.0),
                                          shimmerVal.clamp(0.0, 1.0),
                                          (shimmerVal + 0.25).clamp(0.0, 1.0),
                                        ],
                                        colors: [
                                          Colors.white.withValues(alpha: 0.0),
                                          Colors.white.withValues(alpha: 0.75),
                                          Colors.white.withValues(alpha: 0.0),
                                        ],
                                      ).createShader(bounds);
                                    },
                                    blendMode: BlendMode.srcATop,
                                    child: Container(color: Colors.transparent),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLiquidIndicator(bool isPaused, Color color) {
    if (isPaused) {
      return Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final scale = 0.8 + 0.4 * (0.5 - (_shimmerController.value - 0.5).abs()) * 2;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.8),
                  blurRadius: 5,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
