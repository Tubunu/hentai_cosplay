import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class IosTheme {
  // Vibrant Apple Music / Liquid Accent Colors
  static const Color primaryPink = Color(0xFFFF2D55);
  static const Color primaryPurple = Color(0xFFAF52DE);
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color primaryCyan = Color(0xFF32ADE6);
  static const Color primaryGreen = Color(0xFF34C759);
  static const Color primaryOrange = Color(0xFFFF9500);

  // Signatures & Gradients
  static const LinearGradient musicGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF2D55),
      Color(0xFFFF375F),
      Color(0xFFFA2D55),
    ],
  );

  // Backgrounds & Surface (Light)
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color lightSurface = Colors.white;
  static const Color lightGlassSurface = Color(0xCCFFFFFF);
  static const Color lightBorder = Color(0x1F000000);

  // Backgrounds & Surface (Dark)
  static const Color darkBg = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkSurface2 = Color(0xFF2C2C2E);
  static const Color darkSurface3 = Color(0xFF3A3A3C);
  static const Color darkGlassSurface = Color(0xCC1C1C1E);
  static const Color darkBorder = Color(0x2EFFFFFF);

  // Semantic Layers
  static Color surfaceLayer0(bool isDark) => isDark ? darkBg : lightBg;
  static Color surfaceLayer1(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color surfaceLayer2(bool isDark) => isDark ? darkSurface2 : const Color(0xFFE5E5EA);
  static Color surfaceLayer3(bool isDark) => isDark ? darkSurface3 : const Color(0xFFD1D1D6);
  static Color borderSubtle(bool isDark) => isDark ? darkBorder : lightBorder;

  // Design Tokens
  static const double minTouchTarget = 44.0;
  static const double radiusCard = 16.0;
  static const double radiusPill = 20.0;
  static const double radiusCapsule = 26.0;
  static const double radiusSheet = 24.0;

  static List<BoxShadow> cardShadow(bool isDark, {Color? auraColor}) {
    return [
      if (auraColor != null)
        BoxShadow(
          color: auraColor.withValues(alpha: isDark ? 0.20 : 0.10),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];
  }

  static List<BoxShadow> floatingShadow(bool isDark, {Color? auraColor}) {
    return [
      if (auraColor != null)
        BoxShadow(
          color: auraColor.withValues(alpha: isDark ? 0.25 : 0.12),
          blurRadius: 24,
          spreadRadius: -2,
          offset: const Offset(0, 8),
        ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ];
  }

  static Color getAccentColor(String accent) {
    switch (accent) {
      case 'purple':
        return primaryPurple;
      case 'blue':
        return primaryBlue;
      case 'cyan':
        return primaryCyan;
      case 'green':
        return primaryGreen;
      case 'orange':
        return primaryOrange;
      default:
        return primaryPink;
    }
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPink,
        brightness: Brightness.light,
        primary: primaryPink,
        surface: lightSurface,
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: primaryPink,
        brightness: Brightness.light,
        barBackgroundColor: lightGlassSurface,
        scaffoldBackgroundColor: lightBg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: primaryPink),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: lightBorder, width: 0.5),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPink,
        brightness: Brightness.dark,
        primary: primaryPink,
        surface: darkSurface,
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: primaryPink,
        brightness: Brightness.dark,
        barBackgroundColor: darkGlassSurface,
        scaffoldBackgroundColor: darkBg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: primaryPink),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: darkBorder, width: 0.5),
        ),
      ),
    );
  }

  /// Unified card aspect ratio calculation with min/max clamping.
  /// - isVideo = true: standard 16:9-friendly ratio (default 1.45, clamped between 1.30 and 1.85)
  /// - isVideo = false: standard 3:4-friendly ratio (default 0.72, clamped between 0.60 and 0.85)
  static double cardAspectRatio({
    required bool isVideo,
    double? customRatio,
    double minRatio = 0.55,
    double maxRatio = 1.95,
  }) {
    if (customRatio != null) {
      return customRatio.clamp(minRatio, maxRatio);
    }
    final defaultRatio = isVideo ? 1.45 : 0.72;
    return defaultRatio.clamp(minRatio, maxRatio);
  }
}
