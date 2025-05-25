import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../AI/ChatStorage.dart';
import '../HomeWidget/HomeWidgetManager.dart';
import '../LoginSignupPage/LoginPage.dart';
import '../Utils/GuestAuthService.dart';
import '../Utils/UnifiedDatabaseService.dart';
import '../Utils/FirebaseDatabaseService.dart';
import '../Utils/LocalDatabaseService.dart';
import '../Utils/customSnackBar_error.dart';
import '../Utils/platform_utils.dart';
import 'AboutPage.dart';
import 'ChangePassPage.dart';
import 'ChangeMailPage.dart';
import 'FetchReleaseNote.dart';
import 'FrequencyPage.dart';
import 'GuestDataManagementWidget.dart';
import 'NotificationPage.dart';
import 'ProfileHeader.dart';
import 'ProfileOptionCard.dart';
import 'ProfilePage.dart';
import 'ProfileProvider.dart';
import 'ThemePage.dart';
import 'TrackingTypePage.dart';
import 'buildDetailPageAppBar.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileProvider(),
      child: SettingsPageContent(),
    );
  }
}

class SettingsPageContent extends StatefulWidget {
  @override
  _SettingsPageContentState createState() => _SettingsPageContentState();
}

class _SettingsPageContentState extends State<SettingsPageContent> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  Widget? _currentDetailPage;
  String _currentTitle = 'Edit Profile'; // Set default title
  bool _isInitialized = false;
  final FirebaseDatabaseService _databaseService = FirebaseDatabaseService();

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    profileProvider.loadProfileImage(context);
    profileProvider.loadDisplayName();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Start the animation
    _animationController.forward();

  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }


  Future<void> _logout(BuildContext context) async {
    try {
      await _animationController.reverse();
      final databaseService = CombinedDatabaseService();
      databaseService.stopListening();

      if (PlatformUtils.instance.isAndroid) {
        await HomeWidgetService.updateWidgetData([],[],[]);
      }

      // Get a reference to the local database
      final localDatabase = LocalDatabaseService();

      // Check if user is in guest mode
      bool isGuestMode = await GuestAuthService.isGuestMode();
      if (isGuestMode) {
        // Handle guest mode logout
        await GuestAuthService.disableGuestMode();
        
        // Clear all guest user data from local database
        await localDatabase.clearAllData();
      } else {
        // Handle regular authentication logout
        await _databaseService.signOut();
      }

      if (PlatformUtils.instance.isAndroid) {
        await HomeWidgetService.updateLoginStatus();
      }

      // Clear all shared preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Clear any cached AI chat data
      try {
        await ChatStorage.clearAllConversations();
      } catch (e) {
        print('Error clearing chat data: $e');
      }

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => LoginPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              var begin = const Offset(0.0, 1.0);
              var end = Offset.zero;
              var curve = Curves.easeInOutCubic;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        customSnackBar_error(
          context: context,
          message: 'Error during logout: $e',
        );
      }
    }
  }

  Future<void> _refreshProfile() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    await profileProvider.fetchAndUpdateDisplayName();
    await profileProvider.fetchAndUpdateProfileImage(context);
  }
  String getCurrentUserUid() {
    return _databaseService.currentUserId ?? '';
  }

  Future<bool> _isGuestMode() async {
    return await GuestAuthService.isGuestMode();
  }

  Future<String> _getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
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
            var begin = const Offset(1.0, 0.0);
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
          transitionDuration: const Duration(milliseconds: 300),
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
    return const EditProfilePage(
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
          icon: const Icon(Icons.arrow_back_rounded),
          color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
          onPressed: _handleBackNavigation,
          tooltip: 'Back',
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
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
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.2),
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
          _buildAnimatedOptionCards(isSmallScreen),
          const SizedBox(height: 32),

          // Animated logout button
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
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
                minimumSize: const Size(70, 55),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
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
  Widget _buildAnimatedOptionCards(bool isSmallScreen) {
    return FutureBuilder<bool>(
      future: _isGuestMode(),
      builder: (context, snapshot) {
        bool isGuestMode = snapshot.data ?? false;
        
        // Common options for all users
        final List<Map<String, dynamic>> commonOptions = [
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
        ];
        
        // Options only for authenticated users
        final List<Map<String, dynamic>> authOnlyOptions = [
          {
            'title': 'Change Password',
            'subtitle': 'Update your security credentials',
            'icon': Icons.lock_outline,
            'onTap': () => _showChangePasswordPage(context),
            'isSelected': _shouldShowSelectionHighlight('Change Password'),
          },
          {
            'title': 'Change Email',
            'subtitle': 'Update your email address',
            'icon': Icons.email_outlined,
            'onTap': () => _showChangeEmailPage(context),
            'isSelected': _shouldShowSelectionHighlight('Change Email'),
          },
        ];
        
        // Options only for guest mode users
        final List<Map<String, dynamic>> guestOnlyOptions = [
          {
            'title': 'Guest Data Management',
            'subtitle': 'Export or import your data',
            'icon': Icons.import_export,
            'onTap': () => _navigateToPage(context, GuestDataManagementWidget(), 'Guest Data Management'),
            'isSelected': _shouldShowSelectionHighlight('Guest Data Management'),
          },
        ];
        
        // Common options for all users at the bottom of the list
        final List<Map<String, dynamic>> bottomOptions = [
          {
            'title': 'Notification Settings',
            'subtitle': 'Configure your notifications',
            'icon': Icons.notifications_none,
            'onTap': () => _showNotificationSettingsPage(context),
            'isSelected': _shouldShowSelectionHighlight('Notification Settings'),
          },
          {
            'title': 'About',
            'subtitle': 'App information and updates',
            'icon': Icons.info_outline,
            'onTap': () => _showAboutPage(context),
            'isSelected': _shouldShowSelectionHighlight('About'),
          },
        ];
        
        // Combine options based on auth status
        List<Map<String, dynamic>> options = [
          ...commonOptions,
          ...isGuestMode ? guestOnlyOptions : authOnlyOptions,
          ...bottomOptions,
        ];
        
        // Return a Column widget containing all of the animated option cards
        return Column(
          children: options.asMap().entries.map((entry) {
            int index = entry.key;
            var option = entry.value;
            
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + (index * 100)),
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
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: buildProfileOptionCard(
                  context: context,
                  title: option['title'],
                  subtitle: option['subtitle'],
                  icon: option['icon'],
                  onTap: option['onTap'],
                  isSelected: option['isSelected'],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
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
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  ProfileHeader(
                    isSmallScreen: isSmallScreen,
                    showEditProfilePage: _showEditProfilePage,
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
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        ProfileHeader(
                          isSmallScreen: isSmallScreen,
                          showEditProfilePage: _showEditProfilePage,
                        ),
                        _buildSettingsOptions(isSmallScreen),
                      ],
                    ),
                  ),
                ),
                // Divider between sections
                const VerticalDivider(width: 1, thickness: 1),
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
                                  const SizedBox(height: 16),
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