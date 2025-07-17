class CalculateCustomNextDate {
  static DateTime calculateCustomNextDate(DateTime startDate, Map<String, dynamic> params) {
    // Extract custom_params if nested
    Map<String, dynamic> customParams;
    if (params.containsKey('custom_params')) {
      customParams = params['custom_params'];
    } else {
      customParams = params;
    }    // Extract base parameters with safe fallbacks
    String frequencyType = customParams['frequencyType']?.toString().toLowerCase() ?? 'week';
    int value = customParams['value'] is int ? customParams['value'] : 1;
    DateTime nextDate = startDate;

    // print('Processing: frequencyType=$frequencyType, value=$value');

    switch (frequencyType) {
      case 'day':
      // Simple day increment
        nextDate = startDate.add(Duration(days: value));
        break;

      case 'week':
      // Get selected days of week and ensure it's the right type
        List<bool> daysOfWeek;

        if (customParams['daysOfWeek'] is List) {
          // Convert any list to a list of booleans
          daysOfWeek = List<bool>.from(
              (customParams['daysOfWeek'] as List).map((day) => day == true)
          );

          // Ensure we have exactly 7 elements
          if (daysOfWeek.length < 7) {
            daysOfWeek.addAll(List.filled(7 - daysOfWeek.length, false));
          } else if (daysOfWeek.length > 7) {
            daysOfWeek = daysOfWeek.sublist(0, 7);
          }
        } else {
          daysOfWeek = List.filled(7, false);
        }

        // If no days selected, default to same day next week
        if (!daysOfWeek.contains(true)) {
          return startDate.add(Duration(days: 7 * value));
        }        // Find the first matching day after startDate
        // In Dart, DateTime.weekday is 1-7 where 1 is Monday and 7 is Sunday
        // Convert to 0-6 where 0 is Sunday to match our daysOfWeek array
        int currentWeekday = startDate.weekday % 7;

        bool foundInCurrentWeek = false;

        // First check if there are any selected days later in the current week
        for (int i = currentWeekday + 1; i < 7; i++) {
          if (daysOfWeek[i]) {
            int daysToAdd = i - currentWeekday;
            nextDate = startDate.add(Duration(days: daysToAdd));
            foundInCurrentWeek = true;
            break;
          }
        }

        // If no selected days found later in current week, find first selected day in next week(s)
        if (!foundInCurrentWeek) {
          // Calculate days to Sunday (start of week)
          int daysToFirstDayOfNextWeek = 7 - currentWeekday;

          // Start from the beginning of next week
          DateTime beginningOfNextWeek = startDate.add(Duration(days: daysToFirstDayOfNextWeek));

          // Find the first selected day in the week
          int daysFromSunday = 0;
          for (int i = 0; i < 7; i++) {
            if (daysOfWeek[i]) {
              daysFromSunday = i;
              break;
            }
          }

          // Set next date to the found day in the next week
          nextDate = beginningOfNextWeek.add(Duration(days: daysFromSunday));

          // Now add additional weeks based on value
          if (value > 1) {
            nextDate = nextDate.add(Duration(days: 7 * (value - 1)));
          }
        } else if (value > 1) {
          // If we found a day in the current week but value > 1,
          // add (value-1) weeks to the next occurrence
          nextDate = nextDate.add(Duration(days: 7 * (value - 1)));
        }
        break;

      case 'month':
        String monthlyOption = customParams['monthlyOption']?.toString() ?? 'day';

        switch (monthlyOption) {
          case 'day':
          // Specific day of month
            int dayOfMonth = customParams['dayOfMonth'] is int ? customParams['dayOfMonth'] : startDate.day;            // Calculate the target month
            int targetMonth = startDate.month + value;
            int targetYear = startDate.year + targetMonth ~/ 12;
            int adjustedMonth = ((targetMonth - 1) % 12) + 1;

            // Calculate next date and handle month length issues
            int maxDays = DateTime(targetYear, adjustedMonth + 1, 0).day;
            nextDate = DateTime(targetYear, adjustedMonth, dayOfMonth > maxDays ? maxDays : dayOfMonth);            // Check if the result is before or equal to the start date
            if (nextDate.isBefore(startDate) || nextDate.isAtSameMomentAs(startDate)) {
              int newTargetMonth = startDate.month + value + 1;
              int newTargetYear = startDate.year + newTargetMonth ~/ 12;
              int newAdjustedMonth = ((newTargetMonth - 1) % 12) + 1;

              int newMaxDays = DateTime(newTargetYear, newAdjustedMonth + 1, 0).day;
              nextDate = DateTime(newTargetYear, newAdjustedMonth, dayOfMonth > newMaxDays ? newMaxDays : dayOfMonth);
            }
            break;

        // ... [rest of the month case remains the same]
          case 'weekday':
          // Specific weekday (e.g., "3rd Tuesday")
            int weekOfMonth = customParams['weekOfMonth'] is int ? customParams['weekOfMonth'] : 1;
            String dayOfWeek = customParams['dayOfWeek']?.toString() ?? 'Monday';

            // Map dayOfWeek string to int (1-7, where 1 is Monday)
            Map<String, int> dayMap = {
              'Monday': 1, 'monday': 1, 'mon': 1,
              'Tuesday': 2, 'tuesday': 2, 'tue': 2,
              'Wednesday': 3, 'wednesday': 3, 'wed': 3,
              'Thursday': 4, 'thursday': 4, 'thu': 4,
              'Friday': 5, 'friday': 5, 'fri': 5,
              'Saturday': 6, 'saturday': 6, 'sat': 6,
              'Sunday': 7, 'sunday': 7, 'sun': 7
            };
            int targetWeekday = dayMap[dayOfWeek] ?? 1;            // Calculate target month and year
            int targetMonth = startDate.month + value;
            int targetYear = startDate.year + targetMonth ~/ 12;
            int adjustedMonth = ((targetMonth - 1) % 12) + 1;            // Find the first occurrence of the target weekday in the month
            DateTime firstDayOfMonth = DateTime(targetYear, adjustedMonth, 1);
            int daysUntilWeekday = (targetWeekday - firstDayOfMonth.weekday) % 7;
            if (daysUntilWeekday < 0) daysUntilWeekday += 7;

            // Calculate the date of the first occurrence
            DateTime firstOccurrence = firstDayOfMonth.add(Duration(days: daysUntilWeekday));

            // Add weeks to get to the desired occurrence
            nextDate = firstOccurrence.add(Duration(days: 7 * (weekOfMonth - 1)));

            // If this pushes us into the next month, go back to the last occurrence in the target month
            if (nextDate.month != adjustedMonth) {
              nextDate = nextDate.subtract(const Duration(days: 7));
            }

            // If result is before or on start date, move to the next period
            if (nextDate.isBefore(startDate) || nextDate.isAtSameMomentAs(startDate)) {
              int newTargetMonth = startDate.month + value + 1;
              int newTargetYear = startDate.year + newTargetMonth ~/ 12;
              int newAdjustedMonth = ((newTargetMonth - 1) % 12) + 1;

              firstDayOfMonth = DateTime(newTargetYear, newAdjustedMonth, 1);
              daysUntilWeekday = (targetWeekday - firstDayOfMonth.weekday) % 7;
              if (daysUntilWeekday < 0) daysUntilWeekday += 7;

              firstOccurrence = firstDayOfMonth.add(Duration(days: daysUntilWeekday));
              nextDate = firstOccurrence.add(Duration(days: 7 * (weekOfMonth - 1)));

              if (nextDate.month != newAdjustedMonth) {
                nextDate = nextDate.subtract(const Duration(days: 7));
              }
            }
            break;

          case 'dates':
          // Multiple specific dates in a month
            List<int> selectedDates = [];

            if (customParams['selectedDates'] is List) {
              selectedDates = List<int>.from(customParams['selectedDates'].map((d) => d is int ? d : int.tryParse(d.toString()) ?? 1));
            } else {
              selectedDates = [startDate.day];
            }

            if (selectedDates.isEmpty) selectedDates = [startDate.day];

            // Sort the dates
            selectedDates.sort();

            // Calculate target month and year
            int targetMonth = startDate.month;
            int targetYear = startDate.year;

            // Find the next date in the current month
            int nextDay = -1;
            for (int day in selectedDates) {
              if (day > startDate.day) {
                nextDay = day;
                break;
              }
            }

            // If no valid date found in current month, move to future month
            if (nextDay == -1) {
              targetMonth += value;
              while (targetMonth > 12) {
                targetMonth -= 12;
                targetYear++;
              }
              nextDay = selectedDates.first;
            }

            // Calculate next date
            int maxDays = DateTime(targetYear, targetMonth + 1, 0).day;
            nextDay = nextDay > maxDays ? maxDays : nextDay;
            nextDate = DateTime(targetYear, targetMonth, nextDay);            // If result is before or on start date, move to the next period
            if (nextDate.isBefore(startDate) || nextDate.isAtSameMomentAs(startDate)) {
              int newTargetMonth = startDate.month + value;
              int newTargetYear = startDate.year + newTargetMonth ~/ 12;
              int newAdjustedMonth = ((newTargetMonth - 1) % 12) + 1;

              nextDay = selectedDates.first;
              int newMaxDays = DateTime(newTargetYear, newAdjustedMonth + 1, 0).day;
              nextDay = nextDay > newMaxDays ? newMaxDays : nextDay;
              nextDate = DateTime(newTargetYear, newAdjustedMonth, nextDay);
            }
            break;
        }
        break;

      case 'year':
        String yearlyOption = customParams['yearlyOption']?.toString() ?? 'day';
        List<bool> selectedMonths = [];

        if (customParams['selectedMonths'] is List) {
          selectedMonths = List<bool>.from(
              (customParams['selectedMonths'] as List).map((month) => month == true)
          );

          // Ensure we have exactly 12 elements
          if (selectedMonths.length < 12) {
            selectedMonths.addAll(List.filled(12 - selectedMonths.length, false));
          } else if (selectedMonths.length > 12) {
            selectedMonths = selectedMonths.sublist(0, 12);
          }
        } else {
          selectedMonths = List.filled(12, false);
        }

        // Default to current month if none selected
        if (!selectedMonths.contains(true)) {
          selectedMonths[startDate.month - 1] = true;
        }
        // Find the next month after current month
        int nextMonth = -1;
        for (int i = startDate.month + 1; i <= 12; i++) {
          if (i <= selectedMonths.length && selectedMonths[i - 1]) {
            nextMonth = i;
            break;
          }
        }

        // Calculate target year
        int targetYear = startDate.year;
        if (nextMonth == -1) {
          // If no months found after current month, go to next year
          targetYear += value;

          // Find first selected month
          for (int i = 0; i < 12; i++) {
            if (selectedMonths[i]) {
              nextMonth = i + 1;
              break;
            }
          }
        }

        switch (yearlyOption) {
          case 'day':
          // Specific day of month (e.g., "January 15th")
            int monthDay = customParams['monthDay'] is int ? customParams['monthDay'] : startDate.day;

            // Calculate next date
            int maxDays = DateTime(targetYear, nextMonth + 1, 0).day;
            nextDate = DateTime(targetYear, nextMonth, monthDay > maxDays ? maxDays : monthDay);

            // If this date is not after start date, add more years
            if (nextDate.isBefore(startDate) || nextDate.isAtSameMomentAs(startDate)) {
              targetYear = startDate.year + value;
              maxDays = DateTime(targetYear, nextMonth + 1, 0).day;
              nextDate = DateTime(targetYear, nextMonth, monthDay > maxDays ? maxDays : monthDay);
            }
            break;

          case 'weekday':
          // Specific weekday in month (e.g., "First Monday of January")
            int weekOfYear = customParams['weekOfYear'] is int ? customParams['weekOfYear'] : 1;
            String dayOfWeekForYear = customParams['dayOfWeekForYear']?.toString() ?? 'Monday';

            // Map dayOfWeek string to int
            Map<String, int> dayMap = {
              'Monday': 1, 'monday': 1, 'mon': 1,
              'Tuesday': 2, 'tuesday': 2, 'tue': 2,
              'Wednesday': 3, 'wednesday': 3, 'wed': 3,
              'Thursday': 4, 'thursday': 4, 'thu': 4,
              'Friday': 5, 'friday': 5, 'fri': 5,
              'Saturday': 6, 'saturday': 6, 'sat': 6,
              'Sunday': 7, 'sunday': 7, 'sun': 7
            };
            int targetWeekday = dayMap[dayOfWeekForYear] ?? 1;

            // Find the first occurrence of the weekday in the month
            DateTime firstDayOfMonth = DateTime(targetYear, nextMonth, 1);
            int daysUntilWeekday = (targetWeekday - firstDayOfMonth.weekday) % 7;
            if (daysUntilWeekday < 0) daysUntilWeekday += 7;

            DateTime firstOccurrence = firstDayOfMonth.add(Duration(days: daysUntilWeekday));

            // Add weeks to get to the desired occurrence
            nextDate = firstOccurrence.add(Duration(days: 7 * (weekOfYear - 1)));

            // If this pushes us into the next month, go back to the last occurrence
            if (nextDate.month != nextMonth) {
              nextDate = nextDate.subtract(const Duration(days: 7));
            }

            // If not after start date, go to next occurrence in future year
            if (nextDate.isBefore(startDate) || nextDate.isAtSameMomentAs(startDate)) {
              targetYear = startDate.year + value;

              firstDayOfMonth = DateTime(targetYear, nextMonth, 1);
              daysUntilWeekday = (targetWeekday - firstDayOfMonth.weekday) % 7;
              if (daysUntilWeekday < 0) daysUntilWeekday += 7;

              firstOccurrence = firstDayOfMonth.add(Duration(days: daysUntilWeekday));
              nextDate = firstOccurrence.add(Duration(days: 7 * (weekOfYear - 1)));

              if (nextDate.month != nextMonth) {
                nextDate = nextDate.subtract(const Duration(days: 7));
              }
            }
            break;
        }
        break;
    }

    // Final safety check to ensure the next date is after the start date
    if (nextDate.isBefore(startDate) || nextDate.isAtSameMomentAs(startDate)) {
      // If still not after start date, add one more frequency unit
      switch (frequencyType) {
        case 'day':
          nextDate = startDate.add(Duration(days: value));
          break;
        case 'week':
          nextDate = startDate.add(Duration(days: 7 * value));
          break;
        case 'month':
        // Handle month overflow correctly
          int targetMonth = startDate.month + value;
          int targetYear = startDate.year + targetMonth ~/ 12;
          int adjustedMonth = ((targetMonth - 1) % 12) + 1;
          int maxDays = DateTime(targetYear, adjustedMonth + 1, 0).day;
          int day = startDate.day > maxDays ? maxDays : startDate.day;
          nextDate = DateTime(targetYear, adjustedMonth, day);
          break;
        case 'year':
          int maxDays = DateTime(startDate.year + value, startDate.month + 1, 0).day;
          int day = startDate.day > maxDays ? maxDays : startDate.day;
          nextDate = DateTime(startDate.year + value, startDate.month, day);
          break;
      }
    }

    return nextDate;
  }
}