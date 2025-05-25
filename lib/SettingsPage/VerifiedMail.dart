import '../Utils/FirebaseDatabaseService.dart';

Future<bool> isEmailVerified() async {
  final FirebaseDatabaseService _databaseService = FirebaseDatabaseService();
  await _databaseService.reloadUser();
  return _databaseService.isEmailVerified;
}