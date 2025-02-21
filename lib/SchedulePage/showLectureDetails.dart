import 'package:flutter/material.dart';

import '../DetailsPage/DetailRow.dart';
import '../Utils/CustomSnackBar.dart';
import '../Utils/UpdateRecords.dart';
import '../Utils/date_utils.dart';


void showLectureDetails(BuildContext context, Map<String, dynamic> details, Function() refreshRecords) {
  String revisionFrequency = details['revision_frequency'];
  int noRevision = details['no_revision'];
  bool isEnabled = details['status'] == 'Enabled';
  String lectureNo = details['lecture_no'];
  String selectedSubject = details['subject'];
  String selectedSubjectCode = details['subject_code'];

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
                        '$selectedSubject $selectedSubjectCode $lectureNo Details',
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
                          DetailRow(label: "Type", value: details['lecture_type']),
                          DetailRow(label: 'Subject', value: selectedSubject),
                          DetailRow(label: 'Subject Code', value: selectedSubjectCode),
                          DetailRow(label: 'Lecture No', value: lectureNo),
                          DetailRow(label: 'Date Learned', value: details['date_learnt']),
                          DetailRow(label: 'Date Revised', value: details['date_revised']),
                          DetailRow(label: 'Scheduled Date', value: details['date_scheduled']),
                          DetailRow(label: 'Revision Frequency', value: revisionFrequency),
                          DetailRow(label: 'No. of Revisions', value: details['no_revision'].toString()),
                          DetailRow(label: 'Missed Revisions', value: details['missed_revision'].toString()),
                          DetailRow(label: 'Description', value: details['description']),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.add),
                                  label: Text('Add Revision'),
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

                                      String dateRevised = DateTime.now().toIso8601String().split('T')[0];
                                      int missedRevision = (details['missed_revision'] as num).toInt();
                                      DateTime scheduledDate = DateTime.parse(details['date_scheduled'].toString());
                                      String dateScheduled = (await DateNextRevision.calculateNextRevisionDate(
                                        scheduledDate,
                                        revisionFrequency,
                                        noRevision + 1,
                                      )).toIso8601String().split('T')[0];

                                      if (scheduledDate.toIso8601String().split('T')[0].compareTo(dateRevised) < 0) {
                                        missedRevision += 1;
                                      }
                                      List<String> datesMissedRevisions = List<String>.from(details['dates_missed_revisions'] ?? []);

                                      if (scheduledDate.isBefore(DateTime.parse(dateRevised))) {
                                        datesMissedRevisions.add(scheduledDate.toIso8601String().split('T')[0]);
                                      }
                                      List<String> datesRevised = List<String>.from(details['dates_revised'] ?? []);
                                      datesRevised.add(dateRevised);

                                      await UpdateRecords(
                                        selectedSubject,
                                        selectedSubjectCode,
                                        lectureNo,
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

                                      await refreshRecords();

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        customSnackBar(
                                          context: context,
                                          message: 'Revision added successfully',
                                        ),
                                      );
                                    } catch (e) {
                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        customSnackBar(
                                          context: context,
                                          message: 'Failed to add revision: ${e.toString()}',
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