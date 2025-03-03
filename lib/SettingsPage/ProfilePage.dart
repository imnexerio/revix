import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:retracker/Utils/customSnackBar_error.dart';
import 'package:retracker/Utils/CustomSnackBar.dart';

Future<void> showEditProfileBottomSheet(BuildContext context, Future<String> Function() getDisplayName, Future<Image?> Function(String) decodeProfileImage, Future<void> Function(BuildContext, XFile, String) uploadProfilePicture, String Function() getCurrentUserUid) async {
  final screenSize = MediaQuery.of(context).size;
  final _formKey = GlobalKey<FormState>();
  String? _fullName;
  String? _displayName;

  try {
    _displayName = await getDisplayName();
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
                            icon: Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ],
                      ),
                      SizedBox(height: 40),
                      // Profile Image Section
                      Center(
                        child: Stack(
                          children: [
                            FutureBuilder<Image?>(
                              future: decodeProfileImage(getCurrentUserUid()),
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
                              String uid = getCurrentUserUid();
                              DatabaseReference ref = FirebaseDatabase.instance.ref('users/$uid/profile_data');
                              await ref.update({
                                'name': _fullName
                              });
                              await user?.updateDisplayName(_fullName);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                customSnackBar(
                                  context: context,
                                  message: 'Profile uploaded successfully',
                                ),
                              );;
                            } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  customSnackBar_error(
                                    context: context,
                                    message: 'Failed to update profile: $e',
                                  ),
                                );;
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