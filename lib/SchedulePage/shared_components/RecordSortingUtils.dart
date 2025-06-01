/// Utility class containing common sorting logic for schedule tables
class RecordSortingUtils {
  /// Sorts a list of records based on the specified field and direction
  static List<Map<String, dynamic>> sortRecords({
    required List<Map<String, dynamic>> records,
    required String field,
    required bool ascending,
  }) {
    final List<Map<String, dynamic>> sortedRecords = List.from(records);

    sortedRecords.sort((a, b) {
      switch (field) {
        case 'date_initiated':
          final String? aDate = a['date_initiated'] as String?;
          final String? bDate = b['date_initiated'] as String?;

          // Handle null dates (null comes first in ascending, last in descending)
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return ascending ? -1 : 1;
          if (bDate == null) return ascending ? 1 : -1;

          // Compare dates
          return ascending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);

        case 'date_updated':
          final List<String> aRevised = List<String>.from(a['dates_updated'] ?? []);
          final List<String> bRevised = List<String>.from(b['dates_updated'] ?? []);

          // Get the most recent revision date
          String? aLatest = aRevised.isNotEmpty
              ? aRevised.reduce((curr, next) => curr.compareTo(next) > 0 ? curr : next)
              : null;
          String? bLatest = bRevised.isNotEmpty
              ? bRevised.reduce((curr, next) => curr.compareTo(next) > 0 ? curr : next)
              : null;

          // Handle null dates
          if (aLatest == null && bLatest == null) return 0;
          if (aLatest == null) return ascending ? -1 : 1;
          if (bLatest == null) return ascending ? 1 : -1;

          return ascending ? aLatest.compareTo(bLatest) : bLatest.compareTo(aLatest);

        case 'missed_counts':
          final int aMissed = a['missed_counts'] as int? ?? 0;
          final int bMissed = b['missed_counts'] as int? ?? 0;

          return ascending ? aMissed.compareTo(bMissed) : bMissed.compareTo(aMissed);

        case 'completion_counts':
          final int aRevisions = a['completion_counts'] as int? ?? 0;
          final int bRevisions = b['completion_counts'] as int? ?? 0;

          return ascending ? aRevisions.compareTo(bRevisions) : bRevisions.compareTo(aRevisions);

        case 'reminder_time':
          final String aTime = a['reminder_time'] as String? ?? '';
          final String bTime = b['reminder_time'] as String? ?? '';

          // Special handling for "All Day" - treat it as highest time in ascending order
          if (aTime == 'All Day' && bTime == 'All Day') return 0;
          if (aTime == 'All Day') return ascending ? 1 : -1;
          if (bTime == 'All Day') return ascending ? -1 : 1;

          return ascending ? aTime.compareTo(bTime) : bTime.compareTo(aTime);

        case 'recurrence_frequency':
          // Map priority levels to numeric values for sorting
          const Map<String, int> priorityValues = {
            'High Priority': 3,
            'Medium Priority': 2,
            'Low Priority': 1,
            'Default': 0,
            '': 0, // For empty values
          };

          final int aValue = priorityValues[a['recurrence_frequency'] ?? ''] ?? 0;
          final int bValue = priorityValues[b['recurrence_frequency'] ?? ''] ?? 0;

          return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);

        default:
          return 0;
      }
    });

    return sortedRecords;
  }

  /// Gets the display name for a sort field
  static String getSortFieldDisplayName(String field) {
    switch (field) {
      case 'reminder_time': return 'Reminder Time';
      case 'date_initiated': return 'Date Initiated';
      case 'date_updated': return 'Date Reviewed';
      case 'missed_counts': return 'Overdue Reviews';
      case 'completion_counts': return 'Number of Reviews';
      case 'recurrence_frequency': return 'Review Frequency';
      default: return field;
    }
  }
}
