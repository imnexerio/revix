import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'ProfileImageUpload.dart';
import 'ProfileProvider.dart';
import 'ProfileImageWidget.dart';
import 'package:revix/Utils/customSnackBar_error.dart';
import 'package:revix/Utils/CustomSnackBar.dart';
import '../Utils/FirebaseDatabaseService.dart';
import '../Utils/FirebaseAuthService.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final FirebaseDatabaseService _databaseService = FirebaseDatabaseService();
  final FirebaseAuthService _authService = FirebaseAuthService();
  String? _fullName;
  bool _isLoading_pic = false;
  bool _isLoading_name = false;
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = _authService.currentUserId ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }


  Future<void> _loadUserData() async {
      await Provider.of<ProfileProvider>(context, listen: false).fetchAndUpdateProfileImage(context);
      await Provider.of<ProfileProvider>(context, listen: false).fetchAndUpdateDisplayName();
      _nameController.text = Provider.of<ProfileProvider>(context, listen: false).displayName ?? 'User';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      setState(() {
        _isLoading_pic = true;
      });

      await uploadProfilePicture(context, image);

      await Provider.of<ProfileProvider>(context, listen: false).fetchAndUpdateProfileImage(context);

      if (mounted) {
        setState(() {
          _isLoading_pic = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: _buildProfilePicture(),
                ),
                const SizedBox(height: 40),
                _buildNameField(),
                const SizedBox(height: 40),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Profile Circle with Border
        Container(
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
        ),

        // Profile Image
        SizedBox(
          width: 110,
          height: 110,
          child: _isLoading_pic
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ClipOval(
            child: ProfileImageWidget(),
          ),
        ),

        // Camera Icon
        Positioned(
          bottom: 0,
          right: 0,
          child: InkWell(
            onTap: _updateProfilePicture,
            child: Container(
              padding: const EdgeInsets.all(8),
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
              child: const Icon(
                Icons.camera_alt,
                // color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: TextFormField(
        controller: _nameController,
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
        style: const TextStyle(
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
    );
  }

  Widget _buildSaveButton() {
    return FilledButton(
      onPressed: _isLoading_name ? null : _saveProfile, // Disable button when loading
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
      child: _isLoading_name
          ? const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      )
          : const Text(
        'Save Changes',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    // Check if the form is valid
    if (_formKey.currentState!.validate()) {
      // Save form data
      _formKey.currentState!.save();

        customSnackBar(
          context: context,
          message: 'Updating Display Name',

      );

      // Begin the async operation and update the loading state
      setState(() {
        _isLoading_name = true; // Start loading spinner
      });      try {
        // Update name using centralized database service
        await _databaseService.updateProfileData({'name': _fullName});

        // Update display name for FirebaseAuth user
        await _authService.updateDisplayName(_fullName!);

        // Update the display name in the provider
        await Provider.of<ProfileProvider>(context, listen: false)
            .fetchAndUpdateDisplayName();

        // Show success message
        if (mounted) {

            customSnackBar(
              context: context,
              message: 'Display Name updated successfully',
          );
        }
      } catch (e) {
          customSnackBar_error(
            context: context,
            message: 'Failed to update profile: $e',
        );
      } finally {
        // Reset loading state
        if (mounted) {
          setState(() {
            _isLoading_name = false; // Stop loading spinner
          });
        }
      }
    }
  }
}