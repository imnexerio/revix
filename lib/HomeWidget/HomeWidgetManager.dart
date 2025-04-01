// Add this in your main.dart or in a dedicated widget_service.dart file

import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/material.dart';

import '../Utils/UnifiedDatabaseService.dart';

class HomeWidgetService {
  static const String appGroupId = 'HomeWidgetPreferences';
  static const String todayRecordsKey = 'todayRecords';

  // Initialize the service and setup listeners
  static Future<void> initialize() async {
    // Register for callbacks when widget is updated
    HomeWidget.setAppGroupId(appGroupId);

    // Listen for widget launched app
    HomeWidget.widgetClicked.listen(_widgetClicked);

    // Initial data update
    await updateWidgetData();
  }

  // Handle widget click events
  static void _widgetClicked(Uri? uri) {
    // Handle widget taps here - e.g., navigate to a specific page
    debugPrint('Widget clicked with data: $uri');
  }

  // Update widget with today's records data
  static Future<void> updateWidgetData() async {
    try {
      // Get the database service
      final databaseService = CombinedDatabaseService();

      // Try to get cached data first or force refresh
      var cachedData = databaseService.currentRawData;
      if (cachedData == null) {
        await databaseService.forceDataReprocessing();
      }

      // Get today's records from the service
      final categorizedData = await databaseService.categorizedRecordsStream.first;
      final todayRecords = categorizedData['today'] ?? [];

      // Format today's records for the widget
      final formattedData = _formatTodayRecords(todayRecords);

      // Update the widget with data
      await HomeWidget.saveWidgetData(
        todayRecordsKey,
        jsonEncode(formattedData),
      );

      // Request widget update
      await HomeWidget.updateWidget(
        name: 'TodayWidget',
        androidName: 'TodayWidget',
        iOSName: 'TodayWidget',
      );

      debugPrint('Widget data updated successfully with ${todayRecords.length} records');
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

  // Call this whenever data changes or at regular intervals
  static Future<void> refreshWidgetData() async {
    await updateWidgetData();
  }
}