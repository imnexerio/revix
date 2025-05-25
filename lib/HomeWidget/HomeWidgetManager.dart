import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../Utils/UnifiedDatabaseService.dart';
import '../Utils/FirebaseDatabaseService.dart';

class HomeWidgetService {
  static const String appGroupId = 'HomeWidgetPreferences';
  static const String todayRecordsKey = 'todayRecords';
  static const String missedRecordsKey = 'missedRecords';
  static const String noReminderDateRecordsKey = 'noreminderdate';
  static const String isLoggedInKey = 'isLoggedIn';
  static bool _isInitialized = false;
  static final FirebaseDatabaseService _databaseService = FirebaseDatabaseService();

  static Future<void> initialize() async {
    if (_isInitialized) return;

    HomeWidget.setAppGroupId(appGroupId);

    // Set up widget background callback handling
    HomeWidget.registerInteractivityCallback(backgroundCallback);

    final bool isLoggedIn = _databaseService.isAuthenticated;
    await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);

    if (!isLoggedIn) {
      await HomeWidget.saveWidgetData(todayRecordsKey, jsonEncode([]));
      await HomeWidget.saveWidgetData(missedRecordsKey, jsonEncode([]));
      await HomeWidget.saveWidgetData(noReminderDateRecordsKey, jsonEncode([]));
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

  static Future<void> updateWidgetData(
      List<Map<String, dynamic>> todayRecords,
      List<Map<String, dynamic>> missedRecords,
      List<Map<String, dynamic>> noReminderDateRecords,
      ) async {    try {
      final bool isLoggedIn = _databaseService.isAuthenticated;
      await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);

      // Format and save all three data categories
      await HomeWidget.saveWidgetData(
        todayRecordsKey,
        jsonEncode(_formatRecords(todayRecords)),
      );

      await HomeWidget.saveWidgetData(
        missedRecordsKey,
        jsonEncode(_formatRecords(missedRecords)),
      );

      await HomeWidget.saveWidgetData(
        noReminderDateRecordsKey,
        jsonEncode(_formatRecords(noReminderDateRecords)),
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

  static List<Map<String, dynamic>> _formatRecords(List<Map<String, dynamic>> records) {
    return records.map((record) {
      // Return the entire record with all fields
      // This ensures future additions will be available without code changes
      Map<String, dynamic> formattedRecord = {};

      // Convert all values to strings for consistency
      record.forEach((key, value) {
        formattedRecord[key] = value?.toString() ?? '';
      });

      return formattedRecord;
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
    final bool isLoggedIn = _databaseService.isAuthenticated;
    await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);
    await _updateWidget();
    // debugPrint('Login status updated: $isLoggedIn');
  }

  static Future<void> refreshWidgetFromExternal() async {
    await initialize();
    final User? user = _databaseService.currentUser;
    final bool isLoggedIn = user != null;

    await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);

    if (!isLoggedIn) {
      await HomeWidget.saveWidgetData(todayRecordsKey, jsonEncode([]));
      await HomeWidget.saveWidgetData(missedRecordsKey, jsonEncode([]));
      await HomeWidget.saveWidgetData(noReminderDateRecordsKey, jsonEncode([]));
      await _updateWidget();
      return;
    }

    // The actual refresh will happen in the Kotlin service
    await _updateWidget();
  }
}