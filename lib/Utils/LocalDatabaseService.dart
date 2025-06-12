import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides simple local database functionality using Hive for guest mode.
/// This service handles data storage and retrieval in Firebase-compatible structure.
class LocalDatabaseService {
  static const String _usersBoxName = 'users_data';
  static const String _errorLogBoxName = 'error_logs';
  
  static Box<Map>? _usersBox;
  static Box<String>? _errorLogBox;
  
  // Current user ID for guest mode
  static String _currentUserId = 'guest_user_local';
  
  // Stream controller for raw data changes - simplified to just notify when data changes
  final StreamController<dynamic> _rawDataController =
      StreamController<dynamic>.broadcast();

  // Stream getter for raw data
  Stream<dynamic> get rawDataStream => _rawDataController.stream;
  
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  
  factory LocalDatabaseService() {
    return _instance;
  }
  
  LocalDatabaseService._internal();
  
  /// Sets the current user ID for local storage
  static void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }
  
  /// Gets the current user ID
  static String getCurrentUserId() {
    return _currentUserId;
  }
  
  /// Gets the complete users data structure
  Future<Map<String, dynamic>> getUsersData() async {
    try {
      return (_usersBox!.get('users', defaultValue: {}) ?? {}).cast<String, dynamic>();
    } catch (e) {
      _logError('Error getting users data: $e');
      return {};
    }
  }
  
  /// Gets data for the current user
  Future<Map<String, dynamic>> getCurrentUserData() async {
    try {
      final usersData = await getUsersData();
      return (usersData[_currentUserId] ?? {}).cast<String, dynamic>();
    } catch (e) {
      _logError('Error getting current user data: $e');
      return {};
    }
  }    /// Initializes all Hive boxes needed for the application
  static Future<void> initialize() async {
    try {
      if (!Hive.isBoxOpen(_usersBoxName)) {
        _usersBox = await Hive.openBox<Map>(_usersBoxName);
      }
      if (!Hive.isBoxOpen(_errorLogBoxName)) {
        _errorLogBox = await Hive.openBox<String>(_errorLogBoxName);
      }
    } catch (e) {
      _logError('Error initializing Hive boxes: $e');
      await _recoverFromHiveError();
    }
  }
  /// Attempts to recover from a Hive error by clearing corrupted data
  static Future<void> _recoverFromHiveError() async {
    try {
      await Hive.close();
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hive_recovery_needed', true);
      
      _usersBox = await Hive.openBox<Map>(_usersBoxName);
      _errorLogBox = await Hive.openBox<String>(_errorLogBoxName);
      
      _logError('Recovered from Hive error');
    } catch (e) {
      _logError('Critical Hive error - unable to recover: $e');
    }
  }

  /// Logs an error to the error log box
  static Future<void> _logError(String error) async {
    try {
      if (_errorLogBox != null && _errorLogBox!.isOpen) {
        final timestamp = DateTime.now().toIso8601String();
        await _errorLogBox!.put(timestamp, error);
        
        if (_errorLogBox!.length > 100) {
          final oldestKey = _errorLogBox!.keys.first;
          await _errorLogBox!.delete(oldestKey);
        }
      }
      
      debugPrint('LocalDatabaseService Error: $error');
    } catch (e) {
      debugPrint('Error logging error: $e');
      debugPrint('Original error: $error');
    }
  }    /// Initializes the database with default data for new guest users
  Future<void> initializeWithDefaultData() async {
    try {
      await initialize();
      
      final usersData = await getUsersData();
      
      // Initialize with default profile data if user doesn't exist
      if (usersData[_currentUserId] == null) {
        usersData[_currentUserId] = {
          'profile_data': {
            'email': 'guest@revix.local',
            'name': 'Guest User',
            'createdAt': DateTime.now().toIso8601String(),
            'custom_trackingType': ['Lectures', 'Others'],
            'custom_frequencies': {
              'Default': [1, 4, 7, 15, 30, 60],
              'Priority': [1, 3, 4, 5, 7, 15, 25, 30],
            },
            'theme_data': {
              'customThemeColor': null,
              'selectedThemeIndex': 0,
              'themeMode': 'ThemeMode.system',
            },
            'home_page': {
              'selectedTrackingTypes': {},
              'completionTargets': {},
            }
          },
          'user_data': {}
        };
        
        await _usersBox!.put('users', usersData);
      }

      // Notify listeners of the initial data
      _notifyDataChange();
    } catch (e) {
      _logError('Error initializing default data: $e');
      // Create basic empty data structures if we couldn't initialize properly
      try {
        final usersData = await getUsersData();
        if (usersData[_currentUserId] == null) {
          usersData[_currentUserId] = {
            'profile_data': {
              'name': 'Guest User',
              'theme_data': {'themeMode': 'ThemeMode.system'},
            },
            'user_data': {}
          };
          await _usersBox!.put('users', usersData);
        }
        
        _notifyDataChange();
      } catch (fallbackError) {
        _logError('Critical error in fallback initialization: $fallbackError');
      }
    }
  }
  /// Notifies listeners when data changes
  void _notifyDataChange() async {
    try {
      final userData = await getCurrentUserData();
      final rawData = userData['user_data'] ?? {};
      _rawDataController.add(rawData);
    } catch (e) {
      _logError('Error notifying data change: $e');
      _rawDataController.add({});
    }
  }  // CRUD operations for records - Firebase-compatible structure
  Future<bool> saveRecord(String category, String subCategory, String lectureNo, Map<String, dynamic> recordData) async {
    try {
      final usersData = await getUsersData();
      final userData = (usersData[_currentUserId] ?? {}).cast<String, dynamic>();
      final currentData = (userData['user_data'] ?? {}).cast<String, dynamic>();
      
      if (currentData[category] == null) {
        currentData[category] = <String, dynamic>{};
      }
      if (currentData[category][subCategory] == null) {
        currentData[category][subCategory] = <String, dynamic>{};
      }
      
      currentData[category][subCategory][lectureNo] = recordData;
      
      userData['user_data'] = currentData;
      usersData[_currentUserId] = userData;
      
      await _usersBox!.put('users', usersData);
      _notifyDataChange();
      return true;
    } catch (e) {
      _logError('Error saving record: $e');
      return false;
    }
  }

  Future<bool> updateRecord(String category, String subCategory, String lectureNo, Map<String, dynamic> updates) async {
    try {
      final usersData = await getUsersData();
      final userData = (usersData[_currentUserId] ?? {}).cast<String, dynamic>();
      final currentData = (userData['user_data'] ?? {}).cast<String, dynamic>();
      
      if (currentData[category]?[subCategory]?[lectureNo] != null) {
        final existingRecord = Map<String, dynamic>.from(currentData[category][subCategory][lectureNo]);
        existingRecord.addAll(updates);
        currentData[category][subCategory][lectureNo] = existingRecord;
        
        userData['user_data'] = currentData;
        usersData[_currentUserId] = userData;
        
        await _usersBox!.put('users', usersData);
        _notifyDataChange();
        return true;
      }
      return false;
    } catch (e) {
      _logError('Error updating record: $e');
      return false;
    }
  }

  Future<bool> deleteRecord(String category, String subCategory, String lectureNo) async {
    try {
      final usersData = await getUsersData();
      final userData = (usersData[_currentUserId] ?? {}).cast<String, dynamic>();
      final currentData = (userData['user_data'] ?? {}).cast<String, dynamic>();
      
      if (currentData[category]?[subCategory]?[lectureNo] != null) {
        currentData[category][subCategory].remove(lectureNo);
        
        // Clean up empty sub categories and subjects
        if (currentData[category][subCategory].isEmpty) {
          currentData[category].remove(subCategory);
        }
        if (currentData[category].isEmpty) {
          currentData.remove(category);
        }
        
        userData['user_data'] = currentData;
        usersData[_currentUserId] = userData;
        
        await _usersBox!.put('users', usersData);
        _notifyDataChange();
        return true;
      }
      return false;
    } catch (e) {
      _logError('Error deleting record: $e');
      return false;
    }
  }

    // Profile data operations - Firebase-compatible structure
  Future<bool> saveProfileData(String key, dynamic value) async {
    try {
      final usersData = await getUsersData();
      final userData = (usersData[_currentUserId] ?? {}).cast<String, dynamic>();
      final currentProfile = (userData['profile_data'] ?? {}).cast<String, dynamic>();
      
      // Handle nested keys with dot notation
      if (key.contains('.')) {
        final keys = key.split('.');
        dynamic current = currentProfile;
        
        for (int i = 0; i < keys.length - 1; i++) {
          if (current[keys[i]] == null) {
            current[keys[i]] = <String, dynamic>{};
          }
          current = current[keys[i]];
        }
        current[keys.last] = value;
      } else {
        currentProfile[key] = value;
      }
      
      userData['profile_data'] = currentProfile;
      usersData[_currentUserId] = userData;
      
      await _usersBox!.put('users', usersData);
      return true;
    } catch (e) {
      _logError('Error saving profile data: $e');
      return false;
    }
  }

  Future<bool> updateProfileData(String key, dynamic value) async {
    try {
      final usersData = await getUsersData();
      final userData = (usersData[_currentUserId] ?? {}).cast<String, dynamic>();
      final profile = (userData['profile_data'] ?? {}).cast<String, dynamic>();
      
      if (key.contains('.')) {
        final keys = key.split('.');
        Map<String, dynamic> current = profile;
        
        for (int i = 0; i < keys.length - 1; i++) {
          final k = keys[i];
          if (!current.containsKey(k) || current[k] is! Map) {
            current[k] = <String, dynamic>{};
          }
          current = current[k] as Map<String, dynamic>;
        }
        current[keys.last] = value;
      } else {
        profile[key] = value;
      }
      
      userData['profile_data'] = profile;
      usersData[_currentUserId] = userData;
      
      await _usersBox!.put('users', usersData);
      return true;
    } catch (e) {
      _logError('Error updating profile data: $e');
      return false;
    }
  }

  Future<dynamic> getProfileData(String key, {dynamic defaultValue}) async {
    try {
      final userData = await getCurrentUserData();
      final profile = (userData['profile_data'] ?? {}).cast<String, dynamic>();
      
      if (key.contains('.')) {
        final keys = key.split('.');
        dynamic current = profile;
        
        for (final k in keys) {
          if (current is Map && current.containsKey(k)) {
            current = current[k];
          } else {
            return defaultValue;
          }
        }
        return current;
      } else {
        return profile[key] ?? defaultValue;
      }
    } catch (e) {
      _logError('Error getting profile data: $e');
      return defaultValue;
    }
  }

  Future<Map<String, dynamic>> getAllProfileData() async {
    try {
      final userData = await getCurrentUserData();
      return (userData['profile_data'] ?? {}).cast<String, dynamic>();
    } catch (e) {
      _logError('Error getting all profile data: $e');
      return {};
    }
  }
    // Raw data access for UnifiedDatabaseService compatibility
  Future<dynamic> getRawData() async {
    try {
      final userData = await getCurrentUserData();
      return userData['user_data'] ?? {};
    } catch (e) {
      _logError('Error getting raw data: $e');
      return {};
    }
  }


  /// Imports Firebase data structure directly into local storage
  Future<bool> importFirebaseData(Map<String, dynamic> firebaseData) async {
    try {
      await _usersBox!.put('users', firebaseData);
      _notifyDataChange();
      return true;
    } catch (e) {
      _logError('Error importing Firebase data: $e');
      return false;
    }
  }

  /// Sets data for a specific user (useful for migrating from Firebase)
  Future<bool> setUserData(String userId, Map<String, dynamic> userData) async {
    try {
      final usersData = await getUsersData();
      usersData[userId] = userData;
      await _usersBox!.put('users', usersData);
      _notifyDataChange();
      return true;
    } catch (e) {
      _logError('Error setting user data: $e');
      return false;
    }
  }

  // Utility methods
  Future<void> clearAllData() async {
    try {
      final usersData = await getUsersData();
      usersData.remove(_currentUserId);
      await _usersBox!.put('users', usersData);
      _notifyDataChange();
    } catch (e) {
      _logError('Error clearing all data: $e');
    }
  }

  Future<void> clearAllUsersData() async {
    try {
      await _usersBox!.clear();
      _notifyDataChange();
    } catch (e) {
      _logError('Error clearing all users data: $e');
    }
  }

  Future<void> forceDataReprocessing() async {
    // Simply notify listeners of current data - processing is handled elsewhere
    _notifyDataChange();
  }

  void stopListening() {
    // Local database doesn't need to stop listening as it's not streaming from external source
  }  
  void dispose() {
    _rawDataController.close();
  }

  // Get a specific record
  Future<Map<String, dynamic>?> getRecord(String category, String subCategory, String lectureNo) async {
    try {
      final usersData = await getUsersData();
      final userData = (usersData[_currentUserId] ?? {}).cast<String, dynamic>();
      final currentData = (userData['user_data'] ?? {}).cast<String, dynamic>();
      
      if (currentData[category] != null && 
          currentData[category][subCategory] != null && 
          currentData[category][subCategory][lectureNo] != null) {
        final record = currentData[category][subCategory][lectureNo];
        if (record is Map) {
          return Map<String, dynamic>.from(record);
        }
      }
      
      return null;
    } catch (e) {
      _logError('Error getting record: $e');
      return null;
    }
  }
}
