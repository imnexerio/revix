import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../DetailsPage/AnimatedCardDetailP.dart';
import 'shared_components/RecordSortingUtils.dart';
import 'shared_components/SortingBottomSheet.dart';
import 'shared_components/FilterButton.dart';
import 'shared_components/GridLayoutUtils.dart';

class ScheduleTable extends StatefulWidget {
  final List<Map<String, dynamic>> initialRecords;
  final String title;
  final String tableId;
  final Function(BuildContext, Map<String, dynamic>) onSelect;
  final bool initiallyExpanded;

  const ScheduleTable({
    Key? key,
    required this.initialRecords,
    required this.title,
    required this.tableId,
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
  bool _prefsLoaded = false;
  
  // Multi-filter state
  Set<String> _filterCategories = {};
  Set<String> _filterSubCategories = {};
  Set<String> _filterEntryTypes = {};
  List<String> _availableCategories = [];
  List<String> _availableSubCategories = [];
  List<String> _availableEntryTypes = [];

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
    _updateAvailableCategories();

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
  
  void _updateAvailableCategories() {
    final Set<String> categories = {};
    final Set<String> subCategories = {};
    final Set<String> entryTypes = {};
    for (final record in widget.initialRecords) {
      final category = record['category']?.toString();
      if (category != null && category.isNotEmpty) {
        categories.add(category);
      }
      final subCategory = record['sub_category']?.toString();
      if (subCategory != null && subCategory.isNotEmpty) {
        subCategories.add(subCategory);
      }
      final entryType = record['entry_type']?.toString();
      if (entryType != null && entryType.isNotEmpty) {
        entryTypes.add(entryType);
      }
    }
    _availableCategories = categories.toList()..sort();
    _availableSubCategories = subCategories.toList()..sort();
    _availableEntryTypes = entryTypes.toList()..sort();
  }

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create a unique key using the static tableId (not affected by record count changes)
      final String tableKey = 'schedule_table_${widget.tableId}';

      // Load sort field (default to 'reminder_time' if not found)
      final loadedSortField = prefs.getString('${tableKey}_sort_field') ?? 'reminder_time';

      // Load sort direction (default to true/ascending if not found)
      final loadedAscending = prefs.getBool('${tableKey}_is_ascending') ?? true;

      // Load expansion state (use widget.initiallyExpanded as fallback)
      final loadedExpanded = prefs.getBool('${tableKey}_is_expanded') ?? widget.initiallyExpanded;
      
      // Load filter categories
      final loadedFilters = prefs.getStringList('${tableKey}_filter_categories') ?? [];
      final loadedSubCatFilters = prefs.getStringList('${tableKey}_filter_subcategories') ?? [];
      final loadedEntryTypeFilters = prefs.getStringList('${tableKey}_filter_entrytypes') ?? [];

      // Update state with loaded values
      setState(() {
        currentSortField = loadedSortField;
        isAscending = loadedAscending;
        isExpanded = loadedExpanded;
        _filterCategories = loadedFilters.toSet();
        _filterSubCategories = loadedSubCatFilters.toSet();
        _filterEntryTypes = loadedEntryTypeFilters.toSet();
        _prefsLoaded = true; // Mark that prefs have been loaded
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

      // Create a unique key using the static tableId (not affected by record count changes)
      final String tableKey = 'schedule_table_${widget.tableId}';

      // Save sort field
      await prefs.setString('${tableKey}_sort_field', currentSortField ?? 'reminder_time');

      // Save sort direction
      await prefs.setBool('${tableKey}_is_ascending', isAscending);

      // Save expansion state
      await prefs.setBool('${tableKey}_is_expanded', isExpanded);
      
      // Save filter categories
      await prefs.setStringList('${tableKey}_filter_categories', _filterCategories.toList());
      await prefs.setStringList('${tableKey}_filter_subcategories', _filterSubCategories.toList());
      await prefs.setStringList('${tableKey}_filter_entrytypes', _filterEntryTypes.toList());
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
  
  void _applyMultiFilter(FilterData filterData) {
    _sortedRecordsCache.clear(); // Clear cache when filter changes

    setState(() {
      _filterCategories = filterData.selectedCategories;
      _filterSubCategories = filterData.selectedSubCategories;
      _filterEntryTypes = filterData.selectedEntryTypes;
    });

    _persistState();
  }
  
  bool _recordPassesFilters(Map<String, dynamic> record) {
    // Category filter
    if (_filterCategories.isNotEmpty) {
      final category = record['category']?.toString();
      if (category == null || !_filterCategories.contains(category)) {
        return false;
      }
    }
    // Subcategory filter
    if (_filterSubCategories.isNotEmpty) {
      final subCategory = record['sub_category']?.toString();
      if (subCategory == null || !_filterSubCategories.contains(subCategory)) {
        return false;
      }
    }
    // Entry type filter
    if (_filterEntryTypes.isNotEmpty) {
      final entryType = record['entry_type']?.toString();
      if (entryType == null || !_filterEntryTypes.contains(entryType)) {
        return false;
      }
    }
    return true;
  }
  
  List<Map<String, dynamic>> _getFilteredRecords() {
    if (_filterCategories.isEmpty && _filterSubCategories.isEmpty && _filterEntryTypes.isEmpty) {
      return records;
    }
    return records.where(_recordPassesFilters).toList();
  }

  @override
  void didUpdateWidget(ScheduleTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRecords != oldWidget.initialRecords) {
      setState(() {
        records = List.from(widget.initialRecords);
        // Clear the cache when records change
        _sortedRecordsCache.clear();
        // Update available categories
        _updateAvailableCategories();

        // Reapply sorting if we had a sort field
        if (currentSortField != null && _prefsLoaded) {
          // Apply sorting without resetting animation
          _applyRefreshSorting(currentSortField!, isAscending);
        }
      });
    }
  }
  // New method for refreshing without animation reset
  void _applyRefreshSorting(String field, bool ascending) {
    // Skip animation reset and directly apply sorting
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
                  mainAxisSize: MainAxisSize.min, // Make sure this row takes minimum space
                  children: [
                    if (isExpanded) FilterButton(
                      currentSortField: currentSortField,
                      isAscending: isAscending,
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (context) => SortingBottomSheet(
                            currentSortField: currentSortField,
                            isAscending: isAscending,
                            onSortApplied: _applySorting,
                            filterData: FilterData(
                              availableCategories: _availableCategories,
                              availableSubCategories: _availableSubCategories,
                              availableEntryTypes: _availableEntryTypes,
                              selectedCategories: _filterCategories,
                              selectedSubCategories: _filterSubCategories,
                              selectedEntryTypes: _filterEntryTypes,
                            ),
                            onMultiFilterApplied: _applyMultiFilter,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4), // Add some spacing
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
                  final filteredRecords = _getFilteredRecords();

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
                    itemCount: filteredRecords.length,
                    itemBuilder: (context, index) {
                      final record = filteredRecords[index];
                      final bool isCompleted = record['date_initiated'] != null &&
                          record['date_initiated'].toString().isNotEmpty;

                      final Animation<double> animation = Tween<double>(
                        begin: 0.0,
                        end: 1.0,
                      ).animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: Interval(
                            (index / filteredRecords.length) * 0.5,
                            (index / filteredRecords.length) * 0.5 + 0.5,
                            curve: Curves.easeInOut,
                          ),
                        ),
                      );

                      return AnimatedCardDetailP(
                        animation: animation,
                        record: record,
                        isCompleted: isCompleted,
                        onSelect: widget.onSelect,
                        showCategoryPath: true,
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
    );  }
}


