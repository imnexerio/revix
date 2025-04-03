import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../Utils/UnifiedDatabaseService.dart';

class HomeWidgetService {
  static const String appGroupId = 'HomeWidgetPreferences';
  static const String todayRecordsKey = 'todayRecords';
  static const String isLoggedInKey = 'isLoggedIn';
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    HomeWidget.setAppGroupId(appGroupId);

    // Set up widget background callback handling
    HomeWidget.registerInteractivityCallback(backgroundCallback);

    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;
    await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);

    if (!isLoggedIn) {
      await HomeWidget.saveWidgetData(
        todayRecordsKey,
        jsonEncode([]),
      );
      await _updateWidget();
    }

    _isInitialized = true;
  }

  // This callback will be called when the widget triggers a refresh
  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    if (uri?.host == 'widget_refresh') {
      // Force data refresh from database service
      await CombinedDatabaseService().forceDataReprocessing();
    }
  }

  static Future<void> updateWidgetData(List<Map<String, dynamic>> todayRecords) async {
    try {
      final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;
      await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);

      final formattedData = _formatTodayRecords(todayRecords);

      await HomeWidget.saveWidgetData(
        todayRecordsKey,
        jsonEncode(formattedData),
      );

      // Add timestamp to update the "last updated" time in widget
      await HomeWidget.saveWidgetData(
        'lastUpdated',
        DateTime.now().millisecondsSinceEpoch,
      );

      // Request widget update
      await _updateWidget();
    } catch (e) {
      // debugPrint('Error updating widget data: $e');
    }
  }

  static List<Map<String, String>> _formatTodayRecords(List<Map<String, dynamic>> records) {
    return records.map((record) {
      return {
        'subject': (record['subject'] ?? '').toString(),
        'subject_code': (record['subject_code'] ?? '').toString(),
        'lecture_no': (record['lecture_no'] ?? '').toString(),
        'reminder_time': (record['reminder_time'] ?? '').toString(),
        'date_scheduled': (record['date_scheduled'] ?? '').toString(),
      };
    }).toList();
  }

  static Future<void> _updateWidget() async {
    await HomeWidget.updateWidget(
      name: 'TodayWidget',
      androidName: 'TodayWidget',
      iOSName: 'TodayWidget',
    );

    // Notify the native side that data was updated from Flutter
    var platform = MethodChannel('com.imnexerio.retracker/widget_refresh');
    try {
      await platform.invokeMethod('refreshCompleted');
    } catch (e) {
      // Channel might not be initialized yet, which is fine
    }
  }

  static Future<void> updateLoginStatus() async {
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;
    await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);
    await _updateWidget();
    // debugPrint('Login status updated: $isLoggedIn');
  }
  static Future<void> refreshWidgetFromExternal() async {
    await initialize();
    final User? user = FirebaseAuth.instance.currentUser;
    final bool isLoggedIn = user != null;

    await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);

    if (!isLoggedIn) {
      await HomeWidget.saveWidgetData(todayRecordsKey, jsonEncode([]));
      await _updateWidget();
      return;
    }

    // The actual refresh will happen in the Kotlin service
    await _updateWidget();
  }

}