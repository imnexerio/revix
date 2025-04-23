import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:retracker/Utils/customSnackBar_error.dart';
import 'package:firebase_database/firebase_database.dart';

Future<Image?> decodeProfileImage(BuildContext context) async {
  const String defaultImagePath = 'assets/icon/icon.png'; // Path to your default image
  String uid = FirebaseAuth.instance.currentUser!.uid;
  try {
    DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data');
    DataSnapshot snapshot = await databaseRef.child('profile_picture').get();
    if (snapshot.exists) {
      String? base64String = snapshot.value as String?;
      if (base64String != null) {
        Uint8List imageBytes = base64Decode(base64String);
        return Image.memory(imageBytes);
      }
    }
  } catch (e) {
      customSnackBar_error(
        context: context,
        message: 'Error decoding profile picture: $e',
    );
  }
  return Image.asset(defaultImagePath);
}