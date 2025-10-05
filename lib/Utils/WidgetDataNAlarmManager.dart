import 'dart:async';
import 'package:flutter/services.dart';

class WidgetDataNAlarmManager {
  static final WidgetDataNAlarmManager _instance = WidgetDataNAlarmManager._internal();

  factory WidgetDataNAlarmManager() {
    return _instance;
  }

  WidgetDataNAlarmManager._internal();

  static const MethodChannel _alarmChannel = MethodChannel('data_refresh');

  static Future<void> scheduleAlarmsNWidgetRefresh() async {
    try {
      print('WidgetDataNAlarmManager: Triggering alarm scheduling refresh...');
      await _alarmChannel.invokeMethod('refreshAlarms_and_WidgetData');
      print('WidgetDataNAlarmManager: Alarm refresh triggered successfully');
    } catch (e) {
      print('WidgetDataNAlarmManager: Error triggering alarm refresh: $e');
      // Don't rethrow - this might be called from background context
    }
  }

  // Method to cancel all alarms via method channel
  static Future<void> cancelAllAlarmsNWidgetData() async {
    try {
      print('WidgetDataNAlarmManager: Cancelling all alarms...');
      await _alarmChannel.invokeMethod('cancelAllAlarms_and_WidgetData');
      print('WidgetDataNAlarmManager: All alarms cancelled successfully');
    } catch (e) {
      print('WidgetDataNAlarmManager: Error cancelling alarms: $e');
    }
  }
}