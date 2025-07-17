import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

/// Centralized Firebase Authentication Service that handles all Firebase Auth operations
/// This service provides a single point for authentication management across the app
class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  
  factory FirebaseAuthService() {
    return _instance;
  }
  
  FirebaseAuthService._internal();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // ====================================================================================
  // AUTHENTICATION STATE
  // ====================================================================================
  
  /// Get the current authenticated user
  User? get currentUser => _auth.currentUser;
  
  /// Get the current user's UID
  String? get currentUserId => currentUser?.uid;
  
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
  
  // ====================================================================================
  // AUTHENTICATION OPERATIONS
  // ====================================================================================
  
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
      print('FirebaseAuthService: Sign in error - ${e.code}: ${e.message}');
      rethrow;
    } catch (e) {
      print('FirebaseAuthService: Sign in unexpected error - $e');
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
      print('FirebaseAuthService: Account creation error - ${e.code}: ${e.message}');
      rethrow;
    } catch (e) {
      print('FirebaseAuthService: Account creation unexpected error - $e');
      rethrow;
    }
  }
  
  /// Sign out the current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('FirebaseAuthService: User signed out successfully');
    } catch (e) {
      print('FirebaseAuthService: Sign out error - $e');
      rethrow;
    }
  }
  
  /// Send password reset email
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('FirebaseAuthService: Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthService: Password reset error - ${e.code}: ${e.message}');
      rethrow;
    } catch (e) {
      print('FirebaseAuthService: Password reset unexpected error - $e');
      rethrow;
    }
  }
  
  /// Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        print('FirebaseAuthService: Email verification sent to ${user.email}');
      } else if (user == null) {
        throw Exception('No user is currently signed in');
      } else {
        print('FirebaseAuthService: Email is already verified');
      }
    } catch (e) {
      print('FirebaseAuthService: Email verification error - $e');
      rethrow;
    }
  }
  
  /// Reload the current user to get updated information
  Future<void> reloadUser() async {
    try {
      await currentUser?.reload();
      print('FirebaseAuthService: User data reloaded');
    } catch (e) {
      print('FirebaseAuthService: User reload error - $e');
      rethrow;
    }
  }
  
  // ====================================================================================
  // USER PROFILE OPERATIONS
  // ====================================================================================
  
  /// Update user's display name
  Future<void> updateDisplayName(String displayName) async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.reload();
        print('FirebaseAuthService: Display name updated to $displayName');
      } else {
        throw Exception('No user is currently signed in');
      }
    } catch (e) {
      print('FirebaseAuthService: Display name update error - $e');
      rethrow;
    }
  }
  
  /// Update user's email
  Future<void> updateEmail(String newEmail) async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.verifyBeforeUpdateEmail(newEmail);
        print('FirebaseAuthService: Email update verification sent to $newEmail');
      } else {
        throw Exception('No user is currently signed in');
      }
    } catch (e) {
      print('FirebaseAuthService: Email update error - $e');
      rethrow;
    }
  }
  
  /// Update user's password
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
        print('FirebaseAuthService: Password updated successfully');
      } else {
        throw Exception('No user is currently signed in');
      }
    } catch (e) {
      print('FirebaseAuthService: Password update error - $e');
      rethrow;
    }
  }
  
  /// Reauthenticate user with current credentials
  Future<void> reauthenticateWithCredential(AuthCredential credential) async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.reauthenticateWithCredential(credential);
        print('FirebaseAuthService: User reauthenticated successfully');
      } else {
        throw Exception('No user is currently signed in');
      }
    } catch (e) {
      print('FirebaseAuthService: Reauthentication error - $e');
      rethrow;
    }
  }
  
  /// Delete the current user account
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.delete();
        print('FirebaseAuthService: User account deleted successfully');
      } else {
        throw Exception('No user is currently signed in');
      }
    } catch (e) {
      print('FirebaseAuthService: Account deletion error - $e');
      rethrow;
    }
  }
  
  // ====================================================================================
  // HELPER METHODS
  // ====================================================================================
  
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
  
  /// Check if the error requires reauthentication
  bool requiresReauthentication(FirebaseAuthException e) {
    return e.code == 'requires-recent-login';
  }
}
