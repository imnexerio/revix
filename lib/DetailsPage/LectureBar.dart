import 'package:flutter/material.dart';
import 'dart:async';
import '../Utils/UnifiedDatabaseService.dart';
import '../widgets/LectureDetailsModal.dart';
import 'ScheduleTableDetailP.dart';

class LectureBar extends StatefulWidget {
  final String selectedSubject;
  final String selectedSubjectCode;

  LectureBar({
    required this.selectedSubject,
    required this.selectedSubjectCode,
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
    if (oldWidget.selectedSubject != widget.selectedSubject ||
        oldWidget.selectedSubjectCode != widget.selectedSubjectCode) {
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
    record['subject'] == widget.selectedSubject &&
        record['subject_code'] == widget.selectedSubjectCode)
        .map<MapEntry<String, dynamic>>((record) =>
        MapEntry(record['lecture_no'] as String, record['details']))
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return LectureDetailsModal(
          lectureNo: lectureNo,
          details: details,
          selectedSubject: widget.selectedSubject,
          selectedSubjectCode: widget.selectedSubjectCode,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> formattedRecords = _filteredLectureData.map((entry) {
      Map<String, dynamic> record = Map<String, dynamic>.from(entry.value);
      record['lecture_no'] = entry.key;
      return record;
    }).toList();

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return ScheduleTableDetailP(
            initialRecords: formattedRecords,
            title: '${widget.selectedSubject} - ${widget.selectedSubjectCode} Details',
            onSelect: (context, record) {
              String lectureNo = record['lecture_no'];
              _showLectureDetails(context, lectureNo, record);
            },
          );
        },
      ),
    );
  }
}
