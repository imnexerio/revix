import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _passwordVisibility = false;
  bool _confirmPasswordVisibility = false;

  void _signup() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords don\'t match!')),
      );
      return;
    }

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      Navigator.pop(context);
    } catch (e) {
      // print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sign up', style: textTheme.headlineSmall),
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0, 40, 0, 0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(24, 24, 0, 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        'Get Started',
                        style: textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            'Create your account below.',
                            style: textTheme.titleMedium,
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(0, 20, 0, 0),
                        child: TextFormField(
                          controller: _emailController,
                          obscureText: false,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            labelStyle: textTheme.bodyMedium,
                            hintText: 'Enter your email...',
                            hintStyle: textTheme.bodyMedium,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: colorScheme.onSurface.withOpacity(0.12),
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: colorScheme.surface,
                            contentPadding: EdgeInsetsDirectional.fromSTEB(20, 24, 20, 24),
                          ),
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: !_passwordVisibility,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: textTheme.bodyMedium,
                            hintText: 'Enter your password...',
                            hintStyle: textTheme.bodyMedium,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: colorScheme.onSurface.withOpacity(0.12),
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: colorScheme.surface,
                            contentPadding: EdgeInsetsDirectional.fromSTEB(20, 24, 20, 24),
                            suffixIcon: InkWell(
                              onTap: () => setState(
                                () => _passwordVisibility = !_passwordVisibility,
                              ),
                              focusNode: FocusNode(skipTraversal: true),
                              child: Icon(
                                _passwordVisibility
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: colorScheme.onSurface.withOpacity(0.6),
                                size: 20,
                              ),
                            ),
                          ),
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                        child: TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_confirmPasswordVisibility,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            labelStyle: textTheme.bodyMedium,
                            hintText: 'Enter your password...',
                            hintStyle: textTheme.bodyMedium,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: colorScheme.onSurface.withOpacity(0.12),
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: colorScheme.surface,
                            contentPadding: EdgeInsetsDirectional.fromSTEB(20, 24, 20, 24),
                            suffixIcon: InkWell(
                              onTap: () => setState(
                                () => _confirmPasswordVisibility = !_confirmPasswordVisibility,
                              ),
                              focusNode: FocusNode(skipTraversal: true),
                              child: Icon(
                                _confirmPasswordVisibility
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: colorScheme.onSurface.withOpacity(0.6),
                                size: 20,
                              ),
                            ),
                          ),
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(0, 24, 0, 24),
                        child: ElevatedButton(
                          onPressed: _signup,
                          child: Text('Create Account'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: colorScheme.onPrimary,
                            backgroundColor: colorScheme.primary,
                            textStyle: textTheme.labelLarge,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.8,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_back_rounded,
                                    color: colorScheme.primary,
                                    size: 24,
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(4, 0, 24, 0),
                                    child: Text(
                                      'Login',
                                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.primary),
                                    ),
                                  ),
                                  Text(
                                    'Already have an account?',
                                    style: textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(0, 24, 0, 0),
                        child: ElevatedButton(
                          onPressed: () {
                            // Continue as Guest
                          },
                          child: Text('Continue as Guest'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            backgroundColor: colorScheme.surface,
                            textStyle: textTheme.labelLarge,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}