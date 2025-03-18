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
  }

  Future<DataSnapshot> getData() async {
    final dataSnapshot = await ref.get();
    print('Getting schedule data: ${dataSnapshot.value}');
    return dataSnapshot;
  }

  Future<String> getScheduleData() async {
    final dataSnapshot = await getData();
    // Assuming the schedule data is stored under a key named 'schedule'
    final scheduleData = dataSnapshot.value;
    return scheduleData != null ? scheduleData.toString() : 'No schedule data available';
  }
}