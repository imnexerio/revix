import 'package:flutter/material.dart';
import 'DecodeProfilePic.dart';
import 'VerifiedMail.dart';
import 'DisplayName.dart';

class ProfileProvider with ChangeNotifier {
  Image? _profileImage;
  bool _emailVerified = false;
  String _displayName = 'User';

  Image? get profileImage => _profileImage;
  bool get emailVerified => _emailVerified;
  String get displayName => _displayName;

  Future<void> loadProfileData(BuildContext context, String uid) async {
    _profileImage = await decodeProfileImage(context, uid);
    _emailVerified = await isEmailVerified();
    _displayName = await getDisplayName();
    notifyListeners();
  }
}