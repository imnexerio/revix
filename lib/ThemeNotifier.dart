import 'package:flutter/material.dart';
import 'package:retracker/theme_data.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeData _currentTheme;
  ThemeMode _currentThemeMode;

  ThemeNotifier(this._currentTheme, this._currentThemeMode);

  ThemeData get currentTheme => _currentTheme;
  ThemeMode get currentThemeMode => _currentThemeMode;

  void changeTheme(ThemeData newTheme) {
    _currentTheme = newTheme;
    notifyListeners();
  }

  void changeThemeMode(ThemeMode newMode) {
    _currentThemeMode = newMode;
    notifyListeners();
  }

  void updateThemeBasedOnMode(int selectedThemeIndex) {
    if (_currentThemeMode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.window.platformBrightness;
      _currentTheme = AppThemes.themes[selectedThemeIndex * 2 + (brightness == Brightness.dark ? 1 : 0)];
    } else {
      _currentTheme = AppThemes.themes[selectedThemeIndex * 2 + (_currentThemeMode == ThemeMode.dark ? 1 : 0)];
    }
    notifyListeners();
  }
}