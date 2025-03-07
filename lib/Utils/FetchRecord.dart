import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:retracker/Utils/FetchAllDataUtils.dart';

class FetchRecord {
  // Add a stream controller to broadcast changes
  final StreamController<Map<String, dynamic>> _recordsController =
  StreamController<Map<String, dynamic>>.broadcast();

  // Expose a stream that components can listen to
  Stream<Map<String, dynamic>> get recordsStream => _recordsController.stream;

  // Reference to the database listener
  StreamSubscription<DatabaseEvent>? _databaseSubscription;

  // Method to start listening to changes
  void startRealTimeUpdates() {
    // Cancel any existing subscription
    _databaseSubscription?.cancel();

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DatabaseReference ref = FirebaseDatabase.instance.ref('users/${user.uid}/user_data');

    _databaseSubscription = ref.onValue.listen((event) {
      if (!event.snapshot.exists) {
        _recordsController.add({'allRecords': []});
        return;
      }

      Map<Object?, Object?> rawData = event.snapshot.value as Map<Object?, Object?>;
      List<Map<String, dynamic>> allRecords = [];

      // Process the data (same logic as in getAllRecords)
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

      _recordsController.add({'allRecords': allRecords});
    });
  }

  // Method to stop listening (important for resource optimization)
  void stopRealTimeUpdates() {
    _databaseSubscription?.cancel();
    _databaseSubscription = null;
  }

  // Clean up resources
  void dispose() {
    stopRealTimeUpdates();
    _recordsController.close();
  }

  Future<Map<String, dynamic>> getAllRecords() async {
    try {
      DataSnapshot snapshot = await Fetchalldatautils.getUserDataSnapshot();

      if (!snapshot.exists) {
        return {'allRecords': []};
      }

      Map<Object?, Object?> rawData = snapshot.value as Map<Object?, Object?>;

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
      return {'allRecords': allRecords};
    } catch (e) {
      throw Exception('Failed to fetch records');
    }
  }
}