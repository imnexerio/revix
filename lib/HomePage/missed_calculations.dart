int calculateMonthlyMissed(List<Map<String, dynamic>> records) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);

  int count = 0;
  for (var record in records) {
    if (record['details']['dates_missed_revisions'] == null) continue;

    List<dynamic> missedDates = record['details']['dates_missed_revisions'];
    for (var dateStr in missedDates) {
      final date = DateTime.parse(dateStr);
      if (date.isAfter(startOfMonth) || date.isAtSameMomentAs(startOfMonth)) {
        count++;
      }
    }
  }
  return count;
}

int calculateWeeklyMissed(List<Map<String, dynamic>> records) {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

  int count = 0;
  for (var record in records) {
    if (record['details']['dates_missed_revisions'] == null) continue;

    List<dynamic> missedDates = record['details']['dates_missed_revisions'];
    for (var dateStr in missedDates) {
      final date = DateTime.parse(dateStr);
      if (date.isAfter(startOfDay) || date.isAtSameMomentAs(startOfDay)) {
        count++;
      }
    }
  }
  return count;
}

int calculateDailyMissed(List<Map<String, dynamic>> records) {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);

  int count = 0;
  for (var record in records) {
    if (record['details']['dates_missed_revisions'] == null) continue;

    List<dynamic> missedDates = record['details']['dates_missed_revisions'];
    for (var dateStr in missedDates) {
      final date = DateTime.parse(dateStr);
      if (date.isAfter(startOfDay) || date.isAtSameMomentAs(startOfDay)) {
        count++;
      }
    }
  }
  return count;
}