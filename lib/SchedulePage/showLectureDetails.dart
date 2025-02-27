import 'package:flutter/material.dart';
import '../DetailsPage/DetailRow.dart';
import '../Utils/CustomSnackBar.dart';
import '../Utils/UpdateRecords.dart';
import '../Utils/customSnackBar_error.dart';
import '../Utils/date_utils.dart';
import 'RevisionGraph.dart';

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
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                )
              ],
            ),
            child: Column(
              children: [
                // Handle bar for dragging
                Container(
                  margin: EdgeInsets.only(top: 12),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                // Header with subject and lecture info
                Container(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.menu_book,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lecture $lectureNo',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$selectedSubject ($selectedSubjectCode)',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Divider(height: 32),

                // Revision progress
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: RevisionGraph(
                          datesMissedRevisions: List<String>.from(details['dates_missed_revisions'] ?? []),
                          datesRevised: List<String>.from(details['dates_revised'] ?? []),
                        ),
                      ),
                    ],
                  ),
                ),


                // Details sections
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dates section
                        // _buildSectionHeader(context, 'Important Dates', Icons.calendar_today),
                        Card(
                          elevation: 0,
                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildDateRow(context, 'Learned', details['date_learnt'], Icons.school),
                                Divider(height: 24),
                                _buildDateRow(context, 'Last Revised', details['date_revised'], Icons.history),
                                Divider(height: 24),
                                _buildDateRow(
                                  context,
                                  'Next Scheduled',
                                  details['date_scheduled'],
                                  Icons.event,
                                  // isHighlighted: true,
                                ),
                                Divider(height: 24),
                                _buildDetailItem(
                                  context,
                                  'Frequency',
                                  revisionFrequency,
                                  Icons.timelapse,
                                ),
                                Divider(height: 24),
                                _buildDetailItem(
                                  context,
                                  'Completed',
                                  '${details['no_revision']} revisions',
                                  Icons.check_circle_outline,
                                ),
                                Divider(height: 24),
                                _buildDetailItem(
                                  context,
                                  'Missed',
                                  '${details['missed_revision']} revisions',
                                  Icons.cancel_outlined,
                                  isNegative: int.parse(details['missed_revision'].toString()) > 0,
                                ),
                                Divider(height: 24),
                                _buildDetailItem(
                                  context,
                                  'Description',
                                  details['description'] ?? 'No description',
                                  Icons.description,

                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action button
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.add_circle_outline),
                        label: Text('MARK AS REVISED'),
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
                              customSnackBar_error(
                                context: context,
                                message: 'Failed to add revision: ${e.toString()}',
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// Helper widget for section headers
Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
  return Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    ),
  );
}

// Helper widget for date rows
Widget _buildDateRow(BuildContext context, String label, String date, IconData icon, {bool isHighlighted = false}) {
  return Row(
    children: [
      Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isHighlighted
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isHighlighted
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[600],
        ),
      ),
      SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            date,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
              color: isHighlighted
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    ],
  );
}

// Helper widget for detail items
Widget _buildDetailItem(BuildContext context, String label, String value, IconData icon, {bool isNegative = false}) {
  return Row(
    children: [
      Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isNegative
              ? Colors.red.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isNegative
              ? Colors.red[700]
              : Colors.grey[600],
        ),
      ),
      SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.normal,
              color: isNegative
                  ? Colors.red[700]
                  : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    ],
  );
}