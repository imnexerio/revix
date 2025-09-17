import 'package:flutter/material.dart';
import 'dart:async';
import '../Utils/UnifiedDatabaseService.dart';
import '../widgets/LectureDetailsModal.dart';
import 'ScheduleTableDetailP.dart';

class LectureBar extends StatefulWidget {
  final String selectedCategory;
  final String selectedCategoryCode;

  LectureBar({
    required this.selectedCategory,
    required this.selectedCategoryCode,
  });

  @override
  _LectureBarState createState() => _LectureBarState();
}

class _LectureBarState extends State<LectureBar> {
  List<dynamic> _allRecords = [];
  List<MapEntry<String, dynamic>> _filteredLectureData = [];
  final UnifiedDatabaseService _recordService = UnifiedDatabaseService();
  Stream<Map<String, dynamic>>? _recordsStream;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _recordService.initialize();
    _recordsStream = _recordService.allRecordsStream;
    _subscribeToStream();
  }

  @override
  void didUpdateWidget(LectureBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory ||
        oldWidget.selectedCategoryCode != widget.selectedCategoryCode) {
      // Reapply filter on the already-cached records.
      _applyFilter();
    }
  }

  void _subscribeToStream() {
    // Cancel any previous subscription to avoid duplicates.
    _subscription?.cancel();
    _subscription = _recordsStream?.listen((data) {
      // Extract the list of records from the data.
      if (data.containsKey('allRecords')) {
        setState(() {
          _allRecords = (data['allRecords'] as List<dynamic>);
          _applyFilter();
        });
      }
    }, onError: (e) {
      // print('Failed to set up listener: $e');
    });
  }

  void _applyFilter() {
    List<MapEntry<String, dynamic>> filteredData = _allRecords
        .where((record) =>
    record['category'] == widget.selectedCategory &&
        record['sub_category'] == widget.selectedCategoryCode)
        .map<MapEntry<String, dynamic>>((record) =>
        MapEntry(record['record_title'] as String, record['details']))
        .toList();

    // Debug print for verification
    // print('Filtered Data: $filteredData');

    _filteredLectureData = filteredData;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _recordService.dispose();
    super.dispose();
  }

  void _showLectureDetails(BuildContext context, String lectureNo, dynamic details) {
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
        return LectureDetailsModal(
          lectureNo: lectureNo,
          details: details,
          selectedCategory: widget.selectedCategory,
          selectedCategoryCode: widget.selectedCategoryCode,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> formattedRecords = _filteredLectureData.map((entry) {
      Map<String, dynamic> record = Map<String, dynamic>.from(entry.value);
      record['record_title'] = entry.key;
      return record;
    }).toList();

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return ScheduleTableDetailP(
            initialRecords: formattedRecords,
            title: '${widget.selectedCategory} - ${widget.selectedCategoryCode}',
            category: widget.selectedCategory,
            subCategory: widget.selectedCategoryCode,
            onSelect: (context, record) {
              String lectureNo = record['record_title'];
              _showLectureDetails(context, lectureNo, record);
            },
          );
        },
      ),
    );
  }
}
