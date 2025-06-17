import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class AlarmManagerService {
  static const MethodChannel _channel = MethodChannel('revix/alarm_manager');

  // Initialize the alarm manager
  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('initialize');
        print('AlarmManagerService initialized successfully');
      } catch (e) {
        print('Error initializing AlarmManagerService: $e');
      }
    }
  }

  // Schedule alarms for today's records
  static Future<void> scheduleAlarmsForTodayRecords(List<Map<String, dynamic>> todayRecords) async {
    if (!Platform.isAndroid || todayRecords.isEmpty) return;

    try {
      // Convert records to a format suitable for method channel
      final List<Map<String, dynamic>> formattedRecords = todayRecords.map((record) {
        return {
          'category': record['category']?.toString() ?? '',
          'sub_category': record['sub_category']?.toString() ?? '',
          'record_title': record['record_title']?.toString() ?? '',
          'reminder_time': record['reminder_time']?.toString() ?? '',
          'alarm_type': _parseAlarmType(record['alarm_type']),
          'description': record['description']?.toString() ?? '',
          'scheduled_date': record['scheduled_date']?.toString() ?? '',
          'status': record['status']?.toString() ?? '',
        };
      }).toList();

      await _channel.invokeMethod('scheduleAlarmsForTodayRecords', {
        'todayRecords': formattedRecords,
      });

      print('Scheduled alarms for ${formattedRecords.length} records');
    } catch (e) {
      print('Error scheduling alarms: $e');
    }
  }

  // Cancel all scheduled alarms
  static Future<void> cancelAllAlarms() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('cancelAllAlarms');
      print('All alarms cancelled');
    } catch (e) {
      print('Error cancelling alarms: $e');
    }
  }

  // Request exact alarm permission (required for Android 12+)
  static Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('requestExactAlarmPermission');
    } catch (e) {
      print('Error requesting exact alarm permission: $e');
    }
  }

  // Check if exact alarm permission is granted
  static Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final bool hasPermission = await _channel.invokeMethod('hasExactAlarmPermission');
      return hasPermission;
    } catch (e) {
      print('Error checking exact alarm permission: $e');
      return false;
    }
  }

  // Handle mark as done action from notification
  static Future<void> markRecordAsDone(String category, String subCategory, String recordTitle) async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('markRecordAsDone', {
        'category': category,
        'sub_category': subCategory,
        'record_title': recordTitle,
      });
      print('Marked record as done: $category - $subCategory - $recordTitle');
    } catch (e) {
      print('Error marking record as done: $e');
    }
  }

  // Parse alarm type from various input formats
  static int _parseAlarmType(dynamic alarmType) {
    if (alarmType == null) return 0;
    
    if (alarmType is int) return alarmType;
    
    if (alarmType is String) {
      final parsed = int.tryParse(alarmType);
      if (parsed != null) return parsed;
      
      // Handle string representations
      switch (alarmType.toLowerCase()) {
        case 'no reminder':
          return 0;
        case 'notification only':
          return 1;
        case 'vibration only':
          return 2;
        case 'sound':
          return 3;
        case 'sound + vibration':
          return 4;
        case 'loud alarm':
          return 5;
        default:
          return 0;
      }
    }
    
    return 0;
  }

  // Convert alarm type to readable string
  static String getAlarmTypeString(int alarmType) {
    switch (alarmType) {
      case 0:
        return 'No Reminder';
      case 1:
        return 'Notification Only';
      case 2:
        return 'Vibration Only';
      case 3:
        return 'Sound';
      case 4:
        return 'Sound + Vibration';
      case 5:
        return 'Loud Alarm';
      default:
        return 'No Reminder';
    }
  }
}
