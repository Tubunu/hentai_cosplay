import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? fluidAuraColor;
  final Color? backgroundColor;
  final double? opacity;

  const LiquidGlass({
    super.key,
    required this.child,
    this.blur = 24.0,
    this.borderRadius = 28.0,
    this.padding,
    this.margin,
    this.fluidAuraColor,
    this.backgroundColor,
    this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aura = fluidAuraColor ?? const Color(0xFFFF2D55);
    final effectiveOpacity = (opacity ?? 0.85).clamp(0.1, 1.0);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: aura.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 24,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: backgroundColor ??
                  (isDark
                      ? const Color(0xFF1A1A1E).withValues(alpha: effectiveOpacity)
                      : Colors.white.withValues(alpha: effectiveOpacity)),
              border: Border.all(
                color: isDark ? const Color(0x33FFFFFF) : const Color(0x22000000),
                width: 0.8,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
