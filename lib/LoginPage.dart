import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:retracker/main.dart';
import 'SignupPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _passwordVisibility = false;

  void _login() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyHomePage()),
      );
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
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
                        'Welcome back',
                        style: textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            'Login to access your account below.',
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
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0, 24, 0, 24),
                            child: TextButton(
                              onPressed: () {
                                // Navigate to forgot password page
                              },
                              child: Text(
                                'Forgot Password?',
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _login,
                            child: Text('Login'),
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
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => SignupPage()),
                              );
                            },
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.8,
                              height: 44,
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account?",
                                    style: textTheme.bodyMedium,
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(24, 0, 4, 0),
                                    child: Text(
                                      'Create',
                                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.primary),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: colorScheme.primary,
                                    size: 24,
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