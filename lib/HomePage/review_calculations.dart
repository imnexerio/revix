int calculateMonthlyReviews(List<Map<String, dynamic>> records) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  int count = 0;

  for (var record in records) {
    if (record['details']['dates_updated'] == null) continue;

    List<dynamic> reviewDates = record['details']['dates_updated'];
    for (var dateStr in reviewDates) {
      DateTime date;
      try {
        date = DateTime.parse(dateStr);
      } catch (e) {
        date = DateTime.parse(dateStr.split('T')[0]);
      }
      if (date.isAfter(startOfMonth) || date.isAtSameMomentAs(startOfMonth)) {
        count++;
      }
    }
  }
  return count;
}

int calculateWeeklyReviews(List<Map<String, dynamic>> records) {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

  int count = 0;
  for (var record in records) {
    if (record['details']['dates_updated'] == null) continue;

    List<dynamic> reviewDates = record['details']['dates_updated'];
    for (var dateStr in reviewDates) {
      DateTime date;
      try {
        date = DateTime.parse(dateStr);
      } catch (e) {
        date = DateTime.parse(dateStr.split('T')[0]);
      }
      if (date.isAfter(startOfDay) || date.isAtSameMomentAs(startOfDay)) {
        count++;
      }
    }
  }
  return count;
}

int calculateDailyReviews(List<Map<String, dynamic>> records) {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);

  int count = 0;
  for (var record in records) {
    if (record['details']['dates_updated'] == null) continue;

    List<dynamic> reviewDates = record['details']['dates_updated'];
    for (var dateStr in reviewDates) {
      DateTime date;
      try {
        date = DateTime.parse(dateStr);
      } catch (e) {
        date = DateTime.parse(dateStr.split('T')[0]);
      }
      if (date.isAfter(startOfDay) || date.isAtSameMomentAs(startOfDay)) {
        count++;
      }
    }
  }
  return count;
}
