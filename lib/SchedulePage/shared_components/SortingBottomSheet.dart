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

/// Reusable sorting and filtering bottom sheet component
/// Fetches filter options independently from services
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

  @override
  void initState() {
    super.initState();
    selectedField = widget.currentSortField ?? 'reminder_time';
    isAscending = widget.isAscending;
    
    // Initialize selected filters from widget
    selectedCategories = Set.from(widget.selectedCategories);
    selectedSubCategories = Set.from(widget.selectedSubCategories);
    selectedEntryTypes = Set.from(widget.selectedEntryTypes);
    
    // Fetch available filter options from services
    _loadFilterOptions();
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
