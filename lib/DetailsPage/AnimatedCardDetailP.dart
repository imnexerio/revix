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
    final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeInOut)
    );
    final fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeInOut)
    );
    final slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero
    ).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeInOut)
    );

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
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Colored line indicator (like Android widget) - solid if enabled, dashed if disabled
                        _buildStatusIndicatorLine(),
                        const SizedBox(width: 12),
                        // Left side with category information
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${record['entry_type'] ?? 'Unknown'}',
                                        style: TextStyle(
                                          color: LectureColors.generateColorFromString(
                                              record['entry_type']?.toString() ?? 'default'
                                          ),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' · ${record['record_title'] ?? 'Untitled'}',
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
                                // Usage info with null safety
                                Text(
                                  '${formatDate(record['start_timestamp']?.toString() ?? '')} · ${record['completion_counts']?.toString() ?? '0'} · ${record['missed_counts']?.toString() ?? '0'}',
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
                                  record['scheduled_date']?.toString() ?? '',
                                  Icons.calendar_today,
                                ),
                                if (isCompleted)
                                  _buildDateInfo(
                                    context,
                                    'Initiated',
                                    record['date_initiated']?.toString() ?? '',
                                    Icons.check_circle_outline,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Right side with the revision graph
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                            child: Center(
                              // Add a key to force rebuild of RevisionRadarChart when data changes
                              child: RevisionRadarChart(
                                key: ValueKey(
                                    'chart_${record['category'] ?? ''}_${record['record_title'] ?? ''}_${(record['dates_updated'] as List?)?.length ?? 0}_${(record['dates_missed_revisions'] as List?)?.length ?? 0}'
                                ),
                                dateLearnt: record['date_initiated'],
                                datesMissedRevisions: _safeListConversion(record['dates_missed_revisions']),
                                datesRevised: _safeListConversion(record['dates_updated']),
                                showLabels: false,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method for safe list conversion
  List<String> _safeListConversion(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  // Build status indicator line - solid if enabled, dashed if disabled
  Widget _buildStatusIndicatorLine() {
    final bool isEnabled = record['status']?.toString().toLowerCase() == 'enabled';
    final Color lineColor = LectureColors.generateColorFromString(
        record['entry_type']?.toString() ?? 'default'
    );

    if (isEnabled) {
      // Solid line for enabled status
      return Container(
        width: 5,
        decoration: BoxDecoration(
          color: lineColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
        ),
      );
    } else {
      // Dashed line for disabled status
      return SizedBox(
        width: 5,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const int dashCount = 4; // Change this number to control dash count
            final totalHeight = constraints.maxHeight;
            final dashHeight = totalHeight / (dashCount * 2 - 1); // Equal space for dashes and gaps
            
            return Column(
              children: List.generate(dashCount, (index) {
                return Column(
                  children: [
                    Container(
                      width: 5,
                      height: dashHeight,
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: index == 0
                            ? const BorderRadius.only(topLeft: Radius.circular(12))
                            : index == dashCount - 1
                            ? const BorderRadius.only(bottomLeft: Radius.circular(12))
                            : null,
                      ),
                    ),
                    if (index < dashCount - 1) SizedBox(height: dashHeight), // Gap between dashes
                  ],
                );
              }),
            );
          },
        ),
      );
    }
  }

  Widget _buildDateInfo(BuildContext context, String label, String date, IconData icon) {
    if (date.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
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
                  formatDate(date),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String formatDate(String date) {
    if (date.isEmpty) return '';

    try {
      final DateTime parsedDate = DateTime.parse(date);
      final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm');
      return formatter.format(parsedDate);
    } catch (e) {
      return date; // Return original string if parsing fails
    }
  }
}