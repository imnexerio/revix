import 'dart:io';
import 'package:flutter/services.dart';

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
}
