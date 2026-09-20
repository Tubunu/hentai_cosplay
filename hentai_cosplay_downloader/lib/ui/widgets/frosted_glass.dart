import 'package:flutter/material.dart';
import 'liquid_glass.dart';

class FrostedGlass extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double vibrancy;

  const FrostedGlass({
    super.key,
    required this.child,
    this.blur = 20.0,
    this.borderRadius = 20.0,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0.5,
    this.vibrancy = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      blur: blur,
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      backgroundColor: backgroundColor,
      border: borderColor != null
          ? Border.all(color: borderColor!, width: borderWidth)
          : null,
      tier: GlassTier.chrome,
      child: child,
    );
  }
}


