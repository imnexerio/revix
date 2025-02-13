import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../LoginSignupPage/LoginPage.dart';
import '../LoginSignupPage/UrlLauncher.dart';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_database/firebase_database.dart';

import '../ThemeNotifier.dart';
import '../theme_data.dart';


class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedTemeIndex = 0;


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

  Future<String?> _getProfilePicture(String uid) async {
    try {
      DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data');
      DataSnapshot snapshot = await databaseRef.child('profile_picture').get();
      // print('snapshot value: ${snapshot.value}');
      if (snapshot.exists) {
        return snapshot.value as String?;
      }
    } catch (e) {
      print('Error retrieving profile picture: $e');
    }
    return null;
  }

  Future<Image?> _getProfileImage(String uid) async {
    const String defaultImagePath = 'assets/icon/icon.png'; // Path to your default image

    try {
      String? base64String = await _getProfilePicture(uid);
      if (base64String != null) {
        Uint8List imageBytes = base64Decode(base64String);
        return Image.memory(imageBytes);
      }
    } catch (e) {
      print('Error decoding profile picture: $e');
    }
    return Image.asset(defaultImagePath);
  }



  Future<void> uploadProfilePicture(BuildContext context, XFile imageFile, String uid) async {
    try {
      // Convert image to byte array
      Uint8List imageBytes = await imageFile.readAsBytes();

      // Set initial quality and size threshold
      int quality = 100;
      const int maxSizeInBytes = 30 * 1024; // 100 KB
      Uint8List? compressedImageBytes;

      // Compress the image and adjust quality until the size is below the threshold
      do {
        compressedImageBytes = await FlutterImageCompress.compressWithList(
          imageBytes,
          minWidth: 120,
          minHeight: 120,
          quality: quality,
        );

        if (compressedImageBytes == null) {
          throw Exception('Failed to compress image');
        }

        quality -= 10; // Decrease quality by 10 for each iteration
      } while (compressedImageBytes.lengthInBytes > maxSizeInBytes && quality > 0);

      // Encode byte array to Base64 string
      String base64String = base64Encode(compressedImageBytes);

      // Store Base64 string in Firebase Realtime Database at the specified location
      DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data');
      await databaseRef.update({'profile_picture': base64String});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Profile picture uploaded successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      setState(() {
        // Update the profile picture in the UI
      });
    } catch (e) {
      print('Failed to upload profile picture: $e');
    }
  }


  Future<void> _sendVerificationEmail(BuildContext context) async {
  try {
    User? user = FirebaseAuth.instance.currentUser;
    await user?.sendEmailVerification();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Verification email sent successfully'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Text('Failed to send verification email: $e'),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}



Future<String> _fetchReleaseNotes() async {
  final response = await http.get(Uri.parse('https://api.github.com/repos/imnexerio/retracker/releases/latest'));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return data['body'] ?? 'No release notes available';
  } else {
    throw Exception('Failed to load release notes');
  }
}


  void _showEditProfileBottomSheet(BuildContext context) async {
    final screenSize = MediaQuery.of(context).size;
    final _formKey = GlobalKey<FormState>();
    String? _fullName;
    String? _displayName;

    try {
      _displayName = await _getDisplayName();
    } catch (e) {
      _displayName = 'User';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: screenSize.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 5,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative background element
              // Positioned(
              //   top: -100,
              //   right: -100,
              //   child: Container(
              //     width: 200,
              //     height: 200,
              //     decoration: BoxDecoration(
              //       shape: BoxShape.circle,
              //       color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              //     ),
              //   ),
              // ),
              // Main content
              SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 12,
                    left: 24,
                    right: 24,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle bar
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Profile',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onBackground,
                                  ),
                                ),
                                Text(
                                  'Update your personal information',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close, size: 20),
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                                padding: EdgeInsets.all(12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 40),
                        // Profile Image Section
                        Center(
                          child: Stack(
                            children: [
                              FutureBuilder<Image?>(
                                future: _getProfileImage(getCurrentUserUid()),
                                builder: (context, snapshot) {
                                  Widget profileWidget = Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: snapshot.connectionState == ConnectionState.waiting
                                        ? Center(child: CircularProgressIndicator(strokeWidth: 2))
                                        : CircleAvatar(
                                      radius: 55,
                                      backgroundImage: snapshot.hasData
                                          ? snapshot.data!.image
                                          : AssetImage('assets/icon/icon.png'),
                                      backgroundColor: Colors.transparent,
                                    ),
                                  );

                                  return Stack(
                                    children: [
                                      profileWidget,
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: InkWell(
                                          onTap: () async {
                                            final ImagePicker _picker = ImagePicker();
                                            final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                                            if (image != null) {
                                              await uploadProfilePicture(context, image, getCurrentUserUid());
                                              Navigator.pop(context);
                                            }
                                          },
                                          child: Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 40),
                        // Name Input Field with animated label
                        AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                            ),
                          ),
                          child: TextFormField(
                            initialValue: _displayName,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              labelStyle: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            onSaved: (value) => _fullName = value,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(height: 40),
                        // Save Button
                        FilledButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState!.save();
                              try {
                                User? user = FirebaseAuth.instance.currentUser;
                                await user?.updateDisplayName(_fullName);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Container(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(Icons.check_circle, color: Colors.white, size: 20),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Profile updated successfully',
                                            style: TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    margin: EdgeInsets.all(16),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Container(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(Icons.error, color: Colors.white, size: 20),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Failed to update profile: $e',
                                              style: TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 3),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    margin: EdgeInsets.all(16),
                                  ),
                                );
                              }
                            }
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  void _showThemeBottomSheet(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);

    // RGB values for custom theme
    int _redValue = themeNotifier.customThemeColor?.red ?? 0;
    int _greenValue = themeNotifier.customThemeColor?.green ?? 0;
    int _blueValue = themeNotifier.customThemeColor?.blue ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Handle bar
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Appearance',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onBackground,
                                    ),
                                  ),
                                  Text(
                                    'Customize your app theme',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(Icons.close, size: 20),
                                style: IconButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                                  padding: EdgeInsets.all(12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 32),
                          // Predefined Themes Section
                          Text(
                            'Theme Selection',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          SizedBox(height: 12),
                          Consumer<ThemeNotifier>(
                            builder: (context, themeNotifier, child) {
                              return Container(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: themeNotifier.selectedThemeIndex,
                                    isExpanded: true,
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    items: [
                                      ...List.generate(AppThemes.themeNames.length, (index) {
                                        return DropdownMenuItem<int>(
                                          value: index,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 24,
                                                height: 24,
                                                margin: EdgeInsets.only(right: 12),
                                                decoration: BoxDecoration(
                                                  color: AppThemes.themes[index * 2].colorScheme.primary,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white.withOpacity(0.5),
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                AppThemes.themeNames[index],
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      // Custom theme option
                                      DropdownMenuItem<int>(
                                        value: ThemeNotifier.customThemeIndex,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              margin: EdgeInsets.only(right: 12),
                                              decoration: BoxDecoration(
                                                color: themeNotifier.customThemeColor ?? Colors.grey,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.5),
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Custom',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onChanged: (int? newIndex) {
                                      if (newIndex != null) {
                                        if (newIndex == ThemeNotifier.customThemeIndex) {
                                          // If custom theme is selected but no color is set, initialize with a default
                                          if (themeNotifier.customThemeColor == null) {
                                            final defaultCustomColor = Color.fromRGBO(100, 100, 100, 1);
                                            themeNotifier.setCustomTheme(defaultCustomColor);
                                            setState(() {
                                              _redValue = defaultCustomColor.red;
                                              _greenValue = defaultCustomColor.green;
                                              _blueValue = defaultCustomColor.blue;
                                            });
                                          }
                                        }
                                        themeNotifier.updateThemeBasedOnMode(newIndex);
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 32),

                          // Custom Theme Section - Only show when Custom is selected
                          Consumer<ThemeNotifier>(
                            builder: (context, themeNotifier, child) {
                              if (themeNotifier.selectedThemeIndex != ThemeNotifier.customThemeIndex) {
                                return SizedBox.shrink();
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Custom Theme',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  // Color Preview
                                  Center(
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Color.fromRGBO(_redValue, _greenValue, _blueValue, 1),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.outline,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color.fromRGBO(_redValue, _greenValue, _blueValue, 0.3),
                                            blurRadius: 12,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  // RGB Sliders
                                  _buildColorSlider(
                                    context,
                                    'Red',
                                    _redValue,
                                    Colors.red,
                                        (value) => setState(() => _redValue = value.round()),
                                  ),
                                  SizedBox(height: 16),
                                  _buildColorSlider(
                                    context,
                                    'Green',
                                    _greenValue,
                                    Colors.green,
                                        (value) => setState(() => _greenValue = value.round()),
                                  ),
                                  SizedBox(height: 16),
                                  _buildColorSlider(
                                    context,
                                    'Blue',
                                    _blueValue,
                                    Colors.blue,
                                        (value) => setState(() => _blueValue = value.round()),
                                  ),
                                  SizedBox(height: 24),
                                  // Apply Custom Theme Button
                                  FilledButton(
                                    onPressed: () {
                                      final customColor = Color.fromRGBO(_redValue, _greenValue, _blueValue, 1);
                                      themeNotifier.setCustomTheme(customColor);
                                      Navigator.pop(context);
                                    },
                                    style: FilledButton.styleFrom(
                                      minimumSize: Size(double.infinity, 56),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      'Apply Custom Theme',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                          SizedBox(height: 32),
                          // Theme Mode Selection (remains the same)
                          Text(
                            'Theme Mode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          SizedBox(height: 12),
                          Consumer<ThemeNotifier>(
                            builder: (context, themeNotifier, child) {
                              return Container(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<ThemeMode>(
                                    value: themeNotifier.currentThemeMode,
                                    isExpanded: true,
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: ThemeMode.system,
                                        child: Row(
                                          children: [
                                            Icon(Icons.settings_suggest_outlined, size: 24),
                                            SizedBox(width: 12),
                                            Text('System Default'),
                                          ],
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: ThemeMode.light,
                                        child: Row(
                                          children: [
                                            Icon(Icons.light_mode_outlined, size: 24),
                                            SizedBox(width: 12),
                                            Text('Light'),
                                          ],
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: ThemeMode.dark,
                                        child: Row(
                                          children: [
                                            Icon(Icons.dark_mode_outlined, size: 24),
                                            SizedBox(width: 12),
                                            Text('Dark'),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onChanged: (ThemeMode? newMode) {
                                      if (newMode != null) {
                                        themeNotifier.changeThemeMode(newMode);
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
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



  // Helper method to build color sliders
  Widget _buildColorSlider(
      BuildContext context,
      String label,
      int value,
      Color color,
      ValueChanged<double> onChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            Text(
              value.toString(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  void _showChangePasswordBottomSheet(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final _formKey = GlobalKey<FormState>();
    final TextEditingController _newPasswordController = TextEditingController();
    String? _currentPassword;
    String? _newPassword;
    String? _confirmPassword;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: screenSize.height * 0.8,
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
                  child: Form(
                    key: _formKey,
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
                          onSaved: (value) => _currentPassword = value,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your current password';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        _buildInputField(
                          context: context,
                          label: 'New Password',
                          hint: 'Enter new password',
                          icon: Icons.lock_outline,
                          isPassword: true,
                          controller: _newPasswordController,
                          onSaved: (value) => _newPassword = value,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a new password';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        _buildInputField(
                          context: context,
                          label: 'Confirm Password',
                          hint: 'Confirm new password',
                          icon: Icons.lock_outline,
                          isPassword: true,
                          onSaved: (value) => _confirmPassword = value,
                          validator: (value) {
                            print('Confirm Password: $value');
                            print('New Password: ${_newPasswordController.text}');
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your new password';
                            }
                            if (value != _newPasswordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 40),
                        Center(
                          child: Container(
                            width: 200, // Set the desired width
                            child: FilledButton(
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  _formKey.currentState!.save();
                                  try {
                                    User? user = FirebaseAuth.instance.currentUser;
                                    AuthCredential credential = EmailAuthProvider.credential(
                                      email: user!.email!,
                                      password: _currentPassword!,
                                    );
                                    await user.reauthenticateWithCredential(credential);
                                    await user.updatePassword(_newPassword!);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.white),
                                            SizedBox(width: 8),
                                            Text('Password updated successfully'),
                                          ],
                                        ),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(Icons.error, color: Colors.white),
                                            SizedBox(width: 8),
                                            Text('Failed to update password: $e'),
                                          ],
                                        ),
                                        backgroundColor: Colors.red,
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  }
                                }
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangeEmailBottomSheet(BuildContext context) {
  final screenSize = MediaQuery.of(context).size;
  final _formKey = GlobalKey<FormState>();
  String? _currentPassword;
  String? _newEmail;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return Container(
        height: screenSize.height * 0.6,
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Change Email',
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
                        onSaved: (value) => _currentPassword = value,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your current password';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      _buildInputField(
                        context: context,
                        label: 'New Email',
                        hint: 'Enter new email',
                        icon: Icons.email_outlined,
                        onSaved: (value) => _newEmail = value,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a new email';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 40),
                      Builder(
                        builder: (BuildContext newContext) {
                          return Center(
                          child:
                            Container(
                            width: 200,
                            child:
                            FilledButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                _formKey.currentState!.save();
                                try {
                                  User? user = FirebaseAuth.instance.currentUser;
                                  AuthCredential credential = EmailAuthProvider.credential(
                                    email: user!.email!,
                                    password: _currentPassword!,
                                  );
                                  await user.reauthenticateWithCredential(credential);
                                  await user.verifyBeforeUpdateEmail(_newEmail!);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(newContext).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.white),
                                          SizedBox(width: 8),
                                          Text('Verification email sent to $_newEmail. Please verify it and restart the app.'),
                                        ],
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      margin: EdgeInsets.all(16),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(newContext).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(Icons.error, color: Colors.white),
                                          SizedBox(width: 8),
                                          Text('Failed to update email: $e'),
                                        ],
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      margin: EdgeInsets.all(16),
                                    ),
                                  );
                                }
                              }
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: Size(double.infinity, 55),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Update Email',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),),),
                          );
                        },
                      ),
                    ],
                  ),
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
    final _formKey = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: screenSize.height * 0.8,
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
                  child: Form(
                    key: _formKey,
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
                      false,
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
                )
              )
            ],
          ),
        );
      },
    );
  }

  void _showAboutBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Container(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight * 0.4,
                maxHeight: constraints.maxHeight * 0.85,
              ),
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
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.grey.withOpacity(0.1),
                                child: ClipOval(
                                  child: Stack(
                                    children: [
                                      ColorFiltered(
                                        colorFilter: ColorFilter.mode(
                                          Colors.grey,
                                          BlendMode.saturation,
                                        ),
                                        child: Image.asset(
                                          'assets/icon/icon.png', // Path to your app icon
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withOpacity(0.3),
                                              Colors.transparent,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'reTracker',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onBackground,
                                ),
                              ),
                              SizedBox(height: 5),
                              FutureBuilder<String>(
                                future: _getAppVersion(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return CircularProgressIndicator();
                                  } else if (snapshot.hasError) {
                                    return Text('Error loading version');
                                  } else {
                                    return Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'v${snapshot.data}',
                                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                color: Theme.of(context).colorScheme.secondary,
                                                fontSize: 14,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Theme.of(context).colorScheme.secondary),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'FOSS',
                                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                  color: Theme.of(context).colorScheme.secondary,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        IconButton(
                                          icon: ImageIcon(
                                            AssetImage('assets/github.png'), // Path to your GitHub icon
                                          ),
                                          onPressed: () {
                                            UrlLauncher.launchURL('https://github.com/imnexerio/retracker');
                                          },
                                        ),
                                      ],
                                    );
                                  }
                                },
                              )
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              child: FutureBuilder<String>(
                                future: _fetchReleaseNotes(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  } else if (snapshot.hasError) {
                                    return Text(
                                      'Error loading release notes',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    );
                                  } else {
                                    return Text(
                                      snapshot.data!,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          Container(
                            width: 200, // Set the desired width
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: FilledButton.styleFrom(
                                minimumSize: Size(double.infinity, 55),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: Theme.of(context).colorScheme.primary,
                              ),
                              child: Text(
                                'I Understand',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
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
    );}


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
                          future: _getProfileImage(getCurrentUserUid()),
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
                    icon: Icons.person_2_rounded,
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
              // Container(
              //   padding: EdgeInsets.all(12),
              //   decoration: BoxDecoration(
              //     color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              //     borderRadius: BorderRadius.circular(12),
              //   ),
              //   child: Icon(
              //     icon,
              //     color: Theme.of(context).colorScheme.primary,
              //   ),
              // ),
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