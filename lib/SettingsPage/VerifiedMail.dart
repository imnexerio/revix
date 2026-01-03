import '../Utils/FirebaseAuthService.dart';

// Cache the verification status to avoid repeated network calls
bool? _cachedEmailVerified;
DateTime? _lastVerificationCheck;
const Duration _verificationCacheDuration = Duration(minutes: 5);

Future<bool> isEmailVerified({bool forceRefresh = false}) async {
  final FirebaseAuthService _authService = FirebaseAuthService();
  
  // Return cached value if valid and not forcing refresh
  if (!forceRefresh && 
      _cachedEmailVerified != null && 
      _lastVerificationCheck != null &&
      DateTime.now().difference(_lastVerificationCheck!) < _verificationCacheDuration) {
    return _cachedEmailVerified!;
  }
  
  // Only reload user (network call) when cache is expired or forced
  await _authService.reloadUser();
  _cachedEmailVerified = _authService.isEmailVerified;
  _lastVerificationCheck = DateTime.now();
  
  return _cachedEmailVerified!;
}

/// Call this after sending verification email to force refresh on next check
void invalidateEmailVerificationCache() {
  _cachedEmailVerified = null;
  _lastVerificationCheck = null;
}