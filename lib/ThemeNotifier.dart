import 'package:flutter/material.dart';
import 'package:retracker/theme_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeData _currentTheme;
  ThemeMode _currentThemeMode;
  int _selectedThemeIndex;
  Color? _customThemeColor;
  static const int customThemeIndex = -1; // Special index for custom theme

  // Constructor
  ThemeNotifier(this._currentTheme, this._currentThemeMode) : _selectedThemeIndex = 0 {
    loadPreferences();
  }

  // Getters
  ThemeData get currentTheme => _currentTheme;
  ThemeMode get currentThemeMode => _currentThemeMode;
  int get selectedThemeIndex => _selectedThemeIndex;
  Color? get customThemeColor => _customThemeColor;
  bool get isCustomTheme => _selectedThemeIndex == customThemeIndex;

  // Change the current theme
  void changeTheme(ThemeData newTheme) {
    _currentTheme = newTheme;
    notifyListeners();
  }

  // Change theme mode (light/dark/system)
  void changeThemeMode(ThemeMode newMode) async {
    _currentThemeMode = newMode;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', newMode.toString());

    // Update theme based on new mode
    if (isCustomTheme && _customThemeColor != null) {
      _applyCustomTheme(_customThemeColor!);
    } else {
      updateThemeBasedOnMode(_selectedThemeIndex);
    }
    notifyListeners();
  }

  // Update theme based on selected index and current mode
  void updateThemeBasedOnMode(int selectedThemeIndex) async {
    if (selectedThemeIndex == customThemeIndex && _customThemeColor == null) {
      // If selecting custom theme but no custom color is set, keep current theme
      return;
    }

    _selectedThemeIndex = selectedThemeIndex;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedThemeIndex', selectedThemeIndex);

    if (selectedThemeIndex == customThemeIndex) {
      if (_customThemeColor != null) {
        _applyCustomTheme(_customThemeColor!);
      }
    } else {
      if (_currentThemeMode == ThemeMode.system) {
        final brightness = WidgetsBinding.instance.window.platformBrightness;
        _currentTheme = AppThemes.themes[selectedThemeIndex * 2 + (brightness == Brightness.dark ? 1 : 0)];
      } else {
        _currentTheme = AppThemes.themes[selectedThemeIndex * 2 + (_currentThemeMode == ThemeMode.dark ? 1 : 0)];
      }
    }
    notifyListeners();
  }

  // Set and apply custom theme
  void setCustomTheme(Color color) async {
    _customThemeColor = color;
    _selectedThemeIndex = customThemeIndex;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('customThemeColor', color.value);
    await prefs.setInt('selectedThemeIndex', customThemeIndex);

    _applyCustomTheme(color);
  }

  // Apply custom theme based on color
  void _applyCustomTheme(Color color) {
    final ColorScheme lightScheme = ColorScheme.fromSeed(
      seedColor: color,
      brightness: Brightness.light,
    );

    final ColorScheme darkScheme = ColorScheme.fromSeed(
      seedColor: color,
      brightness: Brightness.dark,
    );

    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: lightScheme,
      // Add other theme customizations here
    );

    final ThemeData darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: darkScheme,
      // Add other theme customizations here
    );

    if (_currentThemeMode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.window.platformBrightness;
      _currentTheme = brightness == Brightness.dark ? darkTheme : lightTheme;
    } else {
      _currentTheme = _currentThemeMode == ThemeMode.dark ? darkTheme : lightTheme;
    }
    notifyListeners();
  }

  // Load saved preferences
  Future<void> loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Load theme mode
    String themeModeString = prefs.getString('themeMode') ?? ThemeMode.system.toString();
    _currentThemeMode = ThemeMode.values.firstWhere((e) => e.toString() == themeModeString);

    // Load selected theme index
    _selectedThemeIndex = prefs.getInt('selectedThemeIndex') ?? 0;

    // Load custom theme if it exists
    if (_selectedThemeIndex == customThemeIndex) {
      final colorValue = prefs.getInt('customThemeColor');
      if (colorValue != null) {
        _customThemeColor = Color(colorValue);
        _applyCustomTheme(_customThemeColor!);
        return;
      }
    }

    updateThemeBasedOnMode(_selectedThemeIndex);
  }

  // Listen to system theme changes
  void handleSystemThemeChange() {
    if (_currentThemeMode == ThemeMode.system) {
      if (isCustomTheme && _customThemeColor != null) {
        _applyCustomTheme(_customThemeColor!);
      } else {
        updateThemeBasedOnMode(_selectedThemeIndex);
      }
    }
  }
}