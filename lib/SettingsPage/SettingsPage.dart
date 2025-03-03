import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

class _SettingsPageState extends State<SettingsPage> with AutomaticKeepAliveClientMixin {
  // Track currently selected page for large screens
  Widget? _currentDetailPage;
  String _currentTitle = 'Edit Profile'; // Set default title
  bool _isInitialized = false;

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
    // Prefetch data to improve UX
    _prefetchUserData();
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
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
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: buildDetailPageAppBar(context, title),
            body: page,
          ),
        ),
      ).then((_) {
        // Optional: refresh data when returning from detail page
        _refreshProfile();
      });
    } else {
      // For large screens, update the detail view without full state rebuild
      if (_currentTitle != title || _currentDetailPage == null) {
        setState(() {
          _currentDetailPage = page;
          _currentTitle = title;
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

  PreferredSizeWidget _buildLargeScreenAppBar() {
    return AppBar(
      title: Text(
        _currentTitle,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      centerTitle: true,
      elevation: 2, // Add shadow
      // backgroundColor: Theme.of(context).colorScheme.surface,
      // foregroundColor: Theme.of(context).colorScheme.onSurface,
      automaticallyImplyLeading: false, // This removes the back button
    );
  }

  // Build profile header with optimized rebuilds
  Widget _buildProfileHeader(bool isSmallScreen) {
    return Container(
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
            Stack(
              children: [
                // Profile image - use cached value when available
                _cachedProfileImage != null
                    ? InkWell(
                  onTap: () => _showEditProfilePage(context),
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
                      backgroundImage: _cachedProfileImage!.image,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                )
                    : FutureBuilder<Image?>(
                  future: _decodeProfileImage(getCurrentUserUid()),
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
                    } else if (snapshot.hasError || snapshot.data == null) {
                      return InkWell(
                        onTap: () async {
                          final ImagePicker _picker = ImagePicker();
                          final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            await uploadProfilePicture(context, image, getCurrentUserUid());
                            _refreshProfile();
                          }
                        },
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
                            backgroundImage: AssetImage('assets/icon/icon.png'),
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      );
                    } else {
                      // Cache the image for future use
                      _cachedProfileImage = snapshot.data;
                      return InkWell(
                        onTap: () => _showEditProfilePage(context),
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
                            backgroundImage: snapshot.data!.image,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            // Display name - use cached value when available
            _cachedDisplayName != null
                ? Text(
              _cachedDisplayName!,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            )
                : FutureBuilder<String>(
              future: _getDisplayName(),
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
                  _cachedDisplayName = snapshot.data;
                  return Text(
                    snapshot.data!,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
              },
            ),
            SizedBox(height: 4),
            // Email verification status - use cached value when available
            _cachedEmailVerified != null
                ? Center(
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
                  if (_cachedEmailVerified!)
                    Icon(Icons.verified_outlined, color: Colors.green)
                  else
                    TextButton(
                      onPressed: () => _sendVerificationEmail(context),
                      child: Icon(Icons.error, color: Colors.red),
                    )
                ],
              ),
            )
                : FutureBuilder<bool>(
              future: _isEmailVerified(),
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
                  _cachedEmailVerified = isVerified;
                  return Center(
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
                            onPressed: () => _sendVerificationEmail(context),
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

  // Check if we're on a large screen to determine whether to show selection
  bool _shouldShowSelectionHighlight(String title) {
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width >= 800;
    // Only show selection highlight on large screens
    return isLargeScreen && _currentTitle == title;
  }

  // Build settings options list with improved selection state handling
  Widget _buildSettingsOptions(bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 16),
      child: Column(
        children: [
          buildProfileOptionCard(
            context: context,
            title: 'Edit Profile',
            subtitle: 'Update your personal information',
            icon: Icons.person,
            onTap: () => _showEditProfilePage(context),
            isSelected: _shouldShowSelectionHighlight('Edit Profile'),
          ),
          SizedBox(height: 16),
          buildProfileOptionCard(
            context: context,
            title: 'Set Theme',
            subtitle: 'Choose your style',
            icon: Icons.color_lens_outlined,
            onTap: () => _showThemePage(context),
            isSelected: _shouldShowSelectionHighlight('Set Theme'),
          ),
          SizedBox(height: 16),
          buildProfileOptionCard(
            context: context,
            title: 'Custom Frequency',
            subtitle: 'Modify your tracking intervals',
            icon: Icons.timelapse_sharp,
            onTap: () => _showFrequencyPage(context),
            isSelected: _shouldShowSelectionHighlight('Custom Frequency'),
          ),
          SizedBox(height: 16),
          buildProfileOptionCard(
            context: context,
            title: 'Custom Tracking Type',
            subtitle: 'Modify your tracking intervals',
            icon: Icons.track_changes_rounded,
            onTap: () => _showTrackingTypePage(context),
            isSelected: _shouldShowSelectionHighlight('Custom Tracking Type'),
          ),
          SizedBox(height: 16),
          buildProfileOptionCard(
            context: context,
            title: 'Change Password',
            subtitle: 'Update your security credentials',
            icon: Icons.lock_outline,
            onTap: () => _showChangePasswordPage(context),
            isSelected: _shouldShowSelectionHighlight('Change Password'),
          ),
          SizedBox(height: 16),
          buildProfileOptionCard(
            context: context,
            title: 'Change Email',
            subtitle: 'Update your Email credentials',
            icon: Icons.email_outlined,
            onTap: () => _showChangeEmailPage(context),
            isSelected: _shouldShowSelectionHighlight('Change Email'),
          ),
          SizedBox(height: 16),
          buildProfileOptionCard(
            context: context,
            title: 'Notification Settings',
            subtitle: 'Manage your notification preferences',
            icon: Icons.notifications_outlined,
            onTap: () => _showNotificationSettingsPage(context),
            isSelected: _shouldShowSelectionHighlight('Notification Settings'),
          ),
          SizedBox(height: 16),
          buildProfileOptionCard(
            context: context,
            title: 'About',
            subtitle: 'Read about this project',
            icon: Icons.privacy_tip_outlined,
            onTap: () => _showAboutPage(context),
            isSelected: _shouldShowSelectionHighlight('About'),
          ),
          SizedBox(height: 32),

          FilledButton(
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
        ],
      ),
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
        child: isSmallScreen
        // Small screen layout - Single column scrollable
            ? SingleChildScrollView(
          child: Column(
            children: [
              _buildProfileHeader(isSmallScreen),
              _buildSettingsOptions(isSmallScreen),
            ],
          ),
        )
        // Large screen layout - Side-by-side master-detail view
            : Row(
          children: [
            // Left side - Settings options
            Container(
              width: 350, // Fixed width for the sidebar
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildProfileHeader(isSmallScreen),
                    _buildSettingsOptions(isSmallScreen),
                  ],
                ),
              ),
            ),
            // Divider between sections
            VerticalDivider(width: 1, thickness: 1),
            // Right side - Detail view with app bar
            Expanded(
              child: Column(
                children: [
                  // App bar for large screens
                  _buildLargeScreenAppBar(),
                  // Detail content
                  Expanded(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}