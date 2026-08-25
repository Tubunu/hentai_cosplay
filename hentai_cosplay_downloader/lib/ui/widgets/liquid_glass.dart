import 'dart:ui';
import 'package:flutter/material.dart';

/// Clean Apple-Style Frosted Translucent Glass Container
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final BorderRadius? customBorderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? fluidAuraColor;
  final Color? backgroundColor;
  final double? opacity;
  final bool isInteractive;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Border? border;
  final Gradient? customGradient;

  // Extra parameters kept for backward compatibility
  final bool hasGlossSweep;
  final bool hasLensRefraction;
  final bool chromaticAberration;
  final double vibrancy;

  const LiquidGlass({
    super.key,
    required this.child,
    this.blur = 20.0,
    this.borderRadius = 28.0,
    this.customBorderRadius,
    this.padding,
    this.margin,
    this.fluidAuraColor,
    this.backgroundColor,
    this.opacity,
    this.isInteractive = false,
    this.onTap,
    this.onLongPress,
    this.border,
    this.customGradient,
    this.hasGlossSweep = false,
    this.hasLensRefraction = false,
    this.chromaticAberration = false,
    this.vibrancy = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveOpacity = (opacity ?? 0.85).clamp(0.05, 1.0);
    final effectiveRadius = customBorderRadius ?? BorderRadius.circular(borderRadius);

    Widget glassContainer = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: [
          if (fluidAuraColor != null)
            BoxShadow(
              color: fluidAuraColor!.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 24,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: effectiveRadius,
              gradient: customGradient,
              color: backgroundColor ??
                  (isDark
                      ? const Color(0xFF1C1C22).withValues(alpha: effectiveOpacity)
                      : Colors.white.withValues(alpha: effectiveOpacity)),
              border: border ??
                  Border.all(
                    color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                    width: 0.8,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (isInteractive || onTap != null || onLongPress != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: glassContainer,
      );
    }

    return glassContainer;
  }
}

