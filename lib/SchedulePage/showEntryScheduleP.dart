import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Utils/MarkAsDoneService.dart';
import '../Utils/entry_colors.dart';
import 'RecurrenceGraph.dart';


void showEntryScheduleP(BuildContext context, Map<String, dynamic> details) {
  String description = details['description'] ?? '';

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
                              '${details['category']} · ${details['sub_category']} · ${details['record_title']}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: EntryColors.generateColorFromString(details['entry_type']?.toString() ?? 'default'),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  details['entry_type']?.toString() ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: EntryColors.generateColorFromString(details['entry_type']?.toString() ?? 'default'),
                                  ),
                                ),
                                Text(
                                  ' · ${details['reminder_time']}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
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
                              child: RecurrenceRadarChart(
                                dateInitiated: details['date_initiated'],
                                datesMissedReviews: List.from(details['dates_missed_revisions'] ?? []),
                                datesReviewed: List.from(details['dates_updated'] ?? []),
                                datesSkipped: List.from(details['skipped_dates'] ?? []),
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

                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "Description: ",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              TextSpan(
                                text: description.isEmpty ? 'No description available' : description,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.normal,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),                // Action buttons
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        // Skip button
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.skip_next),
                            label: const Text('SKIP'),
                            onPressed: () => MarkAsDoneService.markAsDone(
                              context: context,
                              category: details['category'],
                              subCategory: details['sub_category'],
                              entryTitle: details['record_title'],
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
                              category: details['category'],
                              subCategory: details['sub_category'],
                              entryTitle: details['record_title'],
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
  String recurrenceFrequency = details['recurrence_frequency'];
  String completionValue = _getCompletionValue(details);

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
          recurrenceFrequency,
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
          completionValue,
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
          "${details['missed_counts']}",
          Icons.cancel_outlined,
          int.parse(details['missed_counts'].toString()) > 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface,
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
          "${details['skip_counts'] ?? 0}",
          Icons.skip_next_outlined,
          int.parse((details['skip_counts'] ?? 0).toString()) > 0
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
          details['date_initiated'] ?? 'NA',
          Icons.school_outlined,
          isFirst: true,
        ),
        _buildTimelineItem(
          context,
          "Last Reviewed",
          details['date_updated'] != null && details['date_updated'] != "Unspecified"
              ? formatDate(details['date_updated'])
              : 'NA',
          Icons.history,
        ),
        _buildTimelineItem(
          context,
          "Next Review",
          details['scheduled_date'] ?? 'NA',
          Icons.event_outlined,
          isLast: true,
          isHighlighted: true,
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

String _getCompletionValue(Map<String, dynamic> details) {
  int completionCount = details['completion_counts'] ?? 0;
  var durationData = details['duration'];
  
  if (durationData == null) {
    return "$completionCount";
  }
  
  // Convert to Map<String, dynamic> safely
  Map<String, dynamic> duration = Map<String, dynamic>.from(durationData);
  
  String durationType = duration['type']?.toString() ?? '';
  
  switch (durationType) {
    case 'specificTimes':
      int numberOfTimes = int.tryParse(duration['numberOfTimes']?.toString() ?? '0') ?? 0;
      return "$completionCount/$numberOfTimes";
      
    case 'until':
      String endDate = duration['endDate']?.toString() ?? '';
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
