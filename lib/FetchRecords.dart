// import 'package:firebase_database/firebase_database.dart';

// Future<Map<String, dynamic>> fetchAllRecords() async {
//   DatabaseReference ref = FirebaseDatabase.instance.ref();
//   DataSnapshot snapshot = await ref.get();
//   if (snapshot.exists) {
//     return Map<String, dynamic>.from(snapshot.value as Map);
//   } else {
//     throw Exception('No data found');
//   }
// }

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

Future<Map<String, dynamic>> fetchAllRecords() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('No authenticated user');
  }
  String uid = user.uid;
  DatabaseReference ref = FirebaseDatabase.instance.ref('users/$uid');
  DataSnapshot snapshot = await ref.get();
  if (snapshot.exists) {
    return Map<String, dynamic>.from(snapshot.value as Map);
  } else {
    throw Exception('No data found');
  }
}