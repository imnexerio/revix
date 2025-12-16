int calculateMonthlyEntries(List<Map<String, dynamic>> records) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);

  return records.where((record) {
    if (record['details']['date_initiated'] == null || record['details']['date_initiated']=='Unspecified') return false;
    final dateInitiated = DateTime.parse(record['details']['date_initiated']);
    return (dateInitiated.isAfter(startOfMonth) || dateInitiated.isAtSameMomentAs(startOfMonth));
  }).length;
}

int calculateWeeklyEntries(List<Map<String, dynamic>> records) {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

  return records.where((record) {
    if (record['details']['date_initiated'] == null || record['details']['date_initiated']=='Unspecified') return false;
    final dateInitiated = DateTime.parse(record['details']['date_initiated']);
    return (dateInitiated.isAfter(startOfDay) || dateInitiated.isAtSameMomentAs(startOfDay));
  }).length;
}

int calculateDailyEntries(List<Map<String, dynamic>> records) {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);

  return records.where((record) {
    if (record['details']['date_initiated'] == null || record['details']['date_initiated']=='Unspecified') return false;
    final dateInitiated = DateTime.parse(record['details']['date_initiated']);
    return (dateInitiated.isAfter(startOfDay) || dateInitiated.isAtSameMomentAs(startOfDay));
  }).length;
}
