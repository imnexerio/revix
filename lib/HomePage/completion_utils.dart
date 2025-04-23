
double calculateMonthlyCompletion(List<Map<String, dynamic>> records,  int customCompletionTarget) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);


  int completedLectures = records.where((record) {
    if (record['details']['date_learnt'] == null) return false;
    final dateLearnt = DateTime.parse(record['details']['date_learnt']);
    return dateLearnt.isAfter(startOfMonth) || dateLearnt.isAtSameMomentAs(startOfMonth);
  }).length;

  return (completedLectures / customCompletionTarget) * 100;
}

double calculateWeeklyCompletion(List<Map<String, dynamic>> records,  int customCompletionTarget) {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

  int completedLectures = records.where((record) {
    if (record['details']['date_learnt'] == null) return false;
    final dateLearnt = DateTime.parse(record['details']['date_learnt']);
    return dateLearnt.isAfter(startOfDay) || dateLearnt.isAtSameMomentAs(startOfDay);
  }).length;


  return (completedLectures / customCompletionTarget) * 100;
}

double calculateDailyCompletion(List<Map<String, dynamic>> records,  int customCompletionTarget) {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);


  int completedLectures = records.where((record) {
    if (record['details']['date_learnt'] == null) return false;
    final dateLearnt = DateTime.parse(record['details']['date_learnt']);
    return dateLearnt.isAfter(startOfDay) || dateLearnt.isAtSameMomentAs(startOfDay);
  }).length;

  return (completedLectures / customCompletionTarget) *100;
}