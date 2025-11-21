import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException, EmailAuthProvider;
import 'package:revix/Utils/CustomSnackBar.dart';
import 'package:revix/Utils/customSnackBar_error.dart';
import '../Utils/FirebaseAuthService.dart';

class ChangeCredentialsPage extends StatefulWidget {
  @override
  _ChangeCredentialsPageState createState() => _ChangeCredentialsPageState();
}

class _ChangeCredentialsPageState extends State<ChangeCredentialsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Password form
  final _passwordFormKey = GlobalKey<FormState>();
  final TextEditingController _newPasswordController = TextEditingController();
  String? _currentPasswordForPassword;
  String? _newPassword;
  String? _confirmPassword;
  
  // Email form
  final _emailFormKey = GlobalKey<FormState>();
  final TextEditingController _newEmailController = TextEditingController();
  String? _currentPasswordForEmail;
  String? _newEmail;
  
  final FirebaseAuthService _authService = FirebaseAuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newPasswordController.dispose();
    _newEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.lock_outline),
                  text: 'Password',
                ),
                Tab(
                  icon: Icon(Icons.email_outlined),
                  text: 'Email',
                ),
              ],
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.primary,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Theme.of(context).colorScheme.onPrimary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.all(4),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPasswordTab(),
                _buildEmailTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Password',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Update your account password',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            _buildInputField(
              context: context,
              label: 'Current Password',
              hint: 'Enter current password',
              icon: Icons.lock_outline,
              isPassword: true,
              onSaved: (value) => _currentPasswordForPassword = value,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your current password';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
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
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildInputField(
              context: context,
              label: 'Confirm Password',
              hint: 'Confirm new password',
              icon: Icons.lock_outline,
              isPassword: true,
              onSaved: (value) => _confirmPassword = value,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your new password';
                }
                if (value != _newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 40),
            Center(
              child: Container(
                width: 200,
                child: FilledButton(
                  onPressed: () => _changePassword(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Update Password',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _emailFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Email',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Update your account email address',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            _buildInputField(
              context: context,
              label: 'Current Password',
              hint: 'Enter current password',
              icon: Icons.lock_outline,
              isPassword: true,
              onSaved: (value) => _currentPasswordForEmail = value,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your current password';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildInputField(
              context: context,
              label: 'New Email',
              hint: 'Enter new email',
              icon: Icons.email_outlined,
              controller: _newEmailController,
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
            const SizedBox(height: 40),
            Center(
              child: Container(
                width: 200,
                child: FilledButton(
                  onPressed: () => _changeEmail(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Update Email',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    if (_passwordFormKey.currentState!.validate()) {
      _passwordFormKey.currentState!.save();
      
      try {
        // First reauthenticate the user
        final credential = EmailAuthProvider.credential(
          email: _authService.currentUser!.email!,
          password: _currentPasswordForPassword!,
        );
        await _authService.reauthenticateWithCredential(credential);
        
        // Then update the password
        await _authService.updatePassword(_newPassword!);

        customSnackBar(
          context: context,
          message: 'Password updated successfully',
        );

        _newPasswordController.clear();
        _currentPasswordForPassword = null;
        _confirmPassword = null;
        _passwordFormKey.currentState!.reset();
      } on FirebaseAuthException catch (e) {
        _showErrorSnackBar(_authService.getAuthErrorMessage(e));
      }
    }
  }

  Future<void> _changeEmail() async {
    if (_emailFormKey.currentState!.validate()) {
      _emailFormKey.currentState!.save();
      
      try {
        // First reauthenticate the user
        final credential = EmailAuthProvider.credential(
          email: _authService.currentUser!.email!,
          password: _currentPasswordForEmail!,
        );
        await _authService.reauthenticateWithCredential(credential);
        
        // Then update the email
        await _authService.updateEmail(_newEmail!);

        customSnackBar(
          context: context,
          message: 'Verification email sent to $_newEmail. Please verify it and Pull to refresh.',
        );

        _newEmailController.clear();
        _currentPasswordForEmail = null;
        _emailFormKey.currentState!.reset();
      } on FirebaseAuthException catch (e) {
        _showErrorSnackBar(_authService.getAuthErrorMessage(e));
      }
    }
  }

  void _showErrorSnackBar(String message) {
    customSnackBar_error(
      context: context,
      message: message,
      duration: const Duration(seconds: 3),
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
        const SizedBox(height: 8),
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
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            ),
            controller: controller,
            onSaved: onSaved,
            validator: validator,
          ),
        ),
      ],
    );
  }
}
