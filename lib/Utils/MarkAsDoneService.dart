import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../RecordForm/CalculateCustomNextDate.dart';
import '../Utils/CustomSnackBar.dart';
import '../Utils/UpdateRecords.dart';
import '../Utils/customSnackBar_error.dart';
import '../Utils/date_utils.dart';

class MarkAsDoneService {  /// Determines if the lecture should be enabled based on duration settings
  static bool determineEnabledStatus(Map<String, dynamic> details) {
    // Default to the current status (convert from string to bool)
    bool isEnabled = details['status'] == 'Enabled';

    // Get the duration data with proper casting
    Map<String, dynamic> durationData = {};
    if (details['duration'] != null) {
      // Cast the LinkedMap to Map<String, dynamic>
      durationData = Map<String, dynamic>.from(details['duration'] as Map);
    } else {
      durationData = {'type': 'forever'};
    }

    String durationType = durationData['type'] as String? ?? 'forever';

    // Check duration conditions
    if (durationType == 'specificTimes') {
      int? numberOfTimes = durationData['numberOfTimes'] as int?;
      int currentRevisions = (details['completion_counts'] as num?)?.toInt() ?? 0;

      // Disable if we've reached or exceeded the specified number of revisions
      if (numberOfTimes != null && currentRevisions >= numberOfTimes) {
        isEnabled = false;
      }
    }
    else if (durationType == 'until') {
      String? endDateStr = durationData['endDate'] as String?;
      if (endDateStr != null) {
        DateTime endDate = DateTime.parse(endDateStr);
        DateTime today = DateTime.now();

        // Compare only the date part (ignore time)
        if (today.isAfter(DateTime(endDate.year, endDate.month, endDate.day))) {
          isEnabled = false;
        }
      }
    }

    return isEnabled;
  }
  /// Shows a loading dialog
  static void _showLoadingDialog(BuildContext context) {
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
  }

  /// Extracts revision data from details for custom frequency
  static Map<String, dynamic> _extractRevisionData(Map<String, dynamic> details) {
    Map<String, dynamic> revisionData = {};

    if (details['recurrence_data'] != null) {
      final rawData = details['recurrence_data'];
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

  /// Main function to mark a lecture as done
  static Future<void> markAsDone({
    required BuildContext context,
    required Map<String, dynamic> details,
    required String category,
    required String subCategory,
    required String lectureNo,
    String? description,
    Map<String, dynamic>? durationData,
    bool? isEnabled,
    bool useRevisionUpdate = false,
  }) async {
    try {
      _showLoadingDialog(context);

      // Check if not enabled for LectureDetailsModal case
      if (isEnabled != null && !isEnabled) {
        Navigator.pop(context);
        throw 'Cannot mark as done when the status is disabled';
      }

      // Handle unspecified date_initiated case
      if (details['date_initiated'] == 'Unspecified') {
        await moveToDeletedData(category, subCategory, lectureNo, details);
        Navigator.pop(context);
        Navigator.pop(context);
        customSnackBar(
          context: context,
          message: '$category $subCategory $lectureNo has been marked as done and moved to deleted data.',
        );
        return;
      }

      String dateRevised = DateFormat('yyyy-MM-ddTHH:mm').format(DateTime.now());
      int missedRevision = (details['missed_counts'] as num).toInt();
      DateTime scheduledDate = DateTime.parse(details['scheduled_date'].toString());

      // Check if revision was missed
      if (scheduledDate.toIso8601String().split('T')[0].compareTo(dateRevised.split('T')[0]) < 0) {
        missedRevision += 1;
      }

      List<String> datesMissedRevisions = List<String>.from(details['dates_missed_revisions'] ?? []);
      if (scheduledDate.toIso8601String().split('T')[0].compareTo(dateRevised.split('T')[0]) < 0) {
        datesMissedRevisions.add(scheduledDate.toIso8601String().split('T')[0]);
      }

      List<String> datesRevised = List<String>.from(details['dates_updated'] ?? []);
      datesRevised.add(dateRevised);

      // Handle 'No Repetition' case
      if (details['recurrence_frequency'] == 'No Repetition') {
        await moveToDeletedData(category, subCategory, lectureNo, details);
        Navigator.pop(context);
        Navigator.pop(context);
        customSnackBar(
          context: context,
          message: '$category $subCategory $lectureNo has been marked as done and moved to deleted data.',
        );
        return;
      }

      // Calculate next scheduled date
      String dateScheduled;
      if (details['recurrence_frequency'] == 'Custom') {
        Map<String, dynamic> revisionData = _extractRevisionData(details);
        DateTime nextDateTime = CalculateCustomNextDate.calculateCustomNextDate(
          DateTime.parse(details['scheduled_date']),
          revisionData,
        );
        dateScheduled = nextDateTime.toIso8601String().split('T')[0];
      } else {
        dateScheduled = (await DateNextRevision.calculateNextRevisionDate(
          scheduledDate,
          details['recurrence_frequency'],
          details['completion_counts'] + 1,
        )).toIso8601String().split('T')[0];
      }

      // Handle negative revision case
      if (details['completion_counts'] < 0) {
        datesRevised = [];
        dateScheduled = (await DateNextRevision.calculateNextRevisionDate(
          DateTime.parse(dateRevised),
          details['recurrence_frequency'],
          details['completion_counts'] + 1,
        )).toIso8601String().split('T')[0];
      }      // Determine enabled status for LectureDetailsModal case
      bool finalEnabledStatus = true;
      if (isEnabled != null) {
        Map<String, dynamic> updatedDetails = Map<String, dynamic>.from(details);
        updatedDetails['completion_counts'] = details['completion_counts'] + 1;
        finalEnabledStatus = MarkAsDoneService.determineEnabledStatus(updatedDetails);
      }

      // Create revision data
      Map<String, dynamic> revisionData = {
        'frequency': details['recurrence_frequency'],
      };
      
      if (details['recurrence_frequency'] == 'Custom') {
        Map<String, dynamic> customParams = _extractRevisionData(details);
        if (customParams['custom_params'] != null) {
          revisionData['custom_params'] = customParams['custom_params'];
        }
      }

      // Update records based on the update type
      if (useRevisionUpdate) {
        await UpdateRecordsRevision(
          category,
          subCategory,
          lectureNo,
          dateRevised,
          description ?? details['description'],
          details['reminder_time'],
          details['completion_counts'] + 1,
          dateScheduled,
          datesRevised,
          missedRevision,
          datesMissedRevisions,
          finalEnabledStatus ? 'Enabled' : 'Disabled',
        );
      } else {
        await UpdateRecords(
          category,
          subCategory,
          lectureNo,
          dateRevised,
          details['description'],
          details['reminder_time'],
          details['completion_counts'] + 1,
          dateScheduled,
          datesRevised,
          missedRevision,
          datesMissedRevisions,
          details['recurrence_frequency'],
          finalEnabledStatus ? 'Enabled' : 'Disabled',
          revisionData,
          durationData ?? {},
        );
      }

      Navigator.pop(context);
      Navigator.pop(context);

      // Show success message
      String successMessage = useRevisionUpdate
          ? '$category $subCategory $lectureNo done and scheduled for $dateScheduled'
          : '$category $subCategory $lectureNo, done. Next schedule is on $dateScheduled.';

      customSnackBar(
        context: context,
        message: successMessage,
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      customSnackBar_error(
        context: context,
        message: 'Failed to mark as done: ${e.toString()}',
      );
    }
  }

  /// Creates a reusable "MARK AS DONE" button widget
  static Widget createMarkAsDoneButton({
    required BuildContext context,
    required Map<String, dynamic> details,
    required String category,
    required String subCategory,
    required String lectureNo,
    String? description,
    Map<String, dynamic>? durationData,
    bool? isEnabled,
    bool useRevisionUpdate = false,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(20, 8, 20, 16),
    bool isExpanded = true,
  }) {
    Widget button = ElevatedButton.icon(
      icon: const Icon(Icons.check_circle_outline),
      label: const Text('MARK AS DONE'),
      onPressed: () => markAsDone(
        context: context,
        details: details,
        category: category,
        subCategory: subCategory,
        lectureNo: lectureNo,
        description: description,
        durationData: durationData,
        isEnabled: isEnabled,
        useRevisionUpdate: useRevisionUpdate,
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
    );

    if (isExpanded) {
      button = SizedBox(width: double.infinity, child: button);
    }

    return SafeArea(
      child: Padding(
        padding: padding,
        child: isExpanded
            ? button
            : Row(
                children: [Expanded(child: button)],
              ),
      ),
    );
  }
}
