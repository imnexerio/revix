import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RealtimeDatabaseListener {
  final StreamController<Map<String, List<Map<String, dynamic>>>> _recordsController;
  DatabaseReference? _databaseRef;

  // Remove date parameters from constructor
  RealtimeDatabaseListener(this._recordsController);

  void setupDatabaseListener() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _recordsController.addError('No authenticated user');
      return;
    }

    String uid = user.uid;
    _databaseRef = FirebaseDatabase.instance.ref('users/$uid/user_data');

    _databaseRef!.onValue.listen((event) {
      if (!event.snapshot.exists) {
        _recordsController.add({
          'today': [], 'missed': [], 'nextDay': [], 'next7Days': [], 'todayAdded': []
        });
        return;
      }

      // Process data and add to stream
      Map<String, List<Map<String, dynamic>>> processedData = _processSnapshot(event.snapshot);
      _recordsController.add(processedData);
    }, onError: (error) {
      _recordsController.addError('Failed to fetch records: $error');
    });
  }

  Map<String, List<Map<String, dynamic>>> _processSnapshot(DataSnapshot snapshot) {
    // Calculate dates on-the-fly for each processing
    final DateTime today = DateTime.now();
    final String todayStr = today.toIso8601String().split('T')[0];
    final String nextDayStr = today.add(Duration(days: 1)).toIso8601String().split('T')[0];
    final DateTime next7Days = today.add(Duration(days: 7));

    if (!snapshot.exists) {
      return {'today': [], 'missed': [], 'nextDay': [], 'next7Days': [], 'todayAdded': []};
    }

    Map<Object?, Object?> rawData = snapshot.value as Map<Object?, Object?>;

    // Pre-allocate with estimated capacity
    List<Map<String, dynamic>> todayRecords = [];
    List<Map<String, dynamic>> missedRecords = [];
    List<Map<String, dynamic>> nextDayRecords = [];
    List<Map<String, dynamic>> next7DaysRecords = [];
    List<Map<String, dynamic>> todayAddedRecords = [];

    // Process records with fresh date calculations
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

          // Create record map - only once per record
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

          // Efficient categorization using freshly calculated dates
          if (scheduledDateStr == todayStr) {
            todayRecords.add(record);
          } else if (scheduledDateStr.compareTo(todayStr) < 0) {
            // If scheduled date is before today
            missedRecords.add(record);
          } else if (dateInitiated != null &&
              dateInitiated.toString().split('T')[0] == todayStr) {
            todayAddedRecords.add(record);
          } else if (scheduledDateStr == nextDayStr) {
            nextDayRecords.add(record);
          } else {
            // Only parse full date object if needed for the 7-day comparison
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

  DatabaseReference? get databaseRef => _databaseRef;
}