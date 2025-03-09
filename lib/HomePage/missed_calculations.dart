int calculateMonthlyMissed(List<Map<String, dynamic>> records, Map<String, Set<String>> selectedTrackingTypesMap) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  Set<String> selectedMissedTypes = selectedTrackingTypesMap['missed'] ?? {};

  int count = 0;
  for (var record in records) {
    if (record['details']['missed_revisions'] == null ||
        !selectedMissedTypes.contains(record['details']['lecture_type'])) continue;

    List<dynamic> missedDates = record['details']['missed_revisions'];
    for (var dateStr in missedDates) {
      final date = DateTime.parse(dateStr);
      if (date.isAfter(startOfMonth) || date.isAtSameMomentAs(startOfMonth)) {
        count++;
      }
    }
  }
  return count;
}

int calculateWeeklyMissed(List<Map<String, dynamic>> records, Map<String, Set<String>> selectedTrackingTypesMap) {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
  Set<String> selectedMissedTypes = selectedTrackingTypesMap['missed'] ?? {};

  int count = 0;
  for (var record in records) {
    if (record['details']['missed_revisions'] == null ||
        !selectedMissedTypes.contains(record['details']['lecture_type'])) continue;

    List<dynamic> missedDates = record['details']['missed_revisions'];
    for (var dateStr in missedDates) {
      final date = DateTime.parse(dateStr);
      if (date.isAfter(startOfDay) || date.isAtSameMomentAs(startOfDay)) {
        count++;
      }
    }
  }
  return count;
}

int calculateDailyMissed(List<Map<String, dynamic>> records, Map<String, Set<String>> selectedTrackingTypesMap) {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  Set<String> selectedMissedTypes = selectedTrackingTypesMap['missed'] ?? {};

  int count = 0;
  for (var record in records) {
    if (record['details']['missed_revisions'] == null ||
        !selectedMissedTypes.contains(record['details']['lecture_type'])) continue;

    List<dynamic> missedDates = record['details']['missed_revisions'];
    for (var dateStr in missedDates) {
      final date = DateTime.parse(dateStr);
      if (date.isAfter(startOfDay) || date.isAtSameMomentAs(startOfDay)) {
        count++;
      }
    }
  }
  return count;
}