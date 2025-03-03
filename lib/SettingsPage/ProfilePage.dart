// EditProfilePage.dart
  import 'package:flutter/material.dart';
  import 'package:image_picker/image_picker.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:firebase_database/firebase_database.dart';
  import 'package:retracker/Utils/customSnackBar_error.dart';
  import 'package:retracker/Utils/CustomSnackBar.dart';

  class EditProfilePage extends StatefulWidget {
    final Future<String> Function() getDisplayName;
    final Future<Image?> Function(String) decodeProfileImage;
    final Future<void> Function(BuildContext, XFile, String) uploadProfilePicture;
    final String Function() getCurrentUserUid;

    EditProfilePage({
      required this.getDisplayName,
      required this.decodeProfileImage,
      required this.uploadProfilePicture,
      required this.getCurrentUserUid,
    });

    @override
    _EditProfilePageState createState() => _EditProfilePageState();
  }

  class _EditProfilePageState extends State<EditProfilePage> {
    final _formKey = GlobalKey<FormState>();
    String? _fullName;
    String? _displayName;

    @override
    void initState() {
      super.initState();
      _loadDisplayName();
    }

    Future<void> _loadDisplayName() async {
      try {
        _displayName = await widget.getDisplayName();
      } catch (e) {
        _displayName = 'User';
      }
      setState(() {});
    }

    @override
    Widget build(BuildContext context) {
      final screenSize = MediaQuery.of(context).size;

      return Scaffold(
        appBar: AppBar(
          title: Text('Edit Profile'),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    children: [
                      FutureBuilder<Image?>(
                        future: widget.decodeProfileImage(widget.getCurrentUserUid()),
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
                                      await widget.uploadProfilePicture(context, image, widget.getCurrentUserUid());
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
                FilledButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      try {
                        User? user = FirebaseAuth.instance.currentUser;
                        String uid = widget.getCurrentUserUid();
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
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          customSnackBar_error(
                            context: context,
                            message: 'Failed to update profile: $e',
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
      );
    }
  }