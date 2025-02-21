import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FetchFrequenciesUtils {
  static Future<Map<String, dynamic>> fetchFrequencies() async {
    Map<String, dynamic> data = {};
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data/custom_frequencies');
      DataSnapshot snapshot = await databaseRef.get();
      if (snapshot.exists) {
        data = Map<String, dynamic>.from(snapshot.value as Map);
      }
    } catch (e) {
      // Handle error
      // print('Error fetching frequencies: $e');
    }
    return data;
  }
}