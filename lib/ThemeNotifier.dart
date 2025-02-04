import 'package:flutter/material.dart';

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
}