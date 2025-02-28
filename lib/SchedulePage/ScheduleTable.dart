import 'package:flutter/material.dart';
import 'AnimatedCard.dart';
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

class _ScheduleTableState extends State<ScheduleTable> with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> records;
  String? currentSortField;
  bool isAscending = true;
  final GlobalKey _gridKey = GlobalKey();

  // Add animation controller
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    records = List.from(widget.initialRecords);

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Start the animation immediately to show cards properly
    _animationController.value = 1.0;  // Add this line
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        } else {
          // Ensure animation is completed if not sorting
          _animationController.value = 1.0;  // Add this line
        }
      });
    }
  }

  void _applySorting(String field, bool ascending) {
    // Reset animation controller
    _animationController.reset();

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

    // Start animation after sorting
    _animationController.forward();
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
        // Animated grid for the cards
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              // In the GridView.builder's gridDelegate
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 700,
                childAspectRatio: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: 135,
              ),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                final bool isCompleted = record['date_learnt'] != null &&
                    record['date_learnt'].toString().isNotEmpty;

                // Animate each card with a staggered effect
                final Animation<double> animation = Tween<double>(
                  begin: 0.0,
                  end: 1.0,
                ).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(
                      (index / records.length) * 0.5, // Stagger the animations
                      (index / records.length) * 0.5 + 0.5,
                      curve: Curves.easeInOut,
                    ),
                  ),
                );

                return AnimatedCard(
                  animation: animation,
                  record: record,
                  isCompleted: isCompleted,
                  onSelect: widget.onSelect,
                );
              },
            );
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        const SizedBox(width: 5),
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
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
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

}

