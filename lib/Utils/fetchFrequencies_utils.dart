import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'GuestAuthService.dart';
import 'LocalDatabaseService.dart';

class FetchFrequenciesUtils {
  static Future<Map<String, dynamic>> fetchFrequencies() async {
    Map<String, dynamic> data = {};
    
    // Check if the user is in guest mode
    bool isGuest = await GuestAuthService.isGuestMode();
    
    if (isGuest) {
      // Get data from Hive for guest users
      final localDb = LocalDatabaseService();
      try {
        // Get the custom_frequencies from the profile data
        final frequencies = await localDb.getProfileData('custom_frequencies', defaultValue: {});
        if (frequencies != null) {
          data = Map<String, dynamic>.from(frequencies);
        } else {
          // Use default frequencies if none are found
          data = {
            'Default': [1, 4, 7, 15, 30, 60],
            'Priority': [1, 3, 4, 5, 7, 15, 25, 30]
          };
        }
      } catch (e) {
        // Handle error
        // print('Error fetching frequencies from local DB: $e');
      }
    } else {
      // Get data from Firebase for logged-in users
      try {
        String uid = FirebaseAuth.instance.currentUser!.uid;
        DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data/custom_frequencies');
        DataSnapshot snapshot = await databaseRef.get();
        if (snapshot.exists) {
          data = Map<String, dynamic>.from(snapshot.value as Map);
        }
      } catch (e) {
        // Handle error
        // print('Error fetching frequencies from Firebase: $e');
      }
    }
    
    // Ensure we always return at least the default frequencies
    if (data.isEmpty) {
      data = {
        'Default': [1, 4, 7, 15, 30, 60],
      };
    }
    
    return data;
  }
}