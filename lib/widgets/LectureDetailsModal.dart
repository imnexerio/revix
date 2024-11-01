import 'package:flutter/material.dart';
import '../DetailRow.dart';
import '../UpdateRecords.dart';
import 'date_utils.dart';


class LectureDetailsModal extends StatefulWidget {
  final String lectureNo;
  final Map<String, dynamic> details;
  final String selectedSubject;
  final String selectedSubjectCode;

  LectureDetailsModal({
    required this.lectureNo,
    required this.details,
    required this.selectedSubject,
    required this.selectedSubjectCode,
  });

  @override
  _LectureDetailsModalState createState() => _LectureDetailsModalState();
}

class _LectureDetailsModalState extends State<LectureDetailsModal> {
  late String revisionFrequency;
  late int noRevision;
  late bool isEnabled;

  @override
  void initState() {
    super.initState();
    revisionFrequency = widget.details['revision_frequency'];
    noRevision = widget.details['no_revision'];
    isEnabled = widget.details['status'] == 'Enabled';
  }

  @override
  Widget build(BuildContext context) {
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
                  'Lecture ${widget.lectureNo} Details',
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
                    DetailRow(label: "Type", value: widget.details['lecture_type']),
                    DetailRow(label: 'Lecture No', value: widget.lectureNo),
                    DetailRow(label: 'Date Learned', value: widget.details['date_learnt']),
                    DetailRow(label: 'Date Revised', value: widget.details['date_revised']),
                    DetailRow(label: 'No. of Revisions', value: widget.details['no_revision'].toString()),
                    DetailRow(label: 'Next Revision', value: widget.details['date_scheduled']),
                    DetailRow(label: 'Missed Revisions', value: widget.details['missed_revision'].toString()),
                    DetailRow(label: 'Description', value: widget.details['description']),
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
                                int missedRevision = (widget.details['missed_revision'] as num).toInt();
                                DateTime scheduledDate = DateTime.parse(widget.details['date_scheduled'].toString());
                                String dateScheduled = DateNextRevision.calculateScheduledDate(
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
                                  widget.lectureNo,
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
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.add),
                            label: Text('Save Changes'),
                            onPressed: () {
                              String dateScheduled = DateNextRevision.calculateScheduledDate(
                                DateTime.now(),
                                revisionFrequency,
                                noRevision,
                              ).toIso8601String().split('T')[0];
                              String dateRevised = DateTime.now().toIso8601String().split('T')[0];

                              UpdateRecords(
                                widget.selectedSubject,
                                widget.selectedSubjectCode,
                                widget.lectureNo,
                                dateRevised,
                                noRevision,
                                dateScheduled,
                                widget.details['missed_revision'],
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
                          ),
                        ),
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
  }
}