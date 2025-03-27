import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:retracker/Utils/CustomSnackBar.dart';
import 'package:retracker/Utils/customSnackBar_error.dart';

Future<void> uploadProfilePicture(BuildContext context, XFile imageFile) async {
  try {
    // Convert image to byte array
    Uint8List imageBytes = await imageFile.readAsBytes();

    // Set initial quality and size threshold
    int quality = 100;
    const int maxSizeInBytes = 30 * 1024; // 100 KB
    Uint8List? compressedImageBytes;

    // Compress the image and adjust quality until the size is below the threshold
    do {
      compressedImageBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 120,
        minHeight: 120,
        quality: quality,
      );

      quality -= 10; // Decrease quality by 10 for each iteration
    } while (compressedImageBytes.lengthInBytes > maxSizeInBytes && quality > 0);

    // Encode byte array to Base64 string
    String base64String = base64Encode(compressedImageBytes);

    String uid = FirebaseAuth.instance.currentUser!.uid;

    // Store Base64 string in Firebase Realtime Database at the specified location
    DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data');
    await databaseRef.update({'profile_picture': base64String});

    ScaffoldMessenger.of(context).showSnackBar(
      customSnackBar(
        context: context,
        message: 'Profile picture uploaded successfully',
      ),
    );

    // Update the profile picture in the UI
    // You may need to pass a callback to update the UI
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      customSnackBar_error(
        context: context,
        message: 'Failed to upload profile picture',
      ),
    );
  }
}