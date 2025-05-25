import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'GuestAuthService.dart';
import 'LocalDatabaseService.dart';

/// Centralized Firebase Database Service that handles all Firebase Realtime Database operations
/// This service automatically detects guest mode and routes operations to local database when needed
class FirebaseDatabaseService {
  static final FirebaseDatabaseService _instance = FirebaseDatabaseService._internal();
  
  factory FirebaseDatabaseService() {
    return _instance;
  }
  
  FirebaseDatabaseService._internal();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final LocalDatabaseService _localDatabase = LocalDatabaseService();
  
  // Cache for current user
  User? get currentUser => _auth.currentUser;
  String? get currentUserId => currentUser?.uid;
  
  /// Check if the current session is in guest mode
  Future<bool> get isGuestMode => GuestAuthService.isGuestMode();
  
  // ====================================================================================
  // PROFILE DATA OPERATIONS
  // ====================================================================================
  
  /// Fetch custom frequencies from profile data
  Future<Map<String, dynamic>> fetchCustomFrequencies() async {
    try {
      if (await isGuestMode) {
        final profileData = await _localDatabase.getProfileData('custom_frequencies', defaultValue: {});
        return Map<String, dynamic>.from(profileData);
      } else {
        if (currentUserId == null) return {};
        
        DatabaseReference ref = _database.ref('users/$currentUserId/profile_data/custom_frequencies');
        DataSnapshot snapshot = await ref.get();
        
        if (snapshot.exists) {
          return Map<String, dynamic>.from(snapshot.value as Map);
        }
        return {};
      }
    } catch (e) {
      print('Error fetching custom frequencies: $e');
      return {};
    }
  }
  
  /// Save custom frequencies to profile data
  Future<bool> saveCustomFrequencies(Map<String, dynamic> frequencies) async {
    try {
      if (await isGuestMode) {
        return await _localDatabase.saveProfileData('custom_frequencies', frequencies);
      } else {
        if (currentUserId == null) return false;
        
        DatabaseReference ref = _database.ref('users/$currentUserId/profile_data/custom_frequencies');
        await ref.set(frequencies);
        return true;
      }
    } catch (e) {
      print('Error saving custom frequencies: $e');
      return false;
    }
  }
  
  /// Fetch custom tracking types from profile data
  Future<List<String>> fetchCustomTrackingTypes() async {
    try {
      if (await isGuestMode) {
        final profileData = await _localDatabase.getProfileData('custom_trackingType', defaultValue: []);
        return List<String>.from(profileData);
      } else {
        if (currentUserId == null) return [];
        
        DatabaseReference ref = _database.ref('users/$currentUserId/profile_data/custom_trackingType');
        DataSnapshot snapshot = await ref.get();
        
        if (snapshot.exists) {
          return List<String>.from(snapshot.value as List);
        }
        return [];
      }
    } catch (e) {
      print('Error fetching custom tracking types: $e');
      return [];
    }
  }
  
  /// Save custom tracking types to profile data
  Future<bool> saveCustomTrackingTypes(List<String> trackingTypes) async {
    try {
      if (await isGuestMode) {
        return await _localDatabase.saveProfileData('custom_trackingType', trackingTypes);
      } else {
        if (currentUserId == null) return false;
        
        DatabaseReference ref = _database.ref('users/$currentUserId/profile_data/custom_trackingType');
        await ref.set(trackingTypes);
        return true;
      }
    } catch (e) {
      print('Error saving custom tracking types: $e');
      return false;
    }
  }
  
  /// Fetch theme data from profile data
  Future<Map<String, dynamic>> fetchThemeData() async {
    try {
      if (await isGuestMode) {
        final profileData = await _localDatabase.getProfileData('theme_data', defaultValue: {});
        return Map<String, dynamic>.from(profileData);
      } else {
        if (currentUserId == null) return {};
        
        DatabaseReference ref = _database.ref('users/$currentUserId/profile_data/theme_data');
        DataSnapshot snapshot = await ref.get();
        
        if (snapshot.exists) {
          return Map<String, dynamic>.from(snapshot.value as Map);
        }
        return {};
      }
    } catch (e) {
      print('Error fetching theme data: $e');
      return {};
    }
  }
  
  /// Save theme data to profile data
  Future<bool> saveThemeData(Map<String, dynamic> themeData) async {
    try {
      if (await isGuestMode) {
        return await _localDatabase.saveProfileData('theme_data', themeData);
      } else {
        if (currentUserId == null) return false;
        
        DatabaseReference ref = _database.ref('users/$currentUserId/profile_data/theme_data');
        await ref.set(themeData);
        return true;
      }
    } catch (e) {
      print('Error saving theme data: $e');
      return false;
    }
  }
  
  /// Fetch home page settings from profile data
  Future<Map<String, dynamic>> fetchHomePageSettings() async {
    try {
      if (await isGuestMode) {
        final profileData = await _localDatabase.getProfileData('home_page', defaultValue: {});
        return Map<String, dynamic>.from(profileData);
      } else {
        if (currentUserId == null) return {};
        
        DatabaseReference ref = _database.ref('users/$currentUserId/profile_data/home_page');
        DataSnapshot snapshot = await ref.get();
        
        if (snapshot.exists) {
          return Map<String, dynamic>.from(snapshot.value as Map);
        }
        return {};
      }
    } catch (e) {
      print('Error fetching home page settings: $e');
      return {};
    }
  }
  
  /// Save home page settings to profile data
  Future<bool> saveHomePageSettings(Map<String, dynamic> homePageData) async {
    try {
      if (await isGuestMode) {
        return await _localDatabase.saveProfileData('home_page', homePageData);
      } else {
        if (currentUserId == null) return false;
        
        DatabaseReference ref = _database.ref('users/$currentUserId/profile_data/home_page');
        await ref.set(homePageData);
        return true;
      }
    } catch (e) {
      print('Error saving home page settings: $e');
      return false;
    }
  }
  
  /// Fetch entire profile data
  Future<Map<String, dynamic>> fetchProfileData() async {
    try {
      if (await isGuestMode) {
        return await _localDatabase.getAllProfileData();
      } else {
        if (currentUserId == null) return {};
        
        DatabaseReference ref = _database.ref('users/$currentUserId/profile_data');
        DataSnapshot snapshot = await ref.get();
        
        if (snapshot.exists) {
          return Map<String, dynamic>.from(snapshot.value as Map);
        }
        return {};
      }
    } catch (e) {
      print('Error fetching profile data: $e');
      return {};
    }
  }
  
  /// Save entire profile data
  Future<bool> saveProfileData(Map<String, dynamic> profileData) async {
    try {
      if (await isGuestMode) {
        // Save each key-value pair individually for local database
        bool allSuccess = true;
        for (var entry in profileData.entries) {
          bool success = await _localDatabase.saveProfileData(entry.key, entry.value);
          if (!success) allSuccess = false;
        }
        return allSuccess;
      } else {
        if (currentUserId == null) return false;
        
        DatabaseReference ref = _database.ref('users/$currentUserId/profile_data');
        await ref.set(profileData);
        return true;
      }
    } catch (e) {
      print('Error saving profile data: $e');
      return false;
    }
  }
  
  // ====================================================================================
  // USER DATA (RECORDS) OPERATIONS
  // ====================================================================================
  
  /// Save a record to user data
  Future<bool> saveRecord(String subject, String subjectCode, String lectureNo, Map<String, dynamic> recordData) async {
    try {
      if (await isGuestMode) {
        return await _localDatabase.saveRecord(subject, subjectCode, lectureNo, recordData);
      } else {
        if (currentUserId == null) return false;
        
        DatabaseReference ref = _database.ref('users/$currentUserId/user_data/$subject/$subjectCode/$lectureNo');
        await ref.set(recordData);
        return true;
      }
    } catch (e) {
      print('Error saving record: $e');
      return false;
    }
  }
  
  /// Update a record in user data
  Future<bool> updateRecord(String subject, String subjectCode, String lectureNo, Map<String, dynamic> updates) async {
    try {
      if (await isGuestMode) {
        return await _localDatabase.updateRecord(subject, subjectCode, lectureNo, updates);
      } else {
        if (currentUserId == null) return false;
        
        DatabaseReference ref = _database.ref('users/$currentUserId/user_data/$subject/$subjectCode/$lectureNo');
        await ref.update(updates);
        return true;
      }
    } catch (e) {
      print('Error updating record: $e');
      return false;
    }
  }
  
  /// Delete a record from user data
  Future<bool> deleteRecord(String subject, String subjectCode, String lectureNo) async {
    try {
      if (await isGuestMode) {
        return await _localDatabase.deleteRecord(subject, subjectCode, lectureNo);
      } else {
        if (currentUserId == null) return false;
        
        DatabaseReference ref = _database.ref('users/$currentUserId/user_data/$subject/$subjectCode/$lectureNo');
        await ref.remove();
        return true;
      }
    } catch (e) {
      print('Error deleting record: $e');
      return false;
    }
  }
  
  /// Move a record to deleted data
  Future<bool> moveToDeletedData(String subject, String subjectCode, String lectureNo, Map<String, dynamic> recordData) async {
    try {
      // Add deletion timestamp
      Map<String, dynamic> deletedData = Map<String, dynamic>.from(recordData);
      deletedData['deleted_at'] = DateTime.now().toIso8601String();
      
      if (await isGuestMode) {
        // Save to deleted data in local database
        bool saveSuccess = await _localDatabase.saveDeletedRecord(subject, subjectCode, lectureNo, deletedData);
        if (!saveSuccess) return false;
        
        // Remove from original location
        return await _localDatabase.deleteRecord(subject, subjectCode, lectureNo);
      } else {
        if (currentUserId == null) return false;
        
        // Save to deleted data in Firebase
        DatabaseReference deletedRef = _database.ref('users/$currentUserId/deleted_user_data/$subject/$subjectCode/$lectureNo');
        await deletedRef.set(deletedData);
        
        // Remove from original location
        DatabaseReference originalRef = _database.ref('users/$currentUserId/user_data/$subject/$subjectCode/$lectureNo');
        await originalRef.remove();
        
        return true;
      }
    } catch (e) {
      print('Error moving record to deleted data: $e');
      return false;
    }
  }
  
  /// Fetch a specific record
  Future<Map<String, dynamic>?> fetchRecord(String subject, String subjectCode, String lectureNo) async {
    try {
      if (await isGuestMode) {
        final userData = await _localDatabase.getCurrentUserData();
        final userRecords = userData['user_data'] as Map<String, dynamic>? ?? {};
        
        if (userRecords[subject]?[subjectCode]?[lectureNo] != null) {
          return Map<String, dynamic>.from(userRecords[subject][subjectCode][lectureNo]);
        }
        return null;
      } else {
        if (currentUserId == null) return null;
        
        DatabaseReference ref = _database.ref('users/$currentUserId/user_data/$subject/$subjectCode/$lectureNo');
        DataSnapshot snapshot = await ref.get();
        
        if (snapshot.exists) {
          return Map<String, dynamic>.from(snapshot.value as Map);
        }
        return null;
      }
    } catch (e) {
      print('Error fetching record: $e');
      return null;
    }
  }
  
  /// Fetch all user data
  Future<Map<String, dynamic>> fetchAllUserData() async {
    try {
      if (await isGuestMode) {
        final userData = await _localDatabase.getCurrentUserData();
        return userData['user_data'] as Map<String, dynamic>? ?? {};
      } else {
        if (currentUserId == null) return {};
        
        DatabaseReference ref = _database.ref('users/$currentUserId/user_data');
        DataSnapshot snapshot = await ref.get();
        
        if (snapshot.exists) {
          return Map<String, dynamic>.from(snapshot.value as Map);
        }
        return {};
      }
    } catch (e) {
      print('Error fetching all user data: $e');
      return {};
    }
  }
  
  // ====================================================================================
  // DELETED DATA OPERATIONS
  // ====================================================================================
  
  /// Fetch all deleted user data
  Future<Map<String, dynamic>> fetchAllDeletedData() async {
    try {
      if (await isGuestMode) {
        return await _localDatabase.getDeletedUserData();
      } else {
        if (currentUserId == null) return {};
        
        DatabaseReference ref = _database.ref('users/$currentUserId/deleted_user_data');
        DataSnapshot snapshot = await ref.get();
        
        if (snapshot.exists) {
          return Map<String, dynamic>.from(snapshot.value as Map);
        }
        return {};
      }
    } catch (e) {
      print('Error fetching deleted data: $e');
      return {};
    }
  }
  
  // ====================================================================================
  // UTILITY METHODS
  // ====================================================================================
  
  /// Get frequencies formatted for date calculations
  Future<List<Map<String, String>>> fetchFrequenciesForDateCalculation() async {
    List<Map<String, String>> frequencies = [];
    try {
      Map<String, dynamic> data = await fetchCustomFrequencies();
      
      if (data.isNotEmpty) {
        frequencies = data.entries.map((entry) {
          return {
            'title': entry.key,
            'frequency': (entry.value as List<dynamic>).join(', '),
          };
        }).toList();
      }
    } catch (e) {
      print('Error fetching frequencies for date calculation: $e');
    }
    return frequencies;
  }
  
  /// Initialize the service - call this during app startup
  Future<void> initialize() async {
    if (await isGuestMode) {
      await _localDatabase.initialize();
    }
  }
  
  /// Get database reference for Firebase operations (use only when necessary)
  DatabaseReference? getDatabaseReference(String path) {
    if (currentUserId == null) return null;
    return _database.ref('users/$currentUserId/$path');
  }
  
  /// Listen to user data changes (returns a stream subscription)
  StreamSubscription<DatabaseEvent>? listenToUserData({
    required Function(Map<String, dynamic>) onData,
    required Function(Object) onError,
  }) {
    if (currentUserId == null) {
      onError('No authenticated user');
      return null;
    }
    
    DatabaseReference ref = _database.ref('users/$currentUserId/user_data');
    return ref.onValue.listen(
      (event) {
        if (event.snapshot.exists) {
          Map<String, dynamic> data = Map<String, dynamic>.from(event.snapshot.value as Map);
          onData(data);
        } else {
          onData({});
        }
      },
      onError: onError,
    );
  }
  
  /// Listen to profile data changes (returns a stream subscription)
  StreamSubscription<DatabaseEvent>? listenToProfileData({
    required Function(Map<String, dynamic>) onData,
    required Function(Object) onError,
  }) {
    if (currentUserId == null) {
      onError('No authenticated user');
      return null;
    }
    
    DatabaseReference ref = _database.ref('users/$currentUserId/profile_data');
    return ref.onValue.listen(
      (event) {
        if (event.snapshot.exists) {
          Map<String, dynamic> data = Map<String, dynamic>.from(event.snapshot.value as Map);
          onData(data);
        } else {
          onData({});
        }
      },
      onError: onError,
    );
  }
}
