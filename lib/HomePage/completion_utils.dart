
double calculateMonthlyCompletion(List<Map<String, dynamic>> records,  int customCompletionTarget) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);

  int completedEntries = records.where((record) {
    if (record['details']['date_initiated'] == 'Unspecified') return false;
    if (record['details']['date_initiated'] == null) return false;
    final dateLearnt = DateTime.parse(record['details']['date_initiated']);
    return dateLearnt.isAfter(startOfMonth) || dateLearnt.isAtSameMomentAs(startOfMonth);
  }).length;

  return (completedEntries / customCompletionTarget) * 100;
}

double calculateWeeklyCompletion(List<Map<String, dynamic>> records,  int customCompletionTarget) {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

  int completedEntries = records.where((record) {
    if (record['details']['date_initiated'] == 'Unspecified') return false;
    if (record['details']['date_initiated'] == null) return false;
    final dateLearnt = DateTime.parse(record['details']['date_initiated']);
    return dateLearnt.isAfter(startOfDay) || dateLearnt.isAtSameMomentAs(startOfDay);
  }).length;


  return (completedEntries / customCompletionTarget) * 100;
}

double calculateDailyCompletion(List<Map<String, dynamic>> records,  int customCompletionTarget) {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);


  int completedEntries = records.where((record) {
    if (record['details']['date_initiated'] == 'Unspecified') return false;
    if (record['details']['date_initiated'] == null) return false;
    final dateLearnt = DateTime.parse(record['details']['date_initiated']);
    return dateLearnt.isAfter(startOfDay) || dateLearnt.isAtSameMomentAs(startOfDay);
  }).length;

  return (completedEntries / customCompletionTarget) *100;
}