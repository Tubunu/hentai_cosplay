import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/settings_provider.dart';
import 'bouncing_button.dart';
import 'liquid_glass.dart';

class ScrollToTopButton extends StatefulWidget {
  final ScrollController scrollController;
  final double threshold;
  final Color? color;
  final double? bottomOffset;
  final double rightOffset;

  const ScrollToTopButton({
    super.key,
    required this.scrollController,
    this.threshold = 200.0,
    this.color,
    this.bottomOffset,
    this.rightOffset = 18.0,
  });

  @override
  State<ScrollToTopButton> createState() => _ScrollToTopButtonState();
}

class _ScrollToTopButtonState extends State<ScrollToTopButton> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ScrollToTopButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final show = widget.scrollController.offset > widget.threshold;
    if (show != _isVisible) {
      setState(() => _isVisible = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = widget.color ?? const Color(0xFFFF2D55);
    final isDownloading = context.select<DownloadProvider, bool>((p) => p.isDownloading);
    final customOpacity = context.select<SettingsProvider, double>((p) => p.config.navBarOpacity);
    final bottom = widget.bottomOffset ?? (isDownloading ? 165.0 : 105.0);

    return Positioned(
      bottom: bottom,
      right: widget.rightOffset,
      child: AnimatedScale(
        scale: _isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: _isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          child: BouncingButton(
            onTap: () {
              if (widget.scrollController.hasClients) {
                widget.scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            child: LiquidGlass(
              borderRadius: 22,
              blur: 24,
              opacity: customOpacity,
              fluidAuraColor: themeColor,
              padding: EdgeInsets.zero,
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.12),
                width: 1.0,
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(
                    CupertinoIcons.arrow_up,
                    size: 20,
                    color: themeColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
