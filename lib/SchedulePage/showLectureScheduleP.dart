import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../RecordForm/CalculateCustomNextDate.dart';
import '../Utils/CustomSnackBar.dart';
import '../Utils/UpdateRecords.dart';
import '../Utils/customSnackBar_error.dart';
import '../Utils/date_utils.dart';
import '../widgets/DescriptionCard.dart';
import 'RevisionGraph.dart';


void showLectureScheduleP(BuildContext context, Map<String, dynamic> details) {
  String description = details['description'] ?? '';
  String dateScheduled = details['date_scheduled'] ?? '';

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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, -2),
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              children: [
                // Handle bar for dragging
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                // Header with subject and lecture info
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.menu_book,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${details['subject']} · ${details['subject_code']} · ${details['lecture_no']}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${details['lecture_type']} · ${details['reminder_time']}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),

                // Details sections
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 300, // Maximum width to prevent the chart from becoming too large
                              maxHeight: 300, // Maximum height to maintain aspect ratio
                            ),
                            child: AspectRatio(
                              aspectRatio: 1.0, // Keep the chart perfectly circular
                              child: RevisionRadarChart(
                                dateLearnt: details['date_learnt'],
                                datesMissedRevisions: List.from(details['dates_missed_revisions'] ?? []),
                                datesRevised: List.from(details['dates_revised'] ?? []),
                              ),
                            ),
                          ),
                        ),
                        // Status card
                        _buildStatusCard(context, details),

                        const SizedBox(height: 20),

                        // Dates section
                        Text(
                          "Timeline",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTimelineCard(context, details),

                        const SizedBox(height: 24),

                        Text(
                          "Description",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DescriptionCard(
                          details: details,
                          onDescriptionChanged: (text) {
                            setState(() {
                              description = text;
                              details['description'] = text;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Action button
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('MARK AS DONE'),
                        onPressed: () async {
                          try {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext context) {
                                return Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text(
                                          "Updating...",
                                          style: TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );

                            if (details['date_learnt'] == 'Unspecified') {
                              await moveToDeletedData(
                                  details['subject'],
                                  details['subject_code'],
                                  details['lecture_no'],
                                  details
                              );

                              Navigator.pop(context);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                customSnackBar(
                                  context: context,
                                  message: '${details['subject']} ${details['subject_code']} ${details['lecture_no']} has been marked as done and moved to deleted data.',
                                ),
                              );
                              return;
                            }

                            String dateRevised = DateFormat('yyyy-MM-ddTHH:mm').format(DateTime.now());
                            int missedRevision = (details['missed_revision'] as num).toInt();
                            DateTime scheduledDate = DateTime.parse(details['date_scheduled'].toString());

                            if (scheduledDate.toIso8601String().split('T')[0].compareTo(dateRevised.split('T')[0]) < 0) {
                              missedRevision += 1;
                            }

                            List<String> datesMissedRevisions = List<String>.from(details['dates_missed_revisions'] ?? []);

                            if (scheduledDate.toIso8601String().split('T')[0].compareTo(dateRevised.split('T')[0]) < 0) {
                              datesMissedRevisions.add(scheduledDate.toIso8601String().split('T')[0]);
                            }
                            List<String> datesRevised = List<String>.from(details['dates_revised'] ?? []);
                            datesRevised.add(dateRevised);

                            if (details['no_revision'] < 0) {
                              datesRevised = [];
                            }
                            if (details['revision_frequency']== 'No Repetition'){
                              await moveToDeletedData(
                                  details['subject'],
                                  details['subject_code'],
                                  details['lecture_no'],
                                  details
                              );

                              Navigator.pop(context);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                customSnackBar(
                                  context: context,
                                  message: '${details['subject']} ${details['subject_code']} ${details['lecture_no']} has been marked as done and moved to deleted data.',
                                ),
                              );
                              return;
                            }else{
                              if (details['revision_frequency'] == 'Custom') {
                                // First convert the LinkedMap to a proper Map<String, dynamic>
                                print('details: $details');
                                Map<String, dynamic> revisionData = {};

                                // Check if revision_data exists and has the necessary custom_params
                                if (details['revision_data'] != null) {
                                  final rawData = details['revision_data'];
                                  revisionData['frequency'] = rawData['frequency'];

                                  if (rawData['custom_params'] != null) {
                                    Map<String, dynamic> customParams = {};
                                    final rawCustomParams = rawData['custom_params'];

                                    if (rawCustomParams['frequencyType'] != null) {
                                      customParams['frequencyType'] = rawCustomParams['frequencyType'];
                                    }

                                    if (rawCustomParams['value'] != null) {
                                      customParams['value'] = rawCustomParams['value'];
                                    }

                                    if (rawCustomParams['daysOfWeek'] != null) {
                                      customParams['daysOfWeek'] = List<bool>.from(rawCustomParams['daysOfWeek']);
                                    }

                                    revisionData['custom_params'] = customParams;
                                  }
                                }
                                print('revisionData: $revisionData');
                                DateTime nextDateTime = CalculateCustomNextDate.calculateCustomNextDate(
                                    DateTime.parse(details['date_scheduled']),
                                    revisionData
                                );
                                dateScheduled = nextDateTime.toIso8601String().split('T')[0];
                              } else {
                                dateScheduled = (await DateNextRevision.calculateNextRevisionDate(
                                  scheduledDate,
                                  details['revision_frequency'],
                                  details['no_revision'] + 1,
                                )).toIso8601String().split('T')[0];
                              }


                            await UpdateRecords(
                              details['subject'],
                              details['subject_code'],
                              details['lecture_no'],
                              dateRevised,
                              description,
                              details['reminder_time'],
                              details['no_revision'] + 1,
                              dateScheduled,
                              datesRevised,
                              missedRevision,
                              datesMissedRevisions,
                              details['revision_frequency'],
                              details['status'],
                            );

                            Navigator.pop(context);
                            Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                customSnackBar(
                                  context: context,
                                  message: '${details['subject']} ${details['subject_code']} ${details['lecture_no']} done.',
                                ),
                              );
                            }
                          } catch (e) {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              customSnackBar_error(
                                context: context,
                                message: 'Failed : ${e.toString()}',
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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

Widget _buildStatusCard(BuildContext context, Map<String, dynamic> details) {
  String revisionFrequency = details['revision_frequency'];
  int noRevision = details['no_revision'];

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Theme.of(context).colorScheme.surface,
          Theme.of(context).colorScheme.surface.withOpacity(0.9),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        _buildStatusItem(
          context,
          "Frequency",
          revisionFrequency,
          Icons.refresh,
          Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        VerticalDivider(
          thickness: 1,
          color: Colors.grey.withOpacity(0.2),
        ),
        const SizedBox(width: 8),
        _buildStatusItem(
          context,
          "Completed",
          "${noRevision}",
          Icons.check_circle_outline,
          Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(width: 8),
        VerticalDivider(
          thickness: 1,
          color: Colors.grey.withOpacity(0.2),
        ),
        const SizedBox(width: 8),
        _buildStatusItem(
          context,
          "Missed",
          "${details['missed_revision']}",
          Icons.cancel_outlined,
          int.parse(details['missed_revision'].toString()) > 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface,
        ),
      ],
    ),
  );
}

Widget _buildStatusItem(BuildContext context, String label, String value, IconData icon, Color color) {
  return Expanded(
    child: Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 22,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    ),
  );
}

Widget _buildTimelineCard(BuildContext context, Map<String, dynamic> details) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      children: [
        _buildTimelineItem(
          context,
          "Initiated on",
          details['date_learnt'],
          Icons.school_outlined,
          isFirst: true,
        ),
        _buildTimelineItem(
          context,
          "Last Reviewed",
          details['date_revised'] != null ? formatDate(details['date_revised']) : 'NA',
          Icons.history,
        ),
        _buildTimelineItem(
          context,
          "Next Review",
          details['date_scheduled'],
          Icons.event_outlined,
          isLast: true,
          isHighlighted: true,
        ),
      ],
    ),
  );
}

String formatDate(String date) {
  final DateTime parsedDate = DateTime.parse(date);
  final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm');
  return formatter.format(parsedDate);
}

Widget _buildTimelineItem(
    BuildContext context, String label, String date, IconData icon,
    {bool isFirst = false, bool isLast = false, bool isHighlighted = false}) {
  final color = isHighlighted
      ? Theme.of(context).colorScheme.primary
      : Theme.of(context).colorScheme.onSurface;

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isHighlighted
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          if (!isLast)
            Container(
              width: 2,
              height: 40,
              color: Colors.grey.withOpacity(0.3),
            ),
        ],
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
                  color: color,
                ),
              ),
              SizedBox(height: isLast ? 0 : 20),
            ],
          ),
        ),
      ),
    ],
  );
}
