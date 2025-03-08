import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

Future<Map<String, dynamic>> getStoredCodeData(String selectedSubject,String selectedsubjectCode) async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('No authenticated user');
  }
  String uid = user.uid;
  DatabaseReference ref = FirebaseDatabase.instance.ref('users/$uid/user_data/$selectedSubject/$selectedsubjectCode');
  DataSnapshot snapshot = await ref.get();
  if (snapshot.exists) {
    return Map<String, dynamic>.from(snapshot.value as Map);
  } else {
    throw Exception('No data found in Firebase for subject code: $selectedsubjectCode');
  }
}