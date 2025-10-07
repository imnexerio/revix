import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:home_widget/home_widget.dart';
import 'package:revix/Utils/platform_utils.dart';
import '../HomeWidget/HomeWidgetManager.dart';
import 'GuestAuthService.dart';
import 'LocalDatabaseService.dart';
import 'CustomSnackBar.dart';


class UnifiedDatabaseService {
  static final UnifiedDatabaseService _instance = UnifiedDatabaseService._internal();

  factory UnifiedDatabaseService() {
    return _instance;
  }

  UnifiedDatabaseService._internal() {
    _auth.authStateChanges().listen((User? user) {
      _cleanupCurrentListener();
      if (user != null) {
        _initialize(user.uid);
      } else {
        _resetState();
      }
    });
  }
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final LocalDatabaseService _localDatabase = LocalDatabaseService();
  DatabaseReference? _databaseRef;
  StreamSubscription? _dataSubscription;
  bool _isGuestMode = false;

  final StreamController<Map<String, List<Map<String, dynamic>>>> _categorizedRecordsController =
  StreamController<Map<String, List<Map<String, dynamic>>>>.broadcast();

  final StreamController<Map<String, dynamic>> _allRecordsController =
  StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _categoriesController =
  StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<dynamic> _rawDataController =
  StreamController<dynamic>.broadcast();
  Stream<Map<String, List<Map<String, dynamic>>>> get categorizedRecordsStream =>
      _categorizedRecordsController.stream;

  Stream<Map<String, dynamic>> get allRecordsStream =>
      _allRecordsController.stream;

  Stream<Map<String, dynamic>> get subjectsStream =>
      _categoriesController.stream;

  Stream<dynamic> get rawDataStream =>
      _isGuestMode ? _localDatabase.rawDataStream : _rawDataController.stream;

  Map<String, dynamic>? _cachedCategoriesData;
  dynamic _cachedRawData;
  Map<String, List<Map<String, dynamic>>>? _cachedCategorizedData;  Future<void> initialize() async {
    try {
      await _checkGuestMode();
      if (_isGuestMode) {
        await _initializeLocalDatabase();
      } else {
        User? user = _auth.currentUser;
        if (user == null) {
          _addErrorToAllControllers('No authenticated user');
          return;
        }
        
        // Additional validation to ensure user has valid UID
        if (user.uid.isEmpty) {
          _addErrorToAllControllers('Authenticated user has invalid UID');
          return;
        }
        
        _initialize(user.uid);
      }
    } catch (e) {
      print('Error in UnifiedDatabaseService.initialize(): $e');
      _addErrorToAllControllers('Failed to initialize database service: $e');
    }
  }

  Future<void> _checkGuestMode() async {
    _isGuestMode = await GuestAuthService.isGuestMode();
  }  Future<void> _initializeLocalDatabase() async {
    try {
      await LocalDatabaseService.initialize(); // Make sure Hive boxes are initialized
      await _localDatabase.initializeWithDefaultData();
      
      // Set up stream subscription for local database changes
      _setupDataListener();
      
      // Initial data load
      await forceDataReprocessing();
    } catch (e) {
      print('Error initializing local database: $e');
      // Try to recover by reinitializing
      try {
        await Future.delayed(Duration(milliseconds: 500));
        await LocalDatabaseService.initialize();
        await _localDatabase.initializeWithDefaultData();
        _setupDataListener();
        await forceDataReprocessing();
      } catch (retryError) {
        print('Failed to recover local database initialization: $retryError');
        throw Exception('Local database initialization failed: $retryError');
      }
    }
  }
  void _setupDataListener() {
    _dataSubscription?.cancel();

    if (_isGuestMode) {
      // Set up local database stream listener
      _dataSubscription = _localDatabase.rawDataStream.listen((rawData) {
        _processDataChange(rawData);
      }, onError: (error) {
        String errorMsg = 'Failed to fetch local data: $error';
        _addErrorToAllControllers(errorMsg);
      });
    } else {
      // Set up Firebase database stream listener
      if (_databaseRef == null) return;
      
      _dataSubscription = _databaseRef!.onValue.listen((event) {
        if (!event.snapshot.exists) {
          _processDataChange(null);
          return;
        }
        Map<Object?, Object?> rawData = event.snapshot.value as Map<Object?, Object?>;
        _processDataChange(rawData);
      }, onError: (error) {
        String errorMsg = 'Failed to fetch data: $error';
        _addErrorToAllControllers(errorMsg);
      });
    }
  }  void _initialize(String uid) {
    if (uid.isEmpty) {
      _addErrorToAllControllers('Invalid user ID - cannot initialize Firebase database reference');
      return;
    }
    
    try {
      _databaseRef = _database.ref('users/$uid/user_data');
      _setupDataListener();
    } catch (e) {
      _addErrorToAllControllers('Failed to create database reference for user $uid: $e');
    }
  }
  void _processDataChange(dynamic rawData) {
    // Ensure PlatformUtils is initialized for background contexts
    if (!PlatformUtils.instance.isInitialized) {
      PlatformUtils.init();
    }

    if (rawData == null) {
      Map<String, List<Map<String, dynamic>>> emptyData = {
        'today': [], 'missed': [], 'nextDay': [], 'next7Days': [], 'todayAdded': [], 'noreminderdate': []
      };
      _cachedCategorizedData = emptyData;
      _categorizedRecordsController.add(emptyData);
      _allRecordsController.add({'allRecords': []});
      _categoriesController.add({'subjects': [], 'subCategories': {}});
      _rawDataController.add(null);

      if (PlatformUtils.instance.isAndroid ) {
        _updateHomeWidget([], [], [], [], <Object?, Object?>{});
      }
      return;
    }

    Map<Object?, Object?> processedRawData = rawData is Map<Object?, Object?>
        ? rawData
        : Map<Object?, Object?>.from(rawData as Map);

    _cachedRawData = processedRawData;
    _rawDataController.add(_cachedRawData);

    Map<String, List<Map<String, dynamic>>> categorizedData = _processCategorizedData(processedRawData);
    _cachedCategorizedData = categorizedData;
    _categorizedRecordsController.add(categorizedData);

    List<Map<String, dynamic>> allRecords = _processAllRecords(processedRawData);
    _allRecordsController.add({'allRecords': allRecords});
    _processCategoriesData(processedRawData);
    if (PlatformUtils.instance.isAndroid ) {
      _updateHomeWidget(categorizedData['today'] ?? [],
          categorizedData['nextDay'] ?? [],  // NEW - pass tomorrow data
          categorizedData['missed'] ?? [],
          categorizedData['noreminderdate'] ?? [],
          processedRawData);
      HomeWidget.saveWidgetData('categoriesData', jsonEncode(_cachedCategoriesData));
    }
  }

  void _updateHomeWidget(List<Map<String, dynamic>> todayRecords,List<Map<String, dynamic>> tomorrowRecords, List<Map<String, dynamic>> missedRecords,List<Map<String, dynamic>> noReminderDateRecords, Map<Object?, Object?> allRecords) {
    HomeWidgetService.updateWidgetData(todayRecords, tomorrowRecords, missedRecords, noReminderDateRecords, allRecords);
  }

  void _processCategoriesData(Map<Object?, Object?> rawData) {
    List<String> subjects = rawData.keys
        .map((key) => key.toString())
        .toList();

    Map<String, List<String>> subCategories = {};

    rawData.forEach((category, value) {
      if (value is Map) {
        subCategories[category.toString()] =
            value.keys.map((code) => code.toString()).toList();
      }
    });

    _cachedCategoriesData = {
      'subjects': subjects,
      'subCategories': subCategories,
    };
    _categoriesController.add(_cachedCategoriesData!);
  }

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

          final dateScheduled = recordValue['scheduled_date'];
          final dateInitiated = recordValue['start_timestamp'];
          final status = recordValue['status'];

          if (dateScheduled == null || status != 'Enabled') return;

          final Map<String, dynamic> record = {
            'category': subjectKey.toString(),
            'sub_category': codeKey.toString(),
            'record_title': recordKey.toString(),
            'scheduled_date': dateScheduled.toString(),
            'start_timestamp': recordValue['start_timestamp'],
            'reminder_time': recordValue['reminder_time'] ?? 'All Day',
            'alarm_type': recordValue['alarm_type'] ?? 0,
            'entry_type': recordValue['entry_type'],
            'date_initiated': recordValue['date_initiated'],
            'date_updated': recordValue['date_updated'],
            'description': recordValue['description'],
            'missed_counts': recordValue['missed_counts'],
            'dates_missed_revisions': recordValue['dates_missed_revisions'] ?? [],
            'dates_updated': recordValue['dates_updated'] ?? [],
            'completion_counts': recordValue['completion_counts'],
            'recurrence_frequency': recordValue['recurrence_frequency'],
            'status': recordValue['status'],
            'recurrence_data': recordValue['recurrence_data'] ?? [],
            'duration': recordValue['duration'] ?? 0,
            'skip_counts': recordValue['skip_counts'] ?? 0,
            'skipped_dates': recordValue['skipped_dates'] ?? [],
          };

          if (recordValue['date_initiated'] == 'Unspecified') {
            noreminderdate.add(record);
            return;
          }

          final scheduledDateStr = dateScheduled.toString().split('T')[0];
          if (scheduledDateStr == todayStr) {
            todayRecords.add(record);
          }if (scheduledDateStr.compareTo(todayStr) < 0) {
            missedRecords.add(record);
          }if (dateInitiated != null &&
              dateInitiated.toString().split('T')[0] == todayStr) {
            todayAddedRecords.add(record);
          }if (scheduledDateStr == nextDayStr) {
            nextDayRecords.add(record);
          }else {
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

  List<Map<String, dynamic>> _processAllRecords(Map<Object?, Object?> rawData) {
    List<Map<String, dynamic>> allRecords = [];

    rawData.forEach((subjectKey, subjectValue) {
      if (subjectValue is Map) {
        subjectValue.forEach((codeKey, codeValue) {
          if (codeValue is Map) {
            codeValue.forEach((recordKey, recordValue) {
              if (recordValue is Map) {
                var record = {
                  'category': subjectKey.toString(),
                  'sub_category': codeKey.toString(),
                  'record_title': recordKey.toString(),
                  'details': Map<String, dynamic>.from(recordValue),
                };
                allRecords.add(record);
              }
            });
          }
        });
      }
    });

    return allRecords;
  }
  Future<void> forceDataReprocessing() async {
    if (_isGuestMode) {
      // Get latest data from local database
      await _localDatabase.forceDataReprocessing();
      final rawData = await _localDatabase.getRawData();
      if (rawData != null) {
        _cachedRawData = rawData;
        _rawDataController.add(_cachedRawData);
        
        // Process the data
        _processCategoriesData(_cachedRawData);
        
        Map<String, List<Map<String, dynamic>>> categorizedData = _processCategorizedData(_cachedRawData);
        _cachedCategorizedData = categorizedData;
        _categorizedRecordsController.add(categorizedData);

        List<Map<String, dynamic>> allRecords = _processAllRecords(_cachedRawData);
        _allRecordsController.add({'allRecords': allRecords});

        if (PlatformUtils.instance.isAndroid ) {
          _updateHomeWidget(categorizedData['today'] ?? [],
              categorizedData['nextDay'] ?? [],  // NEW - pass tomorrow data
              categorizedData['missed'] ?? [],
              categorizedData['noreminderdate'] ?? [],
              _cachedRawData);
          HomeWidget.saveWidgetData('categoriesData', jsonEncode(_cachedCategoriesData));
        }

      }
      return;
    }
      if (_databaseRef != null) {
      try {
        final snapshot = await _databaseRef!.get();
        final rawData = snapshot.exists ? snapshot.value as Map<Object?, Object?> : null;
        _processDataChange(rawData);
        return;
      } catch (error) {
        String errorMsg = 'Failed to refresh data: $error';
        _addErrorToAllControllers(errorMsg);
        rethrow;
      }
    }
  }


  void _addErrorToAllControllers(String errorMsg) {
    _categorizedRecordsController.addError(errorMsg);
    _allRecordsController.addError(errorMsg);
    _categoriesController.addError(errorMsg);
    _rawDataController.addError(errorMsg);
  }

  void _resetState() {
    _cachedCategoriesData = null;
    _cachedRawData = null;
    _cachedCategorizedData = null;
    _databaseRef = null;
  }  void _cleanupCurrentListener() {
    _dataSubscription?.cancel();
    _dataSubscription = null;
  }void stopListening() {
    _cleanupCurrentListener();
    if (_isGuestMode) {
      _localDatabase.stopListening();
    }
  }

  void dispose() {
    stopListening();
    _categorizedRecordsController.close();
    _allRecordsController.close();
    _categoriesController.close();
    _rawDataController.close();
    
    if (_isGuestMode) {
      _localDatabase.dispose();
    }
  }

  DatabaseReference? get databaseRef => _databaseRef;
  Map<String, dynamic>? get currentSubjectsData => _cachedCategoriesData;
      
  dynamic get currentRawData => _cachedRawData;
      
  Map<String, List<Map<String, dynamic>>>? get currentCategorizedData => _cachedCategorizedData;
  String getScheduleData() {
    if (_cachedRawData != null) {
      return _cachedRawData.toString();
    }
    return 'No schedule data available';
  }

  Future<Map<String, dynamic>> fetchCategoriesAndSubCategories() async {
    if (_cachedCategoriesData != null) {
      return _cachedCategoriesData!;
    }

    if (_isGuestMode) {
      // For guest mode, get raw data from local database and process it
      final rawData = await _localDatabase.getRawData();
      if (rawData != null) {
        _processCategoriesData(rawData);
        if (_cachedCategoriesData != null) {
          return _cachedCategoriesData!;
        }
      }    } else {
      User? user = _auth.currentUser;
      if (user == null) {
        // User is not authenticated (logged out), return default data instead of throwing exception
        return {'subjects': [], 'subCategories': {}};
      }

      await forceDataReprocessing();
    }

    if (_cachedCategoriesData == null) {
      return {'subjects': [], 'subCategories': {}};
    }

    return _cachedCategoriesData!;
  }

  Future<dynamic> fetchRawData() async {
    if (_cachedRawData != null) {
      return _cachedRawData;
    }

    if (_isGuestMode) {
      return await _localDatabase.getRawData();
    }    
    User? user = _auth.currentUser;
    if (user == null) {
      // User is not authenticated (logged out), return null instead of throwing exception
      return null;
    }

    await forceDataReprocessing();

    return _cachedRawData;
  }
  
  // Add public method for saving records that works in both guest mode and Firebase mode
  Future<bool> saveRecord(String category, String subCategory, String lectureNo, Map<String, dynamic> recordData) async {
    if (_isGuestMode) {
      return await _localDatabase.saveRecord(category, subCategory, lectureNo, recordData);
    } else {
      try {
        if (_databaseRef == null) {
          throw Exception('Database reference not initialized');
        }
        await _databaseRef!.child(category).child(subCategory).child(lectureNo).set(recordData);
        return true;
      } catch (e) {
        _addErrorToAllControllers('Failed to save record: $e');
        return false;
      }
    }
  }
  
  // Add public method for updating records
  Future<bool> updateRecord(String category, String subCategory, String lectureNo, Map<String, dynamic> updates) async {
    if (_isGuestMode) {
      return await _localDatabase.updateRecord(category, subCategory, lectureNo, updates);
    } else {
      try {
        if (_databaseRef == null) {
          throw Exception('Database reference not initialized');
        }
        await _databaseRef!.child(category).child(subCategory).child(lectureNo).update(updates);
        return true;
      } catch (e) {
        _addErrorToAllControllers('Failed to update record: $e');
        return false;
      }
    }
  }
  
  // Add public method for deleting records
  Future<bool> deleteRecord(String category, String subCategory, String lectureNo) async {
    if (_isGuestMode) {
      return await _localDatabase.deleteRecord(category, subCategory, lectureNo);
    } else {
      try {
        if (_databaseRef == null) {
          throw Exception('Database reference not initialized');
        }
        await _databaseRef!.child(category).child(subCategory).child(lectureNo).remove();
        return true;
      } catch (e) {
        _addErrorToAllControllers('Failed to delete record: $e');
        return false;
      }
    }
  }
  
  // Delete entire subcategory and all its records
  Future<bool> deleteSubCategory(String category, String subCategory) async {
    if (_isGuestMode) {
      return await _localDatabase.deleteSubCategory(category, subCategory);
    } else {
      try {
        if (_databaseRef == null) {
          throw Exception('Database reference not initialized');
        }
        await _databaseRef!.child(category).child(subCategory).remove();
        return true;
      } catch (e) {
        _addErrorToAllControllers('Failed to delete subcategory: $e');
        return false;
      }
    }
  }

  // Delete entire category and all its subcategories/records  
  Future<bool> deleteCategory(String category) async {
    if (_isGuestMode) {
      return await _localDatabase.deleteCategory(category);
    } else {
      try {
        if (_databaseRef == null) {
          throw Exception('Database reference not initialized');
        }
        await _databaseRef!.child(category).remove();
        return true;
      } catch (e) {
        _addErrorToAllControllers('Failed to delete category: $e');
        return false;
      }
    }
  }

  /// Delete records in a subcategory that have a specific field value
  /// Example: Delete all holidays where record_added_via = 'PublicHolidayFetcher'
  /// Returns: Number of records deleted
  Future<int> deleteRecordsWithField({
    required String category,
    required String subCategory,
    required String fieldName,
    required dynamic fieldValue,
  }) async {
    int deletedCount = 0;
    
    if (_isGuestMode) {
      // Guest mode: Get raw data, filter, and delete from local database
      try {
        final rawData = await _localDatabase.getRawData();
        
        if (rawData != null && rawData[category] != null) {
          final categoryData = rawData[category];
          
          if (categoryData[subCategory] != null) {
            final subCategoryData = categoryData[subCategory] as Map<dynamic, dynamic>;
            
            // Find and delete matching records
            for (var entry in subCategoryData.entries) {
              final recordName = entry.key.toString();
              final recordData = entry.value;
              
              // Check if field matches
              if (recordData is Map && recordData[fieldName] == fieldValue) {
                final success = await _localDatabase.deleteRecord(category, subCategory, recordName);
                if (success) {
                  deletedCount++;
                }
              }
            }
          }
        }
      } catch (e) {
        print('Error deleting records with field in guest mode: $e');
      }
    } else {
      // Firebase mode: Fetch, filter, and delete
      try {
        if (_databaseRef == null) {
          throw Exception('Database reference not initialized');
        }
        
        // Fetch all records in subcategory
        final snapshot = await _databaseRef!.child(category).child(subCategory).get();
        
        if (snapshot.exists && snapshot.value != null) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          
          // Find records with matching field
          final recordsToDelete = <String>[];
          data.forEach((key, value) {
            if (value is Map && value[fieldName] == fieldValue) {
              recordsToDelete.add(key.toString());
            }
          });
          
          // Delete matching records
          for (var recordName in recordsToDelete) {
            try {
              await _databaseRef!.child(category).child(subCategory).child(recordName).remove();
              deletedCount++;
            } catch (e) {
              print('Error deleting record $recordName: $e');
            }
          }
        }
      } catch (e) {
        print('Error deleting records with field in Firebase: $e');
      }
    }
    
    return deletedCount;
  }

  /// Bulk save multiple records in a single operation
  /// Returns: { 'success': count, 'failed': count, 'total': count }
  Future<Map<String, int>> bulkSaveRecords({
    required String category,
    required String subCategory,
    required Map<String, Map<String, dynamic>> records, // key: recordName, value: recordData
  }) async {
    int successCount = 0;
    int failedCount = 0;
    final total = records.length;
    
    if (_isGuestMode) {
      // Guest mode: Save to local database one by one
      for (var entry in records.entries) {
        try {
          final success = await _localDatabase.saveRecord(
            category, 
            subCategory, 
            entry.key, 
            entry.value
          );
          if (success) {
            successCount++;
          } else {
            failedCount++;
          }
        } catch (e) {
          failedCount++;
          print('Error saving ${entry.key}: $e');
        }
      }
    } else {
      // Firebase mode: Batch save using update
      try {
        if (_databaseRef == null) {
          throw Exception('Database reference not initialized');
        }
        
        // Firebase batch update - all at once
        final updates = <String, dynamic>{};
        for (var entry in records.entries) {
          updates['$category/$subCategory/${entry.key}'] = entry.value;
        }
        
        await _databaseRef!.update(updates);
        successCount = total;
      } catch (e) {
        print('Bulk save error: $e');
        // Fallback: Save one by one
        for (var entry in records.entries) {
          try {
            final success = await saveRecord(
              category, 
              subCategory, 
              entry.key, 
              entry.value
            );
            if (success) {
              successCount++;
            } else {
              failedCount++;
            }
          } catch (e) {
            failedCount++;
            print('Error saving ${entry.key}: $e');
          }
        }
      }
    }
    
    return {
      'success': successCount,
      'failed': failedCount,
      'total': total,
    };
  }
  
  // Add public method for updating record revision data
  Future<bool> updateRecordRevision(
    String category,
    String subCategory,
    String lectureNo,
    String dateRevised,
    String description,
    String reminderTime,
    int noRevision,
    String dateScheduled,
    List<String> datesRevised,
    int missedRevision,
    List<String> datesMissedRevisions,
    String status, {
    bool isSkip = false,
    List<String>? skippedDates,
    int? skipCounts,
  }) async {
    try {
      // Prepare update data
      Map<String, dynamic> updateData = {
        'reminder_time': reminderTime,
        'completion_counts': noRevision,
        'scheduled_date': dateScheduled,
        'missed_counts': missedRevision,
        'dates_missed_revisions': datesMissedRevisions,
        'description': description,
        'status': status,
        'last_mark_done': DateTime.now().toIso8601String().split('T')[0],
      };

      // Add skip-specific data if this is a skip operation
      if (isSkip) {
        updateData['skipped_dates'] = skippedDates ?? [];
        updateData['skip_counts'] = skipCounts ?? 0;
      } else {
        // Add completion-specific data for mark as done
        updateData['date_updated'] = dateRevised;
        updateData['dates_updated'] = datesRevised;
      }
      
      // Update the record using the existing updateRecord method
      return await updateRecord(category, subCategory, lectureNo, updateData);
    } catch (e) {
      _addErrorToAllControllers('Failed to update record revision: $e');
      return false;
    }
  }
  
  // Add public method for getting data from a particular location
  Future<Map<String, dynamic>?> getDataAtLocation(String category, String subCategory, String lectureNo) async {
    if (_isGuestMode) {
      try {
        return await _localDatabase.getRecord(category, subCategory, lectureNo);
      } catch (e) {
        _addErrorToAllControllers('Failed to get local record: $e');
        return null;
      }
    } else {
      try {
        if (_databaseRef == null) {
          throw Exception('Database reference not initialized');
        }
        
        DatabaseEvent event = await _databaseRef!.child(category).child(subCategory).child(lectureNo).once();
        
        if (!event.snapshot.exists) {
          return null;
        }
        
        final data = event.snapshot.value;
        if (data is Map<Object?, Object?>) {
          return Map<String, dynamic>.from(data);
        }
        
        return null;
      } catch (e) {
        _addErrorToAllControllers('Failed to get Firebase record: $e');
        return null;
      }
    }
  }

  // Helper method to sanitize title to prevent Firebase array conversion
  String _sanitizeTitle(String title) {
    // Check if title is purely numeric (with or without leading zeros)
    final numericRegex = RegExp(r'^\d+$');
    if (numericRegex.hasMatch(title)) {
      // Prefix numeric titles with an underscore to prevent array conversion
      return '_$title';
    }
    return title;
  }

  // Helper method to generate unique title by appending (2), (3), etc.
  Future<String> _generateUniqueTitle(String category, String subCategory, String originalTitle) async {
    // Sanitize the title first to prevent array conversion
    String sanitizedTitle = _sanitizeTitle(originalTitle);
    String baseTitle = sanitizedTitle;
    int counter = 2;
    String currentTitle = baseTitle;
    
    while (await getDataAtLocation(category, subCategory, currentTitle) != null) {
      currentTitle = "$baseTitle ($counter)";
      counter++;
    }
    
    return currentTitle;
  }

  // Private method containing the common logic for updating records
  Future<String> _updateRecordsInternal(
    String selectedCategory,
    String selectedCategoryCode,
    String lectureNo,
    String startTimestamp,
    String timeController,
    String lectureType,
    String todayDate,
    String dateScheduled,
    String description,
    String revisionFrequency,
    Map<String, dynamic> durationData,
    Map<String, dynamic> customFrequencyParams,
    int alarmType,
  ) async {
    // Generate unique title to prevent duplicates
    String uniqueTitle = await _generateUniqueTitle(selectedCategory, selectedCategoryCode, lectureNo);
    
    try {
      int completionCounts = 0;
      
      if (todayDate == 'Unspecified') {
        completionCounts = -1;
        revisionFrequency = 'No Repetition';
        dateScheduled = 'Unspecified';
        durationData = {
          "type": "forever",
          "numberOfTimes": null,
          "endDate": null
        };
      } else {
        if (DateTime.parse(startTimestamp).isBefore(DateTime.parse(todayDate)) || revisionFrequency == 'No Repetition') {
          completionCounts = -1;
        }
      }

      // Create a map to store all revision parameters including custom ones
      Map<String, dynamic> revisionData = {
        'frequency': revisionFrequency,
      };

      // Add custom frequency parameters if present
      if (customFrequencyParams.isNotEmpty) {
        revisionData['custom_params'] = customFrequencyParams;
      }

      // Prepare record data for storage
      Map<String, dynamic> recordData = {
        'start_timestamp': startTimestamp,
        'reminder_time': timeController,
        'alarm_type': alarmType,
        'entry_type': lectureType,
        'date_initiated': todayDate,
        'date_updated': todayDate,
        'scheduled_date': dateScheduled,
        'description': description,
        'missed_counts': 0,
        'completion_counts': completionCounts,
        'recurrence_frequency': revisionFrequency,
        'recurrence_data': revisionData,
        'status': 'Enabled',
        'duration': durationData,
      };

      // Save record using unified service with unique title
      bool success = await saveRecord(selectedCategory, selectedCategoryCode, uniqueTitle, recordData);
      
      if (!success) {
        throw Exception('Failed to save record');
      }
      
      // Return the unique title that was used
      return uniqueTitle;
    } catch (e) {
      throw Exception('Failed to save lecture: $e');
    }
  }

  // Public method for updating records with context (shows snackbar)
  Future<void> updateRecords(
    BuildContext context,
    String selectedCategory,
    String selectedCategoryCode,
    String lectureNo,
    String startTimestamp,
    String timeController,
    String lectureType,
    String todayDate,
    String dateScheduled,
    String description,
    String revisionFrequency,
    Map<String, dynamic> durationData,
    Map<String, dynamic> customFrequencyParams,
    int alarmType,
  ) async {
    try {
      String uniqueTitle = await _updateRecordsInternal(
        selectedCategory,
        selectedCategoryCode,
        lectureNo,
        startTimestamp,
        timeController,
        lectureType,
        todayDate,
        dateScheduled,
        description,
        revisionFrequency,
        durationData,
        customFrequencyParams,
        alarmType,
      );
      
      // Show appropriate success message
      final message = uniqueTitle != lectureNo 
          ? 'Record saved as "$uniqueTitle"'
          : 'Record added successfully';
          
      customSnackBar(
        context: context,
        message: message,
      );
    } catch (e) {
      throw e; // Re-throw the exception for the caller to handle
    }
  }

  // Public method for updating records without context (no snackbar)
  Future<void> updateRecordsWithoutContext(
    String selectedCategory,
    String selectedCategoryCode,
    String lectureNo,
    String startTimestamp,
    String timeController,
    String lectureType,
    String todayDate,
    String dateScheduled,
    String description,
    String revisionFrequency,
    Map<String, dynamic> durationData,
    Map<String, dynamic> customFrequencyParams,
    int alarmType,
  ) async {
    await _updateRecordsInternal(
      selectedCategory,
      selectedCategoryCode,
      lectureNo,
      startTimestamp,
      timeController,
      lectureType,
      todayDate,
      dateScheduled,
      description,
      revisionFrequency,
      durationData,
      customFrequencyParams,
      alarmType,
    );
  }

  // Method to load categories and subcategories for forms
  Future<Map<String, dynamic>> loadCategoriesAndSubCategories() async {
    try {
      // Check if user is in guest mode
      if (await GuestAuthService.isGuestMode()) {
        // Use local database for guest users
        final localDb = LocalDatabaseService();
        
        // Get cached data directly from local database
        final rawData = await localDb.getRawData();
        
        if (rawData != null && rawData is Map) {
          Map<String, dynamic> data = Map<String, dynamic>.from(rawData);
          
          // Extract categories and sub categories from local data
          List<String> subjects = [];
          Map<String, List<String>> subCategories = {};
          
          for (String category in data.keys) {
            subjects.add(category);
            subCategories[category] = [];
            
            if (data[category] is Map) {
              Map<String, dynamic> categoryData = Map<String, dynamic>.from(data[category]);
              for (String subCategory in categoryData.keys) {
                subCategories[category]!.add(subCategory);
              }
            }
          }
          
          return {
            'subjects': subjects,
            'subCategories': subCategories,
          };
        } else {
          // Return empty data for new guest users
          return {
            'subjects': <String>[],
            'subCategories': <String, List<String>>{},
          };
        }
      } else {
        // Use Firebase for authenticated users (original code)
        // First check if cached data is available
        Map<String, dynamic>? data = currentSubjectsData;

        data ??= await fetchCategoriesAndSubCategories();

        return data;
      }
    } catch (e) {
      throw Exception('Error loading categories and sub categories: $e');
    }
  }
}