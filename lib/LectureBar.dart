import 'package:flutter/material.dart';
import 'UpdateRecords.dart';

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

    String revisionFrequency = details['revision_frequency'];
    int noRevision = details['no_revision'];
    bool isEnabled = details['status'] == 'Enabled';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lecture $lectureNo Details',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Divider(),
                    SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _detailRow("Type", details['lecture_type']),
                            _detailRow('Lecture No', lectureNo),
                            _detailRow('Date Learned', details['date_learnt']),
                            _detailRow('Date Revised', details['date_revised']),
                            _detailRow('No. of Revisions', details['no_revision'].toString()),
                            _detailRow('Next Revision', details['date_scheduled']),
                            _detailRow('Missed Revisions', details['missed_revision'].toString()),
                            _detailRow('Description', details['description']),
                            SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Revision Frequency',
                                labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                                border: OutlineInputBorder(),
                              ),
                              value: revisionFrequency,
                              onChanged: (String? newValue) {
                                setState(() {
                                  revisionFrequency = newValue!;
                                });
                              },
                              items: [
                                'Daily',
                                '2 Day',
                                '3 Day',
                                'Weekly',
                                'Default',
                              ].map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              style: TextStyle(color: Theme.of(context).colorScheme.primary),
                              dropdownColor: Theme.of(context).colorScheme.surface,
                            ),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Status', style: Theme.of(context).textTheme.titleMedium),
                                Switch(
                                  value: isEnabled,
                                  onChanged: (bool newValue) {
                                    setState(() {
                                      isEnabled = newValue;
                                    });
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: Icon(Icons.add),
                                      label: Text('Add Revision'),
                                      onPressed: () {
                                        setState(() {
                                          noRevision += 1;
                                          String dateRevised = DateTime.now().toIso8601String().split('T')[0];
                                          int missedRevision = (details['missed_revision'] as num).toInt();
                                          DateTime scheduledDate = DateTime.parse(details['date_scheduled'].toString());
                                          String dateScheduled = _calculateScheduledDate(
                                            scheduledDate,
                                            revisionFrequency,
                                            noRevision,
                                          ).toIso8601String().split('T')[0];

                                          if (scheduledDate.toIso8601String().split('T')[0].compareTo(dateRevised) < 0) {
                                            missedRevision += 1;
                                          }

                                          UpdateRecords(
                                            widget.selectedSubject,
                                            widget.selectedSubjectCode,
                                            lectureNo,
                                            dateRevised,
                                            noRevision,
                                            dateScheduled,
                                            missedRevision,
                                            revisionFrequency,
                                            isEnabled ? 'Enabled' : 'Disabled',
                                          );
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16), // Add spacing between the buttons
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: Icon(Icons.add),
                                      label: Text('Save Changes'),
                                      onPressed: () {
                                        String dateScheduled = _calculateScheduledDate_now(
                                          revisionFrequency,
                                          noRevision,
                                        ).toIso8601String().split('T')[0];
                                        String dateRevised = DateTime.now().toIso8601String().split('T')[0];

                                        UpdateRecords(
                                          widget.selectedSubject,
                                          widget.selectedSubjectCode,
                                          lectureNo,
                                          dateRevised,
                                          noRevision,
                                          dateScheduled,
                                          details['missed_revision'],
                                          revisionFrequency,
                                          isEnabled ? 'Enabled' : 'Disabled',
                                        );
                                        Navigator.pop(context);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      // child: Padding(
                                      //   padding: EdgeInsets.symmetric(vertical: 0),
                                      //   child: Text('Save Changes'),
                                      ),
                                    ),
                                  // ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }

  DateTime _calculateScheduledDate_now(String frequency, int noRevision) {
    DateTime today = DateTime.now();
    switch (frequency) {
      case 'Daily':
        return today.add(Duration(days: 1));
      case '2 Day':
        return today.add(Duration(days: 2));
      case '3 Day':
        return today.add(Duration(days: 3));
      case 'Weekly':
        return today.add(Duration(days: 7));
      case 'Default':
      default:
        List<int> intervals = [1, 3, 7, 15, 30];
        int additionalDays = 0;
        for (int i = 0; i <= noRevision; i++) {
          additionalDays += (i < intervals.length) ? intervals[i] : 30;
        }
        return today.add(Duration(days: additionalDays));
    }
  }

  DateTime _calculateScheduledDate(DateTime scheduledDate, String frequency, int noRevision) {
    switch (frequency) {
      case 'Daily':
        return scheduledDate.add(Duration(days: 1));
      case '2 Day':
        return scheduledDate.add(Duration(days: 2));
      case '3 Day':
        return scheduledDate.add(Duration(days: 3));
      case 'Weekly':
        return scheduledDate.add(Duration(days: 7));
      case 'Default':
      default:
        List<int> intervals = [1, 3, 7, 15, 30];
        int additionalDays = 0;
        for (int i = 0; i <= noRevision; i++) {
          additionalDays += (i < intervals.length) ? intervals[i] : 30;
        }
        return scheduledDate.add(Duration(days: additionalDays));
    }
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
                  // This hides the checkbox column
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
                    print("details_lecture : $details");
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