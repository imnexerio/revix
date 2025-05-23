import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'GuestAuthService.dart';

/// Provides local database functionality using Hive for guest mode.
/// This service mimics the Firebase database structure for compatibility.
class LocalDatabaseService {
  static const String _recordsBoxName = 'user_records';
  static const String _profileBoxName = 'user_profile';
  static const String _subjectsBoxName = 'user_subjects';
  static const String _errorLogBoxName = 'error_logs';
  
  static Box<Map>? _recordsBox;
  static Box<Map>? _profileBox;
  static Box<Map>? _subjectsBox;
  static Box<String>? _errorLogBox;
  
  // Stream controllers for local data
  final StreamController<Map<String, List<Map<String, dynamic>>>> _categorizedRecordsController =
      StreamController<Map<String, List<Map<String, dynamic>>>>.broadcast();
  
  final StreamController<Map<String, dynamic>> _allRecordsController =
      StreamController<Map<String, dynamic>>.broadcast();
  
  final StreamController<Map<String, dynamic>> _subjectsController =
      StreamController<Map<String, dynamic>>.broadcast();
  
  final StreamController<dynamic> _rawDataController =
      StreamController<dynamic>.broadcast();

  // Cached data
  Map<String, dynamic>? _cachedSubjectsData;
  dynamic _cachedRawData;
  Map<String, List<Map<String, dynamic>>>? _cachedCategorizedData;

  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  
  factory LocalDatabaseService() {
    return _instance;
  }
  
  LocalDatabaseService._internal();

  // Streams
  Stream<Map<String, List<Map<String, dynamic>>>> get categorizedRecordsStream =>
      _categorizedRecordsController.stream;

  Stream<Map<String, dynamic>> get allRecordsStream =>
      _allRecordsController.stream;

  Stream<Map<String, dynamic>> get subjectsStream =>
      _subjectsController.stream;

  Stream<dynamic> get rawDataStream =>
      _rawDataController.stream;

  // Getters for cached data
  Map<String, dynamic>? get currentSubjectsData => _cachedSubjectsData;
  dynamic get currentRawData => _cachedRawData;
  Map<String, List<Map<String, dynamic>>>? get currentCategorizedData => _cachedCategorizedData;

  /// Initializes all Hive boxes needed for the application
  static Future<void> initialize() async {
    try {
      if (!Hive.isBoxOpen(_recordsBoxName)) {
        _recordsBox = await Hive.openBox<Map>(_recordsBoxName);
      }
      if (!Hive.isBoxOpen(_profileBoxName)) {
        _profileBox = await Hive.openBox<Map>(_profileBoxName);
      }
      if (!Hive.isBoxOpen(_subjectsBoxName)) {
        _subjectsBox = await Hive.openBox<Map>(_subjectsBoxName);
      }
      if (!Hive.isBoxOpen(_errorLogBoxName)) {
        _errorLogBox = await Hive.openBox<String>(_errorLogBoxName);
      }
    } catch (e) {
      _logError('Error initializing Hive boxes: $e');
      // If there's an error with Hive, try to recover by deleting and recreating the boxes
      await _recoverFromHiveError();
    }
  }

  /// Attempts to recover from a Hive error by clearing corrupted data
  static Future<void> _recoverFromHiveError() async {
    try {
      // Close any open boxes
      await Hive.close();
      
      // Try to clear any problematic box data using SharedPreferences as a fallback
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hive_recovery_needed', true);
      
      // Reopen boxes
      _recordsBox = await Hive.openBox<Map>(_recordsBoxName);
      _profileBox = await Hive.openBox<Map>(_profileBoxName);
      _subjectsBox = await Hive.openBox<Map>(_subjectsBoxName);
      _errorLogBox = await Hive.openBox<String>(_errorLogBoxName);
      
      // Log the recovery
      _logError('Recovered from Hive error');
    } catch (e) {
      // Critical failure - can't recover
      _logError('Critical Hive error - unable to recover: $e');
    }
  }

  /// Logs an error to the error log box
  static Future<void> _logError(String error) async {
    try {
      // Try to log to Hive if possible
      if (_errorLogBox != null && _errorLogBox!.isOpen) {
        final timestamp = DateTime.now().toIso8601String();
        await _errorLogBox!.put(timestamp, error);
        
        // Limit error log size to prevent excessive storage use
        if (_errorLogBox!.length > 100) {
          final oldestKey = _errorLogBox!.keys.first;
          await _errorLogBox!.delete(oldestKey);
        }
      }
      
      // Always print to console for debug purposes
      debugPrint('LocalDatabaseService Error: $error');
    } catch (e) {
      // Last resort is just to print to console
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

      // Load and process initial data
      await _loadAndProcessData();
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
        
        // Process whatever data we have
        await _loadAndProcessData();
      } catch (fallbackError) {
        _logError('Critical error in fallback initialization: $fallbackError');
      }
    }
  }

  /// Loads and processes data from the records box
  Future<void> _loadAndProcessData() async {
    final rawData = _recordsBox!.get('user_data', defaultValue: {});
    
    _cachedRawData = rawData;
    _rawDataController.add(_cachedRawData);

    if (rawData is Map && rawData.isNotEmpty) {
      final categorizedData = _processCategorizedData(rawData.cast<Object?, Object?>());
      _cachedCategorizedData = categorizedData;
      _categorizedRecordsController.add(categorizedData);

      final allRecords = _processAllRecords(rawData.cast<Object?, Object?>());
      _allRecordsController.add({'allRecords': allRecords});

      _processSubjectsData(rawData.cast<Object?, Object?>());
    } else {
      final emptyData = {
        'today': <Map<String, dynamic>>[],
        'missed': <Map<String, dynamic>>[],
        'nextDay': <Map<String, dynamic>>[],
        'next7Days': <Map<String, dynamic>>[],
        'todayAdded': <Map<String, dynamic>>[],
        'noreminderdate': <Map<String, dynamic>>[]
      };
      _cachedCategorizedData = emptyData;
      _categorizedRecordsController.add(emptyData);
      _allRecordsController.add({'allRecords': []});
      _subjectsController.add({'subjects': [], 'subjectCodes': {}});
    }
  }

  /// Processes raw data into categorized data for easier access
  Map<String, List<Map<String, dynamic>>> _processCategorizedData(Map<Object?, Object?> rawData) {
    final DateTime today = DateTime.now();
    final String todayStr = today.toIso8601String().split('T')[0];
    final String nextDayStr = today.add(const Duration(days: 1)).toIso8601String().split('T')[0];
    final DateTime next7Days = today.add(const Duration(days: 7));

    List<Map<String, dynamic>> todayRecords = [];
    List<Map<String, dynamic>> missedRecords = [];
    List<Map<String, dynamic>> nextDayRecords = [];
    List<Map<String, dynamic>> next7DaysRecords = [];
    List<Map<String, dynamic>> todayAddedRecords = [];
    List<Map<String, dynamic>> noreminderdate = [];

    rawData.forEach((subjectKey, subjectValue) {
      if (subjectValue is! Map) return;

      subjectValue.forEach((codeKey, codeValue) {
        if (codeValue is! Map) return;

        codeValue.forEach((recordKey, recordValue) {
          if (recordValue is! Map) return;

          final dateScheduled = recordValue['date_scheduled'];
          final dateInitiated = recordValue['initiated_on'];
          final status = recordValue['status'];

          if (dateScheduled == null || status != 'Enabled') return;

          final Map<String, dynamic> record = {
            'subject': subjectKey.toString(),
            'subject_code': codeKey.toString(),
            'lecture_no': recordKey.toString(),
            'date_scheduled': dateScheduled.toString(),
            'initiated_on': recordValue['initiated_on'],
            'reminder_time': recordValue['reminder_time'] ?? 'All Day',
            'lecture_type': recordValue['lecture_type'],
            'date_learnt': recordValue['date_learnt'],
            'date_revised': recordValue['date_revised'],
            'description': recordValue['description'],
            'missed_revision': recordValue['missed_revision'],
            'dates_missed_revisions': recordValue['dates_missed_revisions'] ?? [],
            'dates_revised': recordValue['dates_revised'] ?? [],
            'no_revision': recordValue['no_revision'],
            'revision_frequency': recordValue['revision_frequency'],
            'status': recordValue['status'],
            'revision_data': recordValue['revision_data'] ?? [],
            'duration': recordValue['duration'] ?? 0,
          };

          if (recordValue['date_learnt'] == 'Unspecified') {
            noreminderdate.add(record);
            return;
          }

          final scheduledDateStr = dateScheduled.toString().split('T')[0];
          if (scheduledDateStr == todayStr) {
            todayRecords.add(record);
          }
          if (scheduledDateStr.compareTo(todayStr) < 0) {
            missedRecords.add(record);
          }
          if (dateInitiated != null &&
              dateInitiated.toString().split('T')[0] == todayStr) {
            todayAddedRecords.add(record);
          }
          if (scheduledDateStr == nextDayStr) {
            nextDayRecords.add(record);
          } else {
            final scheduledDate = DateTime.parse(dateScheduled.toString());
            if (scheduledDate.isAfter(today) && scheduledDate.isBefore(next7Days)) {
              next7DaysRecords.add(record);
            }
          }
        });
      });
    });

    return {
      'today': todayRecords,
      'missed': missedRecords,
      'nextDay': nextDayRecords,
      'next7Days': next7DaysRecords,
      'todayAdded': todayAddedRecords,
      'noreminderdate': noreminderdate,
    };
  }

  /// Processes all records into a flat list for easier access
  List<Map<String, dynamic>> _processAllRecords(Map<Object?, Object?> rawData) {
    List<Map<String, dynamic>> allRecords = [];

    rawData.forEach((subjectKey, subjectValue) {
      if (subjectValue is Map) {
        subjectValue.forEach((codeKey, codeValue) {
          if (codeValue is Map) {
            codeValue.forEach((recordKey, recordValue) {
              if (recordValue is Map) {
                allRecords.add({
                  'subject': subjectKey.toString(),
                  'subject_code': codeKey.toString(),
                  'lecture_no': recordKey.toString(),
                  ...recordValue.cast<String, dynamic>(),
                });
              }
            });
          }
        });
      }
    });

    return allRecords;
  }

  /// Processes subject data from raw data for easier access
  void _processSubjectsData(Map<Object?, Object?> rawData) {
    List<String> subjects = rawData.keys
        .map((key) => key.toString())
        .toList();

    Map<String, List<String>> subjectCodes = {};

    rawData.forEach((subject, value) {
      if (value is Map) {
        subjectCodes[subject.toString()] =
            value.keys.map((code) => code.toString()).toList();
      }
    });

    _cachedSubjectsData = {
      'subjects': subjects,
      'subjectCodes': subjectCodes,
    };

    _subjectsController.add(_cachedSubjectsData!);
  }

  // Save data methods with error handling
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
      await _loadAndProcessData();
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
        await _loadAndProcessData();
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
        await _loadAndProcessData();
        return true;
      }
      return false;
    } catch (e) {
      _logError('Error deleting record: $e');
      return false;
    }
  }

  // Profile data methods with improved error handling
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

  // Get all profile data
  Future<Map<String, dynamic>> getAllProfileData() async {
    try {
      return (_profileBox!.get('profile_data', defaultValue: {}) ?? {}).cast<String, dynamic>();
    } catch (e) {
      _logError('Error getting all profile data: $e');
      return {};
    }
  }

  // Cleanup methods
  Future<void> clearAllData() async {
    await _recordsBox!.clear();
    await _profileBox!.clear();
    await _subjectsBox!.clear();
    await _loadAndProcessData();
  }

  Future<void> forceDataReprocessing() async {
    await _loadAndProcessData();
  }

  String getScheduleData() {
    if (_cachedRawData != null) {
      return _cachedRawData.toString();
    }
    return 'No schedule data available';
  }

  Future<Map<String, dynamic>> fetchSubjectsAndCodes() async {
    if (_cachedSubjectsData != null) {
      return _cachedSubjectsData!;
    }
    return {'subjects': [], 'subjectCodes': {}};
  }

  Future<dynamic> fetchRawData() async {
    return _cachedRawData;
  }

  void stopListening() {
    // Local database doesn't need to stop listening as it's not streaming from external source
  }

  void dispose() {
    _categorizedRecordsController.close();
    _allRecordsController.close();
    _subjectsController.close();
    _rawDataController.close();
  }
}
