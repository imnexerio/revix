import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduleDataProvider {
  User? user;
  late String uid;
  late DatabaseReference ref;

  // Cache constants - keeping for fallback purposes
  static const String _cacheKey = 'cached_schedule_data';
  static const String _cacheDateKey = 'cached_schedule_timestamp';

  ScheduleDataProvider() {
    user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }
    uid = user!.uid;
    ref = FirebaseDatabase.instance.ref('users/$uid/user_data');
    print('ScheduleDataProvider initialized for user $uid');
  }

  Future<DataSnapshot> getData() async {
    final dataSnapshot = await ref.get();
    return dataSnapshot;
  }

  Future<String> getScheduleData({bool forceRefresh = false}) async {
    // If we're not forcing a refresh, check for cached data as a fallback
    if (!forceRefresh) {
      final cachedData = await _getCachedScheduleData();
      if (cachedData != null) {
        return cachedData;
      }
    }

    // Always try to fetch fresh data
    try {
      final dataSnapshot = await getData();
      final scheduleData = dataSnapshot.value;

      if (scheduleData != null) {
        final scheduleString = scheduleData.toString();
        // Cache the data (for fallback purposes only)
        await _cacheScheduleData(scheduleString);
        return scheduleString;
      }
    } catch (e) {
      // If there's an error but we have cached data, return it as fallback
      final cachedData = await _getCachedScheduleData(ignoreAge: true);
      if (cachedData != null) {
        return cachedData;
      }
    }

    return 'No schedule data available';
  }

  // Keep caching methods as fallback for offline or error scenarios
  Future<void> _cacheScheduleData(String data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, data);
      await prefs.setInt(_cacheDateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Error handling silently fails
    }
  }

  Future<String?> _getCachedScheduleData({bool ignoreAge = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Just return cached data if it exists, regardless of age
      // Since we're only using it as fallback
      return prefs.getString(_cacheKey);
    } catch (e) {
      // Error handling silently fails
    }

    return null;
  }

  // Clear the cache (useful for logout)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheDateKey);
    } catch (e) {
      // Error handling silently fails
    }
  }
}