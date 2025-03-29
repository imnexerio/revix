import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UnifiedDatabaseService {
  // Stream controllers for different data views
  final StreamController<Map<String, List<Map<String, dynamic>>>> _categorizedRecordsController =
  StreamController<Map<String, List<Map<String, dynamic>>>>.broadcast();

  final StreamController<Map<String, dynamic>> _allRecordsController =
  StreamController<Map<String, dynamic>>.broadcast();

  // Expose streams that components can listen to
  Stream<Map<String, List<Map<String, dynamic>>>> get categorizedRecordsStream =>
      _categorizedRecordsController.stream;

  Stream<Map<String, dynamic>> get allRecordsStream =>
      _allRecordsController.stream;

  // Firebase reference
  DatabaseReference? _databaseRef;
  StreamSubscription<DatabaseEvent>? _databaseSubscription;

  // Initialize the service
  void initialize() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _categorizedRecordsController.addError('No authenticated user');
      _allRecordsController.addError('No authenticated user');
      return;
    }

    String uid = user.uid;
    _databaseRef = FirebaseDatabase.instance.ref('users/$uid/user_data');

    // Set up the single database listener
    _setupDatabaseListener();
  }

  void _setupDatabaseListener() {
    // Cancel existing subscription if any
    _databaseSubscription?.cancel();

    if (_databaseRef == null) return;

    _databaseSubscription = _databaseRef!.onValue.listen((event) {
      if (!event.snapshot.exists) {
        // Send empty data to both streams
        _categorizedRecordsController.add({
          'today': [], 'missed': [], 'nextDay': [], 'next7Days': [], 'todayAdded': []
        });
        _allRecordsController.add({'allRecords': []});
        return;
      }

      // Process data once for both streams
      _processSnapshot(event.snapshot);

    }, onError: (error) {
      String errorMsg = 'Failed to fetch records: $error';
      _categorizedRecordsController.addError(errorMsg);
      _allRecordsController.addError(errorMsg);
    });
  }

  // Process snapshot data and distribute to both streams
  void _processSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) {
      _categorizedRecordsController.add({
        'today': [], 'missed': [], 'nextDay': [], 'next7Days': [], 'todayAdded': []
      });
      _allRecordsController.add({'allRecords': []});
      return;
    }

    // Get the raw data
    Map<Object?, Object?> rawData = snapshot.value as Map<Object?, Object?>;

    // Process for categorized view
    Map<String, List<Map<String, dynamic>>> categorizedData = _processCategorizedData(rawData);
    _categorizedRecordsController.add(categorizedData);

    // Process for all records view
    List<Map<String, dynamic>> allRecords = _processAllRecords(rawData);
    _allRecordsController.add({'allRecords': allRecords});
  }

  // Method for categorized data processing (similar to RealtimeDatabaseListener._processSnapshot)
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

  // Method for all records processing (similar to FetchRecord logic)
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
        String errorMsg = 'Failed to refresh records: $error';
        _categorizedRecordsController.addError(errorMsg);
        _allRecordsController.addError(errorMsg);
        throw error;
      }
    }
  }

  // Stop listening to database updates
  void stopListening() {
    _databaseSubscription?.cancel();
    _databaseSubscription = null;
  }

  // Clean up resources
  void dispose() {
    stopListening();
    _categorizedRecordsController.close();
    _allRecordsController.close();
  }

  // Getter for the database reference
  DatabaseReference? get databaseRef => _databaseRef;
}