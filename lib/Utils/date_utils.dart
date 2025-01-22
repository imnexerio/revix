class DateNextRevision {
  static DateTime calculateNextRevisionDate(DateTime scheduledDate, String frequency, int noRevision) {
    switch (frequency) {
      case 'Daily':
        return scheduledDate.add(Duration(days: 1));
      case '2 Day':
        return scheduledDate.add(Duration(days: 2));
      case '3 Day':
        return scheduledDate.add(Duration(days: 3));
      case 'Weekly':
        return scheduledDate.add(Duration(days: 7));
      case 'Default':
      default:
        List<int> intervals = [1, 4, 7, 15, 30, 60];
        int additionalDays = (noRevision < intervals.length)
            ? intervals[noRevision]
            : 60;  // After using all intervals, use 30 days
        return scheduledDate.add(Duration(days: additionalDays));
    }
  }

  static DateTime calculateFirstScheduledDate(String frequency) {
    DateTime today = DateTime.now();
    switch (frequency) {
      case 'Daily':
        return today.add(Duration(days: 1));
      case '2 Day':
        return today.add(Duration(days: 1));
      case '3 Day':
        return today.add(Duration(days: 1));
      case 'Weekly':
        return today.add(Duration(days: 1));
      case 'Default':
      default:
        return today.add(Duration(days: 1));
    }
  }
}