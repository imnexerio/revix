import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:retracker/Utils/customSnackBar_error.dart';
import '../Utils/FirebaseDatabaseService.dart';

Future<Image?> decodeProfileImage(BuildContext context) async {
  const String defaultImagePath = 'assets/icon/icon.png'; // Path to your default image
  try {
    final firebaseService = FirebaseDatabaseService();
    String? base64String = await firebaseService.getProfilePicture();
    if (base64String != null) {
      Uint8List imageBytes = base64Decode(base64String);
      return Image.memory(imageBytes);
    }
  } catch (e) {
      customSnackBar_error(
        context: context,
        message: 'Error decoding profile picture: $e',
    );
  }
  return Image.asset(defaultImagePath);
}