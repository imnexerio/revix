import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

Future<Map<String, dynamic>> fetchSubjectsAndCodes() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('No authenticated user');
  }
  String uid = user.uid;
  DatabaseReference ref = FirebaseDatabase.instance.ref('users/$uid/user_data');
  DataSnapshot snapshot = await ref.get();

  if (snapshot.exists) {
    Map<Object?, Object?> subject_data_util = snapshot.value as Map<Object?, Object?>;
    List<String> subjects = subject_data_util.keys.map((key) => key.toString()).toList();
    Map<String, List<String>> subjectCodes = {};

    subject_data_util.forEach((subject, value) {
      if (value is Map) {
        subjectCodes[subject.toString()] =
            value.keys.map((code) => code.toString()).toList();
      }
    });

    return {
      'subjects': subjects,
      'subjectCodes': subjectCodes,
    };
  } else {
    throw Exception('No subject_data_util found on server');
  }
}