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
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: widget.lectureData.length,
        itemBuilder: (context, index) {
          final lectureNo = widget.lectureData.keys.elementAt(index);
          final details = widget.lectureData[lectureNo];

          return Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showLectureDetails(context, lectureNo, details),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoChip(
                          details['lecture_type'],
                          backgroundColor: _getTypeColor(details['lecture_type']),
                        ),
                        Text(
                          'Lecture $lectureNo',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildInfoRow(
                      context,
                      'Learned:',
                      details['date_learnt'],
                      'Revised:',
                      details['date_revised'],
                    ),
                    SizedBox(height: 8),
                    _buildInfoRow(
                      context,
                      'Revisions:',
                      details['no_revision'].toString(),
                      'Missed:',
                      details['missed_revision'].toString(),
                      isAlert: int.parse(details['missed_revision'].toString()) > 0,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Text(
                          'Scheduled: ${details['date_scheduled']}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(String text, {required Color backgroundColor}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context,
      String label1,
      String value1,
      String label2,
      String value2, {
        bool isAlert = false,
      }) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                label1,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(width: 4),
              Text(
                value1,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Text(
                label2,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(width: 4),
              Text(
                value2,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isAlert ? Colors.red : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'theory':
        return Colors.blue;
      case 'practical':
        return Colors.green;
      case 'tutorial':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}