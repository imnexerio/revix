import 'package:flutter/material.dart';
import 'AnimatedCardDetailP.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../SchedulePage/shared_components/FilterButton.dart';
import '../SchedulePage/shared_components/SortingBottomSheet.dart';
import '../SchedulePage/shared_components/RecordSortingUtils.dart';
import '../SchedulePage/shared_components/GridLayoutUtils.dart';

class ScheduleTableDetailP extends StatefulWidget {
  final List<Map<String, dynamic>> initialRecords;
  final String title;
  final Function(BuildContext, Map<String, dynamic>) onSelect;
  final String? category;
  final String? subCategory;

  const ScheduleTableDetailP({
    Key? key,
    required this.initialRecords,
    required this.title,
    required this.onSelect,
    this.category,
    this.subCategory,
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
    _animationController.reset();    // Use shared sorting utility
    final List<Map<String, dynamic>> sortedRecords = RecordSortingUtils.sortRecords(
      records: List.from(records),
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
    _cachedColumnCount = GridLayoutUtils.calculateColumns(width);
    return _cachedColumnCount!;
  }
  // Get the display name for the current sort field
  String get currentSortFieldDisplayName {
    return RecordSortingUtils.getSortFieldDisplayName(currentSortField ?? 'reminder_time');
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
                Flexible(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Row(
                  children: [                    FilterButton(
                      currentSortField: currentSortField ?? 'reminder_time',
                      isAscending: isAscending,
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),                          builder: (context) => SortingBottomSheet(
                            currentSortField: currentSortField ?? 'reminder_time',
                            isAscending: isAscending,
                            onSortApplied: _applySorting,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
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

                      return AnimatedCardDetailP(
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
              );
            },
          ),
        ],
      ),
    );
  }
}