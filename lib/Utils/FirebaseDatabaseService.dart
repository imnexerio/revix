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
  // AUTHENTICATION OPERATIONS (Centralized Firebase Auth Access)
  // ====================================================================================
  
  /// Get the current user's email
  String? get currentUserEmail => currentUser?.email;
  
  /// Get the current user's display name
  String? get currentUserDisplayName => currentUser?.displayName;
  
  /// Check if user is currently authenticated
  bool get isAuthenticated => currentUser != null;
  
  /// Check if user's email is verified
  bool get isEmailVerified => currentUser?.emailVerified ?? false;
  
  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  /// Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email, 
    required String password
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
    } on FirebaseAuthException catch (e) {
      print('FirebaseDatabaseService: Sign in error - ${e.code}: ${e.message}');
      rethrow;
    } catch (e) {
      print('FirebaseDatabaseService: Sign in unexpected error - $e');
      rethrow;
    }
  }
  
  /// Create account with email and password
  Future<UserCredential?> createUserWithEmailAndPassword({
    required String email, 
    required String password
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
    } on FirebaseAuthException catch (e) {
      print('FirebaseDatabaseService: Account creation error - ${e.code}: ${e.message}');
      rethrow;
    } catch (e) {
      print('FirebaseDatabaseService: Account creation unexpected error - $e');
      rethrow;
    }
  }
  
  /// Sign out the current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('FirebaseDatabaseService: User signed out successfully');
    } catch (e) {
      print('FirebaseDatabaseService: Sign out error - $e');
      rethrow;
    }
  }
  
  /// Send password reset email
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('FirebaseDatabaseService: Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      print('FirebaseDatabaseService: Password reset error - ${e.code}: ${e.message}');
      rethrow;
    } catch (e) {
      print('FirebaseDatabaseService: Password reset unexpected error - $e');
      rethrow;
    }
  }
  
  /// Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        print('FirebaseDatabaseService: Email verification sent to ${user.email}');
      } else if (user == null) {
        throw Exception('No user is currently signed in');
      } else {
        print('FirebaseDatabaseService: Email is already verified');
      }
    } catch (e) {
      print('FirebaseDatabaseService: Email verification error - $e');
      rethrow;
    }
  }
  
  /// Reload the current user to get updated information
  Future<void> reloadUser() async {
    try {
      await currentUser?.reload();
      print('FirebaseDatabaseService: User data reloaded');
    } catch (e) {
      print('FirebaseDatabaseService: User reload error - $e');
      rethrow;
    }
  }
  
  /// Update user's display name
  Future<void> updateDisplayName(String displayName) async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.reload();
        print('FirebaseDatabaseService: Display name updated to $displayName');
      } else {
        throw Exception('No user is currently signed in');
      }
    } catch (e) {
      print('FirebaseDatabaseService: Display name update error - $e');
      rethrow;
    }
  }
  
  /// Update user's email
  Future<void> updateEmail(String newEmail) async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.verifyBeforeUpdateEmail(newEmail);
        print('FirebaseDatabaseService: Email update verification sent to $newEmail');
      } else {
        throw Exception('No user is currently signed in');
      }
    } catch (e) {
      print('FirebaseDatabaseService: Email update error - $e');
      rethrow;
    }
  }
  
  /// Update user's password
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
        print('FirebaseDatabaseService: Password updated successfully');
      } else {
        throw Exception('No user is currently signed in');
      }
    } catch (e) {
      print('FirebaseDatabaseService: Password update error - $e');
      rethrow;
    }
  }
  
  /// Get Firebase Auth error message in user-friendly format
  String getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'Operation not allowed. Please contact support.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please sign in again.';
      default:
        return e.message ?? 'An unknown error occurred.';
    }
  }

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
  
  /// Adds a new custom tracking type
  Future<void> addCustomTrackingType(String trackingType) async {
    if (await GuestAuthService.isGuestMode()) {
      // Use local database for guest users
      final localDb = LocalDatabaseService();
      final currentList = await localDb.getProfileData('custom_trackingType', defaultValue: <String>[]);
      List<String> updatedList = List<String>.from(currentList);
      
      if (!updatedList.contains(trackingType)) {
        updatedList.add(trackingType);
        await localDb.saveProfileData('custom_trackingType', updatedList);
      }
    } else {
      // Use Firebase for authenticated users
      User? user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      final ref = _database.ref('users/${user.uid}/profile_data/custom_trackingType');
      final snapshot = await ref.get();
      
      List<String> currentList = [];
      if (snapshot.exists) {
        currentList = List<String>.from(snapshot.value as List);
      }
      
      if (!currentList.contains(trackingType)) {
        currentList.add(trackingType);
        await ref.set(currentList);
      }
    }
  }

  /// Adds a new custom frequency
  Future<void> addCustomFrequency(String title, List<int> frequency) async {
    if (await GuestAuthService.isGuestMode()) {
      // Use local database for guest users
      final localDb = LocalDatabaseService();
      final currentFrequencies = await localDb.getProfileData('custom_frequencies', defaultValue: <String, dynamic>{});
      Map<String, dynamic> updatedFrequencies = Map<String, dynamic>.from(currentFrequencies);
      updatedFrequencies[title] = frequency;
      
      await localDb.saveProfileData('custom_frequencies', updatedFrequencies);
    } else {
      // Use Firebase for authenticated users
      User? user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      final ref = _database.ref('users/${user.uid}/profile_data/custom_frequencies');
      await ref.update({title: frequency});
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

  /// Saves completion target for a lecture type
  Future<void> saveHomePageCompletionTarget(String lectureType, String targetValue) async {
    if (await GuestAuthService.isGuestMode()) {
      // Use local database for guest users
      final localDb = LocalDatabaseService();
      await localDb.saveProfileData('home_page.completionTargets.$lectureType', targetValue);
    } else {
      // Use Firebase for authenticated users
      User? user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      final ref = _database.ref('users/${user.uid}/profile_data/home_page/completionTargets');
      await ref.update({lectureType: targetValue});
    }
  }

  /// Fetches completion targets for home page
  Future<Map<String, int>> fetchHomePageCompletionTargets() async {
    Map<String, int> targets = {};
    
    if (await GuestAuthService.isGuestMode()) {
      // Use local database for guest users
      final localDb = LocalDatabaseService();
      final homePageData = await localDb.getProfileData('home_page', defaultValue: {});
      if (homePageData is Map && homePageData.containsKey('completionTargets')) {
        final completionTargets = homePageData['completionTargets'] as Map<String, dynamic>? ?? {};
        completionTargets.forEach((key, value) {
          targets[key] = int.tryParse(value.toString()) ?? 0;
        });
      }
    } else {
      // Use Firebase for authenticated users
      User? user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      final ref = _database.ref('users/${user.uid}/profile_data/home_page/completionTargets');
      final snapshot = await ref.get();
      
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          targets[key.toString()] = int.tryParse(value.toString()) ?? 0;
        });
      }
    }
    
    return targets;
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

  /// Updates profile data fields
  Future<void> updateProfileData(Map<String, dynamic> updates) async {
    if (await GuestAuthService.isGuestMode()) {
      // Use local database for guest users
      final localDb = LocalDatabaseService();
      for (final entry in updates.entries) {
        await localDb.saveProfileData(entry.key, entry.value);
      }
    } else {
      // Use Firebase for authenticated users
      User? user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      final ref = _database.ref('users/${user.uid}/profile_data');
      await ref.update(updates);
    }
  }
  /// Gets profile picture URL
  Future<String?> getProfilePicture() async {
    if (await GuestAuthService.isGuestMode()) {
      // Use local database for guest users
      final localDb = LocalDatabaseService();
      return await localDb.getProfileData('profile_picture');
    } else {
      // Use Firebase for authenticated users
      User? user = _auth.currentUser;
      if (user == null) {
        // User is not authenticated (logged out), return null instead of throwing exception
        return null;
      }
      
      final ref = _database.ref('users/${user.uid}/profile_data/profile_picture');
      final snapshot = await ref.get();
      if (snapshot.exists) {
        return snapshot.value as String?;
      }
    }
    return null;
  }

  /// Sets profile picture URL
  Future<void> setProfilePicture(String profilePictureUrl) async {
    if (await GuestAuthService.isGuestMode()) {
      // Use local database for guest users
      final localDb = LocalDatabaseService();
      await localDb.saveProfileData('profile_picture', profilePictureUrl);
    } else {
      // Use Firebase for authenticated users
      User? user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      final ref = _database.ref('users/${user.uid}/profile_data');
      await ref.update({'profile_picture': profilePictureUrl});
    }
  }

  /// Initializes user profile data for new users
  Future<void> initializeUserProfile(String email, String name) async {
    // This method is only used for Firebase authenticated users during signup
    User? user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    
    final ref = _database.ref('users/${user.uid}/profile_data');
    await ref.set({
      'email': email,
      'name': name,
      'createdAt': DateTime.now().toIso8601String(),
      'custom_trackingType': [
        'Lectures',
        'Others'
      ],
      'custom_frequencies': {
        'Default': [1, 4, 7, 15, 30, 60],
        'Priority': [1, 3, 4, 5, 7, 15, 25, 30],
      },
      'theme_data': {
        'customThemeColor': null,
        'selectedThemeIndex': 0,
        'themeMode': 'ThemeMode.system',
      },
      'home_page': {
        'selectedTrackingTypes': {},
        'completionTargets': {},
      }
    });
  }
  
  // ====================================================================================
  // USER DATA (RECORDS) OPERATIONS
  // ====================================================================================
  
  /// Save a record to user data
  Future<bool> saveRecord(String subject, String subCategory, String lectureNo, Map<String, dynamic> recordData) async {
    try {
      if (await isGuestMode) {
        return await _localDatabase.saveRecord(subject, subCategory, lectureNo, recordData);
      } else {
        if (currentUserId == null) return false;
        
        DatabaseReference ref = _database.ref('users/$currentUserId/user_data/$subject/$subCategory/$lectureNo');
        await ref.set(recordData);
        return true;
      }
    } catch (e) {
      print('Error saving record: $e');
      return false;
    }
  }
  
  /// Update a record in user data
  Future<bool> updateRecord(String subject, String subCategory, String lectureNo, Map<String, dynamic> updates) async {
    try {
      if (await isGuestMode) {
        return await _localDatabase.updateRecord(subject, subCategory, lectureNo, updates);
      } else {
        if (currentUserId == null) return false;
        
        DatabaseReference ref = _database.ref('users/$currentUserId/user_data/$subject/$subCategory/$lectureNo');
        await ref.update(updates);
        return true;
      }
    } catch (e) {
      print('Error updating record: $e');
      return false;
    }
  }
  
  /// Delete a record from user data
  Future<bool> deleteRecord(String subject, String subCategory, String lectureNo) async {
    try {
      if (await isGuestMode) {
        return await _localDatabase.deleteRecord(subject, subCategory, lectureNo);
      } else {
        if (currentUserId == null) return false;
        
        DatabaseReference ref = _database.ref('users/$currentUserId/user_data/$subject/$subCategory/$lectureNo');
        await ref.remove();
        return true;
      }
    } catch (e) {
      print('Error deleting record: $e');
      return false;
    }
  }
  
  /// Move a record to deleted data
  Future<bool> moveToDeletedData(String subject, String subCategory, String lectureNo, Map<String, dynamic> recordData) async {
    try {
      // Add deletion timestamp
      Map<String, dynamic> deletedData = Map<String, dynamic>.from(recordData);
      deletedData['deleted_at'] = DateTime.now().toIso8601String();
      
      if (await isGuestMode) {
        // Save to deleted data in local database
        bool saveSuccess = await _localDatabase.saveDeletedRecord(subject, subCategory, lectureNo, deletedData);
        if (!saveSuccess) return false;
        
        // Remove from original location
        return await _localDatabase.deleteRecord(subject, subCategory, lectureNo);
      } else {
        if (currentUserId == null) return false;
        
        // Save to deleted data in Firebase
        DatabaseReference deletedRef = _database.ref('users/$currentUserId/deleted_user_data/$subject/$subCategory/$lectureNo');
        await deletedRef.set(deletedData);
        
        // Remove from original location
        DatabaseReference originalRef = _database.ref('users/$currentUserId/user_data/$subject/$subCategory/$lectureNo');
        await originalRef.remove();
        
        return true;
      }
    } catch (e) {
      print('Error moving record to deleted data: $e');
      return false;
    }
  }
  
  /// Fetch a specific record
  Future<Map<String, dynamic>?> fetchRecord(String subject, String subCategory, String lectureNo) async {
    try {
      if (await isGuestMode) {
        final userData = await _localDatabase.getCurrentUserData();
        final userRecords = userData['user_data'] as Map<String, dynamic>? ?? {};
        
        if (userRecords[subject]?[subCategory]?[lectureNo] != null) {
          return Map<String, dynamic>.from(userRecords[subject][subCategory][lectureNo]);
        }
        return null;
      } else {
        if (currentUserId == null) return null;
        
        DatabaseReference ref = _database.ref('users/$currentUserId/user_data/$subject/$subCategory/$lectureNo');
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
  
  /// Checks if user data exists in the database
  Future<bool> checkUserDataExists() async {
    // This is only for authenticated users checking Firebase
    User? user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    
    final ref = _database.ref('users/${user.uid}');
    final snapshot = await ref.get();
    return snapshot.exists;
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
      await LocalDatabaseService.initialize();
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
