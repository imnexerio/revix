import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'DecodeProfilePic.dart';

class ProfileProvider with ChangeNotifier {
  Image? _profileImage;

  Image? get profileImage => _profileImage;

  Future<void> loadProfileData(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? imageData = prefs.getString('profile_image');

    if (imageData != null) {
      _profileImage = Image.memory(base64Decode(imageData));
    } else {
      _profileImage = await decodeProfileImage(context);
      await _saveProfileImageLocally(_profileImage!);
    }

    notifyListeners();
  }

  Future<void> fetchAndUpdateProfileImage(BuildContext context) async {
    _profileImage = await decodeProfileImage(context); // Fetch updated image from server
    await _saveProfileImageLocally(_profileImage!);
    notifyListeners();
  }

  Future<void> _saveProfileImageLocally(Image image) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final byteData = await _getImageByteData(image);
    final bytes = byteData.buffer.asUint8List();
    final base64Image = base64Encode(bytes);
    await prefs.setString('profile_image', base64Image);
  }

  Future<ByteData> _getImageByteData(Image image) async {
    final completer = Completer<ByteData>();
    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) async {
        final byteData = await info.image.toByteData(format: ImageByteFormat.png);
        completer.complete(byteData!);
      }),
    );
    return completer.future;
  }
}