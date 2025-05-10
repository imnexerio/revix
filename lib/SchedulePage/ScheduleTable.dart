import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    // Load state from SharedPreferences
    _loadPersistedState();
  }

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create a unique key for this particular table based on its title
      final String tableKey = 'schedule_table_${widget.title.replaceAll(RegExp(r'[^\w]'), '_')}';

      setState(() {
        // Load sort field (default to 'reminder_time' if not found)
        currentSortField = prefs.getString('${tableKey}_sort_field') ?? 'reminder_time';

        // Load sort direction (default to true/ascending if not found)
        isAscending = prefs.getBool('${tableKey}_is_ascending') ?? true;

        // Load expansion state (use widget.initiallyExpanded as fallback)
        isExpanded = prefs.getBool('${tableKey}_is_expanded') ?? widget.initiallyExpanded;

        // Set initial animation state based on loaded expansion state
        if (isExpanded) {
          _animationController.value = 1.0;
        } else {
          _animationController.value = 0.0;
        }
      });

      // Apply default sorting after loading state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applySorting(currentSortField!, isAscending);
      });
    } catch (e) {
      // Fallback to defaults if there's an error loading preferences
      setState(() {
        currentSortField = 'reminder_time';
        isAscending = true;
        isExpanded = widget.initiallyExpanded;

        // Set initial animation state
        if (isExpanded) {
          _animationController.value = 1.0;
        } else {
          _animationController.value = 0.0;
        }
      });

      // Apply default sorting after initialization
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applySorting(currentSortField!, isAscending);
      });
    }
  }

  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create a unique key for this particular table based on its title
      final String tableKey = 'schedule_table_${widget.title.replaceAll(RegExp(r'[^\w]'), '_')}';

      // Save sort field
      await prefs.setString('${tableKey}_sort_field', currentSortField ?? 'reminder_time');

      // Save sort direction
      await prefs.setBool('${tableKey}_is_ascending', isAscending);

      // Save expansion state
      await prefs.setBool('${tableKey}_is_expanded', isExpanded);
    } catch (e) {
      // Silently fail if we can't persist state
      debugPrint('Error persisting ScheduleTable state: $e');
    }
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

        // Persist the state whenever sorting changes
        _persistState();
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

      // Persist the expansion state
      _persistState();
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

  // Get readable name for the sort field
  String _getSortFieldName(String field) {
    switch (field) {
      case 'reminder_time': return 'Reminder Time';
      case 'date_learnt': return 'Date Initiated';
      case 'date_revised': return 'Date Reviewed';
      case 'missed_revision': return 'Overdue Reviews';
      case 'no_revision': return 'Number of Reviews';
      case 'revision_frequency': return 'Review Frequency';
      default: return field;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with expand/collapse control and sorting info
        InkWell(
          onTap: _toggleExpanded,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Show current sort info
                      if (currentSortField != null && isExpanded)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              '(${_getSortFieldName(currentSortField!)} ${isAscending ? '↑' : '↓'})',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
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
                          // Apply sorting immediately with current direction
                          _applySorting(selectedField, isAscending);
                          Navigator.pop(context);
                        },
                      ),
                      _SortFieldBox(
                        label: 'Date Initiated',
                        field: 'date_learnt',
                        isSelected: selectedField == 'date_learnt',
                        onTap: () {
                          setState(() => selectedField = 'date_learnt');
                          // Apply sorting immediately with current direction
                          _applySorting(selectedField, isAscending);
                          Navigator.pop(context);
                        },
                      ),
                      _SortFieldBox(
                        label: 'Date Reviewed',
                        field: 'date_revised',
                        isSelected: selectedField == 'date_revised',
                        onTap: () {
                          setState(() => selectedField = 'date_revised');
                          // Apply sorting immediately with current direction
                          _applySorting(selectedField, isAscending);
                          Navigator.pop(context);
                        },
                      ),
                      _SortFieldBox(
                        label: 'Overdue Reviews',
                        field: 'missed_revision',
                        isSelected: selectedField == 'missed_revision',
                        onTap: () {
                          setState(() => selectedField = 'missed_revision');
                          // Apply sorting immediately with current direction
                          _applySorting(selectedField, isAscending);
                          Navigator.pop(context);
                        },
                      ),
                      _SortFieldBox(
                        label: 'Number of Reviews',
                        field: 'no_revision',
                        isSelected: selectedField == 'no_revision',
                        onTap: () {
                          setState(() => selectedField = 'no_revision');
                          // Apply sorting immediately with current direction
                          _applySorting(selectedField, isAscending);
                          Navigator.pop(context);
                        },
                      ),
                      _SortFieldBox(
                        label: 'Review Frequency',
                        field: 'revision_frequency',
                        isSelected: selectedField == 'revision_frequency',
                        onTap: () {
                          setState(() => selectedField = 'revision_frequency');
                          // Apply sorting immediately with current direction
                          _applySorting(selectedField, isAscending);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Order selection - showing current order
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
                              isSelected: isAscending,
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
                              isSelected: !isAscending,
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
  final bool isSelected;

  const _OrderBox({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            width: isSelected ? 1.5 : 1.0,
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
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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