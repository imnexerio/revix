import 'package:flutter/material.dart';
import 'dart:async';
import '../SchedulePage/AnimatedCard.dart';
import '../SchedulePage/ScheduleTable.dart';
import '../SchedulePage/showLectureDetails.dart';
import '../Utils/Code_data_fetch.dart';
import '../Utils/lecture_colors.dart';
import '../widgets/LectureDetailsModal.dart';

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
  List<MapEntry<String, dynamic>> _filteredLectureData = [];
  StreamSubscription? _subscription;
  final _recordsController = StreamController<Map<String, List<Map<String, dynamic>>>>();

  @override
  void initState() {
    super.initState();
    _setupDataListener();
  }

  @override
  void didUpdateWidget(LectureBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubject != widget.selectedSubject ||
        oldWidget.selectedSubjectCode != widget.selectedSubjectCode) {
      _cancelSubscription();
      _setupDataListener();
    }
  }

  void _setupDataListener() {
    try {
      _subscription = listenToCodeData(
        widget.selectedSubject,
        widget.selectedSubjectCode,
      ).listen((data) {
        final filteredLectureData = data.entries
            .where((entry) => !(entry.value['only_once'] == 1 && entry.value['status'] == 'Disabled'))
            .toList();

        setState(() {
          _filteredLectureData = filteredLectureData;
        });

        // Process data and add to stream
        Map<String, List<Map<String, dynamic>>> processedData = _processSnapshot(data, filteredLectureData);
        _recordsController.add(processedData);
      }, onError: (error) {
        _recordsController.addError('Failed to fetch records: $error');
      });
    } catch (e) {
      // Handle errors
      print('Failed to set up listener: $e');
    }
  }

  Map<String, List<Map<String, dynamic>>> _processSnapshot(
      Map<String, dynamic> snapshot,
      List<MapEntry<String, dynamic>> filteredLectureData) {

    List<Map<String, dynamic>> processedData_all = [];

    for (var entry in filteredLectureData) {
      final recordKey = entry.key;
      final recordValue = entry.value;

      if (recordValue['date_scheduled'] == null) continue;

      final Map<String, dynamic> record = {
        'subject': widget.selectedSubject,
        'subject_code': widget.selectedSubjectCode,
        'lecture_no': recordKey.toString(),
        'date_scheduled': recordValue['date_scheduled'],
        'initiated_on': recordValue['initiated_on'],
        'reminder_time': recordValue['reminder_time'] ?? 'All Day',
        'lecture_type': recordValue['lecture_type'],
        'date_learnt': recordValue['date_learnt'],
        'date_revised': recordValue['date_revised'],
        'description': recordValue['description'],
        'missed_revision': recordValue['missed_revision'],
        'dates_missed_revisions': recordValue['dates_missed_revisions'] ?? [],
        'dates_revised': recordValue['dates_revised'] ?? [],
        'no_revision': recordValue['no_revision'],
        'revision_frequency': recordValue['revision_frequency'],
        'status': recordValue['status'],
        'only_once': recordValue['only_once'],
      };

      processedData_all.add(record);

    }
    // print('Processed data : $processedData_all');
    return {
      'records': processedData_all
    };
  }


  void _cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    _cancelSubscription();
    _recordsController.close();
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // Convert _filteredLectureData to List<Map<String, dynamic>> as expected by ScheduleTable
    List<Map<String, dynamic>> formattedRecords = _filteredLectureData.map((entry) {
      Map<String, dynamic> record = Map<String, dynamic>.from(entry.value);
      // Add lecture_no to each record so it can be identified
      record['lecture_no'] = entry.key;
      return record;
    }).toList();

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use a single ScheduleTable for all lectures
          return ScheduleTable(
            initialRecords: formattedRecords,
            title: '${widget.selectedSubject ?? ''} - ${widget.selectedSubjectCode ?? ''} Details',
            onSelect: (context, record) {
              String lectureNo = record['lecture_no'];
              _showLectureDetails(context, lectureNo, record);
            },
          );
        },
      ),
    );
  }

  int _calculateColumns(double width) {
    if (width < 600) return 1;         // Mobile
    if (width < 900) return 2;         // Tablet
    if (width < 1200) return 3;        // Small desktop
    if (width < 1500) return 4;        // Medium desktop
    return 5;                          // Large desktop
  }
}