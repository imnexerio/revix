import 'package:flutter/material.dart';
import 'RevisionGraph.dart'; // Import the RevisionGraph widget

class ScheduleTable extends StatefulWidget {
  final List<Map<String, dynamic>> initialRecords;
  final String title;
  final Function(BuildContext, Map<String, dynamic>) onSelect;

  const ScheduleTable({
    Key? key,
    required this.initialRecords,
    required this.title,
    required this.onSelect,
  }) : super(key: key);

  @override
  _ScheduleTableState createState() => _ScheduleTableState();
}

class _ScheduleTableState extends State<ScheduleTable> {
  late List<Map<String, dynamic>> records;
  String? currentSortField;
  bool isAscending = true;
  final GlobalKey _gridKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    records = List.from(widget.initialRecords);
  }

  @override
  void didUpdateWidget(ScheduleTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRecords != oldWidget.initialRecords) {
      setState(() {
        records = List.from(widget.initialRecords);
        // Reapply sorting if we had a sort field
        if (currentSortField != null) {
          _applySorting(currentSortField!, isAscending);
        }
      });
    }
  }

  void _applySorting(String field, bool ascending) {
    setState(() {
      currentSortField = field;
      isAscending = ascending;

      records.sort((a, b) {
        switch (field) {
          case 'date_learnt':
            final String? aDate = a['date_learnt'] as String?;
            final String? bDate = b['date_learnt'] as String?;

            // Handle null dates (null comes first in ascending, last in descending)
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return ascending ? -1 : 1;
            if (bDate == null) return ascending ? 1 : -1;

            // Compare dates
            return ascending
                ? aDate.compareTo(bDate)
                : bDate.compareTo(aDate);

          case 'date_revised':
            final List<String> aRevised = List<String>.from(a['dates_revised'] ?? []);
            final List<String> bRevised = List<String>.from(b['dates_revised'] ?? []);

            // Get the most recent revision date
            String? aLatest = aRevised.isNotEmpty ? aRevised.reduce((curr, next) => curr.compareTo(next) > 0 ? curr : next) : null;
            String? bLatest = bRevised.isNotEmpty ? bRevised.reduce((curr, next) => curr.compareTo(next) > 0 ? curr : next) : null;

            // Handle null dates
            if (aLatest == null && bLatest == null) return 0;
            if (aLatest == null) return ascending ? -1 : 1;
            if (bLatest == null) return ascending ? 1 : -1;

            return ascending
                ? aLatest.compareTo(bLatest)
                : bLatest.compareTo(aLatest);

          case 'missed_revision':
            final int aMissed = a['missed_revision'] as int? ?? 0;
            final int bMissed = b['missed_revision'] as int? ?? 0;

            return ascending
                ? aMissed.compareTo(bMissed)
                : bMissed.compareTo(aMissed);

          case 'no_revision':
            final int aRevisions = a['no_revision'] as int? ?? 0;
            final int bRevisions = b['no_revision'] as int? ?? 0;

            return ascending
                ? aRevisions.compareTo(bRevisions)
                : bRevisions.compareTo(aRevisions);

          case 'revision_frequency':
          // Map priority levels to numeric values for sorting
            final Map<String, int> priorityValues = {
              'High Priority': 3,
              'Medium Priority': 2,
              'Low Priority': 1,
              '': 0, // For empty values
            };

            final int aValue = priorityValues[a['revision_frequency'] ?? ''] ?? 0;
            final int bValue = priorityValues[b['revision_frequency'] ?? ''] ?? 0;

            return ascending
                ? aValue.compareTo(bValue)
                : bValue.compareTo(aValue);

          default:
            return 0;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildFilterButton(context),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Responsive grid of cards
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 400, // Maximum width of each card
            childAspectRatio: MediaQuery.of(context).size.width > 600 ? 3 : 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 170, // Increased height slightly for better layout
          ),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final bool isCompleted = record['date_learnt'] != null &&
                record['date_learnt'].toString().isNotEmpty;

            return _buildClassCard(context, record, isCompleted);
          },
        ),
      ],
    );
  }

  Widget _buildFilterButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.filter_list, size: 16),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => buildShortingSheet(context),
        );
      },
    );
  }

  Widget buildShortingSheet(BuildContext context) {
    // State for tracking the selected sort field
    final ValueNotifier<String?> selectedField = ValueNotifier<String?>(currentSortField);

    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle indicator
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
                margin: const EdgeInsets.only(bottom: 16),
              ),

              // Title
              Text(
                'Sort by',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Sort field selection boxes
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSortFieldBox(
                    context,
                    'Date Learnt',
                    'date_learnt',
                    selectedField,
                        () => setState(() {}),
                  ),
                  _buildSortFieldBox(
                    context,
                    'Date Revised',
                    'date_revised',
                    selectedField,
                        () => setState(() {}),
                  ),
                  _buildSortFieldBox(
                    context,
                    'Missed Revisions',
                    'missed_revision',
                    selectedField,
                        () => setState(() {}),
                  ),
                  _buildSortFieldBox(
                    context,
                    'Number of Revisions',
                    'no_revision',
                    selectedField,
                        () => setState(() {}),
                  ),
                  _buildSortFieldBox(
                    context,
                    'Revision Frequency',
                    'revision_frequency',
                    selectedField,
                        () => setState(() {}),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Order selection (only visible when a field is selected)
              if (selectedField.value != null)
                Column(
                  children: [
                    const Text('Order'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildOrderBox(
                            context,
                            'Ascending',
                            Icons.arrow_upward,
                            true,
                            selectedField.value!,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildOrderBox(
                            context,
                            'Descending',
                            Icons.arrow_downward,
                            false,
                            selectedField.value!,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortFieldBox(
      BuildContext context,
      String label,
      String field,
      ValueNotifier<String?> selectedField,
      VoidCallback onSelected,
      ) {
    final bool isSelected = selectedField.value == field;

    return GestureDetector(
      onTap: () {
        selectedField.value = field;
        onSelected();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderBox(
      BuildContext context,
      String label,
      IconData icon,
      bool ascending,
      String field,
      ) {
    return GestureDetector(
      onTap: () {
        _applySorting(field, ascending);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassCard(BuildContext context, Map<String, dynamic> record, bool isCompleted) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onSelect(context, record),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left side with subject information
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      record['subject'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record['lecture_type']} ${record['lecture_no']} · ${record['subject_code']}',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildDateInfo(
                          context,
                          'Scheduled',
                          record['date_scheduled'] ?? '',
                          Icons.calendar_today,
                        ),
                        if (isCompleted)
                          _buildDateInfo(
                            context,
                            'Completed',
                            record['date_learnt'] ?? '',
                            Icons.check_circle_outline,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Right side with the revision graph
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 90,
                  child: Center(
                    // Add a key to force rebuild of RevisionRadarChart when data changes
                    child: RevisionRadarChart(
                      key: ValueKey('chart_${record['subject']}_${record['lecture_no']}'),
                      dateLearnt: record['date_learnt'],
                      datesMissedRevisions: List<String>.from(record['dates_missed_revisions'] ?? []),
                      datesRevised: List<String>.from(record['dates_revised'] ?? []),
                      showLabels: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateInfo(BuildContext context, String label, String date, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
            Text(
              date,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }
}
