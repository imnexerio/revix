import 'package:flutter/animation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'RevisionGraph.dart';

class AnimatedCard extends StatelessWidget {
  final Animation<double> animation;
  final Map<String, dynamic> record;
  final bool isCompleted;
  final Function(BuildContext, Map<String, dynamic>) onSelect;

  const AnimatedCard({
    Key? key,
    required this.animation,
    required this.record,
    required this.isCompleted,
    required this.onSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Apply multiple animations
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
                elevation: 0,
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
                        // Left side with subject information
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${record['subject']} · ${record['subject_code']} · ${record['lecture_no']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record['lecture_type'],
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              // Wrap(
                              //   spacing: 16,
                              //   runSpacing: 8,
                              //   children: [
                                  _buildDateInfo(
                                    context,
                                    'Scheduled',
                                    record['date_scheduled'] ?? '',
                                    Icons.calendar_today,
                                  ),
                                  if (isCompleted)
                                    _buildDateInfo(
                                      context,
                                      'Completed',
                                      record['date_learnt'] ?? '',
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
                            // height: 200,
                            child: Center(
                              // Add a key to force rebuild of RevisionRadarChart when data changes
                              child: RevisionRadarChart(
                                key: ValueKey('chart_${record['subject']}_${record['lecture_no']}_${record['dates_revised']?.length ?? 0}_${record['dates_missed_revisions']?.length ?? 0}'),
                                dateLearnt: record['date_learnt'],
                                datesMissedRevisions: List<String>.from(record['dates_missed_revisions'] ?? []),
                                datesRevised: List<String>.from(record['dates_revised'] ?? []),
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
}