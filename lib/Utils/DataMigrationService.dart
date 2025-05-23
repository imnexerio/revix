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
      
      // Get all records from local storage
      final recordsBox = await Hive.openBox<Map>('user_records');
      final userData = recordsBox.get('user_data');
      
      if (userData == null || userData.isEmpty) {
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
        await _mergeData(userDataRef, userData.cast<dynamic, dynamic>());
      } else {
        // User has no data, we can directly set
        await userDataRef.set(userData);
      }
      
      // Get profile data from local storage
      final profileBox = await Hive.openBox<Map>('user_profile');
      final profileData = profileBox.get('profile_data');
      
      if (profileData != null && profileData.isNotEmpty) {
        // Only migrate non-personal profile data
        Map<String, dynamic> filteredProfileData = Map<String, dynamic>.from(profileData);
        
        // Remove personal identifiers from guest data
        filteredProfileData.remove('email');
        filteredProfileData.remove('name');
        
        // Migrate custom tracking types, frequencies, and theme data
        DatabaseReference profileRef = _database.ref('users/${currentUser.uid}/profile_data');
        
        // Create a shallow copy of existing Firebase profile to maintain other fields
        DataSnapshot existingProfile = await profileRef.get();
        if (existingProfile.exists) {
          Map<dynamic, dynamic> mergedProfile = Map<dynamic, dynamic>.from(existingProfile.value as Map);
          
          // Only update specific fields we want to migrate
          if (filteredProfileData.containsKey('custom_trackingType')) {
            mergedProfile['custom_trackingType'] = filteredProfileData['custom_trackingType'];
          }
          if (filteredProfileData.containsKey('custom_frequencies')) {
            mergedProfile['custom_frequencies'] = filteredProfileData['custom_frequencies'];
          }
          if (filteredProfileData.containsKey('theme_data')) {
            mergedProfile['theme_data'] = filteredProfileData['theme_data'];
          }
          if (filteredProfileData.containsKey('home_page')) {
            mergedProfile['home_page'] = filteredProfileData['home_page'];
          }
          
          // Update the profile with merged data
          await profileRef.update(mergedProfile);
        } else {
          // Set default values for required fields
          filteredProfileData['email'] = currentUser.email ?? '';
          filteredProfileData['name'] = currentUser.displayName ?? 'User';
          filteredProfileData['createdAt'] = DateTime.now().toIso8601String();
          
          // Set the filtered profile data
          await profileRef.set(filteredProfileData);
        }
      }
      
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
      
      // Get data from Hive
      final recordsBox = await Hive.openBox<Map>('user_records');
      final profileBox = await Hive.openBox<Map>('user_profile');
      
      final userData = recordsBox.get('user_data');
      final profileData = profileBox.get('profile_data');
      
      if (userData == null && profileData == null) {
        return null; // No data to export
      }
      
      // Create a map with all data
      Map<String, dynamic> exportData = {
        'user_data': userData,
        'profile_data': profileData,
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
      
      if (!importData.containsKey('user_data') || !importData.containsKey('profile_data')) {
        return false; // Invalid import data
      }
      
      // Get boxes
      final recordsBox = await Hive.openBox<Map>('user_records');
      final profileBox = await Hive.openBox<Map>('user_profile');
      
      // Import the data
      await recordsBox.put('user_data', Map<dynamic, dynamic>.from(importData['user_data']));
      await profileBox.put('profile_data', Map<dynamic, dynamic>.from(importData['profile_data']));
      
      // Force a refresh of the local database
      LocalDatabaseService().forceDataReprocessing();
      
      return true;
    } catch (e) {
      print("Error importing guest data: $e");
      return false;
    }
  }
}
