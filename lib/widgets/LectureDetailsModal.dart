import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../DetailsPage/DetailRow.dart';
import '../Utils/UpdateRecords.dart';
import '../Utils/date_utils.dart';

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
    fetchFrequencies();
  }

  void fetchFrequencies() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data/custom_frequencies');
      DataSnapshot snapshot = await databaseRef.get();
      if (snapshot.exists) {
        Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          frequencies = data.entries.map((entry) {
            return {
              'title': entry.key,
              'frequency': (entry.value as List<dynamic>).join(', '),
            };
          }).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Error fetching frequencies: ${e.toString()}'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
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
                      items: frequencies.map<DropdownMenuItem<String>>((Map<String, String> frequency) {
                        return DropdownMenuItem<String>(
                          value: frequency['title'],
                          child: Text(frequency['title']!),
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
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('Revision added successfully'),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
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
                                        Text('Failed to add revision: ${e.toString()}'),
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

                                await UpdateRecords(
                                  widget.selectedSubject,
                                  widget.selectedSubjectCode,
                                  widget.lectureNo,
                                  widget.details['date_revised'],
                                  noRevision,
                                  widget.details['date_scheduled'],
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
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('Update successfull'),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
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