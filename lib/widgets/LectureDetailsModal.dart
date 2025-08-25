import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../Utils/CustomFrequencySelector.dart';
import '../SchedulePage/RevisionGraph.dart';
import '../Utils/CustomSnackBar.dart';
import '../Utils/customSnackBar_error.dart';
import '../Utils/MarkAsDoneService.dart';
import '../Utils/lecture_colors.dart';
import '../Utils/FirebaseDatabaseService.dart';
import '../Utils/CalculateCustomNextDate.dart';
import '../Utils/date_utils.dart';
import 'DescriptionCard.dart';
import 'RevisionFrequencyDropdown.dart';

class LectureDetailsModal extends StatefulWidget {
  final String lectureNo;
  final Map<String, dynamic> details;
  final String selectedCategory;
  final String selectedCategoryCode;

  LectureDetailsModal({
    required this.lectureNo,
    required this.details,
    required this.selectedCategory,
    required this.selectedCategoryCode,
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
  late String entryType;
  List<String> availableEntryTypes = [];
  Map<String, dynamic> customFrequencyParams = {};
  String duration = 'Forever';
  Map<String, dynamic> durationData = {
    "type": "forever",
    "numberOfTimes": null,
    "endDate": null
  };
  
  // Alarm type field
  late int alarmType;
  final List<String> _alarmOptions = ['No Reminder', 'Notification Only', 'Vibration Only', 'Sound', 'Sound + Vibration', 'Loud Alarm'];
  
  // Track if frequency has been changed to show appropriate message
  bool frequencyChanged = false;

  @override
  void initState() {
    super.initState();
    revisionFrequency = widget.details['recurrence_frequency'];
    isEnabled = widget.details['status'] == 'Enabled'; // Always initialize from widget details
    noRevision = widget.details['completion_counts'];
    formattedTime = widget.details['reminder_time'];
    dateScheduled = widget.details['scheduled_date']; // Initialize with current scheduled date
    entryType = widget.details['entry_type'] ?? '';
    alarmType = widget.details['alarm_type'] ?? 0; // Initialize alarm type with default 0
    _descriptionController = TextEditingController(
      text: widget.details['description'] ?? 'No description available',
    );
    customFrequencyParams = Map<String, dynamic>.from(
      widget.details['recurrence_data']['custom_params'] ?? {},
    );
    durationData = {
      "type": widget.details['duration']['type'],
      "numberOfTimes": widget.details['duration']['numberOfTimes'],
      "endDate": widget.details['duration']['endDate'],
    };

    // Set the correct duration display value based on durationData
    if (durationData["type"] == "forever") {
      duration = "Forever";
    } else if (durationData["type"] == "specificTimes") {
      duration = "Specific Number of Times";
    } else if (durationData["type"] == "until") {
      duration = "Until";
    }
    
    // Load available entry types
    _loadEntryTypes();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadEntryTypes() async {
    try {
      final databaseService = FirebaseDatabaseService();
      final types = await databaseService.fetchCustomTrackingTypes();
      setState(() {
        availableEntryTypes = types;
        // Ensure current entry type is in the list if not already
        if (entryType.isNotEmpty && !availableEntryTypes.contains(entryType)) {
          availableEntryTypes.add(entryType);
        }
      });
    } catch (e) {
      // Handle error - maybe show a snackbar or use default types
      setState(() {
        availableEntryTypes = [entryType]; // At least include current type
      });
    }
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

          // Header with category and lecture info
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
                        '${widget.selectedCategory} · ${widget.selectedCategoryCode} · ${widget.lectureNo}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () {
                          // Show entry type selection dialog
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Select Entry Type'),
                                content: SizedBox(
                                  width: double.minPositive,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: availableEntryTypes.length,
                                    itemBuilder: (context, index) {
                                      String type = availableEntryTypes[index];
                                      return ListTile(
                                        leading: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: LectureColors.generateColorFromString(type),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        title: Text(type),
                                        trailing: entryType == type ? const Icon(Icons.check) : null,
                                        onTap: () {
                                          setState(() {
                                            entryType = type;
                                            widget.details['entry_type'] = type;
                                          });
                                          Navigator.of(context).pop();
                                        },
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: LectureColors.generateColorFromString(entryType),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entryType,
                              style: TextStyle(
                                fontSize: 16,
                                color: LectureColors.generateColorFromString(entryType),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
                          dateLearnt: widget.details['date_initiated'],
                          datesMissedRevisions: List.from(widget.details['dates_missed_revisions'] ?? []),
                          datesRevised: List.from(widget.details['dates_updated'] ?? []),
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

                  // const SizedBox(height: 12),
                  DescriptionCard(
                    details: widget.details,
                    onDescriptionChanged: (text) {
                      setState(() {
                        widget.details['description'] = text;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),          // Action buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('MARK AS DONE'),
                      onPressed: () => MarkAsDoneService.markAsDone(
                        context: context,
                        category: widget.selectedCategory,
                        subCategory: widget.selectedCategoryCode,
                        lectureNo: widget.lectureNo,
                      ),
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
                          List<String> datesRevised = List<String>.from(widget.details['dates_updated'] ?? []);
                          
                          // Use the already calculated dateScheduled value (no need to recalculate)
                          String finalDateScheduled = dateScheduled;
                          Map<String, dynamic> revisionData = {
                            'frequency': revisionFrequency,
                          };
                          if(customFrequencyParams.isNotEmpty) {
                            revisionData['custom_params'] = customFrequencyParams;
                          }

                          // Set alarm type to 0 if "All Day" is selected
                          int finalAlarmType = formattedTime == 'All Day' ? 0 : alarmType;

                          // Use FirebaseDatabaseService directly instead of wrapper
                          final databaseService = FirebaseDatabaseService();
                          
                          // Prepare update data
                          Map<String, dynamic> updateData = {
                            'reminder_time': formattedTime,
                            'date_updated': widget.details['date_updated'],
                            'completion_counts': noRevision,
                            'scheduled_date': finalDateScheduled,
                            'missed_counts': widget.details['missed_counts'],
                            'dates_missed_revisions': datesMissedRevisions,
                            'recurrence_frequency': revisionFrequency,
                            'status': isEnabled ? 'Enabled' : 'Disabled',
                            'dates_updated': datesRevised,
                            'description': widget.details['description'],
                            'recurrence_data': revisionData,
                            'duration': durationData,
                            'alarm_type': finalAlarmType,
                            'entry_type': entryType,
                          };
                          
                          // Update record using centralized service
                          bool success = await databaseService.updateRecord(
                            widget.selectedCategory, 
                            widget.selectedCategoryCode, 
                            widget.lectureNo, 
                            updateData
                          );
                          
                          if (!success) {
                            throw Exception('Failed to update record');
                          }

                          Navigator.pop(context);
                          Navigator.pop(context);


                            customSnackBar(
                              context: context,
                              message: '${widget.selectedCategory} ${widget.selectedCategoryCode} ${widget.lectureNo}, updated. Next schedule is on $finalDateScheduled.',
                          );
                        } catch (e) {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }

                            customSnackBar_error(
                              context: context,
                              message: 'Update Failed: ${e.toString()}',
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
    String completionValue = _getCompletionValue();
    
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
            Theme.of(context).colorScheme.primary,                () async {
              // Show options: "All Day" or "Set Time"
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Reminder Time'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.access_time),
                          title: const Text('Set Specific Time'),
                          onTap: () async {
                            Navigator.of(context).pop();
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
                                // Reset alarm type to "No Reminder" when switching from "All Day" to a specific time
                                // The alarm type dropdown will now be visible for user selection
                              });
                            }
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.all_inclusive),
                          title: const Text('All Day'),
                          onTap: () {
                            setState(() {
                              formattedTime = 'All Day';
                              alarmType = 0; // Reset alarm type to "No Reminder" when "All Day" is selected
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
          VerticalDivider(
            thickness: 1,
            color: Colors.grey.withOpacity(0.2),
          ),
          const SizedBox(width: 8),
          _buildClickableStatusItem(
            context,
            "Completed",
            completionValue,
            Icons.check_circle_outline,
            Theme.of(context).colorScheme.secondary,
            () async {
              // Show duration options dialog
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Duration Settings'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.all_inclusive),
                          title: const Text('Forever'),
                          subtitle: const Text('Continue revisions indefinitely'),
                          onTap: () {
                            setState(() {
                              duration = 'Forever';
                              durationData = {
                                "type": "forever",
                                "numberOfTimes": null,
                                "endDate": null
                              };
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.repeat),
                          title: const Text('Specific Number of Times'),
                          subtitle: const Text('Set a target number of revisions'),
                          onTap: () {
                            Navigator.of(context).pop();
                            _showNumberOfTimesDialog();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.event),
                          title: const Text('Until Date'),
                          subtitle: const Text('Continue until a specific date'),
                          onTap: () {
                            Navigator.of(context).pop();
                            _showUntilDatePicker();
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
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
            "Missed",
            "${widget.details['missed_counts']}",
            Icons.cancel_outlined,
            int.parse(widget.details['missed_counts'].toString()) > 0
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
            widget.details['date_initiated'],
            Icons.school_outlined,
            isFirst: true,
          ),
          _buildTimelineItem(
            context,
            "Last Reviewed",
            widget.details['date_updated'] != null ? formatDate(widget.details['date_updated']) : 'NA',
            Icons.history,
          ),
          _buildTimelineItem(
            context,
            "Next Review",
            frequencyChanged ? "Updated to $dateScheduled" : widget.details['scheduled_date'],
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
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const SizedBox(height: 8),
          
          // Wrap the RevisionFrequencyDropdown in a Container with styling
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).cardColor,
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: RevisionFrequencyDropdown(
              revisionFrequency: revisionFrequency,
              onChanged: (String? newValue) async {
                if (newValue != null) {
                  setState(() {
                    revisionFrequency = newValue;
                    frequencyChanged = true; // Mark that frequency has been changed

                    // If custom is selected, show custom options
                    if (newValue == 'Custom') {
                      // print('extractRevisionData: ${extractRevisionData(widget.details)}');
                      showCustomFrequencySelector();
                    } else {
                      customFrequencyParams = Map<String, dynamic>.from(widget.details['recurrence_data']['custom_params']);
                    }
                  });
                  
                  // Calculate and update the next review date immediately
                  await _calculateAndUpdateNextDate(newValue);
                }
              },
            ),
          ),

          const SizedBox(height: 20),

          // Custom frequency description (if selected)
          if (revisionFrequency == 'Custom' && customFrequencyParams.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              // child: Text(              //   getCustomFrequencyDescription(),
              //   style: TextStyle(
              //     fontStyle: FontStyle.italic,
              //     color: Theme.of(context).colorScheme.secondary,
              //   ),
              // ),
            ),

          const SizedBox(height: 20),

          // Alarm Type section (only shown when not "All Day")
          if (formattedTime != 'All Day') ...[
            Text(
              "Alarm Type",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).cardColor,
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: DropdownButtonFormField<int>(
                value: alarmType,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                isExpanded: true,
                items: _alarmOptions.asMap().entries.map((entry) {
                  int index = entry.key;
                  String option = entry.value;
                  return DropdownMenuItem<int>(
                    value: index,
                    child: Text(option),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    alarmType = newValue!;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Status toggle
          Text(
            "Status",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  isEnabled
                      ? "This lecture is enabled for future revisions"
                      : "This lecture is disabled and won't appear in revisions",
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),              Switch(
                value: isEnabled,
                onChanged: (bool newValue) async {
                  setState(() {
                    isEnabled = newValue;
                    // Don't update widget.details['status'] here - only update in local state
                    // The actual data will only be updated when user clicks "SAVE CHANGES"
                    
                    // Mark frequency as changed when enabling a disabled lecture (triggers new date calculation)
                    if (newValue && widget.details['status'] == 'Disabled') {
                      frequencyChanged = true;
                    }
                  });
                  
                  // Recalculate next review date when enabling a disabled lecture
                  if (newValue && widget.details['status'] == 'Disabled') {
                    await _calculateAndUpdateNextDate(revisionFrequency);
                  }
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
    // Check if the date is a special case like "Unspecified" or empty
    if (date == null || date == "Unspecified" || date.isEmpty) {
      return "NA";
    }

    try {
      final DateTime parsedDate = DateTime.parse(date);
      final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm');
      return formatter.format(parsedDate);
    } catch (e) {
      // Handle any parsing errors gracefully
      print("Error parsing date: $date, Error: $e");
      return "Invalid Date";
    }
  }

  String _getCompletionValue() {
    int completionCount = noRevision;
    
    String durationType = durationData['type'] ?? '';
    
    switch (durationType) {
      case 'specificTimes':
        int numberOfTimes = durationData['numberOfTimes'] ?? 0;
        return "$completionCount/$numberOfTimes";
        
      case 'until':
        String endDate = durationData['endDate'] ?? '';
        if (endDate.isNotEmpty) {
          try {
            return "$completionCount/$endDate";
          } catch (e) {
            return "$completionCount/date";
          }
        }
        return "$completionCount/date";
        
      case 'forever':
        return "$completionCount/∞";
        
      default:
        return "$completionCount";
    }
  }

  void _showNumberOfTimesDialog() {
    final controller = TextEditingController(
      text: durationData["numberOfTimes"]?.toString() ?? ''
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Number of Times'),
          content: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Number of Times',
              hintText: 'Enter a value >= 1',
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a value';
              }
              final number = int.tryParse(value);
              if (number == null || number < 1) {
                return 'Value must be at least 1';
              }
              return null;
            },
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                int? parsedValue = int.tryParse(controller.text);
                if (parsedValue != null && parsedValue >= 1) {
                  setState(() {
                    duration = 'Specific Number of Times';
                    durationData = {
                      "type": "specificTimes",
                      "numberOfTimes": parsedValue,
                      "endDate": null
                    };
                  });
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid number (minimum 1)'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showUntilDatePicker() {
    final initialDate = durationData["endDate"] != null
        ? DateTime.parse(durationData["endDate"])
        : DateTime.now();

    showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(DateTime.now()) ? initialDate : DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    ).then((pickedDate) {
      if (pickedDate != null) {
        setState(() {
          duration = 'Until';
          durationData = {
            "type": "until",
            "numberOfTimes": null,
            "endDate": pickedDate.toIso8601String().split('T')[0]
          };
        });
      }
    });
  }

  /// Helper method to calculate base date for next review calculation
  DateTime _calculateBaseDate() {
    if (widget.details['date_updated'] != null && widget.details['date_updated'] != 'Unspecified') {
      DateTime lastUpdated = DateTime.parse(widget.details['date_updated']);
      DateTime today = DateTime.now();
      
      // If last updated date is in the past, use today as base
      if (lastUpdated.isBefore(DateTime(today.year, today.month, today.day))) {
        return today;
      } else {
        return lastUpdated;
      }
    } else {
      return DateTime.now();
    }
  }

  /// Helper method to calculate and update next review date
  Future<void> _calculateAndUpdateNextDate(String frequency) async {
    try {
      DateTime baseDate = _calculateBaseDate();
      
      String newDateScheduled;
      if (frequency == 'Custom') {
        Map<String, dynamic> revisionData = _extractRevisionData();
        DateTime nextDateTime = CalculateCustomNextDate.calculateCustomNextDate(
          baseDate,
          revisionData,
        );
        newDateScheduled = nextDateTime.toIso8601String().split('T')[0];
      } else {
        DateTime nextDateTime = await DateNextRevision.calculateNextRevisionDate(
          baseDate,
          frequency,
          noRevision,
        );
        newDateScheduled = nextDateTime.toIso8601String().split('T')[0];
      }
      
      setState(() {
        dateScheduled = newDateScheduled;
      });
    } catch (e) {
      print('Error calculating next review date: $e');
    }
  }

  Future<void> showCustomFrequencySelector() async {
    // Get the actual custom params from the nested structure
    Map<String, dynamic> initialParams = {};

    if (widget.details['recurrence_data'] != null &&
        widget.details['recurrence_data']['custom_params'] != null) {
      initialParams = Map<String, dynamic>.from(widget.details['recurrence_data']['custom_params']);
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
        frequencyChanged = true; // Mark that frequency has been changed
      });
      
      // Recalculate next review date with new custom parameters
      await _calculateAndUpdateNextDate('Custom');
    }
  }

  /// Extract revision data using current state variables (for frequency changes)
  Map<String, dynamic> _extractRevisionData() {
    Map<String, dynamic> revisionData = {
      'frequency': revisionFrequency,
    };
    
    if (customFrequencyParams.isNotEmpty) {
      revisionData['custom_params'] = customFrequencyParams;
    }

    return revisionData;
  }
}