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
  static const Color darkGlassSurface = Color(0xCC1C1C1E);
  static const Color darkBorder = Color(0x2EFFFFFF);

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
}
