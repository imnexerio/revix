/// Utility class for formatting recurrence frequency into compact display strings.
/// 
/// This class handles all frequency types:
/// - Predefined frequencies: Default, Priority, Low Priority, No Repetition
/// - Custom frequencies: day, week, month, year with various options
/// 
/// Usage:
/// ```dart
/// final frequency = FrequencyFormatter.format(record);
/// final isCustom = FrequencyFormatter.isCustomFrequency(record);
/// ```
class FrequencyFormatter {
  // Day abbreviations (index 0 = Sunday)
  static const List<String> _dayAbbreviations = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
  ];
  
  // Month abbreviations (index 0 = January)
  static const List<String> _monthAbbreviations = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /// Formats the recurrence frequency from a record into a compact display string.
  /// 
  /// Returns empty string if no frequency data exists.
  /// 
  /// Examples:
  /// - "Daily" for 1 day interval
  /// - "2d" for 2 day interval
  /// - "1w·Mon" for weekly on Monday
  /// - "2w·3d" for bi-weekly on 3 days
  /// - "1m·15th" for monthly on the 15th
  /// - "1y·Mar25" for yearly on March 25th
  static String format(Map<String, dynamic> record) {
    try {
      final String frequency = record['recurrence_frequency']?.toString() ?? '';
      
      // Handle predefined frequencies
      if (frequency.isEmpty) return '';
      if (frequency == 'No Repetition') return 'Once';
      if (frequency != 'Custom') {
        // Predefined: Default, Priority, Low Priority, etc.
        if (frequency == 'Low Priority') return 'Low Pri';
        return frequency;
      }
      
      // Handle Custom frequency
      final rawRecurrenceData = record['recurrence_data'];
      if (rawRecurrenceData == null) return 'Custom';
      
      // Cast to Map<String, dynamic> safely
      final Map<String, dynamic> recurrenceData = _safeMapCast(rawRecurrenceData);
      
      final rawCustomParams = recurrenceData['custom_params'];
      if (rawCustomParams == null) return 'Custom';
      
      // Cast custom_params safely
      final Map<String, dynamic> customParams = _safeMapCast(rawCustomParams);
      
      final String frequencyType = customParams['frequencyType']?.toString().toLowerCase() ?? 'day';
      final int value = _safeIntParse(customParams['value'], 1);
      
      switch (frequencyType) {
        case 'day':
          return _formatDayFrequency(value);
          
        case 'week':
          return _formatWeekFrequency(customParams, value);
          
        case 'month':
          return _formatMonthFrequency(customParams, value);
          
        case 'year':
          return _formatYearFrequency(customParams, value);
          
        default:
          return 'Custom';
      }
    } catch (e) {
      return 'Custom';
    }
  }

  /// Returns true if the record has a custom frequency (as opposed to predefined).
  static bool isCustomFrequency(Map<String, dynamic> record) {
    return record['recurrence_frequency'] == 'Custom';
  }

  /// Returns true if the record has any recurrence frequency set.
  static bool hasFrequency(Map<String, dynamic> record) {
    final String frequency = record['recurrence_frequency']?.toString() ?? '';
    return frequency.isNotEmpty;
  }

  /// Safely casts dynamic map to Map<String, dynamic>.
  static Map<String, dynamic> _safeMapCast(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    } else if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  /// Safely parses an integer from dynamic value.
  static int _safeIntParse(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Formats day frequency.
  /// Examples: "Daily", "2d", "7d"
  static String _formatDayFrequency(int value) {
    if (value == 1) return 'Daily';
    return '${value}d';
  }

  /// Formats week frequency with selected days.
  /// Examples: "Weekly", "1w·Mon", "2w·3d"
  static String _formatWeekFrequency(Map<String, dynamic> customParams, int value) {
    final daysOfWeek = customParams['daysOfWeek'];
    
    if (daysOfWeek == null || daysOfWeek is! List) {
      return value == 1 ? 'Weekly' : '${value}w';
    }
    
    // Count selected days and find which ones
    List<int> selectedDayIndices = [];
    for (int i = 0; i < daysOfWeek.length && i < 7; i++) {
      if (daysOfWeek[i] == true) {
        selectedDayIndices.add(i);
      }
    }
    
    final String prefix = value == 1 ? 'Weekly' : '${value}w';
    
    if (selectedDayIndices.isEmpty) {
      return prefix;
    } else if (selectedDayIndices.length == 1) {
      // Single day selected - show day name
      return '$prefix·${_dayAbbreviations[selectedDayIndices.first]}';
    } else if (selectedDayIndices.length == 7) {
      // All days selected
      return '$prefix·All';
    } else {
      // Multiple days - show count
      return '$prefix·${selectedDayIndices.length}d';
    }
  }

  /// Formats month frequency with various options.
  /// Examples: "Monthly", "1m·15th", "2m·1st Mon", "1m·3dates"
  static String _formatMonthFrequency(Map<String, dynamic> customParams, int value) {
    final String monthlyOption = customParams['monthlyOption']?.toString() ?? 'day';
    final String prefix = value == 1 ? 'Monthly' : '${value}m';
    
    switch (monthlyOption) {
      case 'day':
        final int dayOfMonth = _safeIntParse(customParams['dayOfMonth'], 1);
        return '$prefix·${ordinal(dayOfMonth)}';
        
      case 'weekday':
        final int weekOfMonth = _safeIntParse(customParams['weekOfMonth'], 1);
        final String dayOfWeek = customParams['dayOfWeek']?.toString() ?? 'Monday';
        final String dayAbbr = getDayAbbreviation(dayOfWeek);
        return '$prefix·${ordinal(weekOfMonth)}$dayAbbr';
        
      case 'dates':
        final selectedDates = customParams['selectedDates'];
        if (selectedDates is List && selectedDates.isNotEmpty) {
          if (selectedDates.length == 1) {
            final int day = _safeIntParse(selectedDates.first, 1);
            return '$prefix·${ordinal(day)}';
          } else {
            return '$prefix·${selectedDates.length}dates';
          }
        }
        return prefix;
        
      default:
        return prefix;
    }
  }

  /// Formats year frequency with various options.
  /// Examples: "Yearly", "1y·Mar25", "2y·3mo", "1y·1st Mon"
  static String _formatYearFrequency(Map<String, dynamic> customParams, int value) {
    final String yearlyOption = customParams['yearlyOption']?.toString() ?? 'day';
    final selectedMonths = customParams['selectedMonths'];
    final String prefix = value == 1 ? 'Yearly' : '${value}y';
    
    // Count selected months
    List<int> selectedMonthIndices = [];
    if (selectedMonths is List) {
      for (int i = 0; i < selectedMonths.length && i < 12; i++) {
        if (selectedMonths[i] == true) {
          selectedMonthIndices.add(i);
        }
      }
    }
    
    switch (yearlyOption) {
      case 'day':
        final int monthDay = _safeIntParse(customParams['monthDay'], 1);
        if (selectedMonthIndices.length == 1) {
          // Single month - show month name and day
          return '$prefix·${_monthAbbreviations[selectedMonthIndices.first]}$monthDay';
        } else if (selectedMonthIndices.length > 1) {
          // Multiple months - show count
          return '$prefix·${selectedMonthIndices.length}mo';
        }
        return '$prefix·${ordinal(monthDay)}';
        
      case 'weekday':
        final int weekOfYear = _safeIntParse(customParams['weekOfYear'], 1);
        final String dayOfWeekForYear = customParams['dayOfWeekForYear']?.toString() ?? 'Monday';
        final String dayAbbr = getDayAbbreviation(dayOfWeekForYear);
        return '$prefix·${ordinal(weekOfYear)}$dayAbbr';
        
      default:
        return prefix;
    }
  }

  /// Converts a number to its ordinal form (1st, 2nd, 3rd, etc.)
  /// 
  /// Handles special cases:
  /// - 11th, 12th, 13th (not 11st, 12nd, 13rd)
  /// - Standard ordinals: 1st, 2nd, 3rd, 4th, etc.
  static String ordinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  /// Gets the abbreviated day name from full day name.
  /// 
  /// Examples:
  /// - "Monday" -> "Mon"
  /// - "tuesday" -> "Tue"
  /// - "Wed" -> "Wed"
  static String getDayAbbreviation(String dayName) {
    final Map<String, String> dayMap = {
      'sunday': 'Sun', 'sun': 'Sun',
      'monday': 'Mon', 'mon': 'Mon',
      'tuesday': 'Tue', 'tue': 'Tue',
      'wednesday': 'Wed', 'wed': 'Wed',
      'thursday': 'Thu', 'thu': 'Thu',
      'friday': 'Fri', 'fri': 'Fri',
      'saturday': 'Sat', 'sat': 'Sat',
    };
    return dayMap[dayName.toLowerCase()] ?? 
           (dayName.length >= 3 ? dayName.substring(0, 3) : dayName);
  }

  /// Gets the abbreviated month name from full month name or index.
  /// 
  /// Examples:
  /// - "January" -> "Jan"
  /// - "march" -> "Mar"
  /// - 0 -> "Jan"
  static String getMonthAbbreviation(dynamic month) {
    if (month is int && month >= 0 && month < 12) {
      return _monthAbbreviations[month];
    }
    
    if (month is String) {
      final Map<String, String> monthMap = {
        'january': 'Jan', 'jan': 'Jan',
        'february': 'Feb', 'feb': 'Feb',
        'march': 'Mar', 'mar': 'Mar',
        'april': 'Apr', 'apr': 'Apr',
        'may': 'May',
        'june': 'Jun', 'jun': 'Jun',
        'july': 'Jul', 'jul': 'Jul',
        'august': 'Aug', 'aug': 'Aug',
        'september': 'Sep', 'sep': 'Sep',
        'october': 'Oct', 'oct': 'Oct',
        'november': 'Nov', 'nov': 'Nov',
        'december': 'Dec', 'dec': 'Dec',
      };
      return monthMap[month.toLowerCase()] ?? 
             (month.length >= 3 ? month.substring(0, 3) : month);
    }
    
    return '';
  }

  /// Returns a list of day abbreviations.
  static List<String> get dayAbbreviations => List.unmodifiable(_dayAbbreviations);

  /// Returns a list of month abbreviations.
  static List<String> get monthAbbreviations => List.unmodifiable(_monthAbbreviations);
}
