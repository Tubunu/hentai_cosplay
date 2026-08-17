import 'dart:ui';
import 'package:flutter/material.dart';

/// Pure & Seamless iOS 26 Liquid Glass Container
/// Ultra-translucent fluid crystal glass with soft natural edges
/// and zero artificial hard lines or inner rings.
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry padding;
  final Color? fluidAuraColor;
  final bool isInteractive;
  final VoidCallback? onTap;

  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 26,
    this.blur = 18,
    this.padding = EdgeInsets.zero,
    this.fluidAuraColor,
    this.isInteractive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aura = fluidAuraColor ?? const Color(0xFFFA2D55);

    final content = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          // 1. Subtle living ambient colored aura
          if (fluidAuraColor != null)
            BoxShadow(
              color: aura.withValues(alpha: isDark ? 0.14 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          // 2. Soft physical drop shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.07),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
          // 3. Crisp edge contact shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
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
              // Pure seamless liquid gradient
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.5, 1.0],
                colors: isDark
                    ? [
                        const Color(0xFF2A2A36).withValues(alpha: 0.38),
                        const Color(0xFF181822).withValues(alpha: 0.24),
                        const Color(0xFF101016).withValues(alpha: 0.32),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.60),
                        const Color(0xFFF7F7FC).withValues(alpha: 0.30),
                        const Color(0xFFEDEAF6).withValues(alpha: 0.42),
                      ],
              ),
              // Soft natural waterdrop edge
              border: Border.all(
                width: 0.8,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.45),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (isInteractive && onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
