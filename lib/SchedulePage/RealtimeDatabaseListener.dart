import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RealtimeDatabaseListener {
  final StreamController<Map<String, List<Map<String, dynamic>>>> _recordsController;
  final String _todayStr;
  final String _nextDayStr;
  final DateTime _today;
  final DateTime _next7Days;
  DatabaseReference? _databaseRef;

  RealtimeDatabaseListener(this._recordsController, this._todayStr, this._nextDayStr, this._today, this._next7Days);

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

    // Process records more efficiently
    rawData.forEach((subjectKey, subjectValue) {
      if (subjectValue is! Map) return;

      subjectValue.forEach((codeKey, codeValue) {
        if (codeValue is! Map) return;

        codeValue.forEach((recordKey, recordValue) {
          if (recordValue is! Map) return;

          final dateScheduled = recordValue['date_scheduled'];
          final dateLearnt = recordValue['date_learnt'];
          final status = recordValue['status'];

          // Early filtering - skip disabled records
          if (dateScheduled == null || status != 'Enabled') return;

          // Create record map - only once per record
          final Map<String, dynamic> record = {
            'subject': subjectKey.toString(),
            'subject_code': codeKey.toString(),
            'lecture_no': recordKey.toString(),
            'date_scheduled': dateScheduled.toString(),
            'reminder_time': recordValue['reminder_time'],
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
          };

          // Parse date only once
          final scheduledDateStr = dateScheduled.toString().split('T')[0];

          // Efficient categorization
          if (scheduledDateStr == _todayStr) {
            todayRecords.add(record);
          } else if (scheduledDateStr.compareTo(_todayStr) < 0) {
            // If scheduled date is before today
            missedRecords.add(record);
          } else if (dateLearnt != null &&
              dateLearnt.toString().split('T')[0] == _todayStr) {
            todayAddedRecords.add(record);
          } else if (scheduledDateStr == _nextDayStr) {
            nextDayRecords.add(record);
          } else {
            // Only parse full date object if needed for the 7-day comparison
            final scheduledDate = DateTime.parse(dateScheduled.toString());
            if (scheduledDate.isAfter(_today) && scheduledDate.isBefore(_next7Days)) {
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