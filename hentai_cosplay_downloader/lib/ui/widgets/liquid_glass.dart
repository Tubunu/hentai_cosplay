import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/ios_theme.dart';

/// Standard visual tiers for frosted & liquid glass styling
enum GlassTier {
  /// Card tier: subtle blur (10pt), light alpha, minimal GPU footprint, suitable for cards/chips
  card,
  /// Chrome tier: medium blur (20pt), balanced alpha, suitable for app bars & bottom bars
  chrome,
  /// Modal tier: deep blur (28pt) + vibrant aura glow, suitable for bottom sheets & hub grids
  modal,
}

/// Unified High-Performance Glass Surface Container
class AppGlassSurface extends StatelessWidget {
  final Widget child;
  final GlassTier tier;
  final double? blur;
  final double? borderRadius;
  final BorderRadius? customBorderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? auraColor;
  final Color? backgroundColor;
  final double? opacity;
  final bool isInteractive;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Border? border;
  final Gradient? customGradient;

  const AppGlassSurface({
    super.key,
    required this.child,
    this.tier = GlassTier.chrome,
    this.blur,
    this.borderRadius,
    this.customBorderRadius,
    this.padding,
    this.margin,
    this.auraColor,
    this.backgroundColor,
    this.opacity,
    this.isInteractive = false,
    this.onTap,
    this.onLongPress,
    this.border,
    this.customGradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveBlur = blur ?? switch (tier) {
      GlassTier.card => 10.0,
      GlassTier.chrome => 20.0,
      GlassTier.modal => 28.0,
    };

    final effectiveRadius = customBorderRadius ??
        BorderRadius.circular(borderRadius ?? switch (tier) {
          GlassTier.card => IosTheme.radiusCard,
          GlassTier.chrome => IosTheme.radiusCapsule,
          GlassTier.modal => IosTheme.radiusSheet,
        });

    final defaultOpacity = switch (tier) {
      GlassTier.card => isDark ? 0.70 : 0.80,
      GlassTier.chrome => isDark ? 0.82 : 0.88,
      GlassTier.modal => isDark ? 0.88 : 0.92,
    };
    final effectiveOpacity = (opacity ?? defaultOpacity).clamp(0.05, 1.0);

    Widget glassContainer = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: switch (tier) {
          GlassTier.card => IosTheme.cardShadow(isDark, auraColor: auraColor),
          GlassTier.chrome || GlassTier.modal => IosTheme.floatingShadow(isDark, auraColor: auraColor),
        },
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: effectiveRadius,
              gradient: customGradient,
              color: backgroundColor ??
                  (isDark
                      ? const Color(0xFF18181E).withValues(alpha: effectiveOpacity)
                      : Colors.white.withValues(alpha: effectiveOpacity)),
              border: border ??
                  Border.all(
                    color: isDark ? const Color(0x2EFFFFFF) : const Color(0x18000000),
                    width: 0.6,
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

/// Backward-compatible Clean Apple-Style Frosted Translucent Glass Container
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
    return AppGlassSurface(
      blur: blur,
      borderRadius: borderRadius,
      customBorderRadius: customBorderRadius,
      padding: padding,
      margin: margin,
      auraColor: fluidAuraColor,
      backgroundColor: backgroundColor,
      opacity: opacity,
      isInteractive: isInteractive,
      onTap: onTap,
      onLongPress: onLongPress,
      border: border,
      customGradient: customGradient,
      tier: GlassTier.chrome,
      child: child,
    );
  }
}

