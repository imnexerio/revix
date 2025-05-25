import '../Utils/FirebaseDatabaseService.dart';

Future<String?> getProfilePicture(String uid) async {
  try {
    final firebaseService = FirebaseDatabaseService();
    return await firebaseService.getProfilePicture();
  } catch (e) {
    // Handle the error appropriately in the calling function
    throw Exception('Error retrieving profile picture: $e');
  }
}