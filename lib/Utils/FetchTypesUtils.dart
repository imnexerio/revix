import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FetchtrackingTypeUtils {
  static Future<List<String>> fetchtrackingType() async {
    List<String> data = [];
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data/custom_trackingType');
      DataSnapshot snapshot = await databaseRef.get();

      if (snapshot.exists) {
        data = List<String>.from(snapshot.value as List);
      }
    } catch (e) {
      // Handle error
      // print('Error fetching tracking types: $e');
    }
    return data;
  }
}