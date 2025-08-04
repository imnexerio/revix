
import 'package:flutter/material.dart';

class CustomThemeGenerator {
  static ThemeData generateLightTheme(Color primaryColor) {
    // Create a color scheme based on the primary color
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
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
