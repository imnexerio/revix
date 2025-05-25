import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Utils/GuestAuthService.dart';
import '../Utils/FirebaseDatabaseService.dart';
import 'ProfileImageWidget.dart';
import 'ProfileProvider.dart';
import 'SendVerificationMail.dart';
import 'VerifiedMail.dart';

class ProfileHeader extends StatelessWidget {
  final bool isSmallScreen;
  final void Function(BuildContext) showEditProfilePage;
  final FirebaseDatabaseService _databaseService = FirebaseDatabaseService();

  ProfileHeader({
    required this.isSmallScreen,
    required this.showEditProfilePage,
  });

  @override
  Widget build(BuildContext context) {
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
                          child: ProfileImageWidget(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Animated display name
            Consumer<ProfileProvider>(
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
            // Check if user is in guest mode before showing email verification status
            FutureBuilder<bool>(
              future: GuestAuthService.isGuestMode(),
              builder: (context, guestSnapshot) {
                if (guestSnapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                
                bool isGuest = guestSnapshot.data ?? false;
                
                if (isGuest) {
                  // For guest users, show guest mode indicator
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Guest Mode',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.person_off_outlined, 
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                      ),
                    ],
                  );
                } else {
                  // For authenticated users, show email verification status
                  return FutureBuilder<bool>(
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
                            mainAxisAlignment: MainAxisAlignment.center,                            children: [
                              Text(
                                '${_databaseService.currentUserEmail ?? 'imnexerio@gmail.com'}',
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