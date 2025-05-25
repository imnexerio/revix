import '../Utils/FirebaseAuthService.dart';

Future<bool> isEmailVerified() async {
  final FirebaseAuthService _authService = FirebaseAuthService();
  await _authService.reloadUser();
  return _authService.isEmailVerified;
}