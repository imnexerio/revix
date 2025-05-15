import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ProfileProvider.dart';

class ProfileImageWidget extends StatelessWidget {
  final double radius;

  ProfileImageWidget({this.radius = 50});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, child) {
        return profileProvider.profileImage != null
            ? CircleAvatar(
          radius: radius,
          backgroundImage: profileProvider.profileImage!.image,
          backgroundColor: Colors.transparent,
        )
            : CircleAvatar(
          radius: radius,
          backgroundImage: const AssetImage('assets/icon/icon.png'),
          backgroundColor: Colors.transparent,
        );
      },
    );
  }
}