import 'package:shared_preferences/shared_preferences.dart';

class GuestAuthService {
  static const String _guestModeKey = 'is_guest_mode';
  static const String _guestUserIdKey = 'guest_user_id';
  
  static Future<void> enableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestModeKey, true);
    await prefs.setBool('isLoggedIn', true);
    
    // Generate a unique guest ID if one doesn't exist
    String? guestId = prefs.getString(_guestUserIdKey);
    if (guestId == null) {
      guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_guestUserIdKey, guestId);
    }
  }
  
  static Future<void> disableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestModeKey);
    await prefs.remove(_guestUserIdKey);
    await prefs.setBool('isLoggedIn', false);
  }
  
  static Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestModeKey) ?? false;
  }
  
  static Future<String?> getGuestUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_guestUserIdKey);
  }
  
  static Future<void> clearGuestData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestModeKey);
    await prefs.remove(_guestUserIdKey);
  }
}
