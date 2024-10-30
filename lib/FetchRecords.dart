import 'package:firebase_database/firebase_database.dart';

Future<Map<String, dynamic>> fetchAllRecords() async {
  DatabaseReference ref = FirebaseDatabase.instance.ref();
  DataSnapshot snapshot = await ref.get();
  if (snapshot.exists) {
    return Map<String, dynamic>.from(snapshot.value as Map);
  } else {
    throw Exception('No data found');
  }
}