import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'AnimatedCard.dart';
import 'RecordSortingUtils.dart';
import 'SortingBottomSheet.dart';
import 'FilterButton.dart';
import 'GridLayoutUtils.dart';

class ScheduleTable extends StatefulWidget {
  final List<Map<String, dynamic>> initialRecords;
  final String title;
  final String tableId;
  final Function(BuildContext, Map<String, dynamic>) onSelect;
  final bool initiallyExpanded;
  final String? category;
  final String? subCategory;

  const ScheduleTable({
    Key? key,
    required this.initialRecords,
    required this.title,
    required this.tableId,
    required this.onSelect,
    this.initiallyExpanded = true,
    this.category,
    this.subCategory,
  }) : super(key: key);

  @override
  _ScheduleTableState createState() => _ScheduleTableState();
}

class _ScheduleTableState extends State<ScheduleTable>
    with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> records;
  String? currentSortField;
  bool isAscending = true;
  bool isExpanded = true;
  bool _prefsLoaded = false;

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

      // Create a unique key using the static tableId
      final String tableKey = 'schedule_table_${widget.tableId}';

      // Load sort field (default to 'reminder_time' if not found)
      final loadedSortField = prefs.getString('${tableKey}_sort_field') ?? 'reminder_time';

      // Load sort direction (default to true/ascending if not found)
      final loadedAscending = prefs.getBool('${tableKey}_is_ascending') ?? true;

      // Load expansion state (use widget.initiallyExpanded as fallback)
      final loadedExpanded = prefs.getBool('${tableKey}_is_expanded') ?? widget.initiallyExpanded;

      // Update state with loaded values
      setState(() {
        currentSortField = loadedSortField;
        isAscending = loadedAscending;
        isExpanded = loadedExpanded;
        _prefsLoaded = true;
      });

      // Set animation controller based on expansion state
      if (isExpanded) {
        _animationController.value = 1.0;
      } else {
        _animationController.value = 0.0;
      }

      // Apply sorting after loading state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isExpanded) {
          _applyRefreshSorting(currentSortField!, isAscending);
        }
      });
    } catch (e) {
      // Fallback to defaults if there's an error loading preferences
      setState(() {
        currentSortField = 'reminder_time';
        isAscending = true;
        isExpanded = widget.initiallyExpanded;
        _prefsLoaded = true;
      });

      // Set initial animation state
      if (isExpanded) {
        _animationController.value = 1.0;
      } else {
        _animationController.value = 0.0;
      }

      // Apply default sorting after initialization
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isExpanded) {
          _applyRefreshSorting(currentSortField!, isAscending);
        }
      });
    }
  }

  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create a unique key using the static tableId
      final String tableKey = 'schedule_table_${widget.tableId}';

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
        if (currentSortField != null && _prefsLoaded) {
          _applyRefreshSorting(currentSortField!, isAscending);
        }
      });
    }
  }

  // Method for refreshing without animation reset
  void _applyRefreshSorting(String field, bool ascending) {
    final sortedRecords = RecordSortingUtils.sortRecords(
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
    // Check if we already have sorted records in cache
    final String cacheKey = '${field}_${ascending ? 'asc' : 'desc'}';
    if (_sortedRecordsCache.containsKey(cacheKey)) {
      setState(() {
        currentSortField = field;
        isAscending = ascending;
        records = _sortedRecordsCache[cacheKey]!;
      });

      // Persist the state
      _persistState();

      _animationController.reset();
      _animationController.forward();
      return;
    }

    // Reset animation controller
    _animationController.reset();

    // Sort the records using the shared utility
    final sortedRecords = RecordSortingUtils.sortRecords(
      records: records,
      field: field,
      ascending: ascending,
    );

    // Store sorted list in cache
    _sortedRecordsCache[cacheKey] = sortedRecords;

    setState(() {
      currentSortField = field;
      isAscending = ascending;
      records = sortedRecords;
    });

    // Persist the state
    _persistState();

    _animationController.forward();
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
    _cachedColumnCount = GridLayoutUtils.calculateColumns(width);
    return _cachedColumnCount!;
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      // Show a placeholder while preferences are loading
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ),
      );
    }

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
                // Wrap the title in Flexible with overflow handling
                Flexible(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Separate row for filter and expand icons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isExpanded)
                      FilterButton(
                        currentSortField: currentSortField,
                        isAscending: isAscending,
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (context) => SortingBottomSheet(
                              currentSortField: currentSortField,
                              isAscending: isAscending,
                              onSortApplied: _applySorting,
                            ),
                          );
                        },
                      ),
                    const SizedBox(width: 4),
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
                      final bool isCompleted = record['date_initiated'] != null &&
                          record['date_initiated'].toString().isNotEmpty;

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
                        category: widget.category,
                        subCategory: widget.subCategory,
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
}
