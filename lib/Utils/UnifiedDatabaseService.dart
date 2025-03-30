import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// CombinedDatabaseService combines the functionality of UnifiedDatabaseService and SubjectDataProvider
/// into a single, efficient service that maintains only one Firebase listener.
class CombinedDatabaseService {
  // Singleton pattern implementation
  static final CombinedDatabaseService _instance = CombinedDatabaseService._internal();

  factory CombinedDatabaseService() {
    return _instance;
  }

  CombinedDatabaseService._internal() {
    // Initialize auth listener when the service is first created
    _auth.authStateChanges().listen((User? user) {
      _cleanupCurrentListener();
      if (user != null) {
        _initialize(user.uid);
      } else {
        _resetState();
      }
    });
  }

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Database reference and subscription
  DatabaseReference? _databaseRef;
  StreamSubscription<DatabaseEvent>? _databaseSubscription;

  // Stream controllers for different data views
  final StreamController<Map<String, List<Map<String, dynamic>>>> _categorizedRecordsController =
  StreamController<Map<String, List<Map<String, dynamic>>>>.broadcast();

  final StreamController<Map<String, dynamic>> _allRecordsController =
  StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _subjectsController =
  StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<dynamic> _rawDataController =
  StreamController<dynamic>.broadcast();

  // Expose streams that components can listen to
  Stream<Map<String, List<Map<String, dynamic>>>> get categorizedRecordsStream =>
      _categorizedRecordsController.stream;

  Stream<Map<String, dynamic>> get allRecordsStream =>
      _allRecordsController.stream;

  Stream<Map<String, dynamic>> get subjectsStream =>
      _subjectsController.stream;

  Stream<dynamic> get rawDataStream =>
      _rawDataController.stream;

  // Cached data for faster access
  Map<String, dynamic>? _cachedSubjectsData;
  dynamic _cachedRawData;

  // Initialize the service (can be called manually or automatically via auth state)
  void initialize() {
    User? user = _auth.currentUser;
    if (user == null) {
      _addErrorToAllControllers('No authenticated user');
      return;
    }

    _initialize(user.uid);
  }

  // Internal initialization with user ID
  void _initialize(String uid) {
    _databaseRef = _database.ref('users/$uid/user_data');

    // Enable offline persistence
    _databaseRef!.keepSynced(true);

    // Set up single database listener
    _setupDatabaseListener();
  }

  void _setupDatabaseListener() {
    // Cancel existing subscription if any
    _databaseSubscription?.cancel();

    if (_databaseRef == null) return;

    _databaseSubscription = _databaseRef!.onValue.listen((event) {
      if (!event.snapshot.exists) {
        // Send empty data to all streams
        _categorizedRecordsController.add({
          'today': [], 'missed': [], 'nextDay': [], 'next7Days': [], 'todayAdded': []
        });
        _allRecordsController.add({'allRecords': []});
        _subjectsController.add({'subjects': [], 'subjectCodes': {}});
        _rawDataController.add(null);
        return;
      }

      // Process snapshot data once and distribute to all streams
      _processSnapshot(event.snapshot);

    }, onError: (error) {
      String errorMsg = 'Failed to fetch data: $error';
      _addErrorToAllControllers(errorMsg);
    });
  }

  // Process snapshot data efficiently for all streams
  void _processSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) {
      // Send empty data to all streams
      _categorizedRecordsController.add({
        'today': [], 'missed': [], 'nextDay': [], 'next7Days': [], 'todayAdded': []
      });
      _allRecordsController.add({'allRecords': []});
      _subjectsController.add({'subjects': [], 'subjectCodes': {}});
      _rawDataController.add(null);
      return;
    }

    // Get the raw data
    Map<Object?, Object?> rawData = snapshot.value as Map<Object?, Object?>;

    // Cache and broadcast raw data
    _cachedRawData = rawData;
    _rawDataController.add(_cachedRawData);

    // Process for categorized view
    Map<String, List<Map<String, dynamic>>> categorizedData = _processCategorizedData(rawData);
    _categorizedRecordsController.add(categorizedData);

    // Process for all records view
    List<Map<String, dynamic>> allRecords = _processAllRecords(rawData);
    _allRecordsController.add({'allRecords': allRecords});

    // Process for subjects view (formerly SubjectDataProvider)
    _processSubjectsData(rawData);
  }

  // Process subjects data for the subjects stream
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

  // Method for categorized data processing
  Map<String, List<Map<String, dynamic>>> _processCategorizedData(Map<Object?, Object?> rawData) {
    // Calculate dates on-the-fly
    final DateTime today = DateTime.now();
    final String todayStr = today.toIso8601String().split('T')[0];
    final String nextDayStr = today.add(Duration(days: 1)).toIso8601String().split('T')[0];
    final DateTime next7Days = today.add(Duration(days: 7));

    // Pre-allocate lists
    List<Map<String, dynamic>> todayRecords = [];
    List<Map<String, dynamic>> missedRecords = [];
    List<Map<String, dynamic>> nextDayRecords = [];
    List<Map<String, dynamic>> next7DaysRecords = [];
    List<Map<String, dynamic>> todayAddedRecords = [];

    // Process records
    rawData.forEach((subjectKey, subjectValue) {
      if (subjectValue is! Map) return;

      subjectValue.forEach((codeKey, codeValue) {
        if (codeValue is! Map) return;

        codeValue.forEach((recordKey, recordValue) {
          if (recordValue is! Map) return;

          final dateScheduled = recordValue['date_scheduled'];
          final dateInitiated = recordValue['initiated_on'];
          final status = recordValue['status'];

          // Early filtering - skip disabled records
          if (dateScheduled == null || status != 'Enabled') return;

          // Create record map
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
            'only_once': recordValue['only_once'],
          };

          // Parse date only once
          final scheduledDateStr = dateScheduled.toString().split('T')[0];

          // Categorize
          if (scheduledDateStr == todayStr) {
            todayRecords.add(record);
          } else if (scheduledDateStr.compareTo(todayStr) < 0) {
            missedRecords.add(record);
          } else if (dateInitiated != null &&
              dateInitiated.toString().split('T')[0] == todayStr) {
            todayAddedRecords.add(record);
          } else if (scheduledDateStr == nextDayStr) {
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
    };
  }

  // Method for all records processing
  List<Map<String, dynamic>> _processAllRecords(Map<Object?, Object?> rawData) {
    List<Map<String, dynamic>> allRecords = [];

    rawData.forEach((subjectKey, subjectValue) {
      if (subjectValue is Map) {
        subjectValue.forEach((codeKey, codeValue) {
          if (codeValue is Map) {
            codeValue.forEach((recordKey, recordValue) {
              if (recordValue is Map) {
                var record = {
                  'subject': subjectKey.toString(),
                  'subject_code': codeKey.toString(),
                  'lecture_no': recordKey.toString(),
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

  // Force refresh of the data
  Future<void> forceDataReprocessing() async {
    if (_databaseRef != null) {
      try {
        final snapshot = await _databaseRef!.get();
        _processSnapshot(snapshot);
        return;
      } catch (error) {
        String errorMsg = 'Failed to refresh data: $error';
        _addErrorToAllControllers(errorMsg);
        throw error;
      }
    }
  }

  // Helper to add the same error to all controllers
  void _addErrorToAllControllers(String errorMsg) {
    _categorizedRecordsController.addError(errorMsg);
    _allRecordsController.addError(errorMsg);
    _subjectsController.addError(errorMsg);
    _rawDataController.addError(errorMsg);
  }

  // Reset state when user logs out
  void _resetState() {
    _cachedSubjectsData = null;
    _cachedRawData = null;
    _databaseRef = null;
  }

  // Clean up current listener to prevent memory leaks
  void _cleanupCurrentListener() {
    _databaseSubscription?.cancel();
    _databaseSubscription = null;
  }

  // Stop listening to database updates
  void stopListening() {
    _cleanupCurrentListener();
  }

  // Clean up resources
  void dispose() {
    stopListening();
    _categorizedRecordsController.close();
    _allRecordsController.close();
    _subjectsController.close();
    _rawDataController.close();
  }

  // Getter for the database reference
  DatabaseReference? get databaseRef => _databaseRef;

  // SubjectDataProvider compatibility methods
  Map<String, dynamic>? get currentSubjectsData => _cachedSubjectsData;
  dynamic get currentRawData => _cachedRawData;

  // Get schedule data as string (for compatibility)
  String getScheduleData() {
    if (_cachedRawData != null) {
      return _cachedRawData.toString();
    }
    return 'No schedule data available';
  }

  // Manual fetch method (for compatibility)
  Future<Map<String, dynamic>> fetchSubjectsAndCodes() async {
    if (_cachedSubjectsData != null) {
      return _cachedSubjectsData!;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    // Force a refresh from the database
    await forceDataReprocessing();

    // If we still don't have cached data, return empty result
    if (_cachedSubjectsData == null) {
      return {'subjects': [], 'subjectCodes': {}};
    }

    return _cachedSubjectsData!;
  }

  // Fetch only raw data (for compatibility)
  Future<dynamic> fetchRawData() async {
    if (_cachedRawData != null) {
      return _cachedRawData;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    // Force a refresh from the database
    await forceDataReprocessing();

    return _cachedRawData;
  }
}

// Backward compatibility functions from SubjectDataProvider
Future<Map<String, dynamic>> fetchSubjectsAndCodes() async {
  return await CombinedDatabaseService().fetchSubjectsAndCodes();
}

// Get the subjects stream directly
Stream<Map<String, dynamic>> getSubjectsStream() {
  return CombinedDatabaseService().subjectsStream;
}

// Backward compatibility class that uses the CombinedDatabaseService internally
class SubjectDataProvider {
  static final SubjectDataProvider _instance = SubjectDataProvider._internal();

  final CombinedDatabaseService _service = CombinedDatabaseService();

  factory SubjectDataProvider() {
    return _instance;
  }

  SubjectDataProvider._internal();

  // Forward all method calls to the CombinedDatabaseService
  Stream<Map<String, dynamic>> get subjectsStream => _service.subjectsStream;
  Stream<dynamic> get rawDataStream => _service.rawDataStream;
  Map<String, dynamic>? get currentData => _service.currentSubjectsData;
  dynamic get currentRawData => _service.currentRawData;

  String getScheduleData() => _service.getScheduleData();
  Future<Map<String, dynamic>> fetchSubjectsAndCodes() => _service.fetchSubjectsAndCodes();
  Future<dynamic> fetchRawData() => _service.fetchRawData();
  void dispose() {} // No-op, let CombinedDatabaseService handle real disposal
}

// Backward compatibility class that uses the CombinedDatabaseService internally
class UnifiedDatabaseService {
  static final UnifiedDatabaseService _instance = UnifiedDatabaseService._internal();

  final CombinedDatabaseService _service = CombinedDatabaseService();

  factory UnifiedDatabaseService() {
    return _instance;
  }

  UnifiedDatabaseService._internal();

  // Forward all method calls to the CombinedDatabaseService
  Stream<Map<String, List<Map<String, dynamic>>>> get categorizedRecordsStream =>
      _service.categorizedRecordsStream;

  Stream<Map<String, dynamic>> get allRecordsStream => _service.allRecordsStream;

  void initialize() => _service.initialize();
  Future<void> forceDataReprocessing() => _service.forceDataReprocessing();
  void stopListening() => _service.stopListening();
  void dispose() {} // No-op, let CombinedDatabaseService handle real disposal
  DatabaseReference? get databaseRef => _service.databaseRef;
}