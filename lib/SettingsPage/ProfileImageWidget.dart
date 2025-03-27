import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ProfileProvider.dart';

class ProfileImageWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, child) {
        return profileProvider.profileImage != null
            ? CircleAvatar(
                radius: 50,
                backgroundImage: profileProvider.profileImage!.image,
                backgroundColor: Colors.transparent,
              )
            : CircleAvatar(
                radius: 50,
                backgroundImage: AssetImage('assets/icon/icon.png'),
                backgroundColor: Colors.transparent,
              );
      },
    );
  }
}