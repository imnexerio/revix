import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:retracker/Utils/CustomSnackBar.dart';

void showChangeEmailBottomSheet(BuildContext context) {
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
                            icon: Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                            color: Theme.of(context).colorScheme.onSurface,
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
                            child: Container(
                              width: 200,
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
                                      await user.verifyBeforeUpdateEmail(_newEmail!);
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        customSnackBar(
                                          context: context,
                                          message: 'Verification email sent to $_newEmail. Please verify it and Pull to refresh.',
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
                                ),
                              ),
                            ),
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
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          controller: controller,
          onSaved: onSaved,
          validator: validator,
        ),
      ),
    ],
  );
}