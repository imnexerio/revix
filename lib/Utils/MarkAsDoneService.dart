import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'CalculateCustomNextDate.dart';
import '../Utils/CustomSnackBar.dart';
import '../Utils/customSnackBar_error.dart';
import '../Utils/date_utils.dart';
import '../Utils/UnifiedDatabaseService.dart';

class MarkAsDoneService {  /// Determines if the entry should be enabled based on duration settings
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
      int currentCompletions = (details['completion_counts'] as num?)?.toInt() ?? 0;

      // Disable if we've reached or exceeded the specified number of completions
      if (numberOfTimes != null && currentCompletions >= numberOfTimes) {
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


  /// Extracts recurrence data from details for custom frequency
  static Map<String, dynamic> _extractRecurrenceData(Map<String, dynamic> details) {
    Map<String, dynamic> recurrenceData = {};

    if (details['recurrence_data'] != null) {
      final rawData = details['recurrence_data'];
      recurrenceData['frequency'] = rawData['frequency'];

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

        recurrenceData['custom_params'] = customParams;
      }
    }

    return recurrenceData;
  }

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
  /// Main function to mark an entry as done
  static Future<void> markAsDone({
    BuildContext? context, // Made nullable for background processing
    required String category,
    required String subCategory,
    required String entryTitle,
    bool isSkip = false,
    bool isWidget = false, // New parameter to indicate if request is from widget
  }) async {
    try {
      // Show loading dialog only if context is available
      if (context != null) {
        _showLoadingDialog(context);
      }

      // Get the unified database service instance
      final UnifiedDatabaseService dbService = UnifiedDatabaseService();
      
      // Fetch current entry data from database
      Map<String, dynamic>? details = await dbService.getDataAtLocation(category, subCategory, entryTitle);
      
      if (details == null) {
        if (context != null) Navigator.pop(context);
        throw 'Entry data not found';
      }

      // Check if not enabled
      bool isCurrentlyEnabled = details['status'] == 'Enabled';
      if (!isCurrentlyEnabled) {
        if (context != null) Navigator.pop(context);
        throw 'Cannot mark as done when the status is disabled';
      }

      // Check if already marked as done today (only for widget requests)
      if (isWidget) {
        String todayDate = DateTime.now().toIso8601String().split('T')[0];
        String? lastMarkDone = details['last_mark_done']?.toString();
        
        if (lastMarkDone != null && lastMarkDone == todayDate) {
          if (context != null) Navigator.pop(context);
          throw 'Already marked as done today';
        }
      }

      // Handle unspecified date_initiated case
      if (details['date_initiated'] == 'Unspecified') {
        if (!isSkip) {
          await dbService.deleteRecord(category, subCategory, entryTitle);
        }
        if (context != null) {
          Navigator.pop(context);
          Navigator.pop(context);
          customSnackBar(
            context: context,
            message: isSkip 
                ? 'Cannot skip entry with unspecified date'
                : '$category $subCategory $entryTitle has been marked as done and moved to deleted data.',
          );
        }
        return;
      }

      String dateRevised = DateFormat('yyyy-MM-ddTHH:mm').format(DateTime.now());
      int missedReviewCount = (details['missed_counts'] as num).toInt();
      DateTime scheduledDate = DateTime.parse(details['scheduled_date'].toString());
      String trackDatesMode = details['track_dates'] ?? 'last_30'; // 'off', 'on', 'last_30'
      bool shouldTrackDates = trackDatesMode != 'off';

      // Check if review was missed (only for mark as done, not skip)
      if (!isSkip && scheduledDate.toIso8601String().split('T')[0].compareTo(dateRevised.split('T')[0]) < 0) {
        missedReviewCount += 1;
      }

      // Only track date arrays if tracking is enabled
      List<String> datesMissedReviews = shouldTrackDates 
          ? List<String>.from(details['dates_missed_reviews'] ?? []) 
          : [];
      if (shouldTrackDates && !isSkip && scheduledDate.toIso8601String().split('T')[0].compareTo(dateRevised.split('T')[0]) < 0) {
        datesMissedReviews.add(scheduledDate.toIso8601String().split('T')[0]);
      }

      List<String> datesRevised = shouldTrackDates 
          ? List<String>.from(details['dates_updated'] ?? []) 
          : [];
      if (shouldTrackDates && !isSkip) {
        datesRevised.add(dateRevised);
      }

      // Handle skip-specific data
      List<String> skippedDates = shouldTrackDates 
          ? List<String>.from(details['skipped_dates'] ?? []) 
          : [];
      int skipCounts = (details['skip_counts'] as num?)?.toInt() ?? 0;
      
      if (isSkip) {
        if (shouldTrackDates) {
          skippedDates.add(scheduledDate.toIso8601String().split('T')[0]);
        }
        skipCounts += 1;
      }

      // Apply 'last_30' trimming if needed
      if (trackDatesMode == 'last_30') {
        // Combine all dates with type tags
        List<Map<String, String>> allDates = [];
        for (var date in datesRevised) {
          allDates.add({'date': date.split('T')[0], 'type': 'reviewed'});
        }
        for (var date in datesMissedReviews) {
          allDates.add({'date': date, 'type': 'missed'});
        }
        for (var date in skippedDates) {
          allDates.add({'date': date, 'type': 'skipped'});
        }
        
        // Sort by date descending (newest first)
        allDates.sort((a, b) => b['date']!.compareTo(a['date']!));
        
        // Keep only 30 most recent
        if (allDates.length > 30) {
          allDates = allDates.sublist(0, 30);
        }
        
        // Split back into respective arrays
        datesRevised = allDates.where((e) => e['type'] == 'reviewed').map((e) => e['date']!).toList();
        datesMissedReviews = allDates.where((e) => e['type'] == 'missed').map((e) => e['date']!).toList();
        skippedDates = allDates.where((e) => e['type'] == 'skipped').map((e) => e['date']!).toList();
      }

      // Handle 'No Repetition' case
      if (details['recurrence_frequency'] == 'No Repetition') {
        if (!isSkip) {
          await dbService.deleteRecord(category, subCategory, entryTitle);
        }
        if (context != null) {
          Navigator.pop(context);
          Navigator.pop(context);
          customSnackBar(
            context: context,
            message: isSkip 
                ? 'Cannot skip entry with no repetition'
                : '$category $subCategory $entryTitle has been marked as done and moved to deleted data.',
          );
        }
        return;
      }

      // Calculate next scheduled date
      String dateScheduled;
      if (details['recurrence_frequency'] == 'Custom') {
        Map<String, dynamic> recurrenceData = _extractRecurrenceData(details);
        DateTime nextDateTime = CalculateCustomNextDate.calculateCustomNextDate(
          DateTime.parse(details['scheduled_date']),
          recurrenceData,
        );
        dateScheduled = nextDateTime.toIso8601String().split('T')[0];
      } else {
        int completionCountForCalculation = isSkip 
            ? details['completion_counts'] 
            : details['completion_counts'] + 1;
        dateScheduled = (await DateNextRecurrence.calculateNextRecurrenceDate(
          scheduledDate,
          details['recurrence_frequency'],
          completionCountForCalculation,
        )).toIso8601String().split('T')[0];
      }

      // Handle negative completion case (only for mark as done)
      if (!isSkip && details['completion_counts'] < 0) {
        datesRevised = [];
        dateScheduled = (await DateNextRecurrence.calculateNextRecurrenceDate(
          DateTime.parse(dateRevised),
          details['recurrence_frequency'],
          details['completion_counts'] + 1,
        )).toIso8601String().split('T')[0];
      }

      // Calculate the new status based on duration settings (only for mark as done)
      String newStatus = details['status'];
      if (!isSkip) {
        // Create a copy of details with updated completion_counts for status calculation
        Map<String, dynamic> updatedDetails = Map<String, dynamic>.from(details);
        updatedDetails['completion_counts'] = details['completion_counts'] + 1;
        newStatus = determineEnabledStatus(updatedDetails) ? 'Enabled' : 'Disabled';
      }

      // Build the update data map with all fields
      Map<String, dynamic> updateData = {
        'reminder_time': details['reminder_time'] ?? '',
        'completion_counts': isSkip ? details['completion_counts'] : details['completion_counts'] + 1,
        'scheduled_date': dateScheduled,
        'missed_counts': missedReviewCount,
        'description': details['description'] ?? '',
        'status': newStatus,
        'last_mark_done': DateTime.now().toIso8601String().split('T')[0],
        'dates_missed_reviews': shouldTrackDates ? datesMissedReviews : [],
      };

      // Add skip-specific or completion-specific fields
      if (isSkip) {
        updateData['skipped_dates'] = shouldTrackDates ? skippedDates : [];
        updateData['skip_counts'] = skipCounts;
      } else {
        updateData['date_updated'] = dateRevised;
        updateData['dates_updated'] = shouldTrackDates ? datesRevised : [];
      }

      // Update the record directly
      bool updateSuccess = await dbService.updateRecord(
        category,
        subCategory,
        entryTitle,
        updateData,
      );

      if (!updateSuccess) {
        throw 'Failed to update record';
      }

      // Handle UI operations only if context is available
      if (context != null) {
        Navigator.pop(context);
        Navigator.pop(context);

        // Show success message
        customSnackBar(
          context: context,
          message: isSkip 
              ? '$category $subCategory $entryTitle skipped and rescheduled for $dateScheduled'
              : '$category $subCategory $entryTitle done and scheduled for $dateScheduled',
        );
      }
    } catch (e) {
      if (context != null) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        customSnackBar_error(
          context: context,
          message: isSkip 
              ? 'Failed to skip: ${e.toString()}'
              : 'Failed to mark as done: ${e.toString()}',
        );
      } else {
        // For background processing, just rethrow the error
        rethrow;
      }
    }
  }
}
