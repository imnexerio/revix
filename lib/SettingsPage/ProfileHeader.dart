import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'DIsplayName.dart';
import 'SendVerificationMail.dart';
import 'VerifiedMail.dart';
import 'ProfileProvider.dart';

class ProfileHeader extends StatelessWidget {
  final bool isSmallScreen;
  final void Function(BuildContext) showEditProfilePage;

  ProfileHeader({
    required this.isSmallScreen,
    required this.showEditProfilePage,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
      width: double.infinity,
      height: isSmallScreen ? 250 : 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: AlignmentDirectional(0.94, -1),
          end: AlignmentDirectional(-0.94, 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated profile image
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.5 + (0.5 * value),
                  child: child,
                );
              },
              child: Stack(
                children: [
                  // Profile image - use provider value when available
                  Consumer<ProfileProvider>(
                    builder: (context, profileProvider, child) {
                      return profileProvider.profileImage != null
                          ? Hero(
                        tag: 'profile-image',
                        child: InkWell(
                          onTap: () => showEditProfilePage(context),
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.onPrimary,
                                width: 4,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundImage: profileProvider.profileImage!.image,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        ),
                      )
                          : FutureBuilder<void>(
                        future: profileProvider.loadProfileData(context),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  width: 4,
                                ),
                              ),
                              child: CircularProgressIndicator(),
                            );
                          } else if (snapshot.hasError) {
                            return Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  width: 4,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundImage: AssetImage('assets/icon/icon.png'),
                                backgroundColor: Colors.transparent,
                              ),
                            );
                          } else {
                            return Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  width: 4,
                                ),
                              ),
                              child: Icon(Icons.person, color: Colors.grey),
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            // Animated display name
            FutureBuilder<String>(
              future: getDisplayName(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                } else if (snapshot.hasError) {
                  return Text('Error loading name');
                } else {
                  return Text(
                    snapshot.data!,
                    key: ValueKey(snapshot.data),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
              },
            ),
            SizedBox(height: 4),
            // Animated email verification status
            FutureBuilder<bool>(
              future: isEmailVerified(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                } else if (snapshot.hasError) {
                  return Text('Error loading verification status');
                } else {
                  bool isVerified = snapshot.data!;
                  return Center(
                    key: ValueKey('email-${isVerified}'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${FirebaseAuth.instance.currentUser?.email ?? 'imnexerio@gmail.com'}',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                          ),
                        ),
                        SizedBox(width: 8),
                        if (isVerified)
                          Icon(Icons.verified_outlined, color: Colors.green)
                        else
                          TextButton(
                            onPressed: () => sendVerificationEmail(context),
                            child: Icon(Icons.error, color: Colors.red),
                          )
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}