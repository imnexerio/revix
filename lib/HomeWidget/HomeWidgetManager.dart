import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:ui';

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
    print('Background callback triggered: ${uri?.host}');

    // Ensure Flutter engine is initialized for background work
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    if (uri?.host == 'widget_refresh') {
      try {
        // Process data using CombinedDatabaseService without launching app
        final service = CombinedDatabaseService();
        await service.forceDataReprocessing();
        print('Widget background refresh completed');
      } catch (e) {
        print('Error in background widget refresh: $e');
        // Fallback to empty data
        await _updateWidgetWithEmptyData();
      }
    }
  }

  // New method for background widget updates
  static Future<void> updateWidgetDataFromBackground(
    List<Map<String, dynamic>> todayRecords,
    List<Map<String, dynamic>> missedRecords,
    List<Map<String, dynamic>> noReminderDateRecords, {
    bool? isLoggedIn,
  }) async {
    try {
      // Initialize home_widget if not already done
      await _ensureInitialized();

      final bool loginStatus =
          isLoggedIn ?? FirebaseDatabaseService().isAuthenticated;
      await HomeWidget.saveWidgetData(isLoggedInKey, loginStatus);

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

      // Add timestamp
      await HomeWidget.saveWidgetData(
        'lastUpdated',
        DateTime.now().millisecondsSinceEpoch,
      );

      // Update widget without launching app
      await _updateWidgetSilently();
      print('Background widget update completed');
    } catch (e) {
      print('Error in background widget update: $e');
    }
  }

  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      HomeWidget.setAppGroupId(appGroupId);
      _isInitialized = true;
    }
  }

  static Future<void> _updateWidgetSilently() async {
    await HomeWidget.updateWidget(
      name: 'TodayWidget',
      androidName: 'TodayWidget',
      iOSName: 'TodayWidget',
    );
  }

  static Future<void> _updateWidgetWithEmptyData() async {
    await _ensureInitialized();
    await HomeWidget.saveWidgetData(todayRecordsKey, jsonEncode([]));
    await HomeWidget.saveWidgetData(missedRecordsKey, jsonEncode([]));
    await HomeWidget.saveWidgetData(noReminderDateRecordsKey, jsonEncode([]));
    await HomeWidget.saveWidgetData(isLoggedInKey, false);
    await HomeWidget.saveWidgetData('lastUpdated', DateTime.now().millisecondsSinceEpoch);
    await _updateWidgetSilently();
  }

  static Future<void> updateWidgetData(
    List<Map<String, dynamic>> todayRecords,
    List<Map<String, dynamic>> missedRecords,
    List<Map<String, dynamic>> noReminderDateRecords,
  ) async {
    try {
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

  static List<Map<String, dynamic>> _formatRecords(
      List<Map<String, dynamic>> records) {
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
    var platform = MethodChannel('com.imnexerio.revix/widget_refresh');
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
    final user = _databaseService.currentUser;
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