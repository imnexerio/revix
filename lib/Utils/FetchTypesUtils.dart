import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'GuestAuthService.dart';
import 'LocalDatabaseService.dart';

class FetchtrackingTypeUtils {
  static Future<List<String>> fetchtrackingType() async {
    List<String> data = [];
    try {
      // Check if we're in guest mode
      bool isGuestMode = await GuestAuthService.isGuestMode();
      
      if (isGuestMode) {
        // Fetch from local database for guest users
        final profileData = await LocalDatabaseService().getProfileData('custom_trackingType', defaultValue: ['Lectures', 'Others']);
        if (profileData is List) {
          data = List<String>.from(profileData);
        } else {
          // Fallback to default values
          data = ['Lectures', 'Others'];
        }
      } else {
        // Fetch from Firebase for authenticated users
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          String uid = user.uid;
          DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data/custom_trackingType');
          DataSnapshot snapshot = await databaseRef.get();

          if (snapshot.exists) {
            data = List<String>.from(snapshot.value as List);
          }
        }
      }
    } catch (e) {
      // Fallback to default values on error
      data = ['Lectures', 'Others'];
    }
    return data;
  }
}