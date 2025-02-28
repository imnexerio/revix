import 'package:flutter/material.dart';
import '../DetailsPage/DetailRow.dart';
import '../Utils/CustomSnackBar.dart';
import '../Utils/UpdateRecords.dart';
import '../Utils/customSnackBar_error.dart';
import '../Utils/date_utils.dart';
import 'RevisionFrequencyDropdown.dart';

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
  List<Map<String, String>> frequencies = [];

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
                  '${widget.selectedSubject} ${widget.selectedSubjectCode} ${widget.lectureNo} Details',
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
                    DetailRow(label: "Subject", value: widget.selectedSubject),
                    DetailRow(label: "Subject Code", value: widget.selectedSubjectCode),
                    DetailRow(label: 'Lecture No', value: widget.lectureNo),
                    DetailRow(label: 'Date Learned', value: widget.details['date_learnt']),
                    DetailRow(label: 'Date Revised', value: widget.details['date_revised']),
                    DetailRow(label: 'Next Scheduled', value: widget.details['date_scheduled']),
                    DetailRow(label: 'No. of Revisions', value: widget.details['no_revision'].toString()),
                    DetailRow(label: 'Missed Revisions', value: widget.details['missed_revision'].toString()),
                    DetailRow(label: 'Description', value: widget.details['description']),
                    SizedBox(height: 16),

                    RevisionFrequencyDropdown(
                      revisionFrequency: revisionFrequency,
                      onChanged: (String? newValue) {
                        setState(() {
                          revisionFrequency = newValue!;
                        });
                      },
                    ),


                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
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
                            label: Text('MARK AS DONE'),
                            onPressed: () async {
                              try {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext context) {
                                    return Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                );

                                if(!isEnabled) {
                                  Navigator.pop(context);
                                  throw 'Cannot mark as done when the status is disabled';
                                }

                                String dateRevised = DateTime.now().toIso8601String().split('T')[0];
                                int missedRevision = (widget.details['missed_revision'] as num).toInt();
                                DateTime scheduledDate = DateTime.parse(widget.details['date_scheduled'].toString());
                                String dateScheduled = (await DateNextRevision.calculateNextRevisionDate(
                                  scheduledDate,
                                  revisionFrequency,
                                  noRevision + 1,
                                )).toIso8601String().split('T')[0];

                                if (scheduledDate.toIso8601String().split('T')[0].compareTo(dateRevised) < 0) {
                                  missedRevision += 1;
                                }
                                List<String> datesMissedRevisions = List<String>.from(widget.details['dates_missed_revisions'] ?? []);

                                if (scheduledDate.isBefore(DateTime.parse(dateRevised))) {
                                  datesMissedRevisions.add(scheduledDate.toIso8601String().split('T')[0]);
                                }
                                List<String> datesRevised = List<String>.from(widget.details['dates_revised'] ?? []);
                                datesRevised.add(dateRevised);

                                await UpdateRecords(
                                  widget.selectedSubject,
                                  widget.selectedSubjectCode,
                                  widget.lectureNo,
                                  dateRevised,
                                  noRevision + 1,
                                  dateScheduled,
                                  datesRevised,
                                  missedRevision,
                                  datesMissedRevisions,
                                  revisionFrequency,
                                  isEnabled ? 'Enabled' : 'Disabled',
                                );

                                Navigator.pop(context);
                                Navigator.pop(context);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  customSnackBar(
                                    context: context,
                                    message: '${widget.selectedSubject} ${widget.selectedSubjectCode} ${widget.lectureNo}, done. Next schedule is on $dateScheduled.',
                                  ),
                                );
                              } catch (e) {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  customSnackBar_error(
                                    context: context,
                                    message: 'Failed to mark as done: ${e.toString()}',
                                  ),
                                );
                              }
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
                            onPressed: () async {
                              try {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext context) {
                                    return Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                );
                                List<String> datesMissedRevisions = List<String>.from(widget.details['dates_missed_revisions'] ?? []);

                                // Retrieve the existing dates_revised list
                                List<String> datesRevised = List<String>.from(widget.details['dates_revised'] ?? []);

                                String dateScheduled = widget.details['date_scheduled'];

                                if (isEnabled && widget.details['status'] == 'Disabled' && DateTime.parse(widget.details['date_scheduled']).isBefore(DateTime.now())) {
                                  dateScheduled = DateTime.now().toIso8601String().split('T')[0];;
                                }

                                await UpdateRecords(
                                  widget.selectedSubject,
                                  widget.selectedSubjectCode,
                                  widget.lectureNo,
                                  widget.details['date_revised'],
                                  noRevision,
                                  dateScheduled,
                                  datesRevised,
                                  widget.details['missed_revision'],
                                  datesMissedRevisions,
                                  revisionFrequency,
                                  isEnabled ? 'Enabled' : 'Disabled',
                                );

                                Navigator.pop(context);
                                Navigator.pop(context);

                                // await refreshRecords();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  customSnackBar(
                                    context: context,
                                    message: '${widget.selectedSubject} ${widget.selectedSubjectCode} ${widget.lectureNo}, updated. Next schedule is on $dateScheduled.',
                                  ),
                                );
                              } catch (e) {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('Update Failed: ${e.toString()}'),
                                      ],
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 3),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
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