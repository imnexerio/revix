import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/material.dart';

class HomeWidgetService {
  static const String appGroupId = 'HomeWidgetPreferences';
  static const String todayRecordsKey = 'todayRecords';
  static const String isLoggedInKey = 'isLoggedIn';
  static bool _isInitialized = false;

  // Initialize the service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Register app group for the widget
    HomeWidget.setAppGroupId(appGroupId);

    // Update login status
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;
    await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);

    // For first installation with no login, provide empty data to widget
    if (!isLoggedIn) {
      await HomeWidget.saveWidgetData(
        todayRecordsKey,
        jsonEncode([]),
      );
      await _updateWidget();
    }

    _isInitialized = true;
  }

  // Update widget with provided data
  static Future<void> updateWidgetData(List<Map<String, dynamic>> todayRecords) async {
    try {
      // Update login status
      final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;
      await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);

      // Format today's records for the widget
      final formattedData = _formatTodayRecords(todayRecords);

      // Update the widget with data
      await HomeWidget.saveWidgetData(
        todayRecordsKey,
        jsonEncode(formattedData),
      );

      // Request widget update
      await _updateWidget();

      debugPrint('Widget data updated successfully with ${todayRecords.length} records');
      debugPrint('Login status updated: $isLoggedIn');
    } catch (e) {
      debugPrint('Error updating widget data: $e');
    }
  }

  // Format records for widget display
  static List<Map<String, String>> _formatTodayRecords(List<Map<String, dynamic>> records) {
    return records.map((record) {
      return {
        'subject': (record['subject'] ?? '').toString(),
        'subject_code': (record['subject_code'] ?? '').toString(),
        'lecture_no': (record['lecture_no'] ?? '').toString(),
      };
    }).toList();
  }

  // Helper method to update widget
  static Future<void> _updateWidget() async {
    await HomeWidget.updateWidget(
      name: 'TodayWidget',
      androidName: 'TodayWidget',
      iOSName: 'TodayWidget',
    );
  }

  // Update login status separately when needed
  static Future<void> updateLoginStatus() async {
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;
    await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);
    await _updateWidget();
    debugPrint('Login status updated: $isLoggedIn');
  }
}