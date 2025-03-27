import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'DIsplayName.dart';
import 'DecodeProfilePic.dart';

class ProfileProvider with ChangeNotifier {
  Image? _profileImage;
  String? _displayName;

  Image? get profileImage => _profileImage;
  String? get displayName => _displayName;

  Future<void> loadProfileImage(BuildContext context) async {
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

  Future<void> loadDisplayName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? nameData = prefs.getString('display_name');

    if (nameData != null) {
      _displayName = nameData;
    } else {
      _displayName = await getDisplayName();
      await _saveDisplayNameLocally(_displayName!);
    }

    notifyListeners();
  }

  Future<void> fetchAndUpdateProfileImage(BuildContext context) async {
    _profileImage = await decodeProfileImage(context);
    await _saveProfileImageLocally(_profileImage!);
    notifyListeners();
  }

  Future<void> fetchAndUpdateDisplayName() async {
    _displayName = await getDisplayName();
    await _saveDisplayNameLocally(_displayName!);
    notifyListeners();
  }

  Future<void> _saveProfileImageLocally(Image image) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final byteData = await _getImageByteData(image);
    final bytes = byteData.buffer.asUint8List();
    final base64Image = base64Encode(bytes);
    await prefs.setString('profile_image', base64Image);
  }

  Future<void> _saveDisplayNameLocally(String displayName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('display_name', displayName);
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