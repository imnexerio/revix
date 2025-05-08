import 'package:flutter/material.dart';

import 'AnimatedCard.dart';

class ScheduleTable extends StatefulWidget {
  final List<Map<String, dynamic>> initialRecords;
  final String title;
  final Function(BuildContext, Map<String, dynamic>) onSelect;
  final bool initiallyExpanded;

  const ScheduleTable({
    Key? key,
    required this.initialRecords,
    required this.title,
    required this.onSelect,
    this.initiallyExpanded = true,
  }) : super(key: key);

  @override
  _ScheduleTable createState() => _ScheduleTable();
}

class _ScheduleTable extends State<ScheduleTable>
    with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> records;
  String? currentSortField;
  bool isAscending = true;
  bool isExpanded = true;

  // Cache for sorted records to avoid unnecessary re-sorts
  final Map<String, List<Map<String, dynamic>>> _sortedRecordsCache = {};

  // Add animation controller
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;

  // Memoized column count
  int? _cachedColumnCount;
  double? _previousWidth;

  @override
  void initState() {
    super.initState();
    records = List.from(widget.initialRecords);
    isExpanded = widget.initiallyExpanded;

    // Set default sort field to reminder_time and ascending order
    currentSortField = 'reminder_time';
    isAscending = true;

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Set initial animation state based on initiallyExpanded
    if (isExpanded) {
      _animationController.value = 1.0;
    } else {
      _animationController.value = 0.0;
    }

    // Apply default sorting after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applySorting(currentSortField!, isAscending);
    });
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
          // Apply sorting without resetting animation
          _applyRefreshSorting(currentSortField!, isAscending);
        }
      });
    }
  }

  // New method for refreshing without animation reset
  void _applyRefreshSorting(String field, bool ascending) {
    // Skip animation reset and directly apply sorting
    final sortedRecords = SortingUtils.sortRecords(
      records: records,
      field: field,
      ascending: ascending,
    );

    setState(() {
      currentSortField = field;
      isAscending = ascending;
      records = sortedRecords;
    });
  }

  void _applySorting(String field, bool ascending) {
    applySorting(
      records: records,
      field: field,
      ascending: ascending,
      animationController: _animationController,
      onSorted: (sortedRecords) {
        setState(() {
          currentSortField = field;
          isAscending = ascending;
          records = sortedRecords;
        });
      },
      sortedRecordsCache: _sortedRecordsCache,
      currentSortField: currentSortField,
      isAscending: isAscending,
    );
  }

  void _toggleExpanded() {
    setState(() {
      isExpanded = !isExpanded;
      if (isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
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
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse control
          InkWell(
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (isExpanded) _buildFilterButton(),
                      RotationTransition(
                        turns: _rotateAnimation,
                        child: const Icon(Icons.expand_more),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Collapsible content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = _calculateColumns(constraints.maxWidth);

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                if (records.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'No records available',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
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
        // Initialize with the current sort field
        String selectedField = currentSortField ?? 'reminder_time';

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 400,
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
                      // Added reminder_time option
                      _SortFieldBox(
                        label: 'Reminder Time',
                        field: 'reminder_time',
                        isSelected: selectedField == 'reminder_time',
                        onTap: () {
                          setState(() => selectedField = 'reminder_time');
                          // Update the state of the parent widget to recognize the sort field change
                          this.setState(() => currentSortField = 'reminder_time');
                        },
                      ),
                      _SortFieldBox(
                        label: 'Date Initiated',
                        field: 'date_learnt',
                        isSelected: selectedField == 'date_learnt',
                        onTap: () {
                          setState(() => selectedField = 'date_learnt');
                          // Update the state of the parent widget to recognize the sort field change
                          this.setState(() => currentSortField = 'date_learnt');
                        },
                      ),
                      _SortFieldBox(
                        label: 'Date Reviewed',
                        field: 'date_revised',
                        isSelected: selectedField == 'date_revised',
                        onTap: () {
                          setState(() => selectedField = 'date_revised');
                          // Update the state of the parent widget to recognize the sort field change
                          this.setState(() => currentSortField = 'date_revised');
                        },
                      ),
                      _SortFieldBox(
                        label: 'Overdue Reviews',
                        field: 'missed_revision',
                        isSelected: selectedField == 'missed_revision',
                        onTap: () {
                          setState(() => selectedField = 'missed_revision');
                          // Update the state of the parent widget to recognize the sort field change
                          this.setState(() => currentSortField = 'missed_revision');
                        },
                      ),
                      _SortFieldBox(
                        label: 'Number of Reviews',
                        field: 'no_revision',
                        isSelected: selectedField == 'no_revision',
                        onTap: () {
                          setState(() => selectedField = 'no_revision');
                          // Update the state of the parent widget to recognize the sort field change
                          this.setState(() => currentSortField = 'no_revision');
                        },
                      ),
                      _SortFieldBox(
                        label: 'Review Frequency',
                        field: 'revision_frequency',
                        isSelected: selectedField == 'revision_frequency',
                        onTap: () {
                          setState(() => selectedField = 'revision_frequency');
                          // Update the state of the parent widget to recognize the sort field change
                          this.setState(() => currentSortField = 'revision_frequency');
                        },
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

// Sorting utility function
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
  // Check if sorting is needed
  if (field == currentSortField && ascending == isAscending) {
    // No change in sorting criteria
    return;
  }

  // Try to get from cache first
  final cacheKey = '$field-$ascending';
  if (sortedRecordsCache.containsKey(cacheKey)) {
    // Reset animation
    animationController.reset();
    // Apply the cached sorted records
    onSorted(sortedRecordsCache[cacheKey]!);
    // Start animation
    animationController.forward();
    return;
  }

  // Sort records
  final sortedRecords = SortingUtils.sortRecords(
    records: records,
    field: field,
    ascending: ascending,
  );

  // Cache the result
  sortedRecordsCache[cacheKey] = sortedRecords;

  // Reset animation
  animationController.reset();
  // Apply the sorted records
  onSorted(sortedRecords);
  // Start animation
  animationController.forward();
}

class SortingUtils {
  // Method to sort records without animation
  static List<Map<String, dynamic>> sortRecords({
    required List<Map<String, dynamic>> records,
    required String field,
    required bool ascending,
  }) {
    final List<Map<String, dynamic>> sortedRecords = List.from(records);

    sortedRecords.sort((a, b) {
      var valueA = a[field];
      var valueB = b[field];

      // Handle null values
      if (valueA == null && valueB == null) return 0;
      if (valueA == null) return ascending ? -1 : 1;
      if (valueB == null) return ascending ? 1 : -1;

      // Handle different types
      if (valueA is num && valueB is num) {
        return ascending ? valueA.compareTo(valueB) : valueB.compareTo(valueA);
      } else if (valueA is String && valueB is String) {
        return ascending ? valueA.compareTo(valueB) : valueB.compareTo(valueA);
      } else {
        // Convert to string for comparison as fallback
        return ascending
            ? valueA.toString().compareTo(valueB.toString())
            : valueB.toString().compareTo(valueA.toString());
      }
    });

    return sortedRecords;
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