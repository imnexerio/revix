import 'package:flutter/material.dart';
import '../Utils/FrequencyFormatter.dart';

/// A compact visual widget for displaying recurrence frequency.
/// 
/// Shows day/month letters with dots below selected ones for week/year frequencies.
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

  @override
  Widget build(BuildContext context) {
    final String frequency = record['recurrence_frequency']?.toString() ?? '';
    
    if (frequency.isEmpty) return const SizedBox.shrink();
    
    // Handle predefined frequencies with text
    if (frequency != 'Custom') {
      return _buildTextDisplay(context, FrequencyFormatter.format(record));
    }
    
    // Handle Custom frequency
    final rawRecurrenceData = record['recurrence_data'];
    if (rawRecurrenceData == null) {
      return _buildTextDisplay(context, 'Custom');
    }
    
    final Map<String, dynamic> recurrenceData = _safeMapCast(rawRecurrenceData);
    final rawCustomParams = recurrenceData['custom_params'];
    if (rawCustomParams == null) {
      return _buildTextDisplay(context, 'Custom');
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
        return _buildTextDisplay(context, FrequencyFormatter.format(record));
    }
  }

  /// Builds the week frequency indicator with S M T W T F S letters
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
      children: [
        // Interval prefix
        Text(
          '${value}w ',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        // Day letters
        ...List.generate(7, (index) {
          final isSelected = selectedDays[index];
          return _buildLetterWithDot(
            context,
            _dayLetters[index],
            isSelected,
            primaryColor,
            mutedColor,
          );
        }),
      ],
    );
  }

  /// Builds the year frequency indicator with month letters
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
      children: [
        // Interval prefix
        Text(
          '${value}y ',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        // Month letters
        ...List.generate(12, (index) {
          final isSelected = selectedMonthList[index];
          return _buildLetterWithDot(
            context,
            _monthLetters[index],
            isSelected,
            primaryColor,
            mutedColor,
          );
        }),
      ],
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
    
    // For other cases, use text display
    return _buildTextDisplay(context, FrequencyFormatter.format(record));
  }

  /// Builds indicator for specific dates in a month
  Widget _buildDatesIndicator(BuildContext context, List<dynamic> selectedDates, int value) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final mutedColor = Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3) ?? Colors.grey;
    
    // Convert to set of integers for quick lookup
    final Set<int> dateSet = selectedDates
        .map((d) => d is int ? d : int.tryParse(d.toString()) ?? 0)
        .where((d) => d > 0 && d <= 31)
        .toSet();
    
    // Show compact view: just the selected dates with dots
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${value}m ',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        ...dateSet.take(7).map((date) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$date',
                style: TextStyle(
                  fontSize: fontSize - 1,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        )),
        if (dateSet.length > 7)
          Text(
            '+${dateSet.length - 7}',
            style: TextStyle(
              fontSize: fontSize - 2,
              color: mutedColor,
            ),
          ),
      ],
    );
  }

  /// Builds a single letter with optional dot below
  Widget _buildLetterWithDot(
    BuildContext context,
    String letter,
    bool isSelected,
    Color primaryColor,
    Color mutedColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            letter,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? primaryColor : mutedColor,
            ),
          ),
          const SizedBox(height: 1),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: isSelected ? primaryColor : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds simple text display
  Widget _buildTextDisplay(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize + 2,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).textTheme.bodyMedium?.color,
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
