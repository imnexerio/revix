import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:retracker/Utils/platform_utils.dart';
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
  StreamSubscription<DatabaseEvent>? _databaseSubscription;
  bool _isGuestMode = false;

  final StreamController<Map<String, List<Map<String, dynamic>>>> _categorizedRecordsController =
  StreamController<Map<String, List<Map<String, dynamic>>>>.broadcast();

  final StreamController<Map<String, dynamic>> _allRecordsController =
  StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _subjectsController =
  StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<dynamic> _rawDataController =
  StreamController<dynamic>.broadcast();
  Stream<Map<String, List<Map<String, dynamic>>>> get categorizedRecordsStream =>
      _isGuestMode ? _localDatabase.categorizedRecordsStream : _categorizedRecordsController.stream;

  Stream<Map<String, dynamic>> get allRecordsStream =>
      _isGuestMode ? _localDatabase.allRecordsStream : _allRecordsController.stream;

  Stream<Map<String, dynamic>> get subjectsStream =>
      _isGuestMode ? _localDatabase.subjectsStream : _subjectsController.stream;

  Stream<dynamic> get rawDataStream =>
      _isGuestMode ? _localDatabase.rawDataStream : _rawDataController.stream;

  Map<String, dynamic>? _cachedSubjectsData;
  dynamic _cachedRawData;
  Map<String, List<Map<String, dynamic>>>? _cachedCategorizedData;
  void initialize() {
    _checkGuestMode().then((_) {
      if (_isGuestMode) {
        _initializeLocalDatabase();
      } else {
        User? user = _auth.currentUser;
        if (user == null) {
          _addErrorToAllControllers('No authenticated user');
          return;
        }
        _initialize(user.uid);
      }
    });
  }

  Future<void> _checkGuestMode() async {
    _isGuestMode = await GuestAuthService.isGuestMode();
  }

  Future<void> _initializeLocalDatabase() async {
    await _localDatabase.initializeWithDefaultData();
  }

  void _initialize(String uid) {
    _databaseRef = _database.ref('users/$uid/user_data');
    _setupDatabaseListener();
  }

  void _setupDatabaseListener() {
    _databaseSubscription?.cancel();

    if (_databaseRef == null) return;

    _databaseSubscription = _databaseRef!.onValue.listen((event) {
      if (!event.snapshot.exists) {
        Map<String, List<Map<String, dynamic>>> emptyData = {
          'today': [], 'missed': [], 'nextDay': [], 'next7Days': [], 'todayAdded': [], 'noreminderdate': []
        };
        _cachedCategorizedData = emptyData;
        _categorizedRecordsController.add(emptyData);
        _allRecordsController.add({'allRecords': []});
        _subjectsController.add({'subjects': [], 'subjectCodes': {}});
        _rawDataController.add(null);

        _updateHomeWidget([], [], []);
        return;
      }
      _processSnapshot(event.snapshot);

    }, onError: (error) {
      String errorMsg = 'Failed to fetch data: $error';
      _addErrorToAllControllers(errorMsg);
    });
  }

  void _processSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) {
      Map<String, List<Map<String, dynamic>>> emptyData = {
        'today': [], 'missed': [], 'nextDay': [], 'next7Days': [], 'todayAdded': [], 'noreminderdate': []
      };
      _cachedCategorizedData = emptyData;
      _categorizedRecordsController.add(emptyData);
      _allRecordsController.add({'allRecords': []});
      _subjectsController.add({'subjects': [], 'subjectCodes': {}});
      _rawDataController.add(null);

      _updateHomeWidget([], [], []);
      return;
    }

    Map<Object?, Object?> rawData = snapshot.value as Map<Object?, Object?>;

    _cachedRawData = rawData;
    _rawDataController.add(_cachedRawData);

    Map<String, List<Map<String, dynamic>>> categorizedData = _processCategorizedData(rawData);
    _cachedCategorizedData = categorizedData;
    _categorizedRecordsController.add(categorizedData);

    List<Map<String, dynamic>> allRecords = _processAllRecords(rawData);
    _allRecordsController.add({'allRecords': allRecords});

    _processSubjectsData(rawData);

    if (PlatformUtils.instance.isAndroid) {
      _updateHomeWidget(categorizedData['today'] ?? [],
          categorizedData['missed'] ?? [],
          categorizedData['noreminderdate'] ?? []);
    }
  }

  void _updateHomeWidget(List<Map<String, dynamic>> todayRecords,List<Map<String, dynamic>> missedRecords,List<Map<String, dynamic>> noReminderDateRecords) {
      HomeWidgetService.updateWidgetData(todayRecords, missedRecords, noReminderDateRecords);
  }

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
  Future<void> forceDataReprocessing() async {
    if (_isGuestMode) {
      await _localDatabase.forceDataReprocessing();
      return;
    }
    
    if (_databaseRef != null) {
      try {
        final snapshot = await _databaseRef!.get();
        _processSnapshot(snapshot);
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
    _subjectsController.addError(errorMsg);
    _rawDataController.addError(errorMsg);
  }

  void _resetState() {
    _cachedSubjectsData = null;
    _cachedRawData = null;
    _cachedCategorizedData = null;
    _databaseRef = null;
  }

  void _cleanupCurrentListener() {
    _databaseSubscription?.cancel();
    _databaseSubscription = null;
  }
  void stopListening() {
    if (_isGuestMode) {
      _localDatabase.stopListening();
    } else {
      _cleanupCurrentListener();
    }
  }

  void dispose() {
    if (_isGuestMode) {
      _localDatabase.dispose();
    } else {
      stopListening();
      _categorizedRecordsController.close();
      _allRecordsController.close();
      _subjectsController.close();
      _rawDataController.close();
    }
  }

  DatabaseReference? get databaseRef => _databaseRef;
  Map<String, dynamic>? get currentSubjectsData => 
      _isGuestMode ? _localDatabase.currentSubjectsData : _cachedSubjectsData;
      
  dynamic get currentRawData => 
      _isGuestMode ? _localDatabase.currentRawData : _cachedRawData;
      
  Map<String, List<Map<String, dynamic>>>? get currentCategorizedData => 
      _isGuestMode ? _localDatabase.currentCategorizedData : _cachedCategorizedData;
  String getScheduleData() {
    if (_isGuestMode) {
      return _localDatabase.getScheduleData();
    }
    if (_cachedRawData != null) {
      return _cachedRawData.toString();
    }
    return 'No schedule data available';
  }

  Future<Map<String, dynamic>> fetchSubjectsAndCodes() async {
    if (_isGuestMode) {
      return await _localDatabase.fetchSubjectsAndCodes();
    }
    
    if (_cachedSubjectsData != null) {
      return _cachedSubjectsData!;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    await forceDataReprocessing();

    if (_cachedSubjectsData == null) {
      return {'subjects': [], 'subjectCodes': {}};
    }

    return _cachedSubjectsData!;
  }

  Future<dynamic> fetchRawData() async {
    if (_isGuestMode) {
      return await _localDatabase.fetchRawData();
    }
    
    if (_cachedRawData != null) {
      return _cachedRawData;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    await forceDataReprocessing();

    return _cachedRawData;
  }
}

Future<Map<String, dynamic>> fetchSubjectsAndCodes() async {
  return await CombinedDatabaseService().fetchSubjectsAndCodes();
}

Stream<Map<String, dynamic>> getSubjectsStream() {
  return CombinedDatabaseService().subjectsStream;
}

class SubjectDataProvider {
  static final SubjectDataProvider _instance = SubjectDataProvider._internal();

  final CombinedDatabaseService _service = CombinedDatabaseService();

  factory SubjectDataProvider() {
    return _instance;
  }

  SubjectDataProvider._internal();

  Stream<Map<String, dynamic>> get subjectsStream => _service.subjectsStream;
  Stream<dynamic> get rawDataStream => _service.rawDataStream;
  Map<String, dynamic>? get currentData => _service.currentSubjectsData;
  dynamic get currentRawData => _service.currentRawData;

  String getScheduleData() => _service.getScheduleData();
  Future<Map<String, dynamic>> fetchSubjectsAndCodes() => _service.fetchSubjectsAndCodes();
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
}