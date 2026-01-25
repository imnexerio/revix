import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Utils/UnifiedDatabaseService.dart';
import '../widgets/EntryDetailsModal.dart';
import '../SchedulePage/shared_components/RecordSortingUtils.dart';
import '../SchedulePage/shared_components/SortingBottomSheet.dart';
import '../SchedulePage/shared_components/GridLayoutUtils.dart';
import 'AnimatedCardDetailP.dart';

class EntryBar extends StatefulWidget {
  final String selectedCategory;
  final String selectedCategoryCode;
  final Function(String sortField, bool isAscending)? onSortingChanged;

  const EntryBar({
    Key? key,
    required this.selectedCategory,
    required this.selectedCategoryCode,
    this.onSortingChanged,
  }) : super(key: key);

  @override
  EntryBarState createState() => EntryBarState();
}

class EntryBarState extends State<EntryBar> with SingleTickerProviderStateMixin {
  final UnifiedDatabaseService _recordService = UnifiedDatabaseService();

  // Sorting state
  String currentSortField = 'reminder_time';
  bool isAscending = true;

  // Animation controller for grid
  late AnimationController _gridAnimationController;

  @override
  void initState() {
    super.initState();
    _recordService.initialize();

    _gridAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _gridAnimationController.value = 1.0;

    _loadSortPreferences();
  }

  Future<void> _loadSortPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentSortField = prefs.getString('details_sortField') ?? 'reminder_time';
      isAscending = prefs.getBool('details_isAscending') ?? true;
    });
    widget.onSortingChanged?.call(currentSortField, isAscending);
  }

  Future<void> _saveSortPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('details_sortField', currentSortField);
    await prefs.setBool('details_isAscending', isAscending);
  }

  // Expose sorting info for AppBar
  String get sortField => currentSortField;
  bool get sortAscending => isAscending;

  // Method to show sorting bottom sheet (called from AppBar)
  void showSortingSheet(BuildContext context) {
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
  }

  @override
  void dispose() {
    _gridAnimationController.dispose();
    super.dispose();
  }

  /// Filters records for the current category and subcategory
  List<Map<String, dynamic>> _filterRecords(List<dynamic> allRecords) {
    return allRecords
        .where((record) =>
            record['category'] == widget.selectedCategory &&
            record['sub_category'] == widget.selectedCategoryCode)
        .map<Map<String, dynamic>>((record) {
          Map<String, dynamic> formattedRecord = Map<String, dynamic>.from(record['details']);
          formattedRecord['record_title'] = record['record_title'];
          return formattedRecord;
        })
        .toList();
  }

  void _showEntryDetails(BuildContext context, String entryTitle, dynamic details) {
    if (details is! Map<String, dynamic>) {
      details = Map<String, dynamic>.from(details);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return EntryDetailsModal(
          entryTitle: entryTitle,
          details: details,
          selectedCategory: widget.selectedCategory,
          selectedCategoryCode: widget.selectedCategoryCode,
        );
      },
    );
  }

  void _applySorting(String field, bool ascending) {
    _gridAnimationController.reset();

    setState(() {
      currentSortField = field;
      isAscending = ascending;
    });

    _saveSortPreferences();
    _gridAnimationController.forward();
    widget.onSortingChanged?.call(field, ascending);
  }

  int _calculateColumns(double width) {
    return GridLayoutUtils.calculateColumns(width);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _recordService.allRecordsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            );
          }

          final allRecords = snapshot.data?['allRecords'] as List<dynamic>? ?? [];
          final formattedRecords = _filterRecords(allRecords);

          // Sort records
          final sortedRecords = RecordSortingUtils.sortRecords(
            records: List.from(formattedRecords),
            field: currentSortField,
            ascending: isAscending,
          );

          return _buildRecordsGrid(sortedRecords, colorScheme);
        },
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
              'No records found',
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
                  onSelect: (context, record) {
                    String entryTitle = record['record_title'];
                    _showEntryDetails(context, entryTitle, record);
                  },
                  category: widget.selectedCategory,
                  subCategory: widget.selectedCategoryCode,
                );
              },
            );
          },
        );
      },
    );
  }
}
