import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class DateNextRevision {
  static Future<DateTime> calculateNextRevisionDate(
      DateTime scheduledDate,
      String frequency,
      int noRevision,
      {Map<String, dynamic>? revisionData}
      ) async {
    // Handle No Repetition case
    if (frequency == 'No Repetition') {
      return scheduledDate;
    }

    // Handle Custom frequency with parameters
    if (frequency == 'Custom' && revisionData != null && revisionData.containsKey('custom_params')) {
      return await _calculateCustomNextDate(
          scheduledDate,
          noRevision,
          revisionData['custom_params']
      );
    }

    // Handle standard predefined frequencies
    List<Map<String, String>> frequencies = await fetchFrequencies();

    // Check if the frequency is in the fetched frequencies
    Map<String, String>? customFrequency = frequencies.firstWhere(
          (freq) => freq['title'] == frequency,
      orElse: () => {'title': '', 'frequency': ''},
    );

    if (customFrequency['title']!.isNotEmpty) {
      List<int> intervals = customFrequency['frequency']!.split(',').map((e) => int.parse(e.trim())).toList();
      int additionalDays = (noRevision < intervals.length) ? intervals[noRevision] : intervals.last;
      return scheduledDate.add(Duration(days: additionalDays));
    }

    return scheduledDate;
  }

  static Future<DateTime> _calculateCustomNextDate(
      DateTime baseDate,
      int noRevision,
      Map<String, dynamic> customParams
      ) async {
    // If first calculation or invalid parameters, use default logic
    if (noRevision <= 0 || customParams.isEmpty) {
      return baseDate.add(const Duration(days: 1));
    }

    String frequencyType = customParams['frequencyType'] ?? 'day';
    int value = customParams['value'] ?? 1;

    // Apply appropriate calculation based on frequency type
    switch (frequencyType) {
      case 'day':
        return baseDate.add(Duration(days: value));

      case 'week':
      // For weekly repetition, consider both the interval and days of week
        if (customParams['daysOfWeek'] != null) {
          List<bool> daysOfWeek = List<bool>.from(customParams['daysOfWeek']);
          int currentDayOfWeek = baseDate.weekday % 7; // 0-6 where 0 is Sunday

          // Find the next selected day
          int daysToAdd = 7; // Default to one week if no days selected
          for (int i = 1; i <= 7; i++) {
            int checkDay = (currentDayOfWeek + i) % 7;
            if (daysOfWeek[checkDay]) {
              daysToAdd = i;
              break;
            }
          }

          // Add the weekly interval if we've completed a full cycle
          int weeksToAdd = (daysToAdd == 7) ? value : 0;
          return baseDate.add(Duration(days: daysToAdd + (weeksToAdd * 7)));
        }
        return baseDate.add(Duration(days: value * 7));

      case 'month':
      // Handle monthly options
        if (customParams['monthlyOption'] == 'day') {
          // Fixed day of month
          int dayOfMonth = customParams['dayOfMonth'] ?? baseDate.day;
          return DateTime(baseDate.year, baseDate.month + value, dayOfMonth);
        } else {
          // Specific weekday in month (e.g., 1st Friday)
          int weekOfMonth = customParams['weekOfMonth'] ?? 1;
          String dayOfWeek = customParams['dayOfWeek'] ?? 'Friday';

          // Get the target weekday number (0-6 where 0 is Sunday)
          int targetDayNum = _getDayOfWeekNumber(dayOfWeek);

          // Calculate next month date
          DateTime nextMonth = DateTime(baseDate.year, baseDate.month + value, 1);

          // Find the specified occurrence of the day in that month
          return _findDayInMonth(nextMonth, targetDayNum, weekOfMonth);
        }

      case 'year':
      // Handle yearly options
        String month = customParams['month'] ?? 'Jan';
        int monthNum = _getMonthNumber(month);

        if (customParams['yearlyOption'] == 'day') {
          // Fixed day of month
          int monthDay = customParams['monthDay'] ?? baseDate.day;
          return DateTime(baseDate.year + value, monthNum, monthDay);
        } else {
          // Specific weekday in month (e.g., 1st Friday of April)
          int weekOfYear = customParams['weekOfYear'] ?? 1;
          String dayOfWeekForYear = customParams['dayOfWeekForYear'] ?? 'Friday';

          // Get the target weekday number
          int targetDayNum = _getDayOfWeekNumber(dayOfWeekForYear);

          // Calculate next year month date
          DateTime nextYearMonth = DateTime(baseDate.year + value, monthNum, 1);

          // Find the specified occurrence of the day in that month
          return _findDayInMonth(nextYearMonth, targetDayNum, weekOfYear);
        }

      default:
        return baseDate.add(Duration(days: value));
    }
  }

  // Helper to find nth occurrence of a specific day in a month
  static DateTime _findDayInMonth(DateTime baseDate, int dayOfWeek, int occurrence) {
    // Find the first occurrence of the day in the month
    DateTime date = DateTime(baseDate.year, baseDate.month, 1);
    while (date.weekday != (dayOfWeek == 0 ? 7 : dayOfWeek)) {
      date = date.add(const Duration(days: 1));
    }

    // Add weeks to get to the nth occurrence
    return date.add(Duration(days: 7 * (occurrence - 1)));
  }

  // Convert day name to number (0-6, where 0 is Sunday)
  static int _getDayOfWeekNumber(String dayName) {
    const Map<String, int> days = {
      'Sunday': 0, 'Monday': 1, 'Tuesday': 2, 'Wednesday': 3,
      'Thursday': 4, 'Friday': 5, 'Saturday': 6
    };
    return days[dayName] ?? 5; // Default to Friday if not found
  }

  // Convert month name to number (1-12)
  static int _getMonthNumber(String monthName) {
    const Map<String, int> months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
    };
    return months[monthName] ?? 1; // Default to January if not found
  }

  static Future<List<Map<String, String>>> fetchFrequencies() async {
    List<Map<String, String>> frequencies = [];
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data/custom_frequencies');
      DataSnapshot snapshot = await databaseRef.get();
      if (snapshot.exists) {
        Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
        frequencies = data.entries.map((entry) {
          return {
            'title': entry.key,
            'frequency': (entry.value as List<dynamic>).join(', '),
          };
        }).toList();
      }
    } catch (e) {
      // Handle error
    }
    return frequencies;
  }
}