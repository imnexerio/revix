import 'package:firebase_database/firebase_database.dart';

Future<String?> getProfilePicture(String uid) async {
  try {
    DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data');
    DataSnapshot snapshot = await databaseRef.child('profile_picture').get();
    if (snapshot.exists) {
      return snapshot.value as String?;
    }
  } catch (e) {
    // Handle the error appropriately in the calling function
    throw Exception('Error retrieving profile picture: $e');
  }
  return null;
}