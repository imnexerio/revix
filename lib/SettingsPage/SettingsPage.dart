import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../LoginSignupPage/LoginPage.dart';
import 'AboutPage.dart';
import 'ChangePassPage.dart';
import 'ChangeMailPage.dart';
import 'DecodeProfilePic.dart';
import 'FetchProfilePic.dart';
import 'FetchReleaseNote.dart';
import 'FrequencyPage.dart';
import 'NotificationPage.dart';
import 'ProfileHeader.dart';
import 'ProfileImageUpload.dart';
import 'ProfileOptionCard.dart';
import 'ProfilePage.dart';
import 'SendVerificationMail.dart';
import 'ThemePage.dart';
import 'TrackingTypePage.dart';
import 'buildDetailPageAppBar.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  // Track currently selected page for large screens
  Widget? _currentDetailPage;
  String _currentTitle = 'Edit Profile'; // Set default title
  bool _isInitialized = false;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Cache for frequently accessed data to prevent unnecessary rebuilds
  String? _cachedDisplayName;
  Image? _cachedProfileImage;
  bool? _cachedEmailVerified;

  // Keep widget alive when switching tabs or resizing
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Start the animation
    _animationController.forward();

    // Prefetch data to improve UX
    _prefetchUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Prefetch user data to avoid multiple fetches
  Future<void> _prefetchUserData() async {
    try {
      _cachedDisplayName = await _getDisplayName();
      _cachedEmailVerified = await _isEmailVerified();
      _cachedProfileImage = await _decodeProfileImage(getCurrentUserUid());

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error prefetching user data: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    // Add a subtle animation before logout
    _animationController.reverse().then((_) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var begin = Offset(0.0, 1.0);
            var end = Offset.zero;
            var curve = Curves.easeInOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: Duration(milliseconds: 500),
        ),
      );
    });
  }

  Future<void> _refreshProfile() async {
    // Clear cache
    _cachedDisplayName = null;
    _cachedProfileImage = null;
    _cachedEmailVerified = null;

    // Reload data
    await _prefetchUserData();

    if (mounted) {
      setState(() {
        // This will only rebuild the necessary widgets thanks to the cache
      });
    }
  }

  String getCurrentUserUid() {
    return FirebaseAuth.instance.currentUser!.uid;
  }

  Future<String> _getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  Future<String> _getDisplayName() async {
    if (_cachedDisplayName != null) return _cachedDisplayName!;

    User? user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? 'User';
  }

  Future<bool> _isEmailVerified() async {
    if (_cachedEmailVerified != null) return _cachedEmailVerified!;

    User? user = FirebaseAuth.instance.currentUser;
    await user?.reload();
    return user?.emailVerified ?? false;
  }

  Future<String?> _getProfilePicture(String uid) {
    return getProfilePicture(uid);
  }

  Future<Image?> _decodeProfileImage(String uid) async {
    if (_cachedProfileImage != null) return _cachedProfileImage;

    return decodeProfileImage(context, uid, _getProfilePicture);
  }

  Future<void> _sendVerificationEmail(BuildContext context) async {
    await sendVerificationEmail(context);
    _cachedEmailVerified = null; // Clear cache to force refresh
    await _refreshProfile();
  }

  Future<String> _fetchReleaseNotes() {
    return fetchReleaseNotes();
  }

  // This method handles navigating to different pages based on screen size
  void _navigateToPage(BuildContext context, Widget page, String title) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 800;

    if (isSmallScreen) {
      // For small screens, navigate to a new screen with app bar
      // Don't update _currentTitle for small screens to avoid selection UI issues
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
            appBar: buildDetailPageAppBar(context, title),
            body: page,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var begin = Offset(1.0, 0.0);
            var end = Offset.zero;
            var curve = Curves.easeOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: Duration(milliseconds: 300),
        ),
      ).then((_) {
        // Optional: refresh data when returning from detail page
        _refreshProfile();
      });
    } else {
      // For large screens, update the detail view with animation
      if (_currentTitle != title || _currentDetailPage == null) {
        // Start fade-out animation
        _animationController.reverse().then((_) {
          setState(() {
            _currentDetailPage = page;
            _currentTitle = title;
          });
          // Start fade-in animation
          _animationController.forward();
        });
      }
    }
  }

  // Create pages once and store them in variables to avoid recreation
  Widget _createEditProfilePage() {
    return EditProfilePage(
      getDisplayName: _getDisplayName,
      decodeProfileImage: _decodeProfileImage,
      uploadProfilePicture: uploadProfilePicture,
      getCurrentUserUid: getCurrentUserUid,
    );
  }

  // Only initialize default page once to avoid resets
  void _initializeDefaultPageIfNeeded(BuildContext context) {
    if (!_isInitialized) {
      _currentDetailPage = _createEditProfilePage();
      _currentTitle = 'Edit Profile';
      _isInitialized = true;
    }
  }

  // Updated navigation methods
  void _showEditProfilePage(BuildContext context) {
    _navigateToPage(context, _createEditProfilePage(), 'Edit Profile');
  }

  void _showThemePage(BuildContext context) {
    _navigateToPage(context, ThemePage(), 'Set Theme');
  }

  void _showFrequencyPage(BuildContext context) {
    _navigateToPage(context, FrequencyPage(), 'Custom Frequency');
  }

  void _showTrackingTypePage(BuildContext context) {
    _navigateToPage(context, TrackingTypePage(), 'Custom Tracking Type');
  }

  void _showChangePasswordPage(BuildContext context) {
    _navigateToPage(context, ChangePasswordPage(), 'Change Password');
  }

  void _showChangeEmailPage(BuildContext context) {
    _navigateToPage(context, ChangeEmailPage(), 'Change Email');
  }

  void _showNotificationSettingsPage(BuildContext context) {
    _navigateToPage(context, NotificationSettingsPage(), 'Notification Settings');
  }

  void _showAboutPage(BuildContext context) {
    _navigateToPage(
      context,
      AboutPage(getAppVersion: _getAppVersion, fetchReleaseNotes: _fetchReleaseNotes),
      'About',
    );
  }

  // Method to handle back navigation
  void _handleBackNavigation() {
    Navigator.of(context).pop();
  }

  // Back button component that appears at the top regardless of screen size
  Widget _buildBackButton() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        child: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
          onPressed: _handleBackNavigation,
          tooltip: 'Back',
          padding: EdgeInsets.all(8),
          constraints: BoxConstraints(),
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildLargeScreenAppBar() {
    return AppBar(
      title: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0.0, 0.2),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Text(
          _currentTitle,
          key: ValueKey<String>(_currentTitle), // Important for animation
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      centerTitle: true,
      elevation: 2, // Add shadow
      automaticallyImplyLeading: false, // This removes the back button
    );
  }


  // Check if we're on a large screen to determine whether to show selection
  bool _shouldShowSelectionHighlight(String title) {
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width >= 800;
    // Only show selection highlight on large screens
    return isLargeScreen && _currentTitle == title;
  }

  // Build settings options list with improved selection state handling and animations
  Widget _buildSettingsOptions(bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 16),
      child: Column(
        children: [
          // Using staggered animations for each option card
          ..._buildAnimatedOptionCards(isSmallScreen),
          SizedBox(height: 32),

          // Animated logout button
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: FilledButton(
              onPressed: () => _logout(context),
              style: FilledButton.styleFrom(
                minimumSize: Size(70, 55),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Logout',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Create staggered animation for option cards
  List<Widget> _buildAnimatedOptionCards(bool isSmallScreen) {
    final options = [
      {
        'title': 'Edit Profile',
        'subtitle': 'Update your personal information',
        'icon': Icons.person,
        'onTap': () => _showEditProfilePage(context),
        'isSelected': _shouldShowSelectionHighlight('Edit Profile'),
      },
      {
        'title': 'Set Theme',
        'subtitle': 'Choose your style',
        'icon': Icons.color_lens_outlined,
        'onTap': () => _showThemePage(context),
        'isSelected': _shouldShowSelectionHighlight('Set Theme'),
      },
      {
        'title': 'Custom Frequency',
        'subtitle': 'Modify your tracking intervals',
        'icon': Icons.timelapse_sharp,
        'onTap': () => _showFrequencyPage(context),
        'isSelected': _shouldShowSelectionHighlight('Custom Frequency'),
      },
      {
        'title': 'Custom Tracking Type',
        'subtitle': 'Modify your tracking intervals',
        'icon': Icons.track_changes_rounded,
        'onTap': () => _showTrackingTypePage(context),
        'isSelected': _shouldShowSelectionHighlight('Custom Tracking Type'),
      },
      {
        'title': 'Change Password',
        'subtitle': 'Update your security credentials',
        'icon': Icons.lock_outline,
        'onTap': () => _showChangePasswordPage(context),
        'isSelected': _shouldShowSelectionHighlight('Change Password'),
      },
      {
        'title': 'Change Email',
        'subtitle': 'Update your Email credentials',
        'icon': Icons.email_outlined,
        'onTap': () => _showChangeEmailPage(context),
        'isSelected': _shouldShowSelectionHighlight('Change Email'),
      },
      {
        'title': 'Notification Settings',
        'subtitle': 'Manage your notification preferences',
        'icon': Icons.notifications_outlined,
        'onTap': () => _showNotificationSettingsPage(context),
        'isSelected': _shouldShowSelectionHighlight('Notification Settings'),
      },
      {
        'title': 'About',
        'subtitle': 'Read about this project',
        'icon': Icons.privacy_tip_outlined,
        'onTap': () => _showAboutPage(context),
        'isSelected': _shouldShowSelectionHighlight('About'),
      },
    ];

    List<Widget> cards = [];

    for (int i = 0; i < options.length; i++) {
      final option = options[i];

      // Create staggered animation for each card
      final card = TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        // Delay each card by a bit more
        builder: (context, value, child) {
          // Calculate delay based on index
          final delay = i * 0.1;
          final adjustedValue = (value - delay).clamp(0.0, 1.0) / (1.0 - delay);

          return Opacity(
            opacity: adjustedValue,
            child: Transform.translate(
              offset: Offset(30 * (1 - adjustedValue), 0),
              child: child,
            ),
          );
        },
        child: buildProfileOptionCard(
          context: context,
          title: option['title'] as String,
          subtitle: option['subtitle'] as String,
          icon: option['icon'] as IconData,
          onTap: option['onTap'] as Function(),
          isSelected: option['isSelected'] as bool,
        ),
      );

      cards.add(card);

      // Add spacing except after the last item
      if (i < options.length - 1) {
        cards.add(SizedBox(height: 16));
      }
    }

    return cards;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Initialize default page if needed (only once)
    _initializeDefaultPageIfNeeded(context);

    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 800;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: Stack(
          children: [
            isSmallScreen
            // Small screen layout - Single column scrollable with animation
                ? SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  ProfileHeader(
                    isSmallScreen: isSmallScreen,
                    cachedProfileImage: _cachedProfileImage,
                    cachedDisplayName: _cachedDisplayName,
                    cachedEmailVerified: _cachedEmailVerified,
                    decodeProfileImage: _decodeProfileImage,
                    getDisplayName: _getDisplayName,
                    isEmailVerified: _isEmailVerified,
                    sendVerificationEmail: _sendVerificationEmail,
                    uploadProfilePicture: uploadProfilePicture,
                    refreshProfile: _refreshProfile,
                    showEditProfilePage: _showEditProfilePage,
                    getCurrentUserUid: getCurrentUserUid,
                  ),
                  _buildSettingsOptions(isSmallScreen),
                ],
              ),
            )
            // Large screen layout - Side-by-side master-detail view with animation
                : Row(
              children: [
                // Left side - Settings options
                Container(
                  width: MediaQuery.of(context).size.width * 0.33, // 33% of the screen width
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        ProfileHeader(
                          isSmallScreen: isSmallScreen,
                          cachedProfileImage: _cachedProfileImage,
                          cachedDisplayName: _cachedDisplayName,
                          cachedEmailVerified: _cachedEmailVerified,
                          decodeProfileImage: _decodeProfileImage,
                          getDisplayName: _getDisplayName,
                          isEmailVerified: _isEmailVerified,
                          sendVerificationEmail: _sendVerificationEmail,
                          uploadProfilePicture: uploadProfilePicture,
                          refreshProfile: _refreshProfile,
                          showEditProfilePage: _showEditProfilePage,
                          getCurrentUserUid: getCurrentUserUid,
                        ),
                        _buildSettingsOptions(isSmallScreen),
                      ],
                    ),
                  ),
                ),
                // Divider between sections
                VerticalDivider(width: 1, thickness: 1),
                // Right side - Detail view with app bar and animations
                Expanded(
                  child: Column(
                    children: [
                      // App bar for large screens
                      _buildLargeScreenAppBar(),
                      // Detail content with fade animation
                      Expanded(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: _currentDetailPage ?? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.touch_app,
                                    size: 64,
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Select an option from the left menu',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Back button positioned at the top left, regardless of screen size
            _buildBackButton(),
          ],
        ),
      ),
    );
  }
}