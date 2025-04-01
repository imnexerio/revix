import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';

class HomeWidgetService {
  static const String appGroupId = 'HomeWidgetPreferences';
  static const String todayRecordsKey = 'todayRecords';
  static const String isLoggedInKey = 'isLoggedIn';
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    HomeWidget.setAppGroupId(appGroupId);

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

  static Future<void> updateWidgetData(List<Map<String, dynamic>> todayRecords) async {
    try {
      final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;
      await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);

      final formattedData = _formatTodayRecords(todayRecords);

      await HomeWidget.saveWidgetData(
        todayRecordsKey,
        jsonEncode(formattedData),
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
      };
    }).toList();
  }

  static Future<void> _updateWidget() async {
    await HomeWidget.updateWidget(
      name: 'TodayWidget',
      androidName: 'TodayWidget',
      iOSName: 'TodayWidget',
    );
  }

  static Future<void> updateLoginStatus() async {
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;
    await HomeWidget.saveWidgetData(isLoggedInKey, isLoggedIn);
    await _updateWidget();
    // debugPrint('Login status updated: $isLoggedIn');
  }
}