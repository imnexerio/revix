import 'package:flutter/material.dart';

// lib/theme_data.dart
import 'package:flutter/material.dart';

class AppThemes {
  static final List<ThemeData> themes = [
    ThemeData.light(),
    ThemeData.dark(),

    // Add more themes if needed
  ];
}

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  primarySwatch: customGreen,
  colorScheme: ColorScheme.light(
    primary: Color(0xFF2E7D32),
    primaryContainer: Color(0xFF43A047),
    secondary: Color(0xFF66BB6A),
    secondaryContainer: Color(0xFF81C784),
    tertiary: Color(0xFFA5D6A7),
    tertiaryContainer: Color(0xFFC8E6C9),
    surface: Colors.white,
    background: Color(0xFFF5F5F5),
    surfaceVariant: Color(0xFFE8F5E9),
    error: Color(0xFFE57373),
    errorContainer: Color(0xFFFFCDD2),
    onPrimary: Colors.white,
    onPrimaryContainer: Color(0xFF002200),
    onSecondary: Color(0xFF0D3A0D),
    onSecondaryContainer: Color(0xFF002200),
    onTertiary: Color(0xFF0D3A0D),
    onTertiaryContainer: Color(0xFF002200),
    onSurface: Color(0xFF1B5E20),
    onBackground: Color(0xFF2E7D32),
    onError: Colors.white,
    surfaceTint: Color(0xFF81C784),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 2,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  ),
  cardTheme: CardTheme(
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    clipBehavior: Clip.antiAliasWithSaveLayer,
  ),
  textTheme: TextTheme(
    displayLarge: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold),
    displayMedium: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
    displaySmall: TextStyle(color: Color(0xFF388E3C), fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(color: Color(0xFF388E3C), fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: Color(0xFF2E7D32)),
    bodyMedium: TextStyle(color: Color(0xFF388E3C)),
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  primarySwatch: customGreen,
  colorScheme: ColorScheme.dark(
    primary: Color(0xFF81C784),
    primaryContainer: Color(0xFF66BB6A),
    secondary: Color(0xFFA5D6A7),
    secondaryContainer: Color(0xFF81C784),
    tertiary: Color(0xFF4CAF50),
    tertiaryContainer: Color(0xFF388E3C),
    surface: Color(0xFF1E1E1E),
    background: Color(0xFF121212),
    surfaceVariant: Color(0xFF1B5E20).withOpacity(0.1),
    error: Color(0xFFE57373),
    errorContainer: Color(0xFF442727),
    onPrimary: Color(0xFF002200),
    onPrimaryContainer: Color(0xFFE8F5E9),
    onSecondary: Color(0xFF002200),
    onSecondaryContainer: Color(0xFFE8F5E9),
    onTertiary: Colors.white,
    onTertiaryContainer: Color(0xFFE8F5E9),
    onSurface: Color(0xFFA5D6A7),
    onBackground: Color(0xFF81C784),
    onError: Colors.white,
    surfaceTint: Color(0xFF43A047),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 2,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  ),
  cardTheme: CardTheme(
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    clipBehavior: Clip.antiAliasWithSaveLayer,
  ),
  textTheme: TextTheme(
    displayLarge: TextStyle(color: Color(0xFFA5D6A7), fontWeight: FontWeight.bold),
    displayMedium: TextStyle(color: Color(0xFF81C784), fontWeight: FontWeight.bold),
    displaySmall: TextStyle(color: Color(0xFF66BB6A), fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: Color(0xFF81C784), fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(color: Color(0xFF66BB6A), fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: Color(0xFFA5D6A7), fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: Color(0xFF81C784)),
    bodyMedium: TextStyle(color: Color(0xFF66BB6A)),
  ),
);

const MaterialColor customGreen = MaterialColor(
  0xFF2E7D32,
  <int, Color>{
    50: Color(0xFFE8F5E9),
    100: Color(0xFFC8E6C9),
    200: Color(0xFFA5D6A7),
    300: Color(0xFF81C784),
    400: Color(0xFF66BB6A),
    500: Color(0xFF4CAF50),
    600: Color(0xFF43A047),
    700: Color(0xFF388E3C),
    800: Color(0xFF2E7D32),
    900: Color(0xFF1B5E20),
  },
);