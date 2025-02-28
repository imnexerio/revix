// lib/calculation_utils.dart
import 'package:flutter/material.dart';

int calculateTotalLectures(List<Map<String, dynamic>> records) {
  return records.where((record) => record['details']['date_learnt'] != null).length;
}

int calculateTotalRevisions(List<Map<String, dynamic>> records) {
  int totalRevisions = 0;
  for (var record in records) {
    if (record['details']['no_revision'] != null) {
      totalRevisions += (record['details']['no_revision'] as int);
    }
  }
  return totalRevisions;
}

int calculateMissedRevisions(List<Map<String, dynamic>> records) {
  int missedRevisionsCount = 0;

  for (var record in records) {
    if (record.containsKey('details') && record['details'] is Map) {
      var details = record['details'] as Map;
      if (details.containsKey('missed_revision') && details['missed_revision'] > 0) {
        missedRevisionsCount++;
      }
    }
  }

  return missedRevisionsCount;
}

Color getCompletionColor(double percentage) {
  if (percentage <= 50) {
    return Color.lerp(Color(0xFFC40000), Color(0xFFFFEB3B), percentage / 50)!; // Red to Yellow
  } else {
    return Color.lerp(Color(0xFFFFEB3B), Color(0xFF00C853), (percentage - 50) / 50)!; // Yellow to Green
  }
}

double calculatePercentageCompletion(List<Map<String, dynamic>> records) {
  int completedLectures = records.where((record) => record['details']['date_learnt'] != null && record['details']['lecture_type'] == 'Lectures').length;
  int totalLectures = 322;
  double percentageCompletion = (completedLectures / totalLectures) * 100;
  return percentageCompletion;
}

Map<String, int> calculateSubjectDistribution(List<Map<String, dynamic>> records) {
  Map<String, int> subjectCounts = {};

  for (var record in records) {
    String subject = record['subject'];
    subjectCounts[subject] = (subjectCounts[subject] ?? 0) + 1;
  }

  return subjectCounts;
}