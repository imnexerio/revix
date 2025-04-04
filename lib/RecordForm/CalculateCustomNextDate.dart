class CalculateCustomNextDate {
  static  DateTime calculateCustomNextDate(DateTime startDate, Map<String, dynamic> customParams) {
    // Extract base parameters
    String frequencyType = customParams['frequencyType'] ?? 'week';
    int value = customParams['value'] ?? 1;
    DateTime nextDate = startDate;

    switch (frequencyType) {
      case 'day':
      // Simple day increment
        nextDate = startDate.add(Duration(days: value));
        break;

      case 'week':
      // Get selected days of week
        List<bool> daysOfWeek = customParams['daysOfWeek'] ?? List.filled(7, false);

        // If no days selected, default to same day next week
        if (!daysOfWeek.contains(true)) {
          return startDate.add(Duration(days: 7 * value));
        }

        // Find next occurrence based on selected day(s)
        // Start by adding one day to avoid same-day selection
        nextDate = startDate.add(const Duration(days: 1));
        bool found = false;

        // Look ahead up to value * 7 days to find the next match
        for (int i = 0; i < value * 7; i++) {
          // Check if this day of week is selected (0 = Sunday)
          int weekday = nextDate.weekday % 7; // Convert to 0-6 where 0 = Sunday
          if (daysOfWeek[weekday]) {
            found = true;
            break;
          }
          nextDate = nextDate.add(const Duration(days: 1));
        }

        // If no match found in the first week, add more weeks as needed
        if (!found) {
          nextDate = startDate.add(Duration(days: 7 * value));
        }
        break;

      case 'month':
        String monthlyOption = customParams['monthlyOption'] ?? 'day';

        switch (monthlyOption) {
          case 'day':
          // Specific day of month
            int dayOfMonth = customParams['dayOfMonth'] ?? startDate.day;

            // Start with same day next month
            nextDate = DateTime(startDate.year, startDate.month + value, startDate.day);

            // Adjust to the selected day of month
            int maxDays = DateTime(nextDate.year, nextDate.month + 1, 0).day;
            nextDate = DateTime(nextDate.year, nextDate.month,
                dayOfMonth > maxDays ? maxDays : dayOfMonth);
            break;

          case 'weekday':
          // Specific weekday (e.g., "3rd Tuesday")
            int weekOfMonth = customParams['weekOfMonth'] ?? 1;
            String dayOfWeek = customParams['dayOfWeek'] ?? 'Monday';

            // Map dayOfWeek string to int (1-7, where 1 is Monday)
            Map<String, int> dayMap = {
              'Monday': 1, 'Tuesday': 2, 'Wednesday': 3, 'Thursday': 4,
              'Friday': 5, 'Saturday': 6, 'Sunday': 7
            };
            int targetWeekday = dayMap[dayOfWeek] ?? 1;

            // First, move to the next month
            nextDate = DateTime(startDate.year, startDate.month + value, 1);

            // Find the first occurrence of the target weekday
            while (nextDate.weekday != targetWeekday) {
              nextDate = nextDate.add(const Duration(days: 1));
            }

            // Add weeks as needed to get to the nth occurrence
            nextDate = nextDate.add(Duration(days: 7 * (weekOfMonth - 1)));

            // If this pushes us into the next month, go back to the last occurrence in the target month
            if (nextDate.month != startDate.month + value) {
              nextDate = nextDate.subtract(const Duration(days: 7));
            }
            break;

          case 'dates':
          // Multiple specific dates in a month
            List<int> selectedDates = customParams['selectedDates'] ?? [startDate.day];
            if (selectedDates.isEmpty) selectedDates = [startDate.day];

            // Sort the dates
            selectedDates.sort();

            // Find the next date after the start date
            int nextDay = -1;
            for (int day in selectedDates) {
              if (day > startDate.day) {
                nextDay = day;
                break;
              }
            }

            // If not found (current date is after all selected dates), move to next month
            if (nextDay == -1) {
              nextDate = DateTime(startDate.year, startDate.month + value, selectedDates.first);
            } else {
              nextDate = DateTime(startDate.year, startDate.month, nextDay);
            }

            // Check if the calculated day exists in the month
            int maxDays = DateTime(nextDate.year, nextDate.month + 1, 0).day;
            if (nextDate.day > maxDays) {
              nextDate = DateTime(nextDate.year, nextDate.month, maxDays);
            }
            break;
        }
        break;

      case 'year':
        String yearlyOption = customParams['yearlyOption'] ?? 'day';
        List<bool> selectedMonths = customParams['selectedMonths'] ?? List.filled(12, false);

        // Default to current month if none selected
        if (!selectedMonths.contains(true)) {
          selectedMonths[startDate.month - 1] = true;
        }

        // Find the next month after current month
        int nextMonth = -1;
        for (int i = startDate.month; i < 12; i++) {
          if (selectedMonths[i]) {
            nextMonth = i + 1; // Convert 0-based index to 1-based month
            break;
          }
        }

        // If no months found after current month, go to next year and find first selected month
        int targetYear = startDate.year;
        if (nextMonth == -1) {
          targetYear += value;
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
            int monthDay = customParams['monthDay'] ?? startDate.day;

            // Calculate next date
            nextDate = DateTime(targetYear, nextMonth, 1);

            // Adjust to selected day of month, handling edge cases
            int maxDays = DateTime(targetYear, nextMonth + 1, 0).day;
            nextDate = DateTime(targetYear, nextMonth,
                monthDay > maxDays ? maxDays : monthDay);
            break;

          case 'weekday':
          // Specific weekday in month (e.g., "First Monday of January")
            int weekOfYear = customParams['weekOfYear'] ?? 1;
            String dayOfWeekForYear = customParams['dayOfWeekForYear'] ?? 'Monday';

            // Map dayOfWeek string to int
            Map<String, int> dayMap = {
              'Monday': 1, 'Tuesday': 2, 'Wednesday': 3, 'Thursday': 4,
              'Friday': 5, 'Saturday': 6, 'Sunday': 7
            };
            int targetWeekday = dayMap[dayOfWeekForYear] ?? 1;

            // Find the first occurrence of the weekday in the month
            nextDate = DateTime(targetYear, nextMonth, 1);
            while (nextDate.weekday != targetWeekday) {
              nextDate = nextDate.add(const Duration(days: 1));
            }

            // Add weeks to get to the desired occurrence
            nextDate = nextDate.add(Duration(days: 7 * (weekOfYear - 1)));

            // If this pushes us into the next month, go back to the last occurrence
            if (nextDate.month != nextMonth) {
              nextDate = nextDate.subtract(const Duration(days: 7));
            }
            break;
        }
        break;
    }

    // Ensure the next date is after the start date
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
          nextDate = DateTime(startDate.year, startDate.month + value, startDate.day);
          break;
        case 'year':
          nextDate = DateTime(startDate.year + value, startDate.month, startDate.day);
          break;
      }
    }

    return nextDate;
  }

}
