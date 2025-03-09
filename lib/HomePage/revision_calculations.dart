int calculateMonthlyRevisions(List<Map<String, dynamic>> records, Map<String, Set<String>> selectedTrackingTypesMap) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  Set<String> selectedRevisionTypes = selectedTrackingTypesMap['revision'] ?? {};

  int count = 0;
  for (var record in records) {
    if (record['details']['revision_dates'] == null ||
        !selectedRevisionTypes.contains(record['details']['lecture_type'])) continue;

    List<dynamic> revisionDates = record['details']['revision_dates'];
    for (var dateStr in revisionDates) {
      final date = DateTime.parse(dateStr);
      if (date.isAfter(startOfMonth) || date.isAtSameMomentAs(startOfMonth)) {
        count++;
      }
    }
  }
  return count;
}

int calculateWeeklyRevisions(List<Map<String, dynamic>> records, Map<String, Set<String>> selectedTrackingTypesMap) {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
  Set<String> selectedRevisionTypes = selectedTrackingTypesMap['revision'] ?? {};

  int count = 0;
  for (var record in records) {
    if (record['details']['revision_dates'] == null ||
        !selectedRevisionTypes.contains(record['details']['lecture_type'])) continue;

    List<dynamic> revisionDates = record['details']['revision_dates'];
    for (var dateStr in revisionDates) {
      final date = DateTime.parse(dateStr);
      if (date.isAfter(startOfDay) || date.isAtSameMomentAs(startOfDay)) {
        count++;
      }
    }
  }
  return count;
}

int calculateDailyRevisions(List<Map<String, dynamic>> records, Map<String, Set<String>> selectedTrackingTypesMap) {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  Set<String> selectedRevisionTypes = selectedTrackingTypesMap['revision'] ?? {};

  int count = 0;
  for (var record in records) {
    if (record['details']['revision_dates'] == null ||
        !selectedRevisionTypes.contains(record['details']['lecture_type'])) continue;

    List<dynamic> revisionDates = record['details']['revision_dates'];
    for (var dateStr in revisionDates) {
      final date = DateTime.parse(dateStr);
      if (date.isAfter(startOfDay) || date.isAtSameMomentAs(startOfDay)) {
        count++;
      }
    }
  }
  return count;
}