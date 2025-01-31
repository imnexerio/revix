import 'package:flutter/material.dart';

class AppThemes {
  static final List<ThemeData> themes = [
    defaultLightTheme,
    defaultDarkTheme,
    seaLightTheme,
    seaDarkTheme,
    sunsetLightTheme,
    sunsetDarkTheme,
    purpleLightTheme,
    purpleDarkTheme,
    earthLightTheme,
    earthDarkTheme,
  ];
}

final ThemeData defaultLightTheme = ThemeData(
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

final ThemeData defaultDarkTheme = ThemeData(
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

// Original Light and Dark themes remain the same...

// Sea Theme - Blues and teals
final ThemeData seaLightTheme = ThemeData(
  useMaterial3: true,
  primarySwatch: customBlue,
  colorScheme: ColorScheme.light(
    primary: Color(0xFF1976D2),
    primaryContainer: Color(0xFF2196F3),
    secondary: Color(0xFF4FC3F7),
    secondaryContainer: Color(0xFF81D4FA),
    tertiary: Color(0xFF80DEEA),
    tertiaryContainer: Color(0xFFB2EBF2),
    surface: Colors.white,
    background: Color(0xFFF5F5F5),
    surfaceVariant: Color(0xFFE1F5FE),
    error: Color(0xFFE57373),
    errorContainer: Color(0xFFFFCDD2),
    onPrimary: Colors.white,
    onPrimaryContainer: Color(0xFF000D1A),
    onSecondary: Color(0xFF0D2A3A),
    onSecondaryContainer: Color(0xFF000D1A),
    onTertiary: Color(0xFF0D2A3A),
    onTertiaryContainer: Color(0xFF000D1A),
    onSurface: Color(0xFF0D47A1),
    onBackground: Color(0xFF1976D2),
    onError: Colors.white,
    surfaceTint: Color(0xFF81D4FA),
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
    displayLarge: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold),
    displayMedium: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold),
    displaySmall: TextStyle(color: Color(0xFF2196F3), fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(color: Color(0xFF2196F3), fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: Color(0xFF1976D2)),
    bodyMedium: TextStyle(color: Color(0xFF2196F3)),
  ),
);

// Sunset Theme - Warm oranges and reds
final ThemeData sunsetLightTheme = ThemeData(
  useMaterial3: true,
  primarySwatch: customOrange,
  colorScheme: ColorScheme.light(
    primary: Color(0xFFF57C00),
    primaryContainer: Color(0xFFFF9800),
    secondary: Color(0xFFFFB74D),
    secondaryContainer: Color(0xFFFFCC80),
    tertiary: Color(0xFFFFD180),
    tertiaryContainer: Color(0xFFFFE0B2),
    surface: Colors.white,
    background: Color(0xFFFFF3E0),
    surfaceVariant: Color(0xFFFFE0B2),
    error: Color(0xFFE57373),
    errorContainer: Color(0xFFFFCDD2),
    onPrimary: Colors.white,
    onPrimaryContainer: Color(0xFF1A0F00),
    onSecondary: Color(0xFF1A1000),
    onSecondaryContainer: Color(0xFF1A0F00),
    onTertiary: Color(0xFF1A1000),
    onTertiaryContainer: Color(0xFF1A0F00),
    onSurface: Color(0xFFE65100),
    onBackground: Color(0xFFF57C00),
    onError: Colors.white,
    surfaceTint: Color(0xFFFFB74D),
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
    displayLarge: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold),
    displayMedium: TextStyle(color: Color(0xFFF57C00), fontWeight: FontWeight.bold),
    displaySmall: TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: Color(0xFFF57C00), fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: Color(0xFFF57C00)),
    bodyMedium: TextStyle(color: Color(0xFFFF9800)),
  ),
);

// Purple Theme
final ThemeData purpleLightTheme = ThemeData(
  useMaterial3: true,
  primarySwatch: customPurple,
  colorScheme: ColorScheme.light(
    primary: Color(0xFF7B1FA2),
    primaryContainer: Color(0xFF9C27B0),
    secondary: Color(0xFFBA68C8),
    secondaryContainer: Color(0xFFCE93D8),
    tertiary: Color(0xFFE1BEE7),
    tertiaryContainer: Color(0xFFF3E5F5),
    surface: Colors.white,
    background: Color(0xFFF3E5F5),
    surfaceVariant: Color(0xFFEDE7F6),
    error: Color(0xFFE57373),
    errorContainer: Color(0xFFFFCDD2),
    onPrimary: Colors.white,
    onPrimaryContainer: Color(0xFF1A001A),
    onSecondary: Color(0xFF3A0D3A),
    onSecondaryContainer: Color(0xFF1A001A),
    onTertiary: Color(0xFF3A0D3A),
    onTertiaryContainer: Color(0xFF1A001A),
    onSurface: Color(0xFF4A148C),
    onBackground: Color(0xFF7B1FA2),
    onError: Colors.white,
    surfaceTint: Color(0xFFBA68C8),
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
    displayLarge: TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.bold),
    displayMedium: TextStyle(color: Color(0xFF7B1FA2), fontWeight: FontWeight.bold),
    displaySmall: TextStyle(color: Color(0xFF9C27B0), fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: Color(0xFF7B1FA2), fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(color: Color(0xFF9C27B0), fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: Color(0xFF7B1FA2)),
    bodyMedium: TextStyle(color: Color(0xFF9C27B0)),
  ),
);

// Earth Theme - Browns and neutrals
final ThemeData earthLightTheme = ThemeData(
  useMaterial3: true,
  primarySwatch: customBrown,
  colorScheme: ColorScheme.light(
    primary: Color(0xFF795548),
    primaryContainer: Color(0xFF8D6E63),
    secondary: Color(0xFFA1887F),
    secondaryContainer: Color(0xFFBCAAA4),
    tertiary: Color(0xFFD7CCC8),
    tertiaryContainer: Color(0xFFEFEBE9),
    surface: Colors.white,
    background: Color(0xFFEFEBE9),
    surfaceVariant: Color(0xFFECEFF1),
    error: Color(0xFFE57373),
    errorContainer: Color(0xFFFFCDD2),
    onPrimary: Colors.white,
    onPrimaryContainer: Color(0xFF1A0F0D),
    onSecondary: Color(0xFF3A1F1A),
    onSecondaryContainer: Color(0xFF1A0F0D),
    onTertiary: Color(0xFF3A1F1A),
    onTertiaryContainer: Color(0xFF1A0F0D),
    onSurface: Color(0xFF3E2723),
    onBackground: Color(0xFF795548),
    onError: Colors.white,
    surfaceTint: Color(0xFFA1887F),
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
    displayLarge: TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.bold),
    displayMedium: TextStyle(color: Color(0xFF795548), fontWeight: FontWeight.bold),
    displaySmall: TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: Color(0xFF795548), fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: Color(0xFF795548)),
    bodyMedium: TextStyle(color: Color(0xFF8D6E63)),
  ),
);

// Custom color swatches for new themes
const MaterialColor customBlue = MaterialColor(
  0xFF1976D2,
  <int, Color>{
    50: Color(0xFFE3F2FD),
    100: Color(0xFFBBDEFB),
    200: Color(0xFF90CAF9),
    300: Color(0xFF64B5F6),
    400: Color(0xFF42A5F5),
    500: Color(0xFF2196F3),
    600: Color(0xFF1E88E5),
    700: Color(0xFF1976D2),
    800: Color(0xFF1565C0),
    900: Color(0xFF0D47A1),
  },
);

const MaterialColor customOrange = MaterialColor(
  0xFFF57C00,
  <int, Color>{
    50: Color(0xFFFFF3E0),
    100: Color(0xFFFFE0B2),
    200: Color(0xFFFFCC80),
    300: Color(0xFFFFB74D),
    400: Color(0xFFFFA726),
    500: Color(0xFFFF9800),
    600: Color(0xFFFB8C00),
    700: Color(0xFFF57C00),
    800: Color(0xFFEF6C00),
    900: Color(0xFFE65100),
  },
);

const MaterialColor customPurple = MaterialColor(
  0xFF7B1FA2,
  <int, Color>{
    50: Color(0xFFF3E5F5),
    100: Color(0xFFE1BEE7),
    200: Color(0xFFCE93D8),
    300: Color(0xFFBA68C8),
    400: Color(0xFFAB47BC),
    500: Color(0xFF9C27B0),
    600: Color(0xFF8E24AA),
    700: Color(0xFF7B1FA2),
    800: Color(0xFF6A1B9A),
    900: Color(0xFF4A148C),
  },
);

const MaterialColor customBrown = MaterialColor(
  0xFF795548,
  <int, Color>{
    50: Color(0xFFEFEBE9),
    100: Color(0xFFD7CCC8),
    200: Color(0xFFBCAAA4),
    300: Color(0xFFA1887F),
    400: Color(0xFF8D6E63),
    500: Color(0xFF795548),
    600: Color(0xFF6D4C41),
    700: Color(0xFF5D4037),
    800: Color(0xFF4E342E),
    900: Color(0xFF3E2723),
  },
);

// Sea Theme - Dark variant
final ThemeData seaDarkTheme = ThemeData(
  useMaterial3: true,
  primarySwatch: customBlue,
  colorScheme: ColorScheme.dark(
    primary: Color(0xFF81D4FA),
    primaryContainer: Color(0xFF4FC3F7),
    secondary: Color(0xFFB2EBF2),
    secondaryContainer: Color(0xFF80DEEA),
    tertiary: Color(0xFF4DD0E1),
    tertiaryContainer: Color(0xFF26C6DA),
    surface: Color(0xFF1E1E1E),
    background: Color(0xFF121212),
    surfaceVariant: Color(0xFF0D47A1).withOpacity(0.1),
    error: Color(0xFFE57373),
    errorContainer: Color(0xFF442727),
    onPrimary: Color(0xFF000D1A),
    onPrimaryContainer: Color(0xFFE1F5FE),
    onSecondary: Color(0xFF000D1A),
    onSecondaryContainer: Color(0xFFE1F5FE),
    onTertiary: Colors.white,
    onTertiaryContainer: Color(0xFFE1F5FE),
    onSurface: Color(0xFF81D4FA),
    onBackground: Color(0xFF4FC3F7),
    onError: Colors.white,
    surfaceTint: Color(0xFF2196F3),
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
    displayLarge: TextStyle(color: Color(0xFF81D4FA), fontWeight: FontWeight.bold),
    displayMedium: TextStyle(color: Color(0xFF4FC3F7), fontWeight: FontWeight.bold),
    displaySmall: TextStyle(color: Color(0xFF29B6F6), fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: Color(0xFF4FC3F7), fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(color: Color(0xFF29B6F6), fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: Color(0xFF81D4FA), fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: Color(0xFF4FC3F7)),
    bodyMedium: TextStyle(color: Color(0xFF29B6F6)),
  ),
);

// Sunset Theme - Dark variant
final ThemeData sunsetDarkTheme = ThemeData(
  useMaterial3: true,
  primarySwatch: customOrange,
  colorScheme: ColorScheme.dark(
    primary: Color(0xFFFFB74D),
    primaryContainer: Color(0xFFFFA726),
    secondary: Color(0xFFFFCC80),
    secondaryContainer: Color(0xFFFFB74D),
    tertiary: Color(0xFFFFA726),
    tertiaryContainer: Color(0xFFFF9800),
    surface: Color(0xFF1E1E1E),
    background: Color(0xFF121212),
    surfaceVariant: Color(0xFFE65100).withOpacity(0.1),
    error: Color(0xFFE57373),
    errorContainer: Color(0xFF442727),
    onPrimary: Color(0xFF1A0F00),
    onPrimaryContainer: Color(0xFFFFE0B2),
    onSecondary: Color(0xFF1A0F00),
    onSecondaryContainer: Color(0xFFFFE0B2),
    onTertiary: Colors.white,
    onTertiaryContainer: Color(0xFFFFE0B2),
    onSurface: Color(0xFFFFB74D),
    onBackground: Color(0xFFFFA726),
    onError: Colors.white,
    surfaceTint: Color(0xFFFF9800),
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
    displayLarge: TextStyle(color: Color(0xFFFFB74D), fontWeight: FontWeight.bold),
    displayMedium: TextStyle(color: Color(0xFFFFA726), fontWeight: FontWeight.bold),
    displaySmall: TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: Color(0xFFFFA726), fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: Color(0xFFFFB74D), fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: Color(0xFFFFA726)),
    bodyMedium: TextStyle(color: Color(0xFFFF9800)),
  ),
);

// Purple Theme - Dark variant
final ThemeData purpleDarkTheme = ThemeData(
  useMaterial3: true,
  primarySwatch: customPurple,
  colorScheme: ColorScheme.dark(
    primary: Color(0xFFBA68C8),
    primaryContainer: Color(0xFFAB47BC),
    secondary: Color(0xFFCE93D8),
    secondaryContainer: Color(0xFFBA68C8),
    tertiary: Color(0xFFAB47BC),
    tertiaryContainer: Color(0xFF9C27B0),
    surface: Color(0xFF1E1E1E),
    background: Color(0xFF121212),
    surfaceVariant: Color(0xFF4A148C).withOpacity(0.1),
    error: Color(0xFFE57373),
    errorContainer: Color(0xFF442727),
    onPrimary: Color(0xFF1A001A),
    onPrimaryContainer: Color(0xFFF3E5F5),
    onSecondary: Color(0xFF1A001A),
    onSecondaryContainer: Color(0xFFF3E5F5),
    onTertiary: Colors.white,
    onTertiaryContainer: Color(0xFFF3E5F5),
    onSurface: Color(0xFFBA68C8),
    onBackground: Color(0xFFAB47BC),
    onError: Colors.white,
    surfaceTint: Color(0xFF9C27B0),
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
    displayLarge: TextStyle(color: Color(0xFFBA68C8), fontWeight: FontWeight.bold),
    displayMedium: TextStyle(color: Color(0xFFAB47BC), fontWeight: FontWeight.bold),
    displaySmall: TextStyle(color: Color(0xFF9C27B0), fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: Color(0xFFAB47BC), fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(color: Color(0xFF9C27B0), fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: Color(0xFFBA68C8), fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: Color(0xFFAB47BC)),
    bodyMedium: TextStyle(color: Color(0xFF9C27B0)),
  ),
);

// Earth Theme - Dark variant
final ThemeData earthDarkTheme = ThemeData(
  useMaterial3: true,
  primarySwatch: customBrown,
  colorScheme: ColorScheme.dark(
    primary: Color(0xFFA1887F),
    primaryContainer: Color(0xFF8D6E63),
    secondary: Color(0xFFBCAAA4),
    secondaryContainer: Color(0xFFA1887F),
    tertiary: Color(0xFF8D6E63),
    tertiaryContainer: Color(0xFF795548),
    surface: Color(0xFF1E1E1E),
    background: Color(0xFF121212),
    surfaceVariant: Color(0xFF3E2723).withOpacity(0.1),
    error: Color(0xFFE57373),
    errorContainer: Color(0xFF442727),
    onPrimary: Color(0xFF1A0F0D),
    onPrimaryContainer: Color(0xFFEFEBE9),
    onSecondary: Color(0xFF1A0F0D),
    onSecondaryContainer: Color(0xFFEFEBE9),
    onTertiary: Colors.white,
    onTertiaryContainer: Color(0xFFEFEBE9),
    onSurface: Color(0xFFA1887F),
    onBackground: Color(0xFF8D6E63),
    onError: Colors.white,
    surfaceTint: Color(0xFF795548),
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
    displayLarge: TextStyle(color: Color(0xFFA1887F), fontWeight: FontWeight.bold),
    displayMedium: TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.bold),
    displaySmall: TextStyle(color: Color(0xFF795548), fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(color: Color(0xFF795548), fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: Color(0xFFA1887F), fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: Color(0xFF8D6E63)),
    bodyMedium: TextStyle(color: Color(0xFF795548)),
  ),
);