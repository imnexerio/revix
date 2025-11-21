import 'package:flutter/material.dart';
import 'package:revix/Utils/CustomSnackBar.dart';
import '../Utils/FirebaseAuthService.dart';
import '../Utils/customSnackBar_error.dart';

Future<void> sendVerificationEmail(BuildContext context) async {
  try {
    final FirebaseAuthService _authService = FirebaseAuthService();
    await _authService.sendEmailVerification();


      customSnackBar(
        context: context,
        message: 'Verification email sent successfully after verification restart the app',
    );
  } catch (e) {
    customSnackBar_error(
      context: context,
      message: 'Failed to send verification email: $e',
    );
  }
}