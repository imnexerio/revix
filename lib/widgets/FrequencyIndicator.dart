import 'package:flutter/material.dart';
import '../Utils/FrequencyFormatter.dart';

/// A compact visual widget for displaying recurrence frequency.
/// 
/// Shows day/month letters with color distinction for week/year frequencies.
/// Falls back to text display for day/month frequencies.
class FrequencyIndicator extends StatelessWidget {
  final Map<String, dynamic> record;
  final double fontSize;
  
  const FrequencyIndicator({
    Key? key,
    required this.record,
    this.fontSize = 10,
  }) : super(key: key);

  // Single letter abbreviations
  static const List<String> _dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const List<String> _monthLetters = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

  /// Gets just the interval prefix (e.g., "1w", "2y", "Daily") for display next to label
  static String getPrefix(Map<String, dynamic> record) {
    final String frequency = record['recurrence_frequency']?.toString() ?? '';
    
    if (frequency.isEmpty) return '';
    
    // Handle predefined frequencies
    if (frequency != 'Custom') {
      return FrequencyFormatter.format(record);
    }
    
    // Handle Custom frequency
    final rawRecurrenceData = record['recurrence_data'];
    if (rawRecurrenceData == null) return 'Custom';
    
    final Map<String, dynamic> recurrenceData = _safeMapCastStatic(rawRecurrenceData);
    final rawCustomParams = recurrenceData['custom_params'];
    if (rawCustomParams == null) return 'Custom';
    
    final Map<String, dynamic> customParams = _safeMapCastStatic(rawCustomParams);
    final String frequencyType = customParams['frequencyType']?.toString().toLowerCase() ?? 'day';
    final int value = _safeIntParseStatic(customParams['value'], 1);
    
    switch (frequencyType) {
      case 'day':
        return value == 1 ? 'Daily' : '${value}d';
      case 'week':
        return '${value}w';
      case 'month':
        return '${value}m';
      case 'year':
        return '${value}y';
      default:
        return 'Custom';
    }
  }

  /// Returns true if the frequency has a visual indicator (week/year/month-dates)
  static bool hasVisualIndicator(Map<String, dynamic> record) {
    final String frequency = record['recurrence_frequency']?.toString() ?? '';
    if (frequency != 'Custom') return false;
    
    final rawRecurrenceData = record['recurrence_data'];
    if (rawRecurrenceData == null) return false;
    
    final Map<String, dynamic> recurrenceData = _safeMapCastStatic(rawRecurrenceData);
    final rawCustomParams = recurrenceData['custom_params'];
    if (rawCustomParams == null) return false;
    
    final Map<String, dynamic> customParams = _safeMapCastStatic(rawCustomParams);
    final String frequencyType = customParams['frequencyType']?.toString().toLowerCase() ?? 'day';
    
    if (frequencyType == 'week' || frequencyType == 'year') return true;
    if (frequencyType == 'month') {
      final String monthlyOption = customParams['monthlyOption']?.toString() ?? 'day';
      if (monthlyOption == 'dates') {
        final selectedDates = customParams['selectedDates'];
        return selectedDates is List && selectedDates.length > 1;
      }
    }
    return false;
  }

  static Map<String, dynamic> _safeMapCastStatic(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static int _safeIntParseStatic(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    final String frequency = record['recurrence_frequency']?.toString() ?? '';
    
    if (frequency.isEmpty) return const SizedBox.shrink();
    
    // Handle predefined frequencies - no visual, just empty (prefix shown in label)
    if (frequency != 'Custom') {
      return const SizedBox.shrink();
    }
    
    // Handle Custom frequency
    final rawRecurrenceData = record['recurrence_data'];
    if (rawRecurrenceData == null) {
      return const SizedBox.shrink();
    }
    
    final Map<String, dynamic> recurrenceData = _safeMapCast(rawRecurrenceData);
    final rawCustomParams = recurrenceData['custom_params'];
    if (rawCustomParams == null) {
      return const SizedBox.shrink();
    }
    
    final Map<String, dynamic> customParams = _safeMapCast(rawCustomParams);
    final String frequencyType = customParams['frequencyType']?.toString().toLowerCase() ?? 'day';
    final int value = _safeIntParse(customParams['value'], 1);
    
    switch (frequencyType) {
      case 'week':
        return _buildWeekIndicator(context, customParams, value);
      case 'year':
        return _buildYearIndicator(context, customParams, value);
      case 'month':
        return _buildMonthIndicator(context, customParams, value);
      case 'day':
      default:
        return const SizedBox.shrink();
    }
  }

  /// Builds the week frequency indicator with S M T W T F S letters (no prefix)
  Widget _buildWeekIndicator(BuildContext context, Map<String, dynamic> customParams, int value) {
    final daysOfWeek = customParams['daysOfWeek'];
    List<bool> selectedDays = List.filled(7, false);
    
    if (daysOfWeek is List) {
      for (int i = 0; i < daysOfWeek.length && i < 7; i++) {
        selectedDays[i] = daysOfWeek[i] == true;
      }
    }
    
    final primaryColor = Theme.of(context).colorScheme.primary;
    final mutedColor = Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3) ?? Colors.grey;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (index) {
        final isSelected = selectedDays[index];
        return _buildLetter(
          context,
          _dayLetters[index],
          isSelected,
          primaryColor,
          mutedColor,
        );
      }),
    );
  }

  /// Builds the year frequency indicator with month letters (no prefix)
  Widget _buildYearIndicator(BuildContext context, Map<String, dynamic> customParams, int value) {
    final selectedMonths = customParams['selectedMonths'];
    List<bool> selectedMonthList = List.filled(12, false);
    
    if (selectedMonths is List) {
      for (int i = 0; i < selectedMonths.length && i < 12; i++) {
        selectedMonthList[i] = selectedMonths[i] == true;
      }
    }
    
    final primaryColor = Theme.of(context).colorScheme.primary;
    final mutedColor = Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3) ?? Colors.grey;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(12, (index) {
        final isSelected = selectedMonthList[index];
        return _buildLetter(
          context,
          _monthLetters[index],
          isSelected,
          primaryColor,
          mutedColor,
        );
      }),
    );
  }

  /// Builds month frequency indicator
  Widget _buildMonthIndicator(BuildContext context, Map<String, dynamic> customParams, int value) {
    final String monthlyOption = customParams['monthlyOption']?.toString() ?? 'day';
    
    // For 'dates' option with multiple dates, show visual
    if (monthlyOption == 'dates') {
      final selectedDates = customParams['selectedDates'];
      if (selectedDates is List && selectedDates.length > 1) {
        return _buildDatesIndicator(context, selectedDates, value);
      }
    }
    
    // For other cases, no visual indicator
    return const SizedBox.shrink();
  }

  /// Builds indicator for specific dates in a month (no prefix)
  Widget _buildDatesIndicator(BuildContext context, List<dynamic> selectedDates, int value) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final mutedColor = Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3) ?? Colors.grey;
    
    // Convert to sorted list of integers
    final List<int> dateList = selectedDates
        .map((d) => d is int ? d : int.tryParse(d.toString()) ?? 0)
        .where((d) => d > 0 && d <= 31)
        .toList()
      ..sort();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...dateList.take(5).map((date) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            '$date',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        )),
        if (dateList.length > 5)
          Text(
            '+${dateList.length - 5}',
            style: TextStyle(
              fontSize: fontSize - 2,
              color: mutedColor,
            ),
          ),
      ],
    );
  }

  /// Builds a single letter with color distinction
  Widget _buildLetter(
    BuildContext context,
    String letter,
    bool isSelected,
    Color primaryColor,
    Color mutedColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? primaryColor : mutedColor,
        ),
      ),
    );
  }

  /// Safely casts dynamic map to Map<String, dynamic>
  Map<String, dynamic> _safeMapCast(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  /// Safely parses int from dynamic value
  int _safeIntParse(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
}
