import 'package:intl/intl.dart';

/// Helper class for processing calendar data
class CalendarDataHelper {
  /// Converts categorized records into a map of date -> list of events
  /// This flattens all categories into date-based grouping for calendar display
  static Map<DateTime, List<Map<String, dynamic>>> groupRecordsByDate(
    Map<String, List<Map<String, dynamic>>> categorizedRecords,
  ) {
    final Map<DateTime, List<Map<String, dynamic>>> dateGrouped = {};

    // Process all categories
    for (final category in categorizedRecords.values) {
      for (final record in category) {
        final dates = _getEventDates(record);
        for (final date in dates) {
          final dateKey = DateTime(date.year, date.month, date.day);
          dateGrouped.putIfAbsent(dateKey, () => []);
          
          // Add record with the specific date it appears on
          final recordWithDate = Map<String, dynamic>.from(record);
          recordWithDate['_display_date'] = dateKey;
          dateGrouped[dateKey]!.add(recordWithDate);
        }
      }
    }

    // Sort events within each day by time
    for (final dateKey in dateGrouped.keys) {
      dateGrouped[dateKey]!.sort((a, b) {
        final timeA = _getEventTime(a);
        final timeB = _getEventTime(b);
        return timeA.compareTo(timeB);
      });
    }

    return dateGrouped;
  }

  /// Gets all dates an event appears on (handles multi-day events)
  static List<DateTime> _getEventDates(Map<String, dynamic> record) {
    final List<DateTime> dates = [];
    
    // Get the scheduled date (next occurrence)
    final scheduledDate = record['scheduled_date'] as String?;
    if (scheduledDate != null && scheduledDate != 'Unspecified') {
      try {
        final startDate = DateTime.parse(scheduledDate.split('T')[0]);
        
        // Check if it's a multi-day event
        final endTimestamp = record['end_timestamp'] as String?;
        if (endTimestamp != null && endTimestamp.isNotEmpty) {
          final endDate = DateTime.parse(endTimestamp.split('T')[0]);
          
          // Add all dates from start to end
          DateTime current = startDate;
          while (!current.isAfter(endDate)) {
            dates.add(current);
            current = current.add(const Duration(days: 1));
          }
        } else {
          dates.add(startDate);
        }
      } catch (e) {
        // Invalid date format
      }
    }

    return dates;
  }

  /// Gets events for a specific date range
  static List<Map<String, dynamic>> getEventsForDateRange(
    Map<DateTime, List<Map<String, dynamic>>> groupedRecords,
    DateTime start,
    DateTime end,
  ) {
    final List<Map<String, dynamic>> events = [];
    DateTime current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(endDate)) {
      final dateEvents = groupedRecords[current];
      if (dateEvents != null) {
        events.addAll(dateEvents);
      }
      current = current.add(const Duration(days: 1));
    }

    return events;
  }

  /// Gets events for a specific date
  static List<Map<String, dynamic>> getEventsForDate(
    Map<DateTime, List<Map<String, dynamic>>> groupedRecords,
    DateTime date,
  ) {
    final dateKey = DateTime(date.year, date.month, date.day);
    return groupedRecords[dateKey] ?? [];
  }

  /// Gets the time of an event as minutes from midnight for sorting
  static int _getEventTime(Map<String, dynamic> record) {
    final reminderTime = record['reminder_time'] as String?;
    if (reminderTime == null || reminderTime == 'All Day' || reminderTime.isEmpty) {
      return 0; // All-day events first
    }

    try {
      final parts = reminderTime.split(':');
      if (parts.length >= 2) {
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
    } catch (e) {
      // Invalid time format
    }
    return 0;
  }

  /// Gets the hour of an event (0-23)
  static int getEventHour(Map<String, dynamic> record) {
    final reminderTime = record['reminder_time'] as String?;
    if (reminderTime == null || reminderTime == 'All Day' || reminderTime.isEmpty) {
      return -1; // All-day event
    }

    try {
      final parts = reminderTime.split(':');
      if (parts.length >= 2) {
        return int.parse(parts[0]);
      }
    } catch (e) {
      // Invalid time format
    }
    return -1;
  }

  /// Gets start and end hour for an event
  static (int startHour, int endHour) getEventHourRange(Map<String, dynamic> record) {
    final startHour = getEventHour(record);
    if (startHour == -1) return (-1, -1); // All-day

    final endTimestamp = record['end_timestamp'] as String?;
    if (endTimestamp != null && endTimestamp.contains('T')) {
      try {
        final endDateTime = DateTime.parse(endTimestamp);
        return (startHour, endDateTime.hour);
      } catch (e) {
        // Invalid format
      }
    }

    // Default to 1-hour duration
    return (startHour, startHour + 1);
  }

  /// Formats a date for display
  static String formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today, ${DateFormat('MMM d').format(date)}';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow, ${DateFormat('MMM d').format(date)}';
    } else {
      return DateFormat('EEEE, MMM d').format(date);
    }
  }

  /// Gets week dates starting from a given date
  static List<DateTime> getWeekDates(DateTime date) {
    // Start from Monday
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  /// Gets month grid dates (includes padding days from prev/next months)
  static List<DateTime> getMonthGridDates(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    
    // Find the Monday of the week containing the first day
    final startPadding = (firstDay.weekday - 1) % 7;
    final gridStart = firstDay.subtract(Duration(days: startPadding));
    
    // Calculate total cells needed (always show 6 weeks = 42 days)
    final List<DateTime> dates = [];
    for (int i = 0; i < 42; i++) {
      dates.add(gridStart.add(Duration(days: i)));
    }
    
    return dates;
  }
}
