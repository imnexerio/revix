import 'package:flutter/material.dart';
import 'package:retracker/Utils/CustomSnackBar.dart';
import '../Utils/FirebaseDatabaseService.dart';

Future<void> sendVerificationEmail(BuildContext context) async {
  try {
    final FirebaseDatabaseService _databaseService = FirebaseDatabaseService();
    await _databaseService.sendEmailVerification();


      customSnackBar(
        context: context,
        message: 'Verification email sent successfully after verification restart the app',
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Text('Failed to send verification email: $e'),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}