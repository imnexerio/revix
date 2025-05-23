import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Utils/GuestAuthService.dart';
import 'ProfileImageWidget.dart';
import 'ProfileProvider.dart';
import 'SendVerificationMail.dart';
import 'VerifiedMail.dart';

class ProfileHeader extends StatelessWidget {
  final bool isSmallScreen;
  final void Function(BuildContext) showEditProfilePage;

  ProfileHeader({
    required this.isSmallScreen,
    required this.showEditProfilePage,
  });
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: GuestAuthService.isGuestMode(),
      builder: (context, snapshot) {
        bool isGuestMode = snapshot.data ?? false;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuart,
          width: double.infinity,
          height: isSmallScreen ? 250 : 300,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
              begin: const AlignmentDirectional(0.94, -1),
              end: const AlignmentDirectional(-0.94, 1),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated profile image
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.5 + (0.5 * value),
                      child: child,
                    );
                  },
                  child: Stack(
                    children: [
                      // Profile image - use ProfileImageWidget
                      Hero(
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
                            child: ClipOval(
                              child: isGuestMode
                                ? Icon(
                                    Icons.person,
                                    size: 70,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  )
                                : ProfileImageWidget(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),                const SizedBox(height: 16),
                // Display name - show Guest User for guest mode
                isGuestMode
                    ? Text(
                        "Guest User",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Consumer<ProfileProvider>(
                        builder: (context, profileProvider, child) {
                          if (profileProvider.displayName == null) {
                            return const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          } else {
                            return Text(
                              profileProvider.displayName!,
                              key: ValueKey(profileProvider.displayName),
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                        },
                      ),
                const SizedBox(height: 4),
                // Show Guest Mode badge for guest users or email verification status for regular users
                isGuestMode
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Guest Mode',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : FutureBuilder<bool>(
              future: isEmailVerified(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                } else if (snapshot.hasError) {
                  return const Text('Error loading verification status');
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
                        const SizedBox(width: 8),
                        if (isVerified)
                          const Icon(Icons.verified_outlined, color: Colors.green)
                        else
                          TextButton(
                            onPressed: () => sendVerificationEmail(context),
                            child: const Icon(Icons.error, color: Colors.red),
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
  });
}}