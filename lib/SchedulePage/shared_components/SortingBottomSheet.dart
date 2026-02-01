import 'package:flutter/material.dart';
import 'SortingComponents.dart';
import 'RecordSortingUtils.dart';
import '../../Utils/entry_colors.dart';

/// Filter data class to hold all filter options
class FilterData {
  final List<String> availableCategories;
  final List<String> availableSubCategories;
  final List<String> availableEntryTypes;
  final Set<String> selectedCategories;
  final Set<String> selectedSubCategories;
  final Set<String> selectedEntryTypes;

  const FilterData({
    this.availableCategories = const [],
    this.availableSubCategories = const [],
    this.availableEntryTypes = const [],
    this.selectedCategories = const {},
    this.selectedSubCategories = const {},
    this.selectedEntryTypes = const {},
  });
  
  bool get hasAnyAvailable => 
      availableCategories.isNotEmpty || 
      availableSubCategories.isNotEmpty || 
      availableEntryTypes.isNotEmpty;
  
  int get totalSelectedCount => 
      selectedCategories.length + 
      selectedSubCategories.length + 
      selectedEntryTypes.length;
  
  FilterData copyWith({
    Set<String>? selectedCategories,
    Set<String>? selectedSubCategories,
    Set<String>? selectedEntryTypes,
  }) {
    return FilterData(
      availableCategories: availableCategories,
      availableSubCategories: availableSubCategories,
      availableEntryTypes: availableEntryTypes,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedSubCategories: selectedSubCategories ?? this.selectedSubCategories,
      selectedEntryTypes: selectedEntryTypes ?? this.selectedEntryTypes,
    );
  }
}

/// Reusable sorting and filtering bottom sheet component
class SortingBottomSheet extends StatefulWidget {
  final String? currentSortField;
  final bool isAscending;
  final Function(String field, bool ascending) onSortApplied;
  
  // Legacy single filter parameters (for backward compatibility)
  final List<String> availableCategories;
  final Set<String> selectedCategories;
  final Function(Set<String> categories)? onFilterApplied;
  
  // New multi-filter parameters
  final FilterData? filterData;
  final Function(FilterData)? onMultiFilterApplied;

  const SortingBottomSheet({
    Key? key,
    required this.currentSortField,
    required this.isAscending,
    required this.onSortApplied,
    this.availableCategories = const [],
    this.selectedCategories = const {},
    this.onFilterApplied,
    this.filterData,
    this.onMultiFilterApplied,
  }) : super(key: key);

  @override
  _SortingBottomSheetState createState() => _SortingBottomSheetState();
}

class _SortingBottomSheetState extends State<SortingBottomSheet> {
  late String selectedField;
  late bool isAscending;
  
  // Multi-filter state
  late Set<String> selectedCategories;
  late Set<String> selectedSubCategories;
  late Set<String> selectedEntryTypes;
  
  // Track if sort changed
  // (no longer needed for live updates, but kept for reference)
  
  // Which filter section is expanded
  int _expandedFilterIndex = -1;

  @override
  void initState() {
    super.initState();
    selectedField = widget.currentSortField ?? 'reminder_time';
    isAscending = widget.isAscending;
    
    // Initialize from multi-filter data or legacy single filter
    if (widget.filterData != null) {
      selectedCategories = Set.from(widget.filterData!.selectedCategories);
      selectedSubCategories = Set.from(widget.filterData!.selectedSubCategories);
      selectedEntryTypes = Set.from(widget.filterData!.selectedEntryTypes);
    } else {
      selectedCategories = Set.from(widget.selectedCategories);
      selectedSubCategories = {};
      selectedEntryTypes = {};
    }
  }
  
  bool get _useMultiFilter => widget.filterData != null && widget.onMultiFilterApplied != null;
  
  bool get _showFilterSection {
    if (_useMultiFilter) {
      return widget.filterData!.hasAnyAvailable;
    }
    return widget.availableCategories.isNotEmpty && widget.onFilterApplied != null;
  }
  
  int get _totalSelectedFilters {
    if (_useMultiFilter) {
      return selectedCategories.length + selectedSubCategories.length + selectedEntryTypes.length;
    }
    return selectedCategories.length;
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
              if (_showFilterSection) ...[
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
                
                if (_useMultiFilter) ...[
                  // Multi-filter with expandable sections
                  _buildMultiFilterSections(colorScheme),
                ] else ...[
                  // Legacy single category filter
                  _buildLegacyCategoryFilter(colorScheme),
                ],
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
    );
  }
  
  Widget _buildMultiFilterSections(ColorScheme colorScheme) {
    final filterData = widget.filterData!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category filter
        if (filterData.availableCategories.isNotEmpty)
          _buildFilterSection(
            title: 'Filter by Category',
            icon: Icons.folder_outlined,
            availableItems: filterData.availableCategories,
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
        if (filterData.availableSubCategories.isNotEmpty)
          _buildFilterSection(
            title: 'Filter by Subcategory',
            icon: Icons.folder_open_outlined,
            availableItems: filterData.availableSubCategories,
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
        if (filterData.availableEntryTypes.isNotEmpty)
          _buildFilterSection(
            title: 'Filter by Entry Type',
            icon: Icons.label_outline,
            availableItems: filterData.availableEntryTypes,
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
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasSelections) ...[
              const SizedBox(width: 8),
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
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: itemColor,
                  shape: BoxShape.circle,
                ),
              ),
              label: Text(item),
              selected: isSelected,
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
              checkmarkColor: itemColor,
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
    if (_useMultiFilter) {
      widget.onMultiFilterApplied?.call(FilterData(
        availableCategories: widget.filterData!.availableCategories,
        availableSubCategories: widget.filterData!.availableSubCategories,
        availableEntryTypes: widget.filterData!.availableEntryTypes,
        selectedCategories: Set.from(selectedCategories),
        selectedSubCategories: Set.from(selectedSubCategories),
        selectedEntryTypes: Set.from(selectedEntryTypes),
      ));
    } else {
      widget.onFilterApplied?.call(Set.from(selectedCategories));
    }
  }
  
  Widget _buildFilterExpansionTile({
    required int index,
    required String title,
    required IconData icon,
    required List<String> availableItems,
    required Set<String> selectedItems,
    required Function(Set<String>) onSelectionChanged,
    required ColorScheme colorScheme,
  }) {
    final isExpanded = _expandedFilterIndex == index;
    final hasSelections = selectedItems.isNotEmpty;
    
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _expandedFilterIndex = isExpanded ? -1 : index;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: hasSelections 
                  ? colorScheme.primaryContainer.withOpacity(0.3) 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasSelections 
                    ? colorScheme.primary.withOpacity(0.5) 
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: hasSelections ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (hasSelections) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${selectedItems.length}',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableItems.map((item) {
                final isSelected = selectedItems.contains(item);
                final itemColor = EntryColors.generateColorFromString(item);
                return FilterChip(
                  avatar: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: itemColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  label: Text(item),
                  selected: isSelected,
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
                  checkmarkColor: itemColor,
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
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
  
  Widget _buildLegacyCategoryFilter(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.folder_outlined, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Filter by Category',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (selectedCategories.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${selectedCategories.length}',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
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
          children: widget.availableCategories.map((category) {
            final isSelected = selectedCategories.contains(category);
            final categoryColor = EntryColors.generateColorFromString(category);
            return FilterChip(
              avatar: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: categoryColor,
                  shape: BoxShape.circle,
                ),
              ),
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectedCategories.add(category);
                  } else {
                    selectedCategories.remove(category);
                  }
                });
                _applyFilterLive();
              },
              selectedColor: categoryColor.withOpacity(0.2),
              checkmarkColor: categoryColor,
              side: BorderSide(
                color: isSelected ? categoryColor : colorScheme.outline,
                width: isSelected ? 2 : 1,
              ),
              labelStyle: TextStyle(
                color: isSelected ? categoryColor : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
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
