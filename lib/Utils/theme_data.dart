import 'package:flutter/material.dart';
import 'CustomThemeGenerator.dart';

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

  static final List<String> themeNames = [
    'Default',
    'Sea',
    'Sunset',
    'Purple',
    'Earth',
  ];
}

final ThemeData defaultLightTheme = CustomThemeGenerator.generateLightTheme(const Color.fromARGB(255, 0, 255, 252));
final ThemeData defaultDarkTheme = CustomThemeGenerator.generateDarkTheme(const Color.fromARGB(255, 0, 255, 252));

final ThemeData seaLightTheme = CustomThemeGenerator.generateLightTheme(const Color.fromARGB(255, 10, 128, 200));
final ThemeData seaDarkTheme = CustomThemeGenerator.generateDarkTheme(const Color.fromARGB(255, 10, 128, 200));

final ThemeData sunsetLightTheme = CustomThemeGenerator.generateLightTheme(const Color.fromARGB(255, 255, 107, 107));
final ThemeData sunsetDarkTheme = CustomThemeGenerator.generateDarkTheme(const Color.fromARGB(255, 255, 107, 107));

final ThemeData purpleLightTheme = CustomThemeGenerator.generateLightTheme(const Color.fromARGB(255, 107, 107, 234));
final ThemeData purpleDarkTheme = CustomThemeGenerator.generateDarkTheme(const Color.fromARGB(255, 107, 107, 234));

final ThemeData earthLightTheme = CustomThemeGenerator.generateLightTheme(const Color.fromARGB(255, 107, 234, 107));
final ThemeData earthDarkTheme = CustomThemeGenerator.generateDarkTheme(const Color.fromARGB(255, 107, 234, 107));



