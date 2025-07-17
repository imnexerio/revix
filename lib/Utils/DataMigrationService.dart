import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException, UserCredential, User;

import 'GuestAuthService.dart';
import 'LocalDatabaseService.dart';
import 'HiveService.dart';
import 'FirebaseDatabaseService.dart';
import 'FirebaseAuthService.dart';
import 'CustomSnackBar.dart';
import 'customSnackBar_error.dart';
import '../LoginSignupPage/LoginPage.dart';

class DataMigrationService {
  static final FirebaseDatabaseService _databaseService = FirebaseDatabaseService();
  static final FirebaseAuthService _authService = FirebaseAuthService();
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  /// Migrates data from guest mode to a registered user account
  /// Returns a [bool] indicating if migration was successful
  static Future<bool> migrateGuestDataToAccount() async {
    try {      // Verify if a user is logged in
      var currentUser = _databaseService.currentUser;
      if (currentUser == null) {
        return false;
      }
      
      // Verify if we were in guest mode
      bool wasInGuestMode = await GuestAuthService.isGuestMode();
      if (!wasInGuestMode) {
        return false; // Not migrating if we weren't in guest mode
      }
      
      // Get the local database instance to access cached data
      LocalDatabaseService localDatabase = LocalDatabaseService();
      
      // Get all user data from local storage (Firebase-compatible structure)
      final userData = await localDatabase.getCurrentUserData();
      
      if (userData.isEmpty || userData['user_data'] == null || userData['user_data'].isEmpty) {
        // No data to migrate
        await _completeGuestModeMigration();
        return true;
      }
      
      // Reference to the user's database location
      DatabaseReference userDataRef = _database.ref('users/${currentUser.uid}/user_data');
      
      // Check if user already has data in Firebase
      DataSnapshot existingData = await userDataRef.get();
      if (existingData.exists) {
        // User has existing data, we need to merge
        await _mergeData(userDataRef, userData['user_data'].cast<dynamic, dynamic>());
      } else {
        // User has no data, we can directly set
        await userDataRef.set(userData['user_data']);
      }
      
      // Migrate profile data
      if (userData['profile_data'] != null && userData['profile_data'].isNotEmpty) {
        DatabaseReference profileRef = _database.ref('users/${currentUser.uid}/profile_data');
        DataSnapshot existingProfile = await profileRef.get();
        if (existingProfile.exists) {
          await _mergeData(profileRef, userData['profile_data'].cast<dynamic, dynamic>());
        } else {
          await profileRef.set(userData['profile_data']);
        }
      }

      
      // The profile data migration is handled above, as we now store everything in the users/{userId} structure
      // Adding extra clean-up for any legacy profile data that might exist
      try {
        final legacyProfileBox = await Hive.openBox<Map>('user_profile');
        if (legacyProfileBox.isNotEmpty) {
          await legacyProfileBox.clear();
        }
      } catch (e) {
        // Ignore errors with legacy boxes
      }
      
      // Update user ID for local storage to match Firebase user ID
      LocalDatabaseService.setCurrentUserId(currentUser.uid);
      
      // Complete the migration by cleaning up guest mode
      await _completeGuestModeMigration();
      
      return true;
    } catch (e) {
      print("Error during data migration: $e");
      return false;
    }
  }
  
  /// Creates a new account and migrates guest data to Firebase Realtime Database
  /// Shows UI for account creation and handles the complete migration process
  /// 
  /// This method:
  /// 1. Checks if the user is in guest mode
  /// 2. Shows a form for creating a new account (name, email, password)
  /// 3. Creates the Firebase account using official Firebase Auth
  /// 4. Initializes user profile in Firebase Realtime Database
  /// 5. Migrates all local guest data to Firebase
  /// 6. Sends email verification
  /// 7. Shows instructions to the user
  /// 8. Signs out the user and redirects to login page
  /// 
  /// Returns a [bool] indicating if the process was successful
  /// 
  /// Usage:
  /// ```dart
  /// bool success = await DataMigrationService.createAccountAndMigrateData(context);
  /// if (success) {
  ///   // User will be redirected to login page automatically
  /// }
  /// ```
  static Future<bool> createAccountAndMigrateData(BuildContext context) async {
    try {
      // Check if we are in guest mode
      bool isInGuestMode = await GuestAuthService.isGuestMode();
      if (!isInGuestMode) {
        _showSnackBar(context, 'This feature is only available in guest mode.', isError: true);
        return false;
      }

      // Get guest data first to check if there's anything to migrate
      final LocalDatabaseService localDatabase = LocalDatabaseService();
      final userData = await localDatabase.getCurrentUserData();
      
      bool hasDataToMigrate = userData.isNotEmpty && 
                               (userData['user_data'] != null && userData['user_data'].isNotEmpty ||
                                userData['profile_data'] != null && userData['profile_data'].isNotEmpty);

      // Show account creation dialog
      final accountDetails = await _showAccountCreationDialog(context, hasDataToMigrate);
      if (accountDetails == null) {
        return false; // User cancelled
      }

      try {        // Create the account
        UserCredential? userCredential = await _authService.createUserWithEmailAndPassword(
          email: accountDetails['email']!,
          password: accountDetails['password']!,
        );

        User? user = userCredential?.user;
        if (user == null) {
          _showSnackBar(context, 'Failed to create account. Please try again.', isError: true);
          return false;
        }        // Initialize user profile in Firebase
        await _databaseService.initializeUserProfile(
          accountDetails['email']!,
          accountDetails['name']!,
        );

        // Send email verification
        await _authService.sendEmailVerification();

        // Migrate data if available
        if (hasDataToMigrate) {
          bool migrationSuccess = await _migrateGuestDataToNewAccount(user.uid, userData);
          if (!migrationSuccess) {
            _showSnackBar(context, 'Account created but data migration failed. Your data is still available locally.', isError: true);
          } else {
            _showSnackBar(context, 'Account created and data migrated successfully!');
          }
        } else {
          _showSnackBar(context, 'Account created successfully!');
        }

        // Complete guest mode migration
        await _completeGuestModeMigration();        // Show logout instruction dialog
        if (context.mounted) {
          await _showLogoutInstructionDialog(context, accountDetails['email']!);
        }

        // Sign out the user and navigate to login page
        await _authService.signOut();

        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => LoginPage()),
            (route) => false,
          );
        }

        return true;      } on FirebaseAuthException catch (e) {
        if (context.mounted) {
          _showSnackBar(context, _authService.getAuthErrorMessage(e), isError: true);
        }
        return false;
      } catch (e) {
        if (context.mounted) {
          _showSnackBar(context, 'An unexpected error occurred. Please try again.', isError: true);
        }
        return false;
      }    } catch (e) {
      print("Error during account creation and migration: $e");
      if (context.mounted) {
        _showSnackBar(context, 'Failed to create account. Please try again.', isError: true);
      }
      return false;
    }
  }

  /// Shows account creation dialog and returns user input
  static Future<Map<String, String>?> _showAccountCreationDialog(BuildContext context, bool hasDataToMigrate) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool passwordVisibility = false;
    bool confirmPasswordVisibility = false;

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;

            return AlertDialog(
              title: Text(
                'Create Account',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasDataToMigrate)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.upload_outlined,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your guest data will be uploaded to Firebase after account creation.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Name field
                      TextFormField(
                        controller: nameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'Enter your name...',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Email field
                      TextFormField(
                        controller: emailController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'Enter your email...',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Password field
                      TextFormField(
                        controller: passwordController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        obscureText: !passwordVisibility,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password...',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              passwordVisibility
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                passwordVisibility = !passwordVisibility;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Confirm Password field
                      TextFormField(
                        controller: confirmPasswordController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        obscureText: !confirmPasswordVisibility,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          hintText: 'Confirm your password...',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              confirmPasswordVisibility
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                confirmPasswordVisibility = !confirmPasswordVisibility;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(context).pop({
                        'name': nameController.text.trim(),
                        'email': emailController.text.trim(),
                        'password': passwordController.text,
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  child: Text('Create Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Shows logout instruction dialog
  static Future<void> _showLogoutInstructionDialog(BuildContext context, String email) async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                'Account Created!',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your account has been created successfully.',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.secondary.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: colorScheme.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Next Steps:',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. A verification email has been sent to:\n   $email',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '2. Please verify your email address',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '3. You will now be taken to the login page',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '4. Sign in with your new credentials',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: Text('Continue to Login'),
            ),
          ],
        );
      },
    );
  }

  /// Migrates guest data to the newly created Firebase account
  static Future<bool> _migrateGuestDataToNewAccount(String userId, Map<String, dynamic> guestData) async {
    try {
      // Migrate user data
      if (guestData['user_data'] != null && guestData['user_data'].isNotEmpty) {
        DatabaseReference userDataRef = _database.ref('users/$userId/user_data');
        await userDataRef.set(guestData['user_data']);
      }

      // Migrate profile data (merge with existing profile data created during initialization)
      if (guestData['profile_data'] != null && guestData['profile_data'].isNotEmpty) {
        DatabaseReference profileRef = _database.ref('users/$userId/profile_data');
        DataSnapshot existingProfile = await profileRef.get();
        
        if (existingProfile.exists) {
          Map<dynamic, dynamic> existingData = Map<dynamic, dynamic>.from(existingProfile.value as Map);
          Map<dynamic, dynamic> mergedData = _deepMerge(existingData, guestData['profile_data'].cast<dynamic, dynamic>());
          await profileRef.set(mergedData);
        } else {
          await profileRef.set(guestData['profile_data']);
        }
      }

      return true;
    } catch (e) {
      print("Error migrating guest data to new account: $e");
      return false;
    }
  }

  /// Helper method to show snackbar messages
  static void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (isError) {
      customSnackBar_error(
        context: context,
        message: message,
      );
    } else {
      customSnackBar(
        context: context,
        message: message,
      );
    }
  }
  
  /// Merges local data with Firebase data
  static Future<void> _mergeData(DatabaseReference ref, Map<dynamic, dynamic> localData) async {
    // Get existing data from Firebase
    DataSnapshot snapshot = await ref.get();
    Map<dynamic, dynamic> firebaseData = Map<dynamic, dynamic>.from(snapshot.value as Map);
    
    // Deep merge the data - this is a simplified approach, may need enhancement for complex data
    Map<dynamic, dynamic> mergedData = _deepMerge(firebaseData, localData);
    
    // Update Firebase with merged data
    await ref.set(mergedData);
  }
  
  /// Deep merges two maps - gives priority to localData when conflicts occur
  static Map<dynamic, dynamic> _deepMerge(Map<dynamic, dynamic> target, Map<dynamic, dynamic> source) {
    source.forEach((key, value) {
      if (value is Map && target[key] is Map) {
        target[key] = _deepMerge(Map<dynamic, dynamic>.from(target[key]), Map<dynamic, dynamic>.from(value));
      } else {
        target[key] = value;
      }
    });
    return target;
  }
  
  /// Completes the migration by cleaning up guest mode data
  static Future<void> _completeGuestModeMigration() async {
    // Disable guest mode
    await GuestAuthService.disableGuestMode();
    
    // Clear the Hive boxes but don't delete them
    await HiveService.clearAll();
    
    // Update shared preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.remove('is_guest_mode');
    await prefs.remove('guest_user_id');
  }
  
  /// Creates a backup of guest data as a JSON string
  static Future<String?> exportGuestData() async {
    try {
      if (!await GuestAuthService.isGuestMode()) {
        return null; // Only allow export for guest mode
      }
      
      // Get the data from LocalDatabaseService in Firebase-compatible format
      LocalDatabaseService localDatabase = LocalDatabaseService();
      final userData = await localDatabase.getCurrentUserData();
      
      if (userData == null || userData.isEmpty) {
        return null; // No data to export
      }
      
      // Create a map with all data
      Map<String, dynamic> exportData = {
        'profile_data': userData['profile_data'] ?? {},
        'user_data': userData['user_data'] ?? {}
      };
      
      // Convert to JSON
      String jsonData = jsonEncode(exportData);
      
      return jsonData;
    } catch (e) {
      print("Error exporting guest data: $e");
      return null;
    }
  }
  
  /// Imports guest data from a JSON string
  static Future<bool> importGuestData(String jsonData) async {
    try {
      if (!await GuestAuthService.isGuestMode()) {
        return false; // Only allow import for guest mode
      }
      
      // Parse the JSON data
      Map<String, dynamic> importData = jsonDecode(jsonData);
      
      if (!importData.containsKey('user_data')) {
        return false; // Invalid import data
      }
      
      // Create a user data object in the Firebase-compatible structure
      final LocalDatabaseService localDatabase = LocalDatabaseService();
      final String userId = LocalDatabaseService.getCurrentUserId();
      
      // Prepare the user data structure
      Map<String, dynamic> userData = {
        'user_data': importData['user_data'] ?? {},
        'profile_data': importData['profile_data'] ?? {}
      };
      
      // Import the data
      await localDatabase.setUserData(userId, userData);
      
      // Force a refresh of the local database
      await localDatabase.forceDataReprocessing();
      
      return true;
    } catch (e) {
      print("Error importing guest data: $e");
      return false;
    }
  }
}
