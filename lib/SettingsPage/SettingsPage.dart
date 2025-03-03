import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../LoginSignupPage/LoginPage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'AboutPage.dart';
import 'CHangePassPage.dart';
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

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Track currently selected page for large screens
  Widget? _currentDetailPage;
  String _currentTitle = '';

  @override
  void initState() {
    super.initState();
    // Set Edit Profile as the default page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showEditProfilePage(context);
    });
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
    setState(() {
      // Trigger a rebuild to refresh the profile data
    });
  }

  String getCurrentUserUid() {
    return FirebaseAuth.instance.currentUser!.uid;
  }

  Future<String> _getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  Future<String> _getDisplayName() async {
    User? user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? 'User';
  }

  Future<bool> _isEmailVerified() async {
    User? user = FirebaseAuth.instance.currentUser;
    await user?.reload();
    return user?.emailVerified ?? false;
  }

  // Use the function from the new file
  Future<String?> _getProfilePicture(String uid) {
    return getProfilePicture(uid);
  }

  Future<Image?> _decodeProfileImage(String uid) {
    return decodeProfileImage(context, uid, _getProfilePicture);
  }

  // Use the function from the new file
  Future<void> _sendVerificationEmail(BuildContext context) {
    return sendVerificationEmail(context);
  }

  // Use the function from the new file
  Future<String> _fetchReleaseNotes() {
    return fetchReleaseNotes();
  }

  // This method handles navigating to different pages based on screen size
  void _navigateToPage(BuildContext context, Widget page, String title) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 900; // Adjusting breakpoint for better experience

    if (isSmallScreen) {
      // For small screens, navigate to a new screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
    } else {
      // For large screens, update the detail view
      setState(() {
        _currentDetailPage = page;
        _currentTitle = title;
      });
    }
  }

  // Updated navigation methods to use the responsive handler
  void _showEditProfilePage(BuildContext context) {
    _navigateToPage(
      context,
      EditProfilePage(
        getDisplayName: _getDisplayName,
        decodeProfileImage: _decodeProfileImage,
        uploadProfilePicture: uploadProfilePicture,
        getCurrentUserUid: getCurrentUserUid,
      ),
      'Edit Profile',
    );
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

  // Build profile header
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
                FutureBuilder<Image?>(
                  future: _decodeProfileImage(getCurrentUserUid()),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    } else if (snapshot.hasError) {
                      return InkWell(
                        onTap: () async {
                          final ImagePicker _picker = ImagePicker();
                          final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            await uploadProfilePicture(context, image, getCurrentUserUid());
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
            FutureBuilder<String>(
              future: _getDisplayName(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error loading name');
                } else {
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
            FutureBuilder<bool>(
              future: _isEmailVerified(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error loading verification status');
                } else {
                  bool isVerified = snapshot.data!;
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

  // Build settings options list
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
            isSelected: _currentTitle == 'Edit Profile',
          ),
          SizedBox(height: 16),
          buildProfileOptionCard(
            context: context,
            title: 'Set Theme',
            subtitle: 'Choose your style',
            icon: Icons.color_lens_outlined,
            onTap: () => _showThemePage(context),
            isSelected: _currentTitle == 'Set Theme',
          ),
          SizedBox(height: 16),
          buildProfileOptionCard(
            context: context,
            title: 'Custom Frequency',
            subtitle: 'Modify your tracking intervals',
            icon: Icons.timelapse_sharp,
            onTap: () => _showFrequencyPage(context),
            isSelected: _currentTitle == 'Custom Frequency',
          ),
          SizedBox(height: 16),
          buildProfileOptionCard(
            context: context,
            title: 'Custom Tracking Type',
            subtitle: 'Modify your tracking intervals',
            icon: Icons.track_changes_rounded,
            onTap: () => _showTrackingTypePage(context),
            isSelected: _currentTitle == 'Custom Tracking Type',
          ),
          SizedBox(height: 16),
          buildProfileOptionCard(
            context: context,
            title: 'Change Password',
            subtitle: 'Update your security credentials',
            icon: Icons.lock_outline,
            onTap: () => _showChangePasswordPage(context),
            isSelected: _currentTitle == 'Change Password',
          ),
          SizedBox(height: 16),
          buildProfileOptionCard(
            context: context,
            title: 'Change Email',
            subtitle: 'Update your Email credentials',
            icon: Icons.email_outlined,
            onTap: () => _showChangeEmailPage(context),
            isSelected: _currentTitle == 'Change Email',
          ),
          SizedBox(height: 16),
          buildProfileOptionCard(
            context: context,
            title: 'Notification Settings',
            subtitle: 'Manage your notification preferences',
            icon: Icons.notifications_outlined,
            onTap: () => _showNotificationSettingsPage(context),
            isSelected: _currentTitle == 'Notification Settings',
          ),
          SizedBox(height: 16),
          buildProfileOptionCard(
            context: context,
            title: 'About',
            subtitle: 'Read about this project',
            icon: Icons.privacy_tip_outlined,
            onTap: () => _showAboutPage(context),
            isSelected: _currentTitle == 'About',
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
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 900; // Adjusting breakpoint for better experience

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
            // Right side - Detail view (removed title bar)
            Expanded(


              child: _currentDetailPage != null
                  ? _currentDetailPage!
                  : Center(
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
    );
  }
}