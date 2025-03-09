import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfileDataService {
  // Get the current authenticated user
  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Get reference to a specific path in the user's profile data
  DatabaseReference getUserProfileRef(String path) {
    if (currentUser == null) {
      throw Exception('No authenticated user found');
    }
    return FirebaseDatabase.instance.ref('users/${currentUser!.uid}/profile_data/$path');
  }

  // Get home page completion target reference
  DatabaseReference getCompletionTargetRef() {
    return getUserProfileRef('home_page/customCompletionTarget');
  }

  // Fetch completion target value
  Future<String> getCompletionTarget() async {
    DataSnapshot snapshot = await getCompletionTargetRef().get();
    return snapshot.exists ? snapshot.value.toString() : '';
  }

  // Save completion target value
  Future<void> saveCompletionTarget(String targetValue) async {
    await getCompletionTargetRef().set(targetValue);
  }
}