import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:retracker/Utils/CustomSnackBar.dart';
import 'package:retracker/Utils/customSnackBar_error.dart';
import '../Utils/FirebaseDatabaseService.dart';

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
    } while (compressedImageBytes.lengthInBytes > maxSizeInBytes && quality > 0);    // Encode byte array to Base64 string
    String base64String = base64Encode(compressedImageBytes);

    // Store Base64 string using centralized database service
    final firebaseService = FirebaseDatabaseService();
    await firebaseService.setProfilePicture(base64String);


      customSnackBar(
        context: context,
        message: 'Profile picture uploaded successfully',

    );

    // Update the profile picture in the UI
    // You may need to pass a callback to update the UI
  } catch (e) {
      customSnackBar_error(
        context: context,
        message: 'Failed to upload profile picture',
    );
  }
}