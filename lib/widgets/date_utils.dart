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
      List<int> intervals = [1, 3, 7, 15, 30];
      int additionalDays = 0;
      for (int i = 0; i <= noRevision; i++) {
        additionalDays += (i < intervals.length) ? intervals[i] : 30;
      }
      return scheduledDate.add(Duration(days: additionalDays));
  }
}
  static DateTime calculateScheduledDate(DateTime scheduledDate, String frequency, int noRevision) {
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
      List<int> intervals = [1, 3, 7, 15, 30];
      int additionalDays = 0;
      for (int i = 0; i <= noRevision; i++) {
        additionalDays += (i < intervals.length) ? intervals[i] : 30;
      }
      return scheduledDate.add(Duration(days: additionalDays));
  }
}
}