import 'dart:async';
import 'package:flutter/services.dart';
import '../HomeWidget/HomeWidgetManager.dart';

class AlarmManager {
  static final AlarmManager _instance = AlarmManager._internal();
  
  factory AlarmManager() {
    return _instance;
  }
  
  AlarmManager._internal();
  
  // Method channel for direct alarm operations if needed
  static const MethodChannel _alarmChannel = MethodChannel('alarm_scheduler');

  static Future<void> scheduleAlarmsWithData(
    List<Map<String, dynamic>> todayRecords,
    List<Map<String, dynamic>> tomorrowRecords,
  ) async {
    try {
      print('AlarmManager: Scheduling alarms with provided data...');
      print('Today records: ${todayRecords.length}, Tomorrow records: ${tomorrowRecords.length}');

      await _alarmChannel.invokeMethod('scheduleAlarms', {
        'todayRecords': todayRecords,
        'tomorrowRecords': tomorrowRecords,
      });

      print('AlarmManager: Alarms scheduled successfully with provided data');
    } catch (e) {
      print('AlarmManager: Error scheduling alarms with data: $e');
      rethrow;
    }
  }

  // NEW: Method to cancel all alarms via method channel
  static Future<void> cancelAllAlarms() async {
    try {
      print('Cancelling all alarms via method channel...');
      await _alarmChannel.invokeMethod('cancelAllAlarms');
      print('All alarms cancelled successfully via method channel');
    } catch (e) {
      print('Error cancelling alarms: $e');
    }
  }

}