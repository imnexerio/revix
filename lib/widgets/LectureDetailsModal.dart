import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../CustomFrequencySelector.dart';
import '../RecordForm/CalculateCustomNextDate.dart';
import '../SchedulePage/RevisionGraph.dart';
import '../Utils/CustomSnackBar.dart';
import '../Utils/UpdateRecords.dart';
import '../Utils/customSnackBar_error.dart';
import '../Utils/date_utils.dart';
import 'DescriptionCard.dart';
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
  late bool isEnabled;
  late int noRevision;
  late TextEditingController _descriptionController;
  late String formattedTime;
  late String dateScheduled;
  Map<String, dynamic> customFrequencyParams = {};

  @override
  void initState() {
    super.initState();
    revisionFrequency = widget.details['revision_frequency'];
    isEnabled = widget.details['status'] == 'Enabled';
    noRevision = widget.details['no_revision'];
    formattedTime = widget.details['reminder_time'];
    _descriptionController = TextEditingController(
      text: widget.details['description'] ?? 'No description available',
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
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
                        '${widget.selectedSubject} · ${widget.selectedSubjectCode} · ${widget.lectureNo}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.details['lecture_type']}',
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
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
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
                        maxWidth: 300,
                        maxHeight: 300,
                      ),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: RevisionRadarChart(
                          dateLearnt: widget.details['date_learnt'],
                          datesMissedRevisions: List.from(widget.details['dates_missed_revisions'] ?? []),
                          datesRevised: List.from(widget.details['dates_revised'] ?? []),
                        ),
                      ),
                    ),
                  ),
                  // Status card
                  _buildStatusCard(context),

                  const SizedBox(height: 20),

                  // Timeline section
                  Text(
                    "Timeline",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTimelineCard(context),

                  const SizedBox(height: 24),

                  // Description section
                  Text(
                    "Description is che",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DescriptionCard(
                    details: widget.details,
                    onDescriptionChanged: (text) {
                      setState(() {
                        widget.details['description'] = text;
                      });
                    },
                  ),

                  const SizedBox(height: 24),
                  Text(
                    "Review Settings",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRevisionSettingsCard(context),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Action buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
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

                          if(!isEnabled) {
                            Navigator.pop(context);
                            throw 'Cannot mark as done when the status is disabled';
                          }

                          if (widget.details['date_learnt'] == 'Unspecified') {
                            await moveToDeletedData(
                                widget.selectedSubject,
                                widget.selectedSubjectCode,
                                widget.lectureNo,
                                widget.details
                            );

                            Navigator.pop(context);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              customSnackBar(
                                context: context,
                                message: '${widget.selectedSubject} ${widget.selectedSubjectCode} ${widget.lectureNo} has been marked as done and moved to deleted data.',
                              ),
                            );
                            return;
                          }

                          String dateRevised = DateFormat('yyyy-MM-ddTHH:mm').format(DateTime.now());
                          int missedRevision = (widget.details['missed_revision'] as num).toInt();
                          DateTime scheduledDate = DateTime.parse(widget.details['date_scheduled'].toString());

                          if (scheduledDate.toIso8601String().split('T')[0].compareTo(dateRevised) < 0) {
                            missedRevision += 1;
                          }
                          List<String> datesMissedRevisions = List<String>.from(widget.details['dates_missed_revisions'] ?? []);

                          if (scheduledDate.toIso8601String().split('T')[0].compareTo(dateRevised.split('T')[0]) < 0) {
                            datesMissedRevisions.add(scheduledDate.toIso8601String().split('T')[0]);
                          }
                          List<String> datesRevised = List<String>.from(widget.details['dates_revised'] ?? []);
                          datesRevised.add(dateRevised);


                          if (widget.details['no_revision'] < 0) {
                            datesRevised = [];
                          }

                            if (widget.details['revision_frequency']== 'No Repetition'){
                              await moveToDeletedData(
                                  widget.selectedSubject,
                                  widget.selectedSubjectCode,
                                  widget.lectureNo,
                                  widget.details
                              );

                              Navigator.pop(context);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                customSnackBar(
                                  context: context,
                                  message: '${widget.selectedSubject} ${widget.selectedSubjectCode} ${widget.lectureNo} has been marked as done and moved to deleted data.',
                                ),
                              );
                              return;
                            }else{
                              if (widget.details['revision_frequency'] == 'Custom') {

                                Map<String, dynamic> revisionData = extractRevisionData(widget.details);
                                // print('revisionData: $revisionData');
                                DateTime nextDateTime = CalculateCustomNextDate.calculateCustomNextDate(
                                    DateTime.parse(widget.details['date_scheduled']),
                                    revisionData
                                );
                                dateScheduled = nextDateTime.toIso8601String().split('T')[0];
                              } else {
                                dateScheduled = (await DateNextRevision.calculateNextRevisionDate(
                                  scheduledDate,
                                  revisionFrequency,
                                  noRevision + 1,
                                )).toIso8601String().split('T')[0];
                              }


                          await UpdateRecords(
                            widget.selectedSubject,
                            widget.selectedSubjectCode,
                            widget.lectureNo,
                            dateRevised,
                            widget.details['description'],
                            widget.details['reminder_time'],
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
                          }
                        } catch (e) {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          // print('Error marking as done: $e');
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('SAVE CHANGES'),
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
                                        "Saving...",
                                        style: TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );

                          List<String> datesMissedRevisions = List<String>.from(widget.details['dates_missed_revisions'] ?? []);
                          List<String> datesRevised = List<String>.from(widget.details['dates_revised'] ?? []);
                          String dateScheduled = widget.details['date_scheduled'];

                          if (isEnabled && widget.details['status'] == 'Disabled' &&
                              DateTime.parse(widget.details['date_scheduled']).isBefore(DateTime.now())) {
                            dateScheduled = DateTime.now().toIso8601String().split('T')[0];
                          }

                          await UpdateRecords(
                            widget.selectedSubject,
                            widget.selectedSubjectCode,
                            widget.lectureNo,
                            widget.details['date_revised'],
                            widget.details['description'],
                            formattedTime,
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
                            customSnackBar_error(
                              context: context,
                              message: 'Update Failed: ${e.toString()}',
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Theme.of(context).colorScheme.onSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
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
          _buildClickableStatusItem(
            context,
            "Timing",
            formattedTime, // Changed from widget.details['reminder_time'] to formattedTime
            Icons.refresh,
            Theme.of(context).colorScheme.primary,
                () async {
              TimeOfDay? pickedTime = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
                builder: (BuildContext context, Widget? child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                    child: child!,
                  );
                },
              );

              if (pickedTime != null) {
                final now = DateTime.now();
                setState(() {
                  formattedTime = DateFormat('HH:mm').format(
                    DateTime(now.year, now.month, now.day, pickedTime.hour, pickedTime.minute),
                  );
                });
              }
            },
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
            "${widget.details['missed_revision']}",
            Icons.cancel_outlined,
            int.parse(widget.details['missed_revision'].toString()) > 0
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurface,
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

  Widget _buildClickableStatusItem(BuildContext context, String label, String value, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
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
      ),
    );
  }

  Widget _buildTimelineCard(BuildContext context) {
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
            widget.details['date_learnt'],
            Icons.school_outlined,
            isFirst: true,
          ),
          _buildTimelineItem(
            context,
            "Last Reviewed",
            widget.details['date_revised'] != null ? formatDate(widget.details['date_revised']) : 'NA',
            Icons.history,
          ),
          _buildTimelineItem(
            context,
            "Next Review",
            widget.details['date_scheduled'],
            Icons.event_outlined,
            isLast: true,
            isHighlighted: true,
          ),
        ],
      ),
    );
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


  Widget _buildRevisionSettingsCard(BuildContext context) {
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Review Frequency",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RevisionFrequencyDropdown(
                      revisionFrequency: revisionFrequency,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            revisionFrequency = newValue;

                            // If custom is selected, show custom options
                            if (newValue == 'Custom') {
                              // print('extractRevisionData: ${extractRevisionData(widget.details)}');
                              showCustomFrequencySelector();
                            } else {
                              // Clear custom parameters if not using custom
                              customFrequencyParams = {};
                            }

                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Status toggle
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Status",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEnabled
                          ? "This lecture is enabled for future revisions"
                          : "This lecture is disabled and won't appear in revisions",
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: (bool newValue) {
                  setState(() {
                    isEnabled = newValue;
                  });
                },
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ],
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

  Future<void> showCustomFrequencySelector() async {
    // Get the actual custom params from the nested structure
    Map<String, dynamic> initialParams = {};

    if (widget.details['revision_data'] != null &&
        widget.details['revision_data']['custom_params'] != null) {
      initialParams = Map<String, dynamic>.from(widget.details['revision_data']['custom_params']);
    }

    // For debugging
    // print('Passing initialParams to CustomFrequencySelector: $initialParams');

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return CustomFrequencySelector(
          initialParams: initialParams,
        );
      },
    );

    if (result != null) {
      setState(() {
        customFrequencyParams = result;
        // Update the nested structure too
        if (widget.details['revision_data'] == null) {
          widget.details['revision_data'] = {};
        }
        widget.details['revision_data']['custom_params'] = result;
      });
    }
  }

  Map<String, dynamic> extractRevisionData(Map<String, dynamic> details) {
    Map<String, dynamic> revisionData = {};

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

    return revisionData;
  }

}