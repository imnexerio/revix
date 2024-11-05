import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../LoginSignupPage/LoginPage.dart';

class ProfilePage extends StatelessWidget {
  Future<void> _logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }



  void _showEditProfileBottomSheet(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: screenSize.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Handle bar at top
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.only(
                  top: 40,
                  left: 24,
                  right: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Edit Profile',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 30),
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: NetworkImage('https://via.placeholder.com/150'),
                              backgroundColor: Colors.transparent,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 30),
                      _buildInputField(
                        context: context,
                        label: 'Full Name',
                        hint: 'Enter your full name',
                        icon: Icons.person_outline,
                      ),
                      SizedBox(height: 20),
                      _buildInputField(
                        context: context,
                        label: 'Email',
                        hint: 'Enter your email',
                        icon: Icons.email_outlined,
                      ),
                      SizedBox(height: 40),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangePasswordBottomSheet(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: screenSize.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: 40,
                  left: 24,
                  right: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Change Password',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 30),
                      _buildInputField(
                        context: context,
                        label: 'Current Password',
                        hint: 'Enter current password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ),
                      SizedBox(height: 20),
                      _buildInputField(
                        context: context,
                        label: 'New Password',
                        hint: 'Enter new password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ),
                      SizedBox(height: 20),
                      _buildInputField(
                        context: context,
                        label: 'Confirm Password',
                        hint: 'Confirm new password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ),
                      SizedBox(height: 40),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Update Password',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationSettingsBottomSheet(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: screenSize.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Notifications',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 30),
                    _buildNotificationOption(
                      context,
                      'Push Notifications',
                      'Get notified about important updates',
                      Icons.notifications_outlined,
                      true,
                    ),
                    Divider(height: 32),
                    _buildNotificationOption(
                      context,
                      'Email Notifications',
                      'Receive updates via email',
                      Icons.email_outlined,
                      false,
                    ),
                    Divider(height: 32),
                    _buildNotificationOption(
                      context,
                      'Marketing Communications',
                      'Stay updated with our latest offers',
                      Icons.campaign_outlined,
                      false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPrivacyPolicyBottomSheet(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (BuildContext context) {
      return Container(
          height: screenSize.height * 0.85,
          decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    boxShadow: [
    BoxShadow(
    color: Colors.black12,
    blurRadius: 10,
    spreadRadius: 5,
    ),
    ],
    ),
    child: Stack(
    children: [
    Align(
    alignment: Alignment.topCenter,
    child: Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
    color: Colors.grey.withOpacity(0.3),
    borderRadius: BorderRadius.circular(2),
    ),
    ),
    ),
    ),
    Padding(
    padding: EdgeInsets.all(24),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    Text(
    'Privacy Policy',
    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
    fontWeight: FontWeight.bold,
    ),
    ),
    IconButton(
    onPressed: () => Navigator.pop(context),
    icon: Icon(Icons.close),
    style: IconButton.styleFrom(
    backgroundColor: Colors.grey.withOpacity(0.1),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    ),
    ),
    ],
    ),
    SizedBox(height: 20),
    Expanded(
    child: Container(
    decoration: BoxDecoration(
    color: Colors.grey.withOpacity(0.1),
    borderRadius: BorderRadius.circular(16),
    ),
    padding: EdgeInsets.all(16),
    child: SingleChildScrollView(
    child: Text(
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
    'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. '
    'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris '
    'nisi ut aliquip ex ea commodo consequat.\n\n'
    'Duis aute irure dolor in reprehenderit in voluptate velit esse '
    'cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat '
    'cupidatat non proident, sunt in culpa qui officia deserunt '
    'mollit anim id est laborum.\n\n'
    'Sed ut perspiciatis unde omnis iste natus error sit voluptatem '
    'accusantium doloremque laudantium, totam rem aperiam, eaque ipsa '
    'quae ab illo inventore veritatis et quasi architecto beatae vitae ''dicta sunt explicabo.\n\n'
        'Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut '
        'odit aut fugit, sed quia consequuntur magni dolores eos qui '
        'ratione voluptatem sequi nesciunt.',
      style: Theme.of(context).textTheme.bodyLarge,
    ),
    ),
    ),
    ),
      SizedBox(height: 20),
      FilledButton(
        onPressed: () {
          Navigator.pop(context);
        },
        style: FilledButton.styleFrom(
          minimumSize: Size(double.infinity, 55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'I Understand',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    ],
    ),
    ),
    ],
    ),
      );
        },
    );
  }

  Widget _buildInputField({
    required BuildContext context,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            obscureText: isPassword,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationOption(
      BuildContext context,
      String title,
      String subtitle,
      IconData icon,
      bool initialValue,
      ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: initialValue,
          onChanged: (value) {},
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
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
                        CircleAvatar(
                          radius: isSmallScreen ? 50 : 60,
                          backgroundImage: NetworkImage('https://via.placeholder.com/150'),
                          backgroundColor: Colors.transparent,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.background,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Your Name',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'imnexerio@gmail.com',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              child: Column(
                children: [
                  _buildProfileOptionCard(
                    context: context,
                    title: 'Edit Profile',
                    subtitle: 'Update your personal information',
                    icon: Icons.edit_outlined,
                    onTap: () => _showEditProfileBottomSheet(context),
                  ),
                  SizedBox(height: 16),
                  _buildProfileOptionCard(
                    context: context,
                    title: 'Change Password',
                    subtitle: 'Update your security credentials',
                    icon: Icons.lock_outline,
                    onTap: () => _showChangePasswordBottomSheet(context),
                  ),
                  SizedBox(height: 16),
                  _buildProfileOptionCard(
                    context: context,
                    title: 'Notification Settings',
                    subtitle: 'Manage your notification preferences',
                    icon: Icons.notifications_outlined,
                    onTap: () => _showNotificationSettingsBottomSheet(context),
                  ),
                  SizedBox(height: 16),
                  _buildProfileOptionCard(
                    context: context,
                    title: 'Privacy Policy',
                    subtitle: 'Read our privacy policy',
                    icon: Icons.privacy_tip_outlined,
                    onTap: () => _showPrivacyPolicyBottomSheet(context),
                  ),
                  SizedBox(height: 32),
                  FilledButton.tonal(
                    onPressed: () => _logout(context),
                    style: FilledButton.styleFrom(

                      minimumSize: Size(70, 55),
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                      foregroundColor: Theme.of(context).colorScheme.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Logout',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  Widget _buildProfileOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}