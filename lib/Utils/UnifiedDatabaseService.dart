import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:revix/Utils/platform_utils.dart';
import '../HomeWidget/HomeWidgetManager.dart';
import 'GuestAuthService.dart';
import 'LocalDatabaseService.dart';

class CombinedDatabaseService {
  static final CombinedDatabaseService _instance = CombinedDatabaseService._internal();

  factory CombinedDatabaseService() {
    return _instance;
  }

  CombinedDatabaseService._internal() {
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
  Map<String, List<Map<String, dynamic>>>? _cachedCategorizedData;  void initialize() async {
    await _checkGuestMode();
    if (_isGuestMode) {
      await _initializeLocalDatabase();
    } else {
      User? user = _auth.currentUser;
      if (user == null) {
        _addErrorToAllControllers('No authenticated user');
        return;
      }
      _initialize(user.uid);
    }
  }

  Future<void> _checkGuestMode() async {
    _isGuestMode = await GuestAuthService.isGuestMode();
  }  Future<void> _initializeLocalDatabase() async {
    await LocalDatabaseService.initialize(); // Make sure Hive boxes are initialized
    await _localDatabase.initializeWithDefaultData();
    
    // Set up stream subscription for local database changes
    _setupDataListener();
    
    // Initial data load
    await forceDataReprocessing();
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
    _databaseRef = _database.ref('users/$uid/user_data');
    _setupDataListener();
  }

  void _processDataChange(dynamic rawData) {
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
        _updateHomeWidget([], [], []);
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
          categorizedData['missed'] ?? [],
          categorizedData['noreminderdate'] ?? []);
    }
  }

  void _updateHomeWidget(List<Map<String, dynamic>> todayRecords,List<Map<String, dynamic>> missedRecords,List<Map<String, dynamic>> noReminderDateRecords) {
      HomeWidgetService.updateWidgetData(todayRecords, missedRecords, noReminderDateRecords);
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
              categorizedData['missed'] ?? [],
              categorizedData['noreminderdate'] ?? []);
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
      bool success = await _localDatabase.saveRecord(category, subCategory, lectureNo, recordData);
      if (success) {
        // Force refresh data to ensure UI updates
        await forceDataReprocessing();
      }
      return success;
    } else {
      try {
        if (_databaseRef == null) {
          throw Exception('Database reference not initialized');
        }
        await _databaseRef!.child(category).child(subCategory).child(lectureNo).set(recordData);
        // Force a data refresh immediately instead of waiting for Firebase event
        await forceDataReprocessing();
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
      bool success = await _localDatabase.updateRecord(category, subCategory, lectureNo, updates);
      if (success) {
        await forceDataReprocessing();
      }
      return success;
    } else {
      try {
        if (_databaseRef == null) {
          throw Exception('Database reference not initialized');
        }
        await _databaseRef!.child(category).child(subCategory).child(lectureNo).update(updates);
        await forceDataReprocessing();
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
      bool success = await _localDatabase.deleteRecord(category, subCategory, lectureNo);
      if (success) {
        await forceDataReprocessing();
      }
      return success;
    } else {
      try {
        if (_databaseRef == null) {
          throw Exception('Database reference not initialized');
        }
        await _databaseRef!.child(category).child(subCategory).child(lectureNo).remove();
        await forceDataReprocessing();
        return true;
      } catch (e) {
        _addErrorToAllControllers('Failed to delete record: $e');
        return false;
      }
    }
  }
}

Future<Map<String, dynamic>> fetchCategoriesAndSubCategories() async {
  return await CombinedDatabaseService().fetchCategoriesAndSubCategories();
}

Stream<Map<String, dynamic>> getCategoriesStream() {
  return CombinedDatabaseService().subjectsStream;
}

class categoryDataProvider {
  static final categoryDataProvider _instance = categoryDataProvider._internal();

  final CombinedDatabaseService _service = CombinedDatabaseService();

  factory categoryDataProvider() {
    return _instance;
  }

  categoryDataProvider._internal();

  Stream<Map<String, dynamic>> get subjectsStream => _service.subjectsStream;
  Stream<dynamic> get rawDataStream => _service.rawDataStream;
  Map<String, dynamic>? get currentData => _service.currentSubjectsData;
  dynamic get currentRawData => _service.currentRawData;

  String getScheduleData() => _service.getScheduleData();
  Future<Map<String, dynamic>> fetchCategoriesAndSubCategories() => _service.fetchCategoriesAndSubCategories();
  Future<dynamic> fetchRawData() => _service.fetchRawData();
  void dispose() {} // No-op, let CombinedDatabaseService handle real disposal
}

class UnifiedDatabaseService {
  static final UnifiedDatabaseService _instance = UnifiedDatabaseService._internal();

  final CombinedDatabaseService _service = CombinedDatabaseService();

  factory UnifiedDatabaseService() {
    return _instance;
  }

  UnifiedDatabaseService._internal();

  Stream<Map<String, List<Map<String, dynamic>>>> get categorizedRecordsStream =>
      _service.categorizedRecordsStream;

  Stream<Map<String, dynamic>> get allRecordsStream => _service.allRecordsStream;

  void initialize() => _service.initialize();
  Future<void> forceDataReprocessing() => _service.forceDataReprocessing();
  void stopListening() => _service.stopListening();
  void dispose() {} // No-op, let CombinedDatabaseService handle real disposal
  DatabaseReference? get databaseRef => _service.databaseRef;
  
  Map<String, dynamic>? get currentSubjectsData => _service.currentSubjectsData;
      
  dynamic get currentRawData => _service.currentRawData;
      
  Map<String, List<Map<String, dynamic>>>? get currentCategorizedData => _service.currentCategorizedData;
  
  // Add method to save records, forwarding to the appropriate database based on guest mode
  Future<bool> saveRecord(String category, String subCategory, String lectureNo, Map<String, dynamic> recordData) async {
    if (_service._isGuestMode) {
      return await _service._localDatabase.saveRecord(category, subCategory, lectureNo, recordData);
    } else {
      try {
        if (_service.databaseRef == null) {
          throw Exception('Database reference not initialized');
        }
        
        await _service.databaseRef!.child(category).child(subCategory).child(lectureNo).set(recordData);
        await _service.forceDataReprocessing();
        return true;
      } catch (e) {
        print('Error saving record to Firebase: $e');
        return false;
      }
    }
  }
  
  // Add method to update existing records
  Future<bool> updateRecord(String category, String subCategory, String lectureNo, Map<String, dynamic> updates) async {
    if (_service._isGuestMode) {
      return await _service._localDatabase.updateRecord(category, subCategory, lectureNo, updates);
    } else {
      try {
        if (_service.databaseRef == null) {
          throw Exception('Database reference not initialized');
        }
        
        await _service.databaseRef!.child(category).child(subCategory).child(lectureNo).update(updates);
        await _service.forceDataReprocessing();
        return true;
      } catch (e) {
        print('Error updating record in Firebase: $e');
        return false;
      }
    }
  }
  
  // Add method to delete records
  Future<bool> deleteRecord(String category, String subCategory, String lectureNo) async {
    if (_service._isGuestMode) {
      return await _service._localDatabase.deleteRecord(category, subCategory, lectureNo);
    } else {
      try {
        if (_service.databaseRef == null) {
          throw Exception('Database reference not initialized');
        }
        
        await _service.databaseRef!.child(category).child(subCategory).child(lectureNo).remove();
        await _service.forceDataReprocessing();
        return true;
      } catch (e) {
        print('Error deleting record from Firebase: $e');
        return false;
      }
    }
  }
}