import 'package:flutter/material.dart';
import 'AnimatedCard.dart';

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

  // Cache for sorted records to avoid unnecessary re-sorts
  final Map<String, List<Map<String, dynamic>>> _sortedRecordsCache = {};

  // Add animation controller
  late AnimationController _animationController;

  // Memoized column count
  int? _cachedColumnCount;
  double? _previousWidth;

  @override
  void initState() {
    super.initState();
    records = List.from(widget.initialRecords);
    // print(records);

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Start the animation immediately to show cards properly
    _animationController.value = 1.0;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _sortedRecordsCache.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(ScheduleTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRecords != oldWidget.initialRecords) {
      setState(() {
        records = List.from(widget.initialRecords);
        // Clear the cache when records change
        _sortedRecordsCache.clear();

        // Reapply sorting if we had a sort field
        if (currentSortField != null) {
          _applySorting(currentSortField!, isAscending);
        } else {
          // Ensure animation is completed if not sorting
          _animationController.value = 1.0;
        }
      });
    }
  }

  void _applySorting(String field, bool ascending) {
    // Check if we already have sorted records in cache
    final String cacheKey = '${field}_${ascending ? 'asc' : 'desc'}';
    if (_sortedRecordsCache.containsKey(cacheKey)) {
      setState(() {
        currentSortField = field;
        isAscending = ascending;
        records = _sortedRecordsCache[cacheKey]!;
      });

      // Animate cards
      _animationController.reset();
      _animationController.forward();
      return;
    }

    // Reset animation controller
    _animationController.reset();

    // Create a copy of records to sort
    final List<Map<String, dynamic>> sortedRecords = List.from(records);

    // Sort the copy
    sortedRecords.sort((a, b) {
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

          // Get the most recent revision date - optimize with null-aware operator
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
        // Use const map as static to avoid recreation
          const Map<String, int> priorityValues = {
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

    // Store sorted list in cache
    _sortedRecordsCache[cacheKey] = sortedRecords;

    setState(() {
      currentSortField = field;
      isAscending = ascending;
      records = sortedRecords;
    });

    // Start animation after sorting
    _animationController.forward();
  }

  int _calculateColumns(double width) {
    // Use cached value if width hasn't changed
    if (_previousWidth == width && _cachedColumnCount != null) {
      return _cachedColumnCount!;
    }

    _previousWidth = width;

    int columns;
    if (width < 500) columns = 1;         // Mobile
    else if (width < 900) columns = 2;    // Tablet
    else if (width < 1200) columns = 3;   // Small desktop
    else if (width < 1500) columns = 4;   // Medium desktop
    else columns = 5;                     // Large desktop

    _cachedColumnCount = columns;
    return columns;
  }

  @override
  Widget build(BuildContext context) {
    // print('ScheduleTable received ${records.length} records for $records');
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
              _buildFilterButton(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Animated grid for the cards
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = _calculateColumns(constraints.maxWidth);

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: MediaQuery.of(context).size.width > 300 ? 3 : 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    mainAxisExtent: 160,
                  ),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final bool isCompleted = record['date_learnt'] != null &&
                        record['date_learnt'].toString().isNotEmpty;

                    final Animation<double> animation = Tween<double>(
                      begin: 0.0,
                      end: 1.0,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(
                          (index / records.length) * 0.5,
                          (index / records.length) * 0.5 + 0.5,
                          curve: Curves.easeInOut,
                        ),
                      ),
                    );

                    // print(record);

                    return AnimatedCard(
                      animation: animation,
                      record: record,
                      isCompleted: isCompleted,
                      onSelect: widget.onSelect,
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilterButton() {
    return IconButton(
      icon: const Icon(Icons.filter_list, size: 16),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => _buildSortingSheet(),
        );
      },
    );
  }

  Widget _buildSortingSheet() {
    // Create a single source of truth for the selected field
    return StatefulBuilder(
      builder: (context, setState) {
        // Properly initialize with the current sort field
        String selectedField = currentSortField ?? 'no_revision';

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 400, // Set height to 60% of screen height
            child: SingleChildScrollView(
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
                      // Use local function to create sort field boxes
                      _SortFieldBox(
                        label: 'Date Learnt',
                        field: 'date_learnt',
                        isSelected: selectedField == 'date_learnt',
                        onTap: () => setState(() => selectedField = 'date_learnt'),
                      ),
                      _SortFieldBox(
                        label: 'Date Revised',
                        field: 'date_revised',
                        isSelected: selectedField == 'date_revised',
                        onTap: () => setState(() => selectedField = 'date_revised'),
                      ),
                      _SortFieldBox(
                        label: 'Missed Revisions',
                        field: 'missed_revision',
                        isSelected: selectedField == 'missed_revision',
                        onTap: () => setState(() => selectedField = 'missed_revision'),
                      ),
                      _SortFieldBox(
                        label: 'Number of Revisions',
                        field: 'no_revision',
                        isSelected: selectedField == 'no_revision',
                        onTap: () => setState(() => selectedField = 'no_revision'),
                      ),
                      _SortFieldBox(
                        label: 'Revision Frequency',
                        field: 'revision_frequency',
                        isSelected: selectedField == 'revision_frequency',
                        onTap: () => setState(() => selectedField = 'revision_frequency'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Order selection (always visible)
                  Column(
                    children: [
                      const Text('Order'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _OrderBox(
                              label: 'Ascending',
                              icon: Icons.arrow_upward,
                              onTap: () {
                                _applySorting(selectedField, true);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: _OrderBox(
                              label: 'Descending',
                              icon: Icons.arrow_downward,
                              onTap: () {
                                _applySorting(selectedField, false);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SortFieldBox extends StatelessWidget {
  final String label;
  final String field;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortFieldBox({
    required this.label,
    required this.field,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
}

class _OrderBox extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OrderBox({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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