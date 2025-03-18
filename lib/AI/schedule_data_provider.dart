import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ScheduleDataProvider {
  User? user;
  late String uid;
  late DatabaseReference ref;

  // Cache constants
  static const String _cacheKey = 'cached_schedule_data';
  static const String _cacheDateKey = 'cached_schedule_timestamp';
  static const int _cacheMaxAgeMinutes = 30; // Cache expires after 30 minutes

  ScheduleDataProvider() {
    user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }
    uid = user!.uid;
    ref = FirebaseDatabase.instance.ref('users/$uid/user_data');
  }

  Future<DataSnapshot> getData() async {
    final dataSnapshot = await ref.get();
    print('Getting schedule data: ${dataSnapshot.value}');
    return dataSnapshot;
  }

  Future<String> getScheduleData({bool forceRefresh = false}) async {
    // Check if we should use cached data
    if (!forceRefresh) {
      final cachedData = await _getCachedScheduleData();
      if (cachedData != null) {
        return cachedData;
      }
    }

    // Fetch fresh data from Firebase
    try {
      final dataSnapshot = await getData();
      final scheduleData = dataSnapshot.value;

      if (scheduleData != null) {
        final scheduleString = scheduleData.toString();
        // Cache the data
        await _cacheScheduleData(scheduleString);
        return scheduleString;
      }
    } catch (e) {
      print('Error fetching schedule data: $e');
      // If there's an error but we have cached data, return it as fallback
      final cachedData = await _getCachedScheduleData(ignoreAge: true);
      if (cachedData != null) {
        return cachedData;
      }
    }

    return 'No schedule data available';
  }

  Future<void> _cacheScheduleData(String data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, data);
      await prefs.setInt(_cacheDateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error caching schedule data: $e');
    }
  }

  Future<String?> _getCachedScheduleData({bool ignoreAge = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedTimestamp = prefs.getInt(_cacheDateKey);

      if (cachedTimestamp != null) {
        final cacheDate = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
        final now = DateTime.now();
        final difference = now.difference(cacheDate);

        // Check if cache is still valid unless ignoreAge is true
        if (ignoreAge || difference.inMinutes < _cacheMaxAgeMinutes) {
          return prefs.getString(_cacheKey);
        }
      }
    } catch (e) {
      print('Error retrieving cached schedule data: $e');
    }

    return null;
  }

  // Clear the cache (useful for logout or force refresh)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheDateKey);
    } catch (e) {
      print('Error clearing schedule data cache: $e');
    }
  }
}