import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides simple local database functionality using Hive for guest mode.
/// This service only handles data storage and retrieval - data processing is handled by UnifiedDatabaseService.
class LocalDatabaseService {
  static const String _recordsBoxName = 'user_records';
  static const String _profileBoxName = 'user_profile';
  static const String _errorLogBoxName = 'error_logs';
  
  static Box<Map>? _recordsBox;
  static Box<Map>? _profileBox;
  static Box<String>? _errorLogBox;
  
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
  /// Initializes all Hive boxes needed for the application
  static Future<void> initialize() async {
    try {
      if (!Hive.isBoxOpen(_recordsBoxName)) {
        _recordsBox = await Hive.openBox<Map>(_recordsBoxName);
      }
      if (!Hive.isBoxOpen(_profileBoxName)) {
        _profileBox = await Hive.openBox<Map>(_profileBoxName);
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
      
      _recordsBox = await Hive.openBox<Map>(_recordsBoxName);
      _profileBox = await Hive.openBox<Map>(_profileBoxName);
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
  }  
  /// Initializes the database with default data for new guest users
  Future<void> initializeWithDefaultData() async {
    try {
      await initialize();
      
      // Initialize with default profile data if guest mode is new
      if (_profileBox!.isEmpty) {
        await _profileBox!.put('profile_data', {
          'email': 'guest@retracker.local',
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
        });
      }

      // Initialize empty records if none exist
      if (_recordsBox!.isEmpty) {
        await _recordsBox!.put('user_data', {});
      }

      // Notify listeners of the initial data
      _notifyDataChange();
    } catch (e) {
      _logError('Error initializing default data: $e');
      // Create basic empty data structures if we couldn't initialize properly
      try {
        if (_profileBox != null && _profileBox!.isOpen && _profileBox!.isEmpty) {
          await _profileBox!.put('profile_data', {
            'name': 'Guest User',
            'theme_data': {'themeMode': 'ThemeMode.system'},
          });
        }
        
        if (_recordsBox != null && _recordsBox!.isOpen && _recordsBox!.isEmpty) {
          await _recordsBox!.put('user_data', {});
        }
        
        _notifyDataChange();
      } catch (fallbackError) {
        _logError('Critical error in fallback initialization: $fallbackError');
      }
    }
  }

  /// Notifies listeners when data changes
  void _notifyDataChange() {
    final rawData = _recordsBox!.get('user_data', defaultValue: {});
    _rawDataController.add(rawData);
  }  
  // CRUD operations for records - simple data storage without processing
  Future<bool> saveRecord(String subject, String subjectCode, String lectureNo, Map<String, dynamic> recordData) async {
    try {
      final currentData = (_recordsBox!.get('user_data', defaultValue: {}) ?? {}).cast<String, dynamic>();
      
      if (currentData[subject] == null) {
        currentData[subject] = <String, dynamic>{};
      }
      if (currentData[subject][subjectCode] == null) {
        currentData[subject][subjectCode] = <String, dynamic>{};
      }
      
      currentData[subject][subjectCode][lectureNo] = recordData;
      
      await _recordsBox!.put('user_data', currentData);
      _notifyDataChange();
      return true;
    } catch (e) {
      _logError('Error saving record: $e');
      return false;
    }
  }

  Future<bool> updateRecord(String subject, String subjectCode, String lectureNo, Map<String, dynamic> updates) async {
    try {
      final currentData = (_recordsBox!.get('user_data', defaultValue: {}) ?? {}).cast<String, dynamic>();
      
      if (currentData[subject]?[subjectCode]?[lectureNo] != null) {
        final existingRecord = Map<String, dynamic>.from(currentData[subject][subjectCode][lectureNo]);
        existingRecord.addAll(updates);
        currentData[subject][subjectCode][lectureNo] = existingRecord;
        
        await _recordsBox!.put('user_data', currentData);
        _notifyDataChange();
        return true;
      }
      return false;
    } catch (e) {
      _logError('Error updating record: $e');
      return false;
    }
  }

  Future<bool> deleteRecord(String subject, String subjectCode, String lectureNo) async {
    try {
      final currentData = (_recordsBox!.get('user_data', defaultValue: {}) ?? {}).cast<String, dynamic>();
      
      if (currentData[subject]?[subjectCode]?[lectureNo] != null) {
        currentData[subject][subjectCode].remove(lectureNo);
        
        // Clean up empty subject codes and subjects
        if (currentData[subject][subjectCode].isEmpty) {
          currentData[subject].remove(subjectCode);
        }
        if (currentData[subject].isEmpty) {
          currentData.remove(subject);
        }
        
        await _recordsBox!.put('user_data', currentData);
        _notifyDataChange();
        return true;
      }
      return false;
    } catch (e) {
      _logError('Error deleting record: $e');
      return false;
    }
  }
  
  // Profile data operations - simple key-value storage
  Future<bool> saveProfileData(String key, dynamic value) async {
    try {
      final currentProfile = (_profileBox!.get('profile_data', defaultValue: {}) ?? {}).cast<String, dynamic>();
      
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
      
      await _profileBox!.put('profile_data', currentProfile);
      return true;
    } catch (e) {
      _logError('Error saving profile data: $e');
      return false;
    }
  }

  Future<bool> updateProfileData(String key, dynamic value) async {
    try {
      final profile = (_profileBox!.get('profile_data', defaultValue: {}) ?? {}).cast<String, dynamic>();
      
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
      
      await _profileBox!.put('profile_data', profile);
      return true;
    } catch (e) {
      _logError('Error updating profile data: $e');
      return false;
    }
  }

  Future<dynamic> getProfileData(String key, {dynamic defaultValue}) async {
    try {
      final profile = (_profileBox!.get('profile_data', defaultValue: {}) ?? {}).cast<String, dynamic>();
      
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
      return (_profileBox!.get('profile_data', defaultValue: {}) ?? {}).cast<String, dynamic>();
    } catch (e) {
      _logError('Error getting all profile data: $e');
      return {};
    }
  }
  
  // Raw data access for UnifiedDatabaseService compatibility
  Future<dynamic> getRawData() async {
    try {
      return _recordsBox!.get('user_data', defaultValue: {});
    } catch (e) {
      _logError('Error getting raw data: $e');
      return {};
    }
  }

  // Utility methods
  Future<void> clearAllData() async {
    try {
      await _recordsBox!.clear();
      await _profileBox!.clear();
      _notifyDataChange();
    } catch (e) {
      _logError('Error clearing all data: $e');
    }
  }

  Future<void> forceDataReprocessing() async {
    // Simply notify listeners of current data - processing is handled elsewhere
    _notifyDataChange();
  }

  void stopListening() {
    // Local database doesn't need to stop listening as it's not streaming from external source
  }  void dispose() {
    _rawDataController.close();
  }
}
