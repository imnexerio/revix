import 'package:flutter/material.dart';
import 'dart:async';
import '../Utils/Code_data_fetch.dart';
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

      }, onError: (error) {
        _recordsController.addError('Failed to fetch records: $error');
      });
    } catch (e) {
      // Handle errors
      // print('Failed to set up listener: $e');
    }
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
    List<Map<String, dynamic>> formattedRecords = _filteredLectureData.map((entry) {
      Map<String, dynamic> record = Map<String, dynamic>.from(entry.value);
      record['lecture_no'] = entry.key;
      return record;
    }).toList();

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use a single ScheduleTable for all lectures
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