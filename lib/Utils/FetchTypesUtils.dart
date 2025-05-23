import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'GuestAuthService.dart';
import 'LocalDatabaseService.dart';

class FetchtrackingTypeUtils {
  static Future<List<String>> fetchtrackingType() async {
    List<String> data = [];
      try {
      // Check if user is in guest mode
      if (await GuestAuthService.isGuestMode()) {
        // Fetch from local database
        final localDb = LocalDatabaseService();
        final profileData = await localDb.getProfileData('custom_trackingType', defaultValue: []);
        
        if (profileData.isNotEmpty) {
          data = List<String>.from(profileData);
        }
      } else {
        // Fetch from Firebase for authenticated users
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          String uid = currentUser.uid;
          DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data/custom_trackingType');
          DataSnapshot snapshot = await databaseRef.get();

          if (snapshot.exists) {
            data = List<String>.from(snapshot.value as List);
          }
        }
      }
    } catch (e) {
      print('Error fetching tracking types: $e');
    }
    return data;
  }
}