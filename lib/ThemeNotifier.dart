import 'package:flutter/material.dart';
import 'package:retracker/theme_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeData _currentTheme;
  ThemeMode _currentThemeMode;
  int _selectedThemeIndex = 0;  // Add this line

  ThemeNotifier(this._currentTheme, this._currentThemeMode);

  ThemeData get currentTheme => _currentTheme;
  ThemeMode get currentThemeMode => _currentThemeMode;
  int get selectedThemeIndex => _selectedThemeIndex;  // Add this getter

  void changeTheme(ThemeData newTheme) {
    _currentTheme = newTheme;
    notifyListeners();
  }

  void changeThemeMode(ThemeMode newMode) async {
    _currentThemeMode = newMode;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', newMode.toString());
    updateThemeBasedOnMode(_selectedThemeIndex);  // Update theme after mode change
    notifyListeners();
  }

  void updateThemeBasedOnMode(int selectedThemeIndex) async {
    _selectedThemeIndex = selectedThemeIndex;  // Update the stored index
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedThemeIndex', selectedThemeIndex);

    if (_currentThemeMode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.window.platformBrightness;
      _currentTheme = AppThemes.themes[selectedThemeIndex * 2 + (brightness == Brightness.dark ? 1 : 0)];
    } else {
      _currentTheme = AppThemes.themes[selectedThemeIndex * 2 + (_currentThemeMode == ThemeMode.dark ? 1 : 0)];
    }
    notifyListeners();
  }

  Future<void> loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _selectedThemeIndex = prefs.getInt('selectedThemeIndex') ?? 0;
    String themeModeString = prefs.getString('themeMode') ?? ThemeMode.system.toString();
    ThemeMode themeMode = ThemeMode.values.firstWhere((e) => e.toString() == themeModeString);

    _currentThemeMode = themeMode;
    updateThemeBasedOnMode(_selectedThemeIndex);
  }
}