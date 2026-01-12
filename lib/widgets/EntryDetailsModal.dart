import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:revix/Utils/UnifiedDatabaseService.dart';
import '../Utils/CustomFrequencySelector.dart';
import '../SchedulePage/RecurrenceGraph.dart';
import '../Utils/CustomSnackBar.dart';
import '../Utils/customSnackBar_error.dart';
import '../Utils/MarkAsDoneService.dart';
import '../Utils/entry_colors.dart';
import '../Utils/FirebaseDatabaseService.dart';
import '../Utils/CalculateCustomNextDate.dart';
import '../Utils/date_utils.dart';
import '../Utils/FrequencyFormatter.dart';
import 'DescriptionCard.dart';
import 'RecurrenceDropdown.dart';
import 'FrequencyIndicator.dart';

class EntryDetailsModal extends StatefulWidget {
  final String entryTitle;
  final Map<String, dynamic> details;
  final String selectedCategory;
  final String selectedCategoryCode;

  EntryDetailsModal({
    required this.entryTitle,
    required this.details,
    required this.selectedCategory,
    required this.selectedCategoryCode,
  });

  @override
  _EntryDetailsModalState createState() => _EntryDetailsModalState();
}

class _EntryDetailsModalState extends State<EntryDetailsModal> {
  late String recurrenceFrequency;
  late bool isEnabled;
  late int completionCount;
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
  late String trackDates; // 'off', 'on', 'last_30'
  
  // Track if any changes have been made (for dynamic button switching)
  bool hasChanges = false;
  
  // Store original values to detect changes
  late String _originalRecurrenceFrequency;
  late bool _originalIsEnabled;
  late String _originalFormattedTime;
  late String _originalEntryType;
  late int _originalAlarmType;
  late String _originalTrackDates;
  late String _originalDescription;
  late Map<String, dynamic> _originalDurationData;
  late Map<String, dynamic> _originalCustomFrequencyParams;

  @override
  void initState() {
    super.initState();
    recurrenceFrequency = widget.details['recurrence_frequency'];
    isEnabled = widget.details['status'] == 'Enabled'; // Always initialize from widget details
    completionCount = widget.details['completion_counts'];
    formattedTime = widget.details['reminder_time'];
    dateScheduled = widget.details['scheduled_date']; // Initialize with current scheduled date
    entryType = widget.details['entry_type'] ?? '';
    alarmType = widget.details['alarm_type'] ?? 0; // Initialize alarm type with default 0
    trackDates = widget.details['track_dates'] ?? 'last_30'; // 'off', 'on', 'last_30'
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
    
    // Store original values for change detection
    _originalRecurrenceFrequency = recurrenceFrequency;
    _originalIsEnabled = isEnabled;
    _originalFormattedTime = formattedTime;
    _originalEntryType = entryType;
    _originalAlarmType = alarmType;
    _originalTrackDates = trackDates;
    _originalDescription = widget.details['description'] ?? 'No description available';
    _originalDurationData = Map<String, dynamic>.from(durationData);
    _originalCustomFrequencyParams = Map<String, dynamic>.from(customFrequencyParams);
    
    // Load available entry types
    _loadEntryTypes();
  }
  
  /// Check if any field has changed from original values
  void _checkForChanges() {
    bool changed = recurrenceFrequency != _originalRecurrenceFrequency ||
        isEnabled != _originalIsEnabled ||
        formattedTime != _originalFormattedTime ||
        entryType != _originalEntryType ||
        alarmType != _originalAlarmType ||
        trackDates != _originalTrackDates ||
        widget.details['description'] != _originalDescription ||
        durationData['type'] != _originalDurationData['type'] ||
        durationData['numberOfTimes'] != _originalDurationData['numberOfTimes'] ||
        durationData['endDate'] != _originalDurationData['endDate'] ||
        _hasCustomParamsChanged();
    
    if (changed != hasChanges) {
      setState(() {
        hasChanges = changed;
      });
    }
  }
  
  /// Check if custom frequency params have changed
  bool _hasCustomParamsChanged() {
    if (customFrequencyParams.length != _originalCustomFrequencyParams.length) return true;
    for (var key in customFrequencyParams.keys) {
      if (customFrequencyParams[key]?.toString() != _originalCustomFrequencyParams[key]?.toString()) {
        return true;
      }
    }
    return false;
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

          // Header with category and entry info
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
                        '${widget.selectedCategory} · ${widget.selectedCategoryCode} · ${widget.entryTitle}',
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
                                            color: EntryColors.generateColorFromString(type),
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
                                          _checkForChanges();
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
                                color: EntryColors.generateColorFromString(entryType),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entryType,
                              style: TextStyle(
                                fontSize: 16,
                                color: EntryColors.generateColorFromString(entryType),
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
                        child: trackDates != 'off' 
                          ? RecurrenceRadarChart(
                              dateInitiated: widget.details['date_initiated'],
                              datesMissedReviews: List.from(widget.details['dates_missed_reviews'] ?? []),
                              datesReviewed: List.from(widget.details['dates_updated'] ?? []),
                              datesSkipped: List.from(widget.details['skipped_dates'] ?? []),
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history_toggle_off,
                                    size: 48,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'History tracking disabled',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Enable to see future completion charts',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                    ),
                                  ),
                                ],
                              ),
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
                  _buildRecurrenceSettingsCard(context),

                  // Track History Toggle
                  if (recurrenceFrequency != 'No Repetition')
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Theme.of(context).colorScheme.surface,
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.history,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Track History',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Store completion dates for charts & analytics',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment<String>(
                                  value: 'off',
                                  label: Text('Off'),
                                  icon: Icon(Icons.history_toggle_off, size: 18),
                                ),
                                ButtonSegment<String>(
                                  value: 'last_30',
                                  label: Text('Last 30'),
                                  icon: Icon(Icons.filter_list, size: 18),
                                ),
                                ButtonSegment<String>(
                                  value: 'on',
                                  label: Text('Unlimited'),
                                  icon: Icon(Icons.all_inclusive, size: 18),
                                ),
                              ],
                              selected: {trackDates},
                              onSelectionChanged: (Set<String> selection) {
                                setState(() {
                                  trackDates = selection.first;
                                });
                                _checkForChanges();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  // const SizedBox(height: 12),
                  DescriptionCard(
                    details: widget.details,
                    onDescriptionChanged: (text) {
                      setState(() {
                        widget.details['description'] = text;
                      });
                      _checkForChanges();
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),          // Action buttons - dynamic based on hasChanges
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: hasChanges 
                ? _buildSaveButtons(context)
                : _buildActionButtons(context),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build SKIP + MARK AS DONE buttons (when no changes)
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // Skip button
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.skip_next),
            label: const Text('SKIP'),
            onPressed: () => MarkAsDoneService.markAsDone(
              context: context,
              category: widget.selectedCategory,
              subCategory: widget.selectedCategoryCode,
              entryTitle: widget.entryTitle,
              isSkip: true,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Mark as done button
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('MARK AS DONE'),
            onPressed: () => MarkAsDoneService.markAsDone(
              context: context,
              category: widget.selectedCategory,
              subCategory: widget.selectedCategoryCode,
              entryTitle: widget.entryTitle,
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
      ],
    );
  }
  
  /// Build DISCARD + SAVE CHANGES buttons (when changes made)
  Widget _buildSaveButtons(BuildContext context) {
    return Row(
      children: [
        // Discard button
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.close),
            label: const Text('DISCARD'),
            onPressed: () {
              // Reset all values to original
              setState(() {
                recurrenceFrequency = _originalRecurrenceFrequency;
                isEnabled = _originalIsEnabled;
                formattedTime = _originalFormattedTime;
                entryType = _originalEntryType;
                alarmType = _originalAlarmType;
                trackDates = _originalTrackDates;
                widget.details['description'] = _originalDescription;
                durationData = Map<String, dynamic>.from(_originalDurationData);
                customFrequencyParams = Map<String, dynamic>.from(_originalCustomFrequencyParams);
                hasChanges = false;
                frequencyChanged = false;
                dateScheduled = widget.details['scheduled_date'];
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Save changes button
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

                List<String> datesMissedReviews = List<String>.from(widget.details['dates_missed_reviews'] ?? []);
                List<String> datesReviewed = List<String>.from(widget.details['dates_updated'] ?? []);
                
                String finalDateScheduled = dateScheduled;
                Map<String, dynamic> recurrenceData = {
                  'frequency': recurrenceFrequency,
                };
                if(customFrequencyParams.isNotEmpty) {
                  recurrenceData['custom_params'] = customFrequencyParams;
                }

                int finalAlarmType = formattedTime == 'All Day' ? 0 : alarmType;

                final databaseService = UnifiedDatabaseService();
                
                Map<String, dynamic> updateData = {
                  'reminder_time': formattedTime,
                  'date_updated': widget.details['date_updated'],
                  'completion_counts': completionCount,
                  'scheduled_date': finalDateScheduled,
                  'missed_counts': widget.details['missed_counts'],
                  'dates_missed_reviews': datesMissedReviews,
                  'recurrence_frequency': recurrenceFrequency,
                  'status': isEnabled ? 'Enabled' : 'Disabled',
                  'dates_updated': datesReviewed,
                  'description': widget.details['description'],
                  'recurrence_data': recurrenceData,
                  'duration': durationData,
                  'alarm_type': finalAlarmType,
                  'entry_type': entryType,
                  'track_dates': trackDates,
                };
                
                bool success = await databaseService.updateRecord(
                  widget.selectedCategory, 
                  widget.selectedCategoryCode, 
                  widget.entryTitle, 
                  updateData
                );
                
                if (!success) {
                  throw Exception('Failed to update record');
                }

                Navigator.pop(context);
                Navigator.pop(context);

                customSnackBar(
                  context: context,
                  message: '${widget.selectedCategory} ${widget.selectedCategoryCode} ${widget.entryTitle}, updated. Next schedule is on $finalDateScheduled.',
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
      ],
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
                              _checkForChanges();
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
                            _checkForChanges();
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
                          subtitle: const Text('Continue reviews indefinitely'),
                          onTap: () {
                            setState(() {
                              duration = 'Forever';
                              durationData = {
                                "type": "forever",
                                "numberOfTimes": null,
                                "endDate": null
                              };
                            });
                            _checkForChanges();
                            Navigator.of(context).pop();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.repeat),
                          title: const Text('Specific Number of Times'),
                          subtitle: const Text('Set a target number of reviews'),
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
          const SizedBox(width: 8),
          VerticalDivider(
            thickness: 1,
            color: Colors.grey.withOpacity(0.2),
          ),
          const SizedBox(width: 8),
          _buildStatusItem(
            context,
            "Skipped",
            "${widget.details['skip_counts'] ?? 0}",
            Icons.skip_next_outlined,
            int.parse((widget.details['skip_counts'] ?? 0).toString()) > 0
                ? Theme.of(context).colorScheme.tertiary
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
      child: Row(
        children: [
          Expanded(
            child: _buildCompactTimelineItem(
              context,
              "Initiated",
              widget.details['date_initiated'],
              Icons.school_outlined,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.withOpacity(0.3),
          ),
          Expanded(
            child: _buildCompactTimelineItem(
              context,
              "Last Review",
              widget.details['date_updated'] != null && widget.details['date_updated'] != 'Unspecified'
                  ? formatDateCompact(widget.details['date_updated'])
                  : 'NA',
              Icons.history,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.withOpacity(0.3),
          ),
          Expanded(
            child: _buildCompactTimelineItem(
              context,
              "Next Review",
              frequencyChanged ? dateScheduled : widget.details['scheduled_date'],
              Icons.event_outlined,
              isHighlighted: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTimelineItem(
      BuildContext context, String label, String date, IconData icon,
      {bool isHighlighted = false}) {
    final color = isHighlighted
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          date ?? 'NA',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String formatDateCompact(String date) {
    if (date == null || date == "Unspecified" || date.isEmpty) {
      return "NA";
    }
    try {
      final DateTime parsedDate = DateTime.parse(date);
      return DateFormat('yyyy-MM-dd').format(parsedDate);
    } catch (e) {
      return date;
    }
  }

  /// Builds frequency visual indicator showing the pattern
  Widget _buildFrequencyVisual(BuildContext context) {
    // Create a temporary record map for FrequencyIndicator
    final Map<String, dynamic> tempRecord = {
      'recurrence_frequency': recurrenceFrequency,
      'recurrence_data': {
        'frequency': recurrenceFrequency,
        'custom_params': customFrequencyParams,
      },
    };
    
    final String prefix = FrequencyIndicator.getPrefix(tempRecord);
    final bool hasVisual = FrequencyIndicator.hasVisualIndicator(tempRecord);
    
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.repeat,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              prefix,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (hasVisual) ...[
              const SizedBox(width: 12),
              Expanded(
                child: FrequencyIndicator(
                  record: tempRecord,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceSettingsCard(BuildContext context) {
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
          
          // Wrap the RecurrenceDropdown in a Container with styling
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).cardColor,
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: RecurrenceDropdown(
              recurrenceFrequency: recurrenceFrequency,
              onChanged: (String? newValue) async {
                if (newValue != null) {
                  setState(() {
                    recurrenceFrequency = newValue;
                    frequencyChanged = true; // Mark that frequency has been changed

                    // If custom is selected, show custom options
                    if (newValue == 'Custom') {
                      // print('extractRecurrenceData: ${extractRecurrenceData(widget.details)}');
                      showCustomFrequencySelector();
                    } else {
                      customFrequencyParams = Map<String, dynamic>.from(widget.details['recurrence_data']['custom_params']);
                    }
                  });
                  _checkForChanges();
                  
                  // Calculate and update the next review date immediately
                  await _calculateAndUpdateNextDate(newValue);
                }
              },
            ),
          ),

          // Frequency visual indicator (like AnimatedCardDetailP)
          if (recurrenceFrequency == 'Custom' && customFrequencyParams.isNotEmpty)
            _buildFrequencyVisual(context),

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
                  _checkForChanges();
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
                      ? "This entry is enabled for future reviews"
                      : "This entry is disabled and won't appear in reviews",
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
                    
                    // Mark frequency as changed when enabling a disabled entry (triggers new date calculation)
                    if (newValue && widget.details['status'] == 'Disabled') {
                      frequencyChanged = true;
                    }
                  });
                  _checkForChanges();
                  
                  // Recalculate next review date when enabling a disabled entry
                  if (newValue && widget.details['status'] == 'Disabled') {
                    await _calculateAndUpdateNextDate(recurrenceFrequency);
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
    int count = completionCount;
    
    String durationType = durationData['type'] ?? '';
    
    switch (durationType) {
      case 'specificTimes':
        int numberOfTimes = durationData['numberOfTimes'] ?? 0;
        return "$count/$numberOfTimes";
        
      case 'until':
        String endDate = durationData['endDate'] ?? '';
        if (endDate.isNotEmpty) {
          try {
            return "$count/$endDate";
          } catch (e) {
            return "$count/date";
          }
        }
        return "$count/date";
        
      case 'forever':
        return "$count/∞";
        
      default:
        return "$count";
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
                  _checkForChanges();
                  Navigator.of(context).pop();
                } else {
                  customSnackBar_error(
                    context: context,
                    message: 'Please enter a valid number (minimum 1)',
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
        _checkForChanges();
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
        Map<String, dynamic> recurrenceData = _extractRecurrenceData();
        DateTime nextDateTime = CalculateCustomNextDate.calculateCustomNextDate(
          baseDate,
          recurrenceData,
        );
        newDateScheduled = nextDateTime.toIso8601String().split('T')[0];
      } else {
        DateTime nextDateTime = await DateNextRecurrence.calculateNextRecurrenceDate(
          baseDate,
          frequency,
          completionCount,
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
        // Parse the initiation date to use as reference, fallback to today if parsing fails
        DateTime referenceDate = DateTime.now();
        if (widget.details['date_initiated'] != null && 
            widget.details['date_initiated'] != 'Unspecified') {
          try {
            referenceDate = DateTime.parse(widget.details['date_initiated']);
          } catch (e) {
            // If parsing fails, use today's date
            referenceDate = DateTime.now();
          }
        }
        
        return CustomFrequencySelector(
          initialParams: initialParams,
          referenceDate: referenceDate,
        );
      },
    );

    if (result != null) {
      setState(() {
        customFrequencyParams = result;
        frequencyChanged = true; // Mark that frequency has been changed
      });
      _checkForChanges();
      
      // Recalculate next review date with new custom parameters
      await _calculateAndUpdateNextDate('Custom');
    }
  }

  /// Extract recurrence data using current state variables (for frequency changes)
  Map<String, dynamic> _extractRecurrenceData() {
    Map<String, dynamic> recurrenceData = {
      'frequency': recurrenceFrequency,
    };
    
    if (customFrequencyParams.isNotEmpty) {
      recurrenceData['custom_params'] = customFrequencyParams;
    }

    return recurrenceData;
  }
}
