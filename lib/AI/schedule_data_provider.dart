import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ScheduleDataProvider {
  User? user;
  late String uid;
  late DatabaseReference ref;

  ScheduleDataProvider() {
    user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }
    uid = user!.uid;
    ref = FirebaseDatabase.instance.ref('users/$uid/user_data');
    // print('ScheduleDataProvider initialized for user $uid');
  }

  Future<DataSnapshot> getData() async {
    final dataSnapshot = await ref.get();
    return dataSnapshot;
  }

  Future<String> getScheduleData({bool forceRefresh = false}) async {
    try {
      final dataSnapshot = await getData();
      final scheduleData = dataSnapshot.value;

      if (scheduleData != null) {
        return scheduleData.toString();
      }
    } catch (e) {
      print('Error fetching schedule data: $e');
    }

    return 'No schedule data available';
  }
}