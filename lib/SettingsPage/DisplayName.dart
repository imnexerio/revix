import 'package:firebase_auth/firebase_auth.dart';

Future<String> getDisplayName() async {
  User? user = FirebaseAuth.instance.currentUser;
  return user?.displayName ?? 'User';
}