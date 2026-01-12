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
    
    if (mounted) {
      setState(() {
        _isSidebarVisible = savedSidebarState;
        _currentSortField = savedSortField;
        _isAscending = savedAscending;
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

  // Method to show sorting bottom sheet (called from AppBar)
  void showSortingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SortingBottomSheet(
        currentSortField: _currentSortField,
        isAscending: _isAscending,
        onSortApplied: _applySorting,
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

            final availableCategories = _getAvailableCategories(data);

            if (availableCategories.isEmpty) {
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
            if (_selectedCategory == null || !availableCategories.contains(_selectedCategory)) {
              _selectedCategory = availableCategories.first;
            }

            final selectedRecords = data[_selectedCategory] ?? [];
            final sortedRecords = RecordSortingUtils.sortRecords(
              records: List.from(selectedRecords),
              field: _currentSortField,
              ascending: _isAscending,
            );

            return Row(
              children: [
                // Vertical sidebar for categories
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  width: _isSidebarVisible ? 40.0 : 0.0,
                  decoration: BoxDecoration(color: colorScheme.surface),
                  child: _isSidebarVisible
                      ? RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 16.0),
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                              child: ListView.builder(
                                scrollDirection: Axis.vertical,
                                physics: const BouncingScrollPhysics(),
                                cacheExtent: 100,
                                itemCount: availableCategories.length,
                                itemBuilder: (context, index) {
                                  final category = availableCategories[index];
                                  final displayName = _categoryDisplayNames[category] ?? category;
                                  final isSelected = _selectedCategory == category;
                                  final count = data[category]?.length ?? 0;

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
                                              '$displayName ($count)',
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