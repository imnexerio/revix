import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';


Stream<Map<String, dynamic>> listenToCodeData(String selectedSubject, String selectedSubjectCode) {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('No authenticated user');
  }

  String uid = user.uid;
  DatabaseReference ref = FirebaseDatabase.instance.ref('users/$uid/user_data/$selectedSubject/$selectedSubjectCode');

  // Convert the Firebase event stream to a stream of maps
  return ref.onValue.map((event) {
    if (event.snapshot.exists) {
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    } else {
      return <String, dynamic>{};
    }
  });
}