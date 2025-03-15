import 'package:flutter/material.dart';

void applySorting({
  required List<Map<String, dynamic>> records,
  required String field,
  required bool ascending,
  required AnimationController animationController,
  required Function(List<Map<String, dynamic>>) onSorted,
  required Map<String, List<Map<String, dynamic>>> sortedRecordsCache,
  required String? currentSortField,
  required bool isAscending,
}) {
  // Check if we already have sorted records in cache
  final String cacheKey = '${field}_${ascending ? 'asc' : 'desc'}';
  if (sortedRecordsCache.containsKey(cacheKey)) {
    onSorted(sortedRecordsCache[cacheKey]!);
    animationController.reset();
    animationController.forward();
    return;
  }

  // Reset animation controller
  animationController.reset();

  // Create a copy of records to sort
  final List<Map<String, dynamic>> sortedRecords = List.from(records);

  // Sort the copy
  sortedRecords.sort((a, b) {
    switch (field) {
      case 'date_learnt':
        final String? aDate = a['date_learnt'] as String?;
        final String? bDate = b['date_learnt'] as String?;

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return ascending ? -1 : 1;
        if (bDate == null) return ascending ? 1 : -1;

        return ascending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);

      case 'date_revised':
        final List<String> aRevised = List<String>.from(a['dates_revised'] ?? []);
        final List<String> bRevised = List<String>.from(b['dates_revised'] ?? []);

        String? aLatest = aRevised.isNotEmpty
            ? aRevised.reduce((curr, next) => curr.compareTo(next) > 0 ? curr : next)
            : null;
        String? bLatest = bRevised.isNotEmpty
            ? bRevised.reduce((curr, next) => curr.compareTo(next) > 0 ? curr : next)
            : null;

        if (aLatest == null && bLatest == null) return 0;
        if (aLatest == null) return ascending ? -1 : 1;
        if (bLatest == null) return ascending ? 1 : -1;

        return ascending ? aLatest.compareTo(bLatest) : bLatest.compareTo(aLatest);

      case 'missed_revision':
        final int aMissed = a['missed_revision'] as int? ?? 0;
        final int bMissed = b['missed_revision'] as int? ?? 0;

        return ascending ? aMissed.compareTo(bMissed) : bMissed.compareTo(aMissed);

      case 'no_revision':
        final int aRevisions = a['no_revision'] as int? ?? 0;
        final int bRevisions = b['no_revision'] as int? ?? 0;

        return ascending ? aRevisions.compareTo(bRevisions) : bRevisions.compareTo(aRevisions);

      case 'reminder_time':
        final String aTime = a['reminder_time'] as String? ?? '';
        final String bTime = b['reminder_time'] as String? ?? '';

        if (aTime == 'All Day' && bTime == 'All Day') return 0;
        if (aTime == 'All Day') return ascending ? 1 : -1;
        if (bTime == 'All Day') return ascending ? -1 : 1;

        return ascending ? aTime.compareTo(bTime) : bTime.compareTo(aTime);

      case 'revision_frequency':
        const Map<String, int> priorityValues = {
          'High Priority': 3,
          'Medium Priority': 2,
          'Low Priority': 1,
          'Default': 0,
          '': 0,
        };

        final int aValue = priorityValues[a['revision_frequency'] ?? ''] ?? 0;
        final int bValue = priorityValues[b['revision_frequency'] ?? ''] ?? 0;

        return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);

      default:
        return 0;
    }
  });

  // Store sorted list in cache
  sortedRecordsCache[cacheKey] = sortedRecords;

  onSorted(sortedRecords);
  animationController.forward();
}