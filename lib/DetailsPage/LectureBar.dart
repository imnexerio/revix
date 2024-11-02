import 'package:flutter/material.dart';

import '../widgets/LectureDetailsModal.dart';

class LectureBar extends StatefulWidget {
  final Map<String, dynamic> lectureData;
  final String selectedSubject;
  final String selectedSubjectCode;

  LectureBar({
    required this.lectureData,
    required this.selectedSubject,
    required this.selectedSubjectCode,
  });

  @override
  _LectureBarState createState() => _LectureBarState();
}

class _LectureBarState extends State<LectureBar> {
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
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  showCheckboxColumn: false,
                  columns: [
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Lecture No')),
                    DataColumn(label: Text('Date Learned')),
                    DataColumn(label: Text('Date Revised')),
                    DataColumn(label: Text('No. of Revisions')),
                    DataColumn(label: Text("Next Revision")),
                    DataColumn(label: Text('Missed revisions')),
                  ],
                  rows: widget.lectureData.entries.map((entry) {
                    final lectureNo = entry.key;
                    final details = entry.value;
                    return DataRow(
                      cells: [
                        DataCell(Text(details['lecture_type'])),
                        DataCell(Text(lectureNo)),
                        DataCell(Text(details['date_learnt'])),
                        DataCell(Text(details['date_revised'])),
                        DataCell(Text(details['no_revision'].toString())),
                        DataCell(Text(details['date_scheduled'])),
                        DataCell(Text(details['missed_revision'].toString())),
                      ],
                      onSelectChanged: (_) => _showLectureDetails(context, lectureNo, details),
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}