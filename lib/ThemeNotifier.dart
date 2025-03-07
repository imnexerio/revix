import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:retracker/theme_data.dart';

import 'CustomThemeGenerator.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeData _currentTheme;
  ThemeMode _currentThemeMode;
  int _selectedThemeIndex;
  Color? _customThemeColor;
  static const int customThemeIndex = -1; // Special index for custom theme

  // Constructor
  ThemeNotifier(this._currentTheme, this._currentThemeMode) : _selectedThemeIndex = 0 {
    fetchCustomTheme();
  }

  // Getters
  ThemeData get currentTheme => _currentTheme;
  ThemeMode get currentThemeMode => _currentThemeMode;
  int get selectedThemeIndex => _selectedThemeIndex;
  Color? get customThemeColor => _customThemeColor;
  bool get isCustomTheme => _selectedThemeIndex == customThemeIndex;

  // Change theme mode (light/dark/system)
  void changeThemeMode(ThemeMode newMode) async {
    _currentThemeMode = newMode;
    String uid = FirebaseAuth.instance.currentUser!.uid;
    DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data/theme_data');
    await databaseRef.update({'themeMode': newMode.toString()});

    // Update theme based on new mode
    if (isCustomTheme && _customThemeColor != null) {
      _applyCustomTheme(_customThemeColor!);
    } else {
      updateThemeBasedOnMode(_selectedThemeIndex);
    }
    notifyListeners();
  }

  // Fetch custom theme from Firebase
  Future<void> fetchCustomTheme() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // User is not logged in, use default theme
      _currentThemeMode = ThemeMode.system;
      _selectedThemeIndex = 0;
      updateThemeBasedOnMode(_selectedThemeIndex);
      notifyListeners();
      return;
    }

    String uid = user.uid;
    try {
      DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data/theme_data');
      DataSnapshot snapshot = await databaseRef.get();
      if (snapshot.exists) {
        Map<String, dynamic> themeData = Map<String, dynamic>.from(snapshot.value as Map);
        int colorValue = themeData['customThemeColor'];
        int selectedThemeIndex = themeData['selectedThemeIndex'];
        String themeModeString = themeData['themeMode'] ?? ThemeMode.system.toString();
        _customThemeColor = Color(colorValue);
        _selectedThemeIndex = selectedThemeIndex;
        _currentThemeMode = ThemeMode.values.firstWhere((e) => e.toString() == themeModeString);
        if (_selectedThemeIndex == customThemeIndex) {
          _applyCustomTheme(_customThemeColor!);
        } else {
          updateThemeBasedOnMode(_selectedThemeIndex);
        }
        notifyListeners();
      } else {
        // Use default theme if no data exists
        _currentThemeMode = ThemeMode.system;
        _selectedThemeIndex = 0;
        updateThemeBasedOnMode(_selectedThemeIndex);
      }
    } catch (e) {
      // print('Error retrieving theme data: $e');
      // Use default theme if an error occurs
      _currentThemeMode = ThemeMode.system;
      _selectedThemeIndex = 0;
      updateThemeBasedOnMode(_selectedThemeIndex);
      notifyListeners();
    }
  }
  // Set and apply custom theme, and upload to Firebase
  void setCustomTheme(Color color) async {
    _customThemeColor = color;
    _selectedThemeIndex = customThemeIndex;

    String uid = FirebaseAuth.instance.currentUser!.uid;
    DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data/theme_data');
    await databaseRef.set({
      'customThemeColor': color.value,
      'selectedThemeIndex': customThemeIndex,
      'themeMode': _currentThemeMode.toString(),
    });

    _applyCustomTheme(color);
    notifyListeners();
  }

  // Update theme based on selected index and current mode
  void updateThemeBasedOnMode(int selectedThemeIndex) async {
    if (selectedThemeIndex == customThemeIndex && _customThemeColor == null) {
      // If selecting custom theme but no custom color is set, keep current theme
      return;
    }

    _selectedThemeIndex = selectedThemeIndex;

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // User is not logged in, use default theme
      if (_currentThemeMode == ThemeMode.system) {
        final brightness = WidgetsBinding.instance.window.platformBrightness;
        _currentTheme = AppThemes.themes[selectedThemeIndex * 2 + (brightness == Brightness.dark ? 1 : 0)];
      } else {
        _currentTheme = AppThemes.themes[selectedThemeIndex * 2 + (_currentThemeMode == ThemeMode.dark ? 1 : 0)];
      }
      notifyListeners();
      return;
    }

    String uid = user.uid;
    DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data/theme_data');
    await databaseRef.update({'selectedThemeIndex': selectedThemeIndex});

    if (selectedThemeIndex == customThemeIndex) {
      if (_customThemeColor != null) {
        _applyCustomTheme(_customThemeColor!);
      }
    } else {
      // Determine which theme to use based on current theme mode
      if (_currentThemeMode == ThemeMode.system) {
        final brightness = WidgetsBinding.instance.window.platformBrightness;
        _currentTheme = AppThemes.themes[selectedThemeIndex * 2 + (brightness == Brightness.dark ? 1 : 0)];
      } else {
        _currentTheme = AppThemes.themes[selectedThemeIndex * 2 + (_currentThemeMode == ThemeMode.dark ? 1 : 0)];
      }
    }

    notifyListeners();
  }

  // Apply custom theme based on color
  void _applyCustomTheme(Color color) {
    // Generate light and dark themes using the CustomThemeGenerator
    final ThemeData lightTheme = CustomThemeGenerator.generateLightTheme(color);
    final ThemeData darkTheme = CustomThemeGenerator.generateDarkTheme(color);

    // Determine which theme to apply based on current theme mode
    if (_currentThemeMode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.window.platformBrightness;
      _currentTheme = brightness == Brightness.dark ? darkTheme : lightTheme;
    } else {
      _currentTheme = _currentThemeMode == ThemeMode.dark ? darkTheme : lightTheme;
    }
    notifyListeners();
  }
}