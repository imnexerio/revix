import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:retracker/Utils/customSnackBar_error.dart';

Future<Image?> decodeProfileImage(BuildContext context, String uid, Future<String?> Function(String) getProfilePicture) async {
  const String defaultImagePath = 'assets/icon/icon.png'; // Path to your default image

  try {
    String? base64String = await getProfilePicture(uid);
    if (base64String != null) {
      Uint8List imageBytes = base64Decode(base64String);
      return Image.memory(imageBytes);
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      customSnackBar_error(
        context: context,
        message: 'Error decoding profile picture: $e',
      ),
    );
  }
  return Image.asset(defaultImagePath);
}