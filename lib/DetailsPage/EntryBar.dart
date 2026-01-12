import 'package:flutter/material.dart';
import '../Utils/UnifiedDatabaseService.dart';
import '../widgets/EntryDetailsModal.dart';
import 'ScheduleTableDetailP.dart';

class EntryBar extends StatefulWidget {
  final String selectedCategory;
  final String selectedCategoryCode;

  EntryBar({
    required this.selectedCategory,
    required this.selectedCategoryCode,
  });

  @override
  _EntryBarState createState() => _EntryBarState();
}

class _EntryBarState extends State<EntryBar> {
  final UnifiedDatabaseService _recordService = UnifiedDatabaseService();

  @override
  void initState() {
    super.initState();
    _recordService.initialize();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _recordService.allRecordsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }

          final allRecords = snapshot.data?['allRecords'] as List<dynamic>? ?? [];
          final formattedRecords = _filterRecords(allRecords);

          return LayoutBuilder(
            builder: (context, constraints) {
              return ScheduleTableDetailP(
                initialRecords: formattedRecords,
                title: '${widget.selectedCategory} - ${widget.selectedCategoryCode}',
                category: widget.selectedCategory,
                subCategory: widget.selectedCategoryCode,
                onSelect: (context, record) {
                  String entryTitle = record['record_title'];
                  _showEntryDetails(context, entryTitle, record);
                },
              );
            },
          );
        },
      ),
    );
  }
}
