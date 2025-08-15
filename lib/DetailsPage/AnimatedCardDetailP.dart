import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../SchedulePage/RevisionGraph.dart';
import '../Utils/lecture_colors.dart';

class AnimatedCardDetailP extends StatelessWidget {
  final Animation<double> animation;
  final Map<String, dynamic> record;
  final bool isCompleted;
  final Function(BuildContext, Map<String, dynamic>) onSelect;

  const AnimatedCardDetailP({
    Key? key,
    required this.animation,
    required this.record,
    required this.isCompleted,
    required this.onSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(animation);
    final fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(animation);
    final slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: Card(
                elevation: 5,
                margin: const EdgeInsets.all(4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelect(context, record),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    // child: SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Colored line indicator (like Android widget) - solid if enabled, dashed if disabled
                        _buildStatusIndicatorLine(),
                        const SizedBox(width: 12),
                        // Left side with category information
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${record['entry_type']}',
                                      style: TextStyle(
                                        color: LectureColors.generateColorFromString(record['entry_type']?.toString() ?? 'default'),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' · ${record['record_title']}',
                                      style: TextStyle(
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),


                              // Usage
                              Text(
                                '${formatDate(record['start_timestamp'])} · ${record['completion_counts']} · ${record['missed_counts']}',
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              _buildDateInfo(
                                context,
                                'Scheduled',
                                record['scheduled_date'] ?? '',
                                Icons.calendar_today,
                              ),
                              if (isCompleted)
                                _buildDateInfo(
                                  context,
                                  'Initiated',
                                  record['date_initiated'] ?? '',
                                  Icons.check_circle_outline,
                                ),
                              // ],
                              // ),
                            ],
                          ),
                        ),
                        // Right side with the revision graph
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            child: Center(
                              // Add a key to force rebuild of RevisionRadarChart when data changes
                              child: RevisionRadarChart(
                                key: ValueKey('chart_${record['category']}_${record['record_title']}_${record['dates_updated']?.length ?? 0}_${record['dates_missed_revisions']?.length ?? 0}'),
                                dateLearnt: record['date_initiated'],
                                datesMissedRevisions: List<String>.from(record['dates_missed_revisions'] ?? []),
                                datesRevised: List<String>.from(record['dates_updated'] ?? []),
                                showLabels: false,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Build status indicator line - solid if enabled, dashed if disabled
  Widget _buildStatusIndicatorLine() {
    final bool isEnabled = record['status'] == 'Enabled';
    final Color lineColor = LectureColors.generateColorFromString(record['entry_type']?.toString() ?? 'default');

    if (isEnabled) {
      // Solid line for enabled status
      return Container(
        width: 4,
        height: 100,
        decoration: BoxDecoration(
          color: lineColor,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    } else {
      // Dashed line for disabled status
      return SizedBox(
        width: 4,
        height: 100,
        child: Column(
          children: List.generate(5, (index) {
            return Expanded(
              child: Container(
                width: 4,
                margin: const EdgeInsets.symmetric(vertical: 1),
                decoration: BoxDecoration(
                  color: index % 2 == 0 ? lineColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      );
    }
  }

  Widget _buildDateInfo(BuildContext context, String label, String date, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
            Text(
              date,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

  // import 'package:intl/intl.dart';

  // Inside your build method or wherever you need to format the date
  String formatDate(String date) {
    final DateTime parsedDate = DateTime.parse(date);
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm');
    return formatter.format(parsedDate);
  }
}