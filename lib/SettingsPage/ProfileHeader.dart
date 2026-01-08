import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Utils/GuestAuthService.dart';
import '../Utils/FirebaseDatabaseService.dart';
import 'ProfileImageWidget.dart';
import 'ProfileProvider.dart';
import 'SendVerificationMail.dart';
import 'VerifiedMail.dart';

class ProfileHeader extends StatefulWidget {
  final bool isSmallScreen;
  final void Function(BuildContext) showEditProfilePage;

  const ProfileHeader({
    Key? key,
    required this.isSmallScreen,
    required this.showEditProfilePage,
  }) : super(key: key);

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  final FirebaseDatabaseService _databaseService = FirebaseDatabaseService();
  
  // Cached future results to prevent recreation on rebuild
  bool? _isGuestMode;
  bool? _isEmailVerified;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserStatus();
  }

  Future<void> _loadUserStatus() async {
    try {
      final isGuest = await GuestAuthService.isGuestMode();
      bool? emailVerified;
      
      if (!isGuest) {
        emailVerified = await isEmailVerified();
      }
      
      if (mounted) {
        setState(() {
          _isGuestMode = isGuest;
          _isEmailVerified = emailVerified;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user status: $e');
      if (mounted) {
        setState(() {
          _isGuestMode = false;
          _isEmailVerified = false;
          _isLoading = false;
        });
      }
    }
  }

  /// Call this to refresh email verification status after sending verification email
  Future<void> refreshEmailVerification() async {
    if (_isGuestMode == true) return;
    
    invalidateEmailVerificationCache();
    final verified = await isEmailVerified(forceRefresh: true);
    if (mounted) {
      setState(() {
        _isEmailVerified = verified;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: widget.isSmallScreen ? 220 : 280,
        maxHeight: widget.isSmallScreen ? 280 : 350,
      ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
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
                      onTap: () => widget.showEditProfilePage(context),
                      child: Container(
                        width: widget.isSmallScreen ? 90 : 110,
                        height: widget.isSmallScreen ? 90 : 110,
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
            const SizedBox(height: 12),
            // Animated display name
            Flexible(
              child: Consumer<ProfileProvider>(
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
            ),
            const SizedBox(height: 4),
            // Email verification status - now uses cached state
            Flexible(
              child: _buildEmailVerificationSection(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailVerificationSection(BuildContext context) {
    // Fixed height container to prevent layout jumps
    const double sectionHeight = 28;
    
    if (_isLoading) {
      return const SizedBox(
        height: sectionHeight,
        width: 24,
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_isGuestMode == true) {
      // For guest users, show guest mode indicator
      return SizedBox(
        height: sectionHeight,
        child: Row(
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
              size: 20,
            ),
          ],
        ),
      );
    } else {
      // For authenticated users, show email verification status
      final isVerified = _isEmailVerified ?? false;
      return SizedBox(
        height: sectionHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${_databaseService.currentUserEmail ?? 'imnexerio@gmail.com'}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 8),
            if (isVerified)
              const Icon(Icons.verified_outlined, color: Colors.green, size: 20)
            else
              GestureDetector(
                onTap: () async {
                  await sendVerificationEmail(context);
                  // Refresh verification status after sending email
                  refreshEmailVerification();
                },
                child: const Icon(Icons.error, color: Colors.red, size: 20),
              )
          ],
        ),
      );
    }
  }
}