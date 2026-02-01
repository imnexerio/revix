import 'dart:async';
import 'package:flutter/material.dart';
import 'SortingComponents.dart';
import 'RecordSortingUtils.dart';
import '../../Utils/entry_colors.dart';
import '../../Utils/FirebaseDatabaseService.dart';
import '../../Utils/UnifiedDatabaseService.dart';

/// Filter data class to hold selected filter options
class FilterData {
  final Set<String> selectedCategories;
  final Set<String> selectedSubCategories;
  final Set<String> selectedEntryTypes;

  const FilterData({
    this.selectedCategories = const {},
    this.selectedSubCategories = const {},
    this.selectedEntryTypes = const {},
  });
  
  int get totalSelectedCount => 
      selectedCategories.length + 
      selectedSubCategories.length + 
      selectedEntryTypes.length;
  
  bool get hasAnySelected => totalSelectedCount > 0;
  
  FilterData copyWith({
    Set<String>? selectedCategories,
    Set<String>? selectedSubCategories,
    Set<String>? selectedEntryTypes,
  }) {
    return FilterData(
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedSubCategories: selectedSubCategories ?? this.selectedSubCategories,
      selectedEntryTypes: selectedEntryTypes ?? this.selectedEntryTypes,
    );
  }
}

/// Search state class to hold search query and filters for restoration
class SearchState {
  final String query;
  final FilterData filters;
  
  const SearchState({
    this.query = '',
    this.filters = const FilterData(),
  });
  
  SearchState copyWith({
    String? query,
    FilterData? filters,
  }) {
    return SearchState(
      query: query ?? this.query,
      filters: filters ?? this.filters,
    );
  }
}

/// Reusable sorting and filtering bottom sheet component
/// Fetches filter options independently from services
/// Can also be used as a search sheet when searchMode is enabled
class SortingBottomSheet extends StatefulWidget {
  final String? currentSortField;
  final bool isAscending;
  final Function(String field, bool ascending) onSortApplied;
  
  // Selected filters (passed from parent)
  final Set<String> selectedCategories;
  final Set<String> selectedSubCategories;
  final Set<String> selectedEntryTypes;
  
  // Callback when filters change
  final Function(FilterData)? onFilterApplied;
  
  // Control which filter sections to show
  final bool showCategoryFilter;
  final bool showSubCategoryFilter;
  final bool showEntryTypeFilter;
  
  // Search mode parameters
  final bool searchMode;
  final String? initialSearchQuery;
  final Function(Map<String, dynamic> record)? onRecordSelected;
  final Function(SearchState searchState)? onSearchStateChanged;

  const SortingBottomSheet({
    Key? key,
    required this.currentSortField,
    required this.isAscending,
    required this.onSortApplied,
    this.selectedCategories = const {},
    this.selectedSubCategories = const {},
    this.selectedEntryTypes = const {},
    this.onFilterApplied,
    this.showCategoryFilter = true,
    this.showSubCategoryFilter = true,
    this.showEntryTypeFilter = true,
    // Search mode
    this.searchMode = false,
    this.initialSearchQuery,
    this.onRecordSelected,
    this.onSearchStateChanged,
  }) : super(key: key);

  @override
  _SortingBottomSheetState createState() => _SortingBottomSheetState();
}

class _SortingBottomSheetState extends State<SortingBottomSheet> {
  late String selectedField;
  late bool isAscending;
  
  // Selected filter state
  late Set<String> selectedCategories;
  late Set<String> selectedSubCategories;
  late Set<String> selectedEntryTypes;
  
  // Available options (fetched from services)
  List<String> _availableCategories = [];
  List<String> _availableSubCategories = [];
  List<String> _availableEntryTypes = [];
  bool _isLoadingFilters = true;
  
  // Search state
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];
  bool _isLoadingRecords = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    selectedField = widget.currentSortField ?? 'reminder_time';
    isAscending = widget.isAscending;
    
    // Initialize selected filters from widget
    selectedCategories = Set.from(widget.selectedCategories);
    selectedSubCategories = Set.from(widget.selectedSubCategories);
    selectedEntryTypes = Set.from(widget.selectedEntryTypes);
    
    // Initialize search query if provided
    if (widget.searchMode && widget.initialSearchQuery != null) {
      _searchController.text = widget.initialSearchQuery!;
    }
    
    // Fetch available filter options from services
    _loadFilterOptions();
    
    // Load records for search if in search mode
    if (widget.searchMode) {
      _loadAllRecords();
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _loadAllRecords() async {
    try {
      final service = UnifiedDatabaseService();
      // Listen to the stream for records
      service.allRecordsStream.listen((data) {
        if (mounted) {
          final records = (data['allRecords'] as List<dynamic>? ?? [])
              .map((r) => Map<String, dynamic>.from(r))
              .toList();
          setState(() {
            _allRecords = records;
            _isLoadingRecords = false;
            _filterRecords();
          });
        }
      });
      // Force a refresh
      await service.forceDataReprocessing();
    } catch (e) {
      print('Error loading records for search: $e');
      if (mounted) {
        setState(() {
          _isLoadingRecords = false;
        });
      }
    }
  }
  
  void _filterRecords() {
    final query = _searchController.text.toLowerCase().trim();
    
    List<Map<String, dynamic>> results = _allRecords;
    
    // Apply text search
    if (query.isNotEmpty) {
      results = results.where((record) {
        final title = (record['record_title'] ?? '').toString().toLowerCase();
        final category = (record['category'] ?? '').toString().toLowerCase();
        final subCategory = (record['sub_category'] ?? '').toString().toLowerCase();
        final description = (record['details']?['description'] ?? '').toString().toLowerCase();
        final entryType = (record['details']?['entry_type'] ?? '').toString().toLowerCase();
        
        return title.contains(query) ||
               category.contains(query) ||
               subCategory.contains(query) ||
               description.contains(query) ||
               entryType.contains(query);
      }).toList();
    }
    
    // Apply category filter
    if (selectedCategories.isNotEmpty) {
      results = results.where((r) => 
        selectedCategories.contains(r['category']?.toString())
      ).toList();
    }
    
    // Apply subcategory filter
    if (selectedSubCategories.isNotEmpty) {
      results = results.where((r) => 
        selectedSubCategories.contains(r['sub_category']?.toString())
      ).toList();
    }
    
    // Apply entry type filter
    if (selectedEntryTypes.isNotEmpty) {
      results = results.where((r) {
        final entryType = r['details']?['entry_type']?.toString();
        return entryType != null && selectedEntryTypes.contains(entryType);
      }).toList();
    }
    
    setState(() {
      _filteredRecords = results;
    });
    
    // Notify parent about search state change
    _notifySearchStateChanged();
  }
  
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _filterRecords();
    });
  }
  
  void _notifySearchStateChanged() {
    widget.onSearchStateChanged?.call(SearchState(
      query: _searchController.text,
      filters: FilterData(
        selectedCategories: Set.from(selectedCategories),
        selectedSubCategories: Set.from(selectedSubCategories),
        selectedEntryTypes: Set.from(selectedEntryTypes),
      ),
    ));
  }
  
  void _onRecordTap(Map<String, dynamic> record) {
    // Notify about search state before closing
    _notifySearchStateChanged();
    // Close the bottom sheet
    Navigator.pop(context);
    // Call the record selected callback
    widget.onRecordSelected?.call(record);
  }
  
  Future<void> _loadFilterOptions() async {
    try {
      // Fetch data in parallel
      final results = await Future.wait([
        if (widget.showEntryTypeFilter) 
          FirebaseDatabaseService().fetchCustomTrackingTypes()
        else 
          Future.value(<String>[]),
        if (widget.showCategoryFilter || widget.showSubCategoryFilter)
          UnifiedDatabaseService().loadCategoriesAndSubCategories()
        else
          Future.value(<String, dynamic>{'subjects': <String>[], 'subCategories': <String, List<String>>{}}),
      ]);
      
      if (mounted) {
        setState(() {
          // Entry types from first result
          if (widget.showEntryTypeFilter && results.isNotEmpty) {
            _availableEntryTypes = List<String>.from(results[0] as List);
          }
          
          // Categories and subcategories from second result
          if ((widget.showCategoryFilter || widget.showSubCategoryFilter) && results.length > 1) {
            final catData = results[1] as Map<String, dynamic>;
            if (widget.showCategoryFilter) {
              _availableCategories = List<String>.from(catData['subjects'] ?? []);
            }
            if (widget.showSubCategoryFilter) {
              // Flatten all subcategories into a single list
              final subCatMap = catData['subCategories'] as Map<String, dynamic>? ?? {};
              final allSubCats = <String>{};
              for (final subList in subCatMap.values) {
                if (subList is List) {
                  allSubCats.addAll(subList.map((e) => e.toString()));
                }
              }
              _availableSubCategories = allSubCats.toList()..sort();
            }
          }
          
          _isLoadingFilters = false;
        });
      }
    } catch (e) {
      print('Error loading filter options: $e');
      if (mounted) {
        setState(() {
          _isLoadingFilters = false;
        });
      }
    }
  }
  
  bool get _showFilterSection {
    if (_isLoadingFilters) return true; // Show shimmer while loading
    return _availableCategories.isNotEmpty || 
           _availableSubCategories.isNotEmpty || 
           _availableEntryTypes.isNotEmpty;
  }
  
  int get _totalSelectedFilters {
    return selectedCategories.length + selectedSubCategories.length + selectedEntryTypes.length;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Use search mode UI if enabled
    if (widget.searchMode) {
      return _buildSearchUI(colorScheme);
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Handle indicator
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant,
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
                  SortFieldBox(
                    label: 'Reminder Time',
                    field: 'reminder_time',
                    isSelected: selectedField == 'reminder_time',
                    onTap: () => _selectSortField('reminder_time'),
                  ),
                  SortFieldBox(
                    label: 'Date Initiated',
                    field: 'date_initiated',
                    isSelected: selectedField == 'date_initiated',
                    onTap: () => _selectSortField('date_initiated'),
                  ),
                  SortFieldBox(
                    label: 'Date Reviewed',
                    field: 'date_updated',
                    isSelected: selectedField == 'date_updated',
                    onTap: () => _selectSortField('date_updated'),
                  ),
                  SortFieldBox(
                    label: 'Overdue Reviews',
                    field: 'missed_counts',
                    isSelected: selectedField == 'missed_counts',
                    onTap: () => _selectSortField('missed_counts'),
                  ),
                  SortFieldBox(
                    label: 'Number of Reviews',
                    field: 'completion_counts',
                    isSelected: selectedField == 'completion_counts',
                    onTap: () => _selectSortField('completion_counts'),
                  ),
                  SortFieldBox(
                    label: 'Review Frequency',
                    field: 'recurrence_frequency',
                    isSelected: selectedField == 'recurrence_frequency',
                    onTap: () => _selectSortField('recurrence_frequency'),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Order selection
              Column(
                children: [
                  const Text('Order'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OrderBox(
                          label: 'Ascending',
                          icon: Icons.arrow_upward,
                          isSelected: isAscending,
                          onTap: () => _selectOrder(true),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: OrderBox(
                          label: 'Descending',
                          icon: Icons.arrow_downward,
                          isSelected: !isAscending,
                          onTap: () => _selectOrder(false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Filter section
              if (_showFilterSection && widget.onFilterApplied != null) ...[
                const SizedBox(height: 20),
                Divider(color: colorScheme.outlineVariant),
                const SizedBox(height: 12),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Filters',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_totalSelectedFilters > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_totalSelectedFilters',
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_totalSelectedFilters > 0)
                      TextButton(
                        onPressed: _clearAllFilters,
                        child: Text(
                          'Clear All',
                          style: TextStyle(
                            color: colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                
                if (_isLoadingFilters)
                  _buildFilterShimmer(colorScheme)
                else
                  _buildFilterSections(colorScheme),
              ],
              
              const SizedBox(height: 24),
              
              // Done button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _applyChanges,
                  child: const Text('Done'),
                ),
              ),
              
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      ),
    );
  }
  
  Widget _buildSearchUI(ColorScheme colorScheme) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Handle indicator
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
            margin: const EdgeInsets.only(bottom: 16),
          ),
          
          // Search field
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search records...',
              prefixIcon: Icon(Icons.search, color: colorScheme.primary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filterRecords();
                      },
                    )
                  : null,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
            ),
            onChanged: _onSearchChanged,
          ),
          
          const SizedBox(height: 12),
          
          // Filter chips row (collapsible)
          if (_showFilterSection) ...[
            ExpansionTile(
              title: Row(
                children: [
                  Icon(Icons.filter_list, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (_totalSelectedFilters > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_totalSelectedFilters',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: _totalSelectedFilters > 0
                  ? TextButton(
                      onPressed: () {
                        _clearAllFilters();
                        _filterRecords();
                      },
                      child: Text(
                        'Clear',
                        style: TextStyle(color: colorScheme.error, fontSize: 12),
                      ),
                    )
                  : null,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.25,
                  ),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      child: _isLoadingFilters
                          ? _buildFilterShimmer(colorScheme)
                          : _buildFilterSections(colorScheme),
                    ),
                  ),
                ),
              ],
            ),
            Divider(color: colorScheme.outlineVariant),
          ],
          
          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  _isLoadingRecords 
                      ? 'Loading...' 
                      : '${_filteredRecords.length} result${_filteredRecords.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Search results
          Expanded(
            child: _isLoadingRecords
                ? Center(
                    child: CircularProgressIndicator(color: colorScheme.primary),
                  )
                : _filteredRecords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchController.text.isEmpty 
                                  ? Icons.search 
                                  : Icons.search_off,
                              size: 48,
                              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty 
                                  ? 'Start typing to search'
                                  : 'No matching records found',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredRecords.length,
                        itemBuilder: (context, index) {
                          return _buildSearchResultItem(
                            _filteredRecords[index],
                            colorScheme,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchResultItem(Map<String, dynamic> record, ColorScheme colorScheme) {
    final title = record['record_title'] ?? 'Untitled';
    final category = record['category'] ?? '';
    final subCategory = record['sub_category'] ?? '';
    final entryType = record['details']?['entry_type'] ?? '';
    final description = record['details']?['description'] ?? '';
    final scheduledDate = record['details']?['scheduled_date'] ?? '';
    final status = record['details']?['status'] ?? 'Enabled';
    
    final entryColor = EntryColors.generateColorFromString(entryType);
    final isDisabled = status != 'Enabled';
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: isDisabled 
          ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
          : colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        onTap: () => _onRecordTap(record),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Entry type color indicator
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: entryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDisabled 
                            ? colorScheme.onSurface.withOpacity(0.5)
                            : colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Category path
                    Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$category · $subCategory',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    // Description preview if available
                    if (description.isNotEmpty && description != 'No description available') ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Right side info
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Entry type chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: entryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entryType,
                      style: TextStyle(
                        fontSize: 10,
                        color: entryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (scheduledDate.isNotEmpty && scheduledDate != 'Unspecified') ...[
                    const SizedBox(height: 4),
                    Text(
                      scheduledDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (isDisabled) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: colorScheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Disabled',
                        style: TextStyle(
                          fontSize: 9,
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFilterShimmer(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < 2; i++) ...[
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 120,
                height: 14,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(3, (index) => Container(
              width: 70 + (index * 10).toDouble(),
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
            )),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
  
  Widget _buildFilterSections(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category filter
        if (widget.showCategoryFilter && _availableCategories.isNotEmpty)
          _buildFilterSection(
            title: 'Filter by Category',
            icon: Icons.folder_outlined,
            availableItems: _availableCategories,
            selectedItems: selectedCategories,
            onSelectionChanged: (items) {
              setState(() {
                selectedCategories = items;
              });
              _applyFilterLive();
            },
            colorScheme: colorScheme,
          ),
        
        // Subcategory filter
        if (widget.showSubCategoryFilter && _availableSubCategories.isNotEmpty)
          _buildFilterSection(
            title: 'Filter by Subcategory',
            icon: Icons.folder_open_outlined,
            availableItems: _availableSubCategories,
            selectedItems: selectedSubCategories,
            onSelectionChanged: (items) {
              setState(() {
                selectedSubCategories = items;
              });
              _applyFilterLive();
            },
            colorScheme: colorScheme,
          ),
        
        // Entry type filter
        if (widget.showEntryTypeFilter && _availableEntryTypes.isNotEmpty)
          _buildFilterSection(
            title: 'Filter by Entry Type',
            icon: Icons.label_outline,
            availableItems: _availableEntryTypes,
            selectedItems: selectedEntryTypes,
            onSelectionChanged: (items) {
              setState(() {
                selectedEntryTypes = items;
              });
              _applyFilterLive();
            },
            colorScheme: colorScheme,
          ),
      ],
    );
  }
  
  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required List<String> availableItems,
    required Set<String> selectedItems,
    required Function(Set<String>) onSelectionChanged,
    required ColorScheme colorScheme,
  }) {
    final hasSelections = selectedItems.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (hasSelections) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${selectedItems.length}',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelectionChanged({}),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableItems.map((item) {
            final isSelected = selectedItems.contains(item);
            final itemColor = EntryColors.generateColorFromString(item);
            return FilterChip(
              avatar: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: itemColor,
                  shape: BoxShape.circle,
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              label: Text(item),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (selected) {
                final newSet = Set<String>.from(selectedItems);
                if (selected) {
                  newSet.add(item);
                } else {
                  newSet.remove(item);
                }
                onSelectionChanged(newSet);
              },
              selectedColor: itemColor.withOpacity(0.2),
              side: BorderSide(
                color: isSelected ? itemColor : colorScheme.outline,
                width: isSelected ? 2 : 1,
              ),
              labelStyle: TextStyle(
                color: isSelected ? itemColor : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
  
  void _applyFilterLive() {
    widget.onFilterApplied?.call(FilterData(
      selectedCategories: Set.from(selectedCategories),
      selectedSubCategories: Set.from(selectedSubCategories),
      selectedEntryTypes: Set.from(selectedEntryTypes),
    ));
    
    // Also re-filter search results if in search mode
    if (widget.searchMode) {
      _filterRecords();
    }
  }
  
  void _clearAllFilters() {
    setState(() {
      selectedCategories.clear();
      selectedSubCategories.clear();
      selectedEntryTypes.clear();
    });
    _applyFilterLive();
  }
  
  void _selectSortField(String field) {
    if (selectedField != field) {
      setState(() {
        selectedField = field;
      });
      widget.onSortApplied(selectedField, isAscending);
    }
  }
  
  void _selectOrder(bool ascending) {
    if (isAscending != ascending) {
      setState(() {
        isAscending = ascending;
      });
      widget.onSortApplied(selectedField, isAscending);
    }
  }
  
  void _applyChanges() {
    Navigator.pop(context);
  }
}
