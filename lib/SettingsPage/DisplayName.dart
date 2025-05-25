import '../Utils/FirebaseDatabaseService.dart';

Future<String> getDisplayName() async {
  final FirebaseDatabaseService _databaseService = FirebaseDatabaseService();
  return _databaseService.currentUserDisplayName ?? 'User';
}