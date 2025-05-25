import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:retracker/theme_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'CustomThemeGenerator.dart';
import 'Utils/GuestAuthService.dart';
import 'Utils/LocalDatabaseService.dart';

class ThemeNotifier extends ChangeNotifier with WidgetsBindingObserver {
  // Theme management class that supports both Firebase (for authenticated users) 
  // and local storage (for guest users) while maintaining existing functionality
  ThemeData _currentTheme;
  ThemeMode _currentThemeMode;
  int _selectedThemeIndex;
  Color? _customThemeColor;
  SharedPreferences? _prefs;
  StreamSubscription? _connectivitySubscription;
  bool _isOnline = false;
  static const int customThemeIndex = -1; // Special index for custom theme

  // Preference keys - make them public so main.dart can use them
  static const String prefThemeMode = 'theme_mode';
  static const String prefThemeIndex = 'theme_index';
  static const String prefCustomThemeColor = 'custom_theme_color';

  // Private references to the same constants for internal use
  static const String _prefThemeMode = prefThemeMode;
  static const String _prefThemeIndex = prefThemeIndex;
  static const String _prefCustomThemeColor = prefCustomThemeColor;

  // Constructor
  ThemeNotifier(this._currentTheme, this._currentThemeMode)
      : _selectedThemeIndex = 0 {
    // Register as an observer to listen for system theme changes
    WidgetsBinding.instance.addObserver(this);
    _initPreferences();
    _setupConnectivityListener();
  }

  // Set initial values from cached data (called from main.dart)
  void setInitialValues(int themeIndex, Color? customColor) {
    _selectedThemeIndex = themeIndex;
    _customThemeColor = customColor;
  }
  // Initialize SharedPreferences and prepare for remote theme fetch
  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();

    // We don't need to load theme from SharedPreferences here
    // since we already did that in main.dart and passed it to the constructor

    // Check if user is in guest mode
    bool isGuestMode = await GuestAuthService.isGuestMode();
    if (isGuestMode) {
      // For guest users, fetch theme from local storage
      fetchRemoteTheme();
    } else {
      // For authenticated users, check connectivity and fetch remote theme if online
      final connectivityResult = await Connectivity().checkConnectivity();
      _isOnline = connectivityResult.any((result) => result != ConnectivityResult.none);
      if (_isOnline) {
        fetchRemoteTheme();
      }
    }
  }
  // Setup connectivity listener to detect when internet becomes available
  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
        List<ConnectivityResult> results) async {
      // Only handle connectivity changes for authenticated users
      bool isGuestMode = await GuestAuthService.isGuestMode();
      if (isGuestMode) return;

      final wasOffline = !_isOnline;
      // Check if any connection is available
      _isOnline = results.any((result) => result != ConnectivityResult.none);

      // If we just came online, try to fetch the remote theme
      if (wasOffline && _isOnline) {
        fetchRemoteTheme();
      }
    });
  }

  // Load theme from local storage - only used when needed
  // (not for initial app load, which is handled in main.dart)
  Future<void> _loadLocalTheme() async {
    if (_prefs == null) return;

    // Load theme mode
    final themeModeString = _prefs!.getString(_prefThemeMode);
    if (themeModeString != null) {
      _currentThemeMode = ThemeMode.values.firstWhere(
              (e) => e.toString() == themeModeString,
          orElse: () => ThemeMode.system
      );
    }

    // Load theme index
    _selectedThemeIndex = _prefs!.getInt(_prefThemeIndex) ?? 0;

    // Load custom theme color if applicable
    final customColorValue = _prefs!.getInt(_prefCustomThemeColor);
    if (customColorValue != null) {
      _customThemeColor = Color(customColorValue);
    }

    // Apply the loaded theme
    if (_selectedThemeIndex == customThemeIndex && _customThemeColor != null) {
      _applyCustomTheme(_customThemeColor!);
    } else {
      updateThemeBasedOnMode(_selectedThemeIndex);
    }

    notifyListeners();
  }

  // Save theme to local storage
  Future<void> _saveThemeToLocal() async {
    if (_prefs == null) return;

    await _prefs!.setString(_prefThemeMode, _currentThemeMode.toString());
    await _prefs!.setInt(_prefThemeIndex, _selectedThemeIndex);

    if (_customThemeColor != null) {
      await _prefs!.setInt(_prefCustomThemeColor, _customThemeColor!.value);
    }
  }

  // Override didChangePlatformBrightness to detect system theme changes
  @override
  void didChangePlatformBrightness() {
    if (_currentThemeMode == ThemeMode.system) {
      // Update theme based on new system brightness
      if (isCustomTheme && _customThemeColor != null) {
        _applyCustomTheme(_customThemeColor!);
      } else {
        _updateThemeBasedOnSystemBrightness();
      }
      notifyListeners();
    }
    super.didChangePlatformBrightness();
  }

  // Cleanup when the notifier is disposed
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // Helper method to update theme based on system brightness
  void _updateThemeBasedOnSystemBrightness() {
    // For custom theme, we need to handle it separately
    if (_selectedThemeIndex == customThemeIndex && _customThemeColor != null) {
      _applyCustomTheme(_customThemeColor!);
      return;
    }

    // For standard themes
    final brightness = WidgetsBinding.instance.window.platformBrightness;
    _currentTheme = AppThemes.themes[_selectedThemeIndex * 2 +
        (brightness == Brightness.dark ? 1 : 0)];
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

    // Update theme based on new mode
    if (isCustomTheme && _customThemeColor != null) {
      _applyCustomTheme(_customThemeColor!);
    } else {
      updateThemeBasedOnMode(_selectedThemeIndex);
    }

    // Save locally first for immediate effect
    await _saveThemeToLocal();
    notifyListeners();

    // Then save to Firebase if online (for authenticated users) or to local storage (for guest users)
    _saveThemeToFirebase();
  }
  // Save current theme settings to Firebase if logged in and online, or to local storage for guest users
  Future<void> _saveThemeToFirebase() async {
    try {
      // Check if user is in guest mode
      if (await GuestAuthService.isGuestMode()) {
        // Use local database for guest users
        final localDb = LocalDatabaseService();

        // Save theme data to local database
        await localDb.saveProfileData('theme_data.customThemeColor', _customThemeColor?.value);
        await localDb.saveProfileData('theme_data.selectedThemeIndex', _selectedThemeIndex);
        await localDb.saveProfileData('theme_data.themeMode', _currentThemeMode.toString());

        return;
      }

      // Original Firebase logic for authenticated users
      if (!_isOnline) return;

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String uid = user.uid;
      DatabaseReference databaseRef = FirebaseDatabase.instance.ref(
          'users/$uid/profile_data/theme_data');

      await databaseRef.set({
        'customThemeColor': _customThemeColor?.value,
        'selectedThemeIndex': _selectedThemeIndex,
        'themeMode': _currentThemeMode.toString(),
      });
    } catch (e) {
      // Silently fail - we've already updated locally
      print('Error saving theme: $e');
    }
  }
  // Fetch theme from Firebase (called when online) or from local storage for guest users
  Future<void> fetchRemoteTheme() async {
    // Add a small delay to avoid slowing down the initial app render
    // This ensures the app launches quickly with cached theme
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // Check if user is in guest mode
      if (await GuestAuthService.isGuestMode()) {
        // Use local database for guest users
        final localDb = LocalDatabaseService();

        // Get theme data from local database
        final remoteColorValue = await localDb.getProfileData('theme_data.customThemeColor');
        final remoteThemeIndex = await localDb.getProfileData('theme_data.selectedThemeIndex');
        final remoteThemeModeString = await localDb.getProfileData('theme_data.themeMode', defaultValue: ThemeMode.system.toString());

        bool hasChanged = false;

        // Check if theme index has changed
        if (remoteThemeIndex != null && remoteThemeIndex != _selectedThemeIndex) {
          _selectedThemeIndex = remoteThemeIndex;
          hasChanged = true;
        }

        // Check if theme mode has changed
        final remoteThemeMode = ThemeMode.values.firstWhere(
                (e) => e.toString() == remoteThemeModeString,
            orElse: () => ThemeMode.system
        );
        if (remoteThemeMode != _currentThemeMode) {
          _currentThemeMode = remoteThemeMode;
          hasChanged = true;
        }

        // Check if custom color has changed
        if (remoteColorValue != null &&
            (_customThemeColor == null ||
                remoteColorValue != _customThemeColor!.value)) {
          _customThemeColor = Color(remoteColorValue);
          hasChanged = true;
        }

        // If anything has changed, apply the new theme and save locally
        if (hasChanged) {
          if (_selectedThemeIndex == customThemeIndex &&
              _customThemeColor != null) {
            _applyCustomTheme(_customThemeColor!);
          } else {
            updateThemeBasedOnMode(_selectedThemeIndex);
          }
          await _saveThemeToLocal();
          notifyListeners();
        }
        return;
      }

      // Original Firebase logic for authenticated users
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String uid = user.uid;
      DatabaseReference databaseRef = FirebaseDatabase.instance.ref(
          'users/$uid/profile_data/theme_data');
      DataSnapshot snapshot = await databaseRef.get();

      if (snapshot.exists) {
        Map<String, dynamic> themeData = Map<String, dynamic>.from(
            snapshot.value as Map);

        // Compare with local data to see if we need to update
        final remoteColorValue = themeData['customThemeColor'];
        final remoteThemeIndex = themeData['selectedThemeIndex'];
        final remoteThemeModeString = themeData['themeMode'] ??
            ThemeMode.system.toString();

        bool hasChanged = false;

        // Check if theme index has changed
        if (remoteThemeIndex != _selectedThemeIndex) {
          _selectedThemeIndex = remoteThemeIndex;
          hasChanged = true;
        }

        // Check if theme mode has changed
        final remoteThemeMode = ThemeMode.values.firstWhere(
                (e) => e.toString() == remoteThemeModeString,
            orElse: () => ThemeMode.system
        );
        if (remoteThemeMode != _currentThemeMode) {
          _currentThemeMode = remoteThemeMode;
          hasChanged = true;
        }

        // Check if custom color has changed
        if (remoteColorValue != null &&
            (_customThemeColor == null ||
                remoteColorValue != _customThemeColor!.value)) {
          _customThemeColor = Color(remoteColorValue);
          hasChanged = true;
        }

        // If anything has changed, apply the new theme and save locally
        if (hasChanged) {
          if (_selectedThemeIndex == customThemeIndex &&
              _customThemeColor != null) {
            _applyCustomTheme(_customThemeColor!);
          } else {
            updateThemeBasedOnMode(_selectedThemeIndex);
          }
          await _saveThemeToLocal();
          notifyListeners();
        }
      }
    } catch (e) {
      // Silently fail - we're still using the locally cached theme
      print('Error retrieving theme data: $e');
    }
  }
  // Set and apply custom theme, save locally first, then to Firebase/local storage depending on user type
  void setCustomTheme(Color color) async {
    _customThemeColor = color;
    _selectedThemeIndex = customThemeIndex;

    // Apply the theme immediately
    _applyCustomTheme(color);

    // Save locally first for immediate effect
    await _saveThemeToLocal();
    notifyListeners();

    // Then save to Firebase if online (for authenticated users) or to local storage (for guest users)
    _saveThemeToFirebase();
  }
  // Update theme based on selected index and current mode
  void updateThemeBasedOnMode(int selectedThemeIndex) async {
    if (selectedThemeIndex == customThemeIndex && _customThemeColor == null) {
      // If selecting custom theme but no custom color is set, keep current theme
      return;
    }

    _selectedThemeIndex = selectedThemeIndex;

    // Determine which theme to use based on current theme mode
    if (_currentThemeMode == ThemeMode.system) {
      _updateThemeBasedOnSystemBrightness();
    } else {
      _currentTheme = AppThemes.themes[selectedThemeIndex * 2 +
          (_currentThemeMode == ThemeMode.dark ? 1 : 0)];
    }

    // Save locally first for immediate effect
    await _saveThemeToLocal();
    notifyListeners();

    // Then save to Firebase if logged in and online (for authenticated users) or to local storage (for guest users)
    _saveThemeToFirebase();
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
      _currentTheme =
      _currentThemeMode == ThemeMode.dark ? darkTheme : lightTheme;
    }
  }
}