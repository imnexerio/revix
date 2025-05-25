import '../Utils/FirebaseDatabaseService.dart';

class ProfileDataService {
  final FirebaseDatabaseService _firebaseService = FirebaseDatabaseService();

  Future<void> saveCompletionTarget(String lectureType, String targetValue) async {
    await _firebaseService.saveHomePageCompletionTarget(lectureType, targetValue);
  }

  Future<Map<String, int>> getCompletionTargets() async {
    return await _firebaseService.fetchHomePageCompletionTargets();
  }
}