import 'dart:async';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'GuestAuthService.dart';

class HiveService {
  static const String _boxName = 'revix_settings';
  static Box? _box;

  // Initialize Hive and open the box
  static Future<void> initialize() async {
    if (_box != null && _box!.isOpen) {
      return;
    }
    
    // Open the main settings box
    _box = await Hive.openBox(_boxName);
  }

  // Get a value from the box
  static Future<dynamic> getValue(String key, {dynamic defaultValue}) async {
    await initialize();
    return _box!.get(key, defaultValue: defaultValue);
  }

  // Set a value in the box
  static Future<void> setValue(String key, dynamic value) async {
    await initialize();
    await _box!.put(key, value);
  }

  // Delete a value from the box
  static Future<void> deleteValue(String key) async {
    await initialize();
    await _box!.delete(key);
  }

  // Clear all values from the box
  static Future<void> clearAll() async {
    await initialize();
    await _box!.clear();
  }
  
  // Check if in guest mode and update SharedPreferences accordingly
  static Future<void> syncGuestModeStatus() async {
    await initialize();
    
    bool isGuestMode = await GuestAuthService.isGuestMode();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    if (isGuestMode) {
      // Make sure guest mode settings are consistent
      await prefs.setBool('isLoggedIn', true);
      await setValue('isGuestMode', true);
    } else {
      await setValue('isGuestMode', false);
    }
  }
  
  // Close box when app is closing
  static Future<void> dispose() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
  }
}
