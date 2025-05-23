import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'GuestAuthService.dart';
import 'LocalDatabaseService.dart';
import 'HiveService.dart';

class DataMigrationService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  /// Migrates data from guest mode to a registered user account
  /// Returns a [bool] indicating if migration was successful
  static Future<bool> migrateGuestDataToAccount() async {
    try {
      // Verify if a user is logged in
      User? currentUser = _auth.currentUser;
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
      
      // Migrate deleted data if it exists
      if (userData['deleted_user_data'] != null && userData['deleted_user_data'].isNotEmpty) {
        DatabaseReference deletedRef = _database.ref('users/${currentUser.uid}/deleted_user_data');
        await deletedRef.set(userData['deleted_user_data']);
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
        'user_data': userData['user_data'] ?? {},
        'profile_data': userData['profile_data'] ?? {},
        'deleted_user_data': userData['deleted_user_data'] ?? {},
        'export_timestamp': DateTime.now().toIso8601String(),
        'app_version': '1.0.0', // Replace with actual app version
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
        'profile_data': importData['profile_data'] ?? {},
        'deleted_user_data': importData['deleted_user_data'] ?? {},
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
