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

  DatabaseReference getCompletionTargetsRef() {
    return getUserProfileRef('home_page/completionTargets');
  }

  DatabaseReference getCompletionTargetForLectureTypeRef(String lectureType) {
    return getCompletionTargetsRef().child(lectureType);
  }

  Future<void> saveCompletionTarget(String lectureType, String targetValue) async {
    await getCompletionTargetForLectureTypeRef(lectureType).set(targetValue);
  }

  Future<Map<String, int>> getCompletionTargets() async {
    final snapshot = await getCompletionTargetsRef().get();
    Map<String, int> targets = {};

    if (snapshot.exists) {
      Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        targets[key.toString()] = int.parse(value.toString());
      });
    }

    return targets;
  }
}