import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfileDataService {
  User? get currentUser => FirebaseAuth.instance.currentUser;

  DatabaseReference getUserProfileRef(String path) {
    if (currentUser == null) {
      throw Exception('No authenticated user found');
    }
    return FirebaseDatabase.instance.ref('users/${currentUser!.uid}/profile_data/$path');
  }

  DatabaseReference getCompletionTargetRef() {
    return getUserProfileRef('home_page/customCompletionTarget');
  }

  Future<String> getCompletionTarget() async {
    DataSnapshot snapshot = await getCompletionTargetRef().get();
    return snapshot.exists ? snapshot.value.toString() : '';
  }

  Future<void> saveCompletionTarget(String targetValue) async {
    await getCompletionTargetRef().set(targetValue);
  }
}