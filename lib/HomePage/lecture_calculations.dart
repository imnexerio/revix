int calculateMonthlyLectures(List<Map<String, dynamic>> records) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);

  return records.where((record) {
    if (record['details']['date_initiated'] == null || record['details']['date_initiated']=='Unspecified') return false;
    final dateLearnt = DateTime.parse(record['details']['date_initiated']);
    return (dateLearnt.isAfter(startOfMonth) || dateLearnt.isAtSameMomentAs(startOfMonth));
  }).length;
}

int calculateWeeklyLectures(List<Map<String, dynamic>> records) {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

  return records.where((record) {
    if (record['details']['date_initiated'] == null || record['details']['date_initiated']=='Unspecified') return false;
    final dateLearnt = DateTime.parse(record['details']['date_initiated']);
    return (dateLearnt.isAfter(startOfDay) || dateLearnt.isAtSameMomentAs(startOfDay));
  }).length;
}

int calculateDailyLectures(List<Map<String, dynamic>> records) {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);

  return records.where((record) {
    if (record['details']['date_initiated'] == null || record['details']['date_initiated']=='Unspecified') return false;
    final dateLearnt = DateTime.parse(record['details']['date_initiated']);
    return (dateLearnt.isAfter(startOfDay) || dateLearnt.isAtSameMomentAs(startOfDay));
  }).length;
}