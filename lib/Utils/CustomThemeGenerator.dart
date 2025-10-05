
import 'package:flutter/material.dart';

class CustomThemeGenerator {
  static ThemeData generateLightTheme(Color primaryColor) {
    // Create a color scheme based on the primary color
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ).copyWith(
      // Override with neutral backgrounds (pure white)
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF000000),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFFAFAFA),
      surfaceContainer: const Color(0xFFF5F5F5),
      surfaceContainerHigh: const Color(0xFFF0F0F0),
      surfaceContainerHighest: const Color(0xFFEBEBEB),
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: Brightness.light,

      // Customize specific theme properties
      primaryColor: colorScheme.primary,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w300),
        displayMedium: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w400),
        displaySmall: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
        headlineLarge: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w400),
        headlineMedium: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
        headlineSmall: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
      ),



      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
      ),
    );
  }

  static ThemeData generateDarkTheme(Color primaryColor) {
    // Create a color scheme based on the primary color
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ).copyWith(
      // Override with neutral backgrounds (pure black)
      surface: const Color(0xFF000000),
      onSurface: const Color(0xFFFFFFFF),
      surfaceContainerLowest: const Color(0xFF000000),
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF141414),
      surfaceContainerHigh: const Color(0xFF1E1E1E),
      surfaceContainerHighest: const Color(0xFF282828),
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: Brightness.dark,

      // Customize specific theme properties
      primaryColor: colorScheme.primary,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w300),
        displayMedium: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w400),
        displaySmall: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
        headlineLarge: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w400),
        headlineMedium: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
        headlineSmall: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
      ),
    );
  }
}
