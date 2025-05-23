import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'GuestAuthService.dart';
import 'LocalDatabaseService.dart';

class FetchFrequenciesUtils {
  static Future<Map<String, dynamic>> fetchFrequencies() async {
    Map<String, dynamic> data = {};
      try {
      // Check if user is in guest mode
      if (await GuestAuthService.isGuestMode()) {
        // Fetch from local database
        final localDb = LocalDatabaseService();
        final profileData = await localDb.getProfileData('custom_frequencies', defaultValue: {});
        
        if (profileData.isNotEmpty) {
          data = Map<String, dynamic>.from(profileData);
        }
      } else {
        // Fetch from Firebase for authenticated users
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          String uid = currentUser.uid;
          DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data/custom_frequencies');
          DataSnapshot snapshot = await databaseRef.get();
          if (snapshot.exists) {
            data = Map<String, dynamic>.from(snapshot.value as Map);
          }
        }
      }
    } catch (e) {
      // Handle error
      print('Error fetching frequencies: $e');
    }
    return data;
  }
}