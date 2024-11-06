import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

Future<Map<String, List<Map<String, dynamic>>>> getRecords() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('No authenticated user');
  }
  String uid = user.uid;
  try {
    DatabaseReference ref = FirebaseDatabase.instance.ref('users/$uid/user_data');
    DataSnapshot snapshot = await ref.get();

    if (!snapshot.exists) {
      return {'today': [], 'missed': [], 'nextDay': [], 'next7Days': [], 'todayAdded': []};
    }

    Map<Object?, Object?> rawData = snapshot.value as Map<Object?, Object?>;
    List<Map<String, dynamic>> todayRecords = [];
    List<Map<String, dynamic>> missedRecords = [];
    List<Map<String, dynamic>> nextDayRecords = [];
    List<Map<String, dynamic>> next7DaysRecords = [];
    List<Map<String, dynamic>> todayAddedRecords = [];
    DateTime today = DateTime.now();
    DateTime nextDay = today.add(Duration(days: 1));
    DateTime next7Days = today.add(Duration(days: 7));
    String todayStr = today.toIso8601String().split('T')[0];
    String nextDayStr = nextDay.toIso8601String().split('T')[0];

    rawData.forEach((subjectKey, subjectValue) {
      if (subjectValue is Map) {
        (subjectValue).forEach((codeKey, codeValue) {
          if (codeValue is Map) {
            (codeValue).forEach((recordKey, recordValue) {
              if (recordValue is Map) {
                var dateScheduled = recordValue['date_scheduled'];
                var dateLearnt = recordValue['date_learnt'];
                var status = recordValue['status'];

                if (dateScheduled != null && status == 'Enabled') {
                  DateTime scheduledDate = DateTime.parse(dateScheduled.toString());
                  Map<String, dynamic> record = {
                    'subject': subjectKey.toString(),
                    'subject_code': codeKey.toString(),
                    'lecture_no': recordKey.toString(),
                    'date_scheduled': dateScheduled.toString(),
                    'lecture_type': recordValue['lecture_type'],
                    'date_learnt': recordValue['date_learnt'],
                    'date_revised': recordValue['date_revised'],
                    'description': recordValue['description'],
                    'missed_revision': recordValue['missed_revision'],
                    'no_revision': recordValue['no_revision'],
                    'revision_frequency': recordValue['revision_frequency'],
                    'status': recordValue['status'],
                  };

                  if (scheduledDate.toIso8601String().split('T')[0] == todayStr) {
                    todayRecords.add(record);
                  } else if (scheduledDate.isBefore(today)) {
                    missedRecords.add(record);
                  } else if (DateTime.parse(dateLearnt.toString()).toIso8601String().split('T')[0] == todayStr) {
                    todayAddedRecords.add(record);
                  } else if (scheduledDate.toIso8601String().split('T')[0] == nextDayStr) {
                    nextDayRecords.add(record);
                  } else if (scheduledDate.isAfter(today) && scheduledDate.isBefore(next7Days)) {
                    next7DaysRecords.add(record);
                  }
                }
              }
            });
          }
        });
      }
    });

    return {
      'today': todayRecords,
      'missed': missedRecords,
      'nextDay': nextDayRecords,
      'next7Days': next7DaysRecords,
      'todayAdded': todayAddedRecords,
    };
  } catch (e) {
    throw Exception('Failed to fetch records');
  }
}