import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Utils/UnifiedDatabaseService.dart';
import '../widgets/EntryDetailsModal.dart';
import '../DetailsPage/AnimatedCardDetailP.dart';
import 'shared_components/RecordSortingUtils.dart';
import 'shared_components/SortingBottomSheet.dart';
import 'shared_components/GridLayoutUtils.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({Key? key}) : super(key: key);

  @override
  TodayPageState createState() => TodayPageState();
}

class TodayPageState extends State<TodayPage> with TickerProviderStateMixin {
  static const String _sidebarVisibilityKey = 'schedulePageSidebarVisible';
  
  final UnifiedDatabaseService _databaseService = UnifiedDatabaseService();
  SharedPreferences? _prefs;
  
  bool _isSidebarVisible = true;
  String? _selectedCategory;
  
  // Sorting state
  String _currentSortField = 'reminder_time';
  bool _isAscending = true;
  
  // Multi-filter state
  Set<String> _filterCategories = {};
  Set<String> _filterSubCategories = {};
  Set<String> _filterEntryTypes = {};
  List<String> _availableCategories = [];
  List<String> _availableSubCategories = [];
  List<String> _availableEntryTypes = [];
  
  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _gridAnimationController;

  // Category definitions with display names
  static const Map<String, String> _categoryDisplayNames = {
    'missed': 'Missed',
    'today': "Today's",
    'todayAdded': 'Added Today',
    'nextDay': 'Next Day',
    'next7Days': 'Next Week',
    'noreminderdate': 'No Date',
  };

  // Category order for display
  static const List<String> _categoryOrder = [
    'missed',
    'today',
    'todayAdded',
    'nextDay',
    'next7Days',
    'noreminderdate',
  ];

  @override
  void initState() {
    super.initState();
    _databaseService.initialize();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();

    _gridAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _gridAnimationController.value = 1.0;

    _initializePreferences();
  }

  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    
    final savedSidebarState = _prefs!.getBool(_sidebarVisibilityKey) ?? true;
    final savedSortField = _prefs!.getString('schedule_sortField') ?? 'reminder_time';
    final savedAscending = _prefs!.getBool('schedule_isAscending') ?? true;
    final savedFilterCats = _prefs!.getStringList('schedule_filterCategories') ?? [];
    final savedFilterSubCats = _prefs!.getStringList('schedule_filterSubCategories') ?? [];
    final savedFilterTypes = _prefs!.getStringList('schedule_filterEntryTypes') ?? [];
    
    if (mounted) {
      setState(() {
        _isSidebarVisible = savedSidebarState;
        _currentSortField = savedSortField;
        _isAscending = savedAscending;
        _filterCategories = savedFilterCats.toSet();
        _filterSubCategories = savedFilterSubCats.toSet();
        _filterEntryTypes = savedFilterTypes.toSet();
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _gridAnimationController.dispose();
    super.dispose();
  }

  void toggleSidebar() {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
    });
    _prefs?.setBool(_sidebarVisibilityKey, _isSidebarVisible);
  }

  // Expose sorting info for AppBar
  String get sortField => _currentSortField;
  bool get sortAscending => _isAscending;
  Set<String> get filterCategories => _filterCategories;
  int get activeFilterCount => 
      _filterCategories.length + _filterSubCategories.length + _filterEntryTypes.length;

  // Method to show sorting bottom sheet (called from AppBar)
  void showSortingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SortingBottomSheet(
        currentSortField: _currentSortField,
        isAscending: _isAscending,
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
  }

  void _applySorting(String field, bool ascending) {
    _gridAnimationController.reset();

    setState(() {
      _currentSortField = field;
      _isAscending = ascending;
    });

    _prefs?.setString('schedule_sortField', field);
    _prefs?.setBool('schedule_isAscending', ascending);
    _gridAnimationController.forward();
  }
  
  void _applyMultiFilter(FilterData filterData) {
    setState(() {
      _filterCategories = filterData.selectedCategories;
      _filterSubCategories = filterData.selectedSubCategories;
      _filterEntryTypes = filterData.selectedEntryTypes;
    });

    _prefs?.setStringList('schedule_filterCategories', filterData.selectedCategories.toList());
    _prefs?.setStringList('schedule_filterSubCategories', filterData.selectedSubCategories.toList());
    _prefs?.setStringList('schedule_filterEntryTypes', filterData.selectedEntryTypes.toList());
  }
  
  // Check if record passes all active filters
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

  void _showEntryDetails(BuildContext context, Map<String, dynamic> record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return EntryDetailsModal(
          entryTitle: record['record_title'],
          details: record,
          selectedCategory: record['category'],
          selectedCategoryCode: record['sub_category'],
        );
      },
    );
  }

  List<String> _getAvailableCategories(Map<String, List<Map<String, dynamic>>> data) {
    return _categoryOrder
        .where((cat) => data[cat]?.isNotEmpty ?? false)
        .toList();
  }

  int _calculateColumns(double width) {
    return GridLayoutUtils.calculateColumns(width);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _databaseService.forceDataReprocessing();
        },
        child: StreamBuilder<Map<String, List<Map<String, dynamic>>>>(
          stream: _databaseService.categorizedRecordsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                  strokeWidth: 3,
                ),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[400],
                      ),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data ?? {
              'today': <Map<String, dynamic>>[],
              'missed': <Map<String, dynamic>>[],
              'nextDay': <Map<String, dynamic>>[],
              'next7Days': <Map<String, dynamic>>[],
              'todayAdded': <Map<String, dynamic>>[],
              'noreminderdate': <Map<String, dynamic>>[],
            };

            // Extract unique values for all filter types
            final Set<String> uniqueCategories = {};
            final Set<String> uniqueSubCategories = {};
            final Set<String> uniqueEntryTypes = {};
            for (final timeCategory in data.values) {
              for (final record in timeCategory) {
                final category = record['category']?.toString();
                if (category != null && category.isNotEmpty) {
                  uniqueCategories.add(category);
                }
                final subCategory = record['sub_category']?.toString();
                if (subCategory != null && subCategory.isNotEmpty) {
                  uniqueSubCategories.add(subCategory);
                }
                final entryType = record['entry_type']?.toString();
                if (entryType != null && entryType.isNotEmpty) {
                  uniqueEntryTypes.add(entryType);
                }
              }
            }
            // Update available values for all filters
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final newCategories = uniqueCategories.toList()..sort();
                final newSubCategories = uniqueSubCategories.toList()..sort();
                final newEntryTypes = uniqueEntryTypes.toList()..sort();
                if (_availableCategories.length != newCategories.length ||
                    _availableSubCategories.length != newSubCategories.length ||
                    _availableEntryTypes.length != newEntryTypes.length) {
                  setState(() {
                    _availableCategories = newCategories;
                    _availableSubCategories = newSubCategories;
                    _availableEntryTypes = newEntryTypes;
                  });
                }
              }
            });

            final availableTimeCategories = _getAvailableCategories(data);

            if (availableTimeCategories.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No schedules found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Auto-select first category if none selected
            if (_selectedCategory == null || !availableTimeCategories.contains(_selectedCategory)) {
              _selectedCategory = availableTimeCategories.first;
            }

            final selectedRecords = data[_selectedCategory] ?? [];
            
            // Apply filter first (empty filter = show all)
            // Apply all active filters
            final bool hasAnyFilter = _filterCategories.isNotEmpty || 
                                       _filterSubCategories.isNotEmpty || 
                                       _filterEntryTypes.isNotEmpty;
            final filteredRecords = !hasAnyFilter
                ? List<Map<String, dynamic>>.from(selectedRecords)
                : selectedRecords.where(_recordPassesFilters).toList();
            
            final sortedRecords = RecordSortingUtils.sortRecords(
              records: filteredRecords,
              field: _currentSortField,
              ascending: _isAscending,
            );

            return Row(
              children: [
                // Vertical sidebar for categories
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  width: _isSidebarVisible ? 32.0 : 0.0,
                  decoration: BoxDecoration(color: colorScheme.surface),
                  child: _isSidebarVisible
                      ? RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 16.0),
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                              child: ListView.builder(
                                scrollDirection: Axis.vertical,
                                physics: const BouncingScrollPhysics(),
                                cacheExtent: 100,
                                itemCount: availableTimeCategories.length,
                                itemBuilder: (context, index) {
                                  final category = availableTimeCategories[index];
                                  final displayName = _categoryDisplayNames[category] ?? category;
                                  final isSelected = _selectedCategory == category;
                                  // Calculate filtered count for this time category
                                  final categoryRecords = data[category] ?? [];
                                  final filteredCount = !hasAnyFilter
                                      ? categoryRecords.length
                                      : categoryRecords.where(_recordPassesFilters).length;
                                  final totalCount = categoryRecords.length;
                                  // Show filtered/total when filter is active
                                  final countText = !hasAnyFilter 
                                      ? '$totalCount' 
                                      : '$filteredCount/$totalCount';

                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          if (_selectedCategory != category) {
                                            setState(() {
                                              _selectedCategory = category;
                                            });
                                            _fadeController.reset();
                                            _fadeController.forward();
                                            _gridAnimationController.reset();
                                            _gridAnimationController.forward();
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(8.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 12.0),
                                          child: RotatedBox(
                                            quarterTurns: 3,
                                            child: Text(
                                              '$displayName ($countText)',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                                                fontSize: 14,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                // Records grid
                Expanded(
                  child: RepaintBoundary(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildRecordsGrid(sortedRecords, colorScheme),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecordsGrid(List<Map<String, dynamic>> records, ColorScheme colorScheme) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No records in this category',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _gridAnimationController,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = _calculateColumns(constraints.maxWidth);

            return GridView.builder(
              padding: const EdgeInsets.only(left: 4, right: 12, top: 8, bottom: 100),
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
                    parent: _gridAnimationController,
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
                  onSelect: (context, record) => _showEntryDetails(context, record),
                  showCategoryPath: true,
                );
              },
            );
          },
        );
      },
    );
  }
}