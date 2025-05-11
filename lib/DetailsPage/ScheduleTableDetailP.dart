import 'package:flutter/material.dart';
import 'AnimatedCardDetailP.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduleTableDetailP extends StatefulWidget {
  final List<Map<String, dynamic>> initialRecords;
  final String title;
  final Function(BuildContext, Map<String, dynamic>) onSelect;

  const ScheduleTableDetailP({
    Key? key,
    required this.initialRecords,
    required this.title,
    required this.onSelect,
  }) : super(key: key);

  @override
  _ScheduleTableState createState() => _ScheduleTableState();
}

class _ScheduleTableState extends State<ScheduleTableDetailP> with SingleTickerProviderStateMixin {
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

    // Set default values initially
    currentSortField = 'reminder_time';
    isAscending = true;

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Start the animation immediately to show cards properly
    _animationController.value = 1.0;

    // Load saved sorting preferences and apply sorting
    _loadSortPreferences();
  }

  // Load sorting preferences from SharedPreferences
  Future<void> _loadSortPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentSortField = prefs.getString('sortField') ?? 'reminder_time';
      isAscending = prefs.getBool('isAscending') ?? true;
    });

    // Apply the loaded sorting after the UI is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applySorting(currentSortField!, isAscending);
    });
  }

  // Save sorting preferences to SharedPreferences
  Future<void> _saveSortPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sortField', currentSortField ?? 'reminder_time');
    await prefs.setBool('isAscending', isAscending);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _sortedRecordsCache.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(ScheduleTableDetailP oldWidget) {
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

      // Save the preferences
      _saveSortPreferences();

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

        case 'reminder_time':
          final String aTime = a['reminder_time'] as String? ?? '';
          final String bTime = b['reminder_time'] as String? ?? '';

          // Special handling for "All Day" - treat it as highest time in ascending order
          if (aTime == 'All Day' && bTime == 'All Day') return 0;
          if (aTime == 'All Day') return ascending ? 1 : -1;
          if (bTime == 'All Day') return ascending ? -1 : 1;

          return ascending
              ? aTime.compareTo(bTime)
              : bTime.compareTo(aTime);

        case 'revision_frequency':
        // Map priority levels to numeric values for sorting
        // Use const map as static to avoid recreation
          const Map<String, int> priorityValues = {
            'High Priority': 3,
            'Medium Priority': 2,
            'Low Priority': 1,
            'Default': 0,
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

    // Save the preferences
    _saveSortPreferences();

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

  // Get the display name for the current sort field
  String get currentSortFieldDisplayName {
    switch (currentSortField) {
      case 'reminder_time': return 'Reminder Time';
      case 'date_learnt': return 'Date Initiated';
      case 'date_revised': return 'Date Reviewed';
      case 'missed_revision': return 'Overdue Reviews';
      case 'no_revision': return 'Number of Reviews';
      case 'revision_frequency': return 'Review Frequency';
      default: return 'Unsorted';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
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
                Row(
                  children: [
                    // Display the current sort field and direction
                    if (currentSortField != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    const SizedBox(width: 8),
                    _buildFilterButton(),
                  ],
                ),
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

                      return AnimatedCardDetailP(
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
      ),
    );
  }

  Widget _buildFilterButton() {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => _buildSortingSheet(),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '($currentSortFieldDisplayName ${isAscending ? '↑' : '↓'})',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.filter_list, size: 16),
          ],
        ),
      ),
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
  final bool isSelected;
  final VoidCallback onTap;

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