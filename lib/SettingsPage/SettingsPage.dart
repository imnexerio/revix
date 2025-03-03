import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:retracker/Utils/customSnackBar_error.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../LoginSignupPage/LoginPage.dart';
import '../LoginSignupPage/UrlLauncher.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_database/firebase_database.dart';

import '../ThemeNotifier.dart';
import '../Utils/CustomSnackBar.dart';
import '../Utils/FetchTypesUtils.dart';
import '../Utils/fetchFrequencies_utils.dart';
import '../theme_data.dart';
import 'AboutPage.dart';
import 'CHangePassPage.dart';
import 'ChangeMailPage.dart';
import 'DecodeProfilePic.dart';
import 'FetchProfilePic.dart';
import 'FetchReleaseNote.dart';
import 'FrequencyPage.dart';
import 'NotificationPage.dart';
import 'ProfileImageUpload.dart';
import 'ProfilePage.dart';
import 'SendVerificationMail.dart';
import 'ThemePage.dart';
import 'TrackingTypePage.dart';


class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

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

  // Use the function from the new file
  void _showEditProfileBottomSheet(BuildContext context) {
    showEditProfileBottomSheet(context, _getDisplayName, _decodeProfileImage, uploadProfilePicture, getCurrentUserUid);
  }


  // Use the function from the new file
  void _showThemeBottomSheet(BuildContext context) {
    showThemeBottomSheet(context);
  }

  void _showFrequencyBottomSheet(BuildContext context) {
    List<Map<String, String>> frequencies = [];
    final _formKey = GlobalKey<FormState>();
    final TextEditingController _customFrequencyController = TextEditingController();
    final TextEditingController _customTitleController = TextEditingController();

    // Validation function remains the same
    bool isValidFrequencyFormat(String frequency) {
      if (frequency.isEmpty) return false;
      try {
        List<String> numbers = frequency.split(',').map((e) => e.trim()).toList();
        List<int> numericalValues = numbers.map((e) => int.parse(e)).toList();
        numericalValues.sort();
        for (int i = 0; i < numericalValues.length - 1; i++) {
          if (numericalValues[i] >= numericalValues[i + 1]) return false;
        }
        return true;
      } catch (e) {
        return false;
      }
    }

    // Fetch data function remains the same
    void fetchFrequencies(StateSetter setState) async {
      try {
        Map<String, dynamic> data = await FetchFrequenciesUtils.fetchFrequencies();
        setState(() {
          frequencies = data.entries.map((entry) {
            String title = entry.key;
            List<dynamic> frequencyList = entry.value;
            String frequency = frequencyList.join(', ');

            return {
              'title': title,
              'frequency': frequency,
            };
          }).toList();
        });
      } catch (e) {

        // ScaffoldMessenger.of(context).showSnackBar(
        //   customSnackBar_error(
        //     context: context,
        //     message: 'Error fetching frequencies: $e',
        //   ),
        // );
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            fetchFrequencies(setState);
            return Container(
              height: MediaQuery.of(context).size.height * 0.73,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar and header
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Frequency (Days)',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Customize your tracking frequency',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1),
                  // Frequencies list
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outlineVariant,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Title',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          'Frequency',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(height: 1),
                                ...frequencies.map((frequency) => Column(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              frequency['title']!,
                                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              frequency['frequency']!,
                                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (frequencies.indexOf(frequency) != frequencies.length - 1)
                                      Divider(height: 1),
                                  ],
                                )).toList(),
                              ],
                            ),
                          ),
                          SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => _showAddFrequencySheet(
                              context,
                              _formKey,
                              _customTitleController,
                              _customFrequencyController,
                              frequencies,
                              setState,
                              isValidFrequencyFormat,
                            ),
                            icon: Icon(Icons.add),
                            label: Text('Add Custom Frequency'),
                            style: FilledButton.styleFrom(
                              minimumSize: Size(200, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
      },
    );
  }


  // Use the function from the new file
  void _showAddFrequencySheet(
    BuildContext context,
    GlobalKey<FormState> formKey,
    TextEditingController titleController,
    TextEditingController frequencyController,
    List<Map<String, String>> frequencies,
    StateSetter setState,
    bool Function(String) isValidFrequencyFormat,
  ) {
    showAddFrequencySheet(
      context,
      formKey,
      titleController,
      frequencyController,
      frequencies,
      setState,
      isValidFrequencyFormat,
    );
  }


  // Use the function from the new file
  void _showtrackingTypeBottomSheet(BuildContext context) {
    showTrackingTypeBottomSheet(context);
  }


  // Use the function from the new file
  void _showChangePasswordBottomSheet(BuildContext context) {
    showChangePasswordBottomSheet(context);
  }


  // Use the function from the new file
  void _showChangeEmailBottomSheet(BuildContext context) {
    showChangeEmailBottomSheet(context);
  }


  // Use the function from the new file
  void _showNotificationSettingsBottomSheet(BuildContext context) {
    showNotificationSettingsBottomSheet(context);
  }


  // Use the function from the new file
  void _showAboutBottomSheet(BuildContext context) {
    showAboutBottomSheet(context, _getAppVersion, _fetchReleaseNotes);
  }


  Widget _buildInputField({
  required BuildContext context,
  required String label,
  required String hint,
  required IconData icon,
  required FormFieldSetter<String> onSaved,
  required FormFieldValidator<String> validator,
  bool isPassword = false,
  TextEditingController? controller,

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
        child: TextFormField(
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
          controller: controller,
          onSaved: onSaved,
          validator: validator,
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
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: SingleChildScrollView(
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
                                onTap: () => _showEditProfileBottomSheet(context),
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
            ),
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              child: Column(
                children: [
                  _buildProfileOptionCard(
                    context: context,
                    title: 'Edit Profile',
                    subtitle: 'Update your personal information',
                    icon: Icons.person,
                    onTap: () => _showEditProfileBottomSheet(context),
                  ),
                  SizedBox(height: 16),
                  _buildProfileOptionCard(
                    context: context,
                    title: 'Set Theme',
                    subtitle: 'Choose your style',
                    icon: Icons.color_lens_outlined,
                    onTap: () => _showThemeBottomSheet(context),
                  ),
                  SizedBox(height: 16),
                  _buildProfileOptionCard(
                    context: context,
                    title: 'Custom Frequency',
                    subtitle: 'Modify your tracking intervals',
                    icon: Icons.timelapse_sharp,
                    onTap: () => _showFrequencyBottomSheet(context),
                  ),
                  SizedBox(height: 16),
                  _buildProfileOptionCard(
                    context: context,
                    title: 'Custom Tracking Type',
                    subtitle: 'Modify your tracking intervals',
                    icon: Icons.track_changes_rounded,
                    onTap: () => _showtrackingTypeBottomSheet(context),
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
                    title: 'Change Email',
                    subtitle: 'Update your Email credentials',
                    icon: Icons.email_outlined,
                    onTap: () => _showChangeEmailBottomSheet(context),
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
                    title: 'About',
                    subtitle: 'Read about this project',
                    icon: Icons.privacy_tip_outlined,
                    onTap: () => _showAboutBottomSheet(context),
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
            ),
          ],
        ),
      ),)
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