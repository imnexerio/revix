import 'dart:ui';

int calculateTotalEntries(List<Map<String, dynamic>> records) {
  return records.where((record) =>
  record['details']['date_initiated'] != null
  ).length;
}

int calculateTotalReviews(List<Map<String, dynamic>> records) {
  int totalReviews = 0;
  for (var record in records) {
    if (record['details']['completion_counts'] != null) {
      totalReviews += (record['details']['completion_counts'] as int);
    }
  }
  return totalReviews;
}

int calculateMissedReviews(List<Map<String, dynamic>> records) {
  int missedReviewsCount = 0;

  for (var record in records) {
    if (record.containsKey('details') && record['details'] is Map) {
      var details = record['details'] as Map;
      if (details.containsKey('missed_counts') && details['missed_counts'] > 0) {
        missedReviewsCount++;
      }
    }
  }

  return missedReviewsCount;
}

Color getCompletionColor(double percentage) {
  if (percentage <= 50) {
    return Color.lerp(const Color(0xFFC40000), const Color(0xFFFFEB3B), percentage / 50)!; // Red to Yellow
  } else {
    return Color.lerp(const Color(0xFFFFEB3B), const Color(0xFF00C853), (percentage - 50) / 50)!; // Yellow to Green
  }
}

double calculatePercentageCompletion(List<Map<String, dynamic>> records) {
  int completedLectures = records.where((record) =>
  record['details']['date_initiated'] != null
  ).length;
  int totalLectures = 322;
  double percentageCompletion = totalLectures > 0
      ? (completedLectures / totalLectures) * 100
      : 0;
  return percentageCompletion;
}

Map<String, int> calculateSubjectDistribution(List<Map<String, dynamic>> records) {
  Map<String, int> subjectCounts = {};

  for (var record in records) {
    String category = record['category'];
    subjectCounts[category] = (subjectCounts[category] ?? 0) + 1;
  }

  return subjectCounts;
}