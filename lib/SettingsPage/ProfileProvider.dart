import 'package:flutter/material.dart';
import 'DecodeProfilePic.dart';

class ProfileProvider with ChangeNotifier {
  Image? _profileImage;

  Image? get profileImage => _profileImage;

  Future<void> loadProfileData(BuildContext context) async {
    _profileImage = await decodeProfileImage(context);
    notifyListeners();
  }

  Future<void> fetchAndUpdateProfileImage(BuildContext context) async {
    _profileImage = await decodeProfileImage(context); // Fetch updated image from server
    notifyListeners();
  }
}