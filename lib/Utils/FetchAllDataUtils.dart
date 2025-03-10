import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class Fetchalldatautils{
  static Future<DataSnapshot> getUserDataSnapshot() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }
    String uid = user.uid;
    DatabaseReference ref = FirebaseDatabase.instance.ref('users/$uid/user_data');
    DataSnapshot snapshot = await ref.get();
    return snapshot;
  }
}