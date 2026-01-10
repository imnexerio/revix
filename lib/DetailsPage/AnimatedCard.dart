import 'package:flutter/material.dart';
import 'RecurrenceGraph.dart';
import '../Utils/entry_colors.dart';
import '../Utils/DeleteConfirmationDialog.dart';

class AnimatedCard extends StatelessWidget {
  final Animation<double> animation;
  final Map<String, dynamic> record;
  final bool isCompleted;
  final Function(BuildContext, Map<String, dynamic>) onSelect;
  final String? category;
  final String? subCategory;

  const AnimatedCard({
    Key? key,
    required this.animation,
    required this.record,
    required this.isCompleted,
    required this.onSelect,
    this.category,
    this.subCategory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Apply multiple animations
    final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(animation);
    final fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(animation);
    final slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation);

    // Get category and subCategory from record if not provided as props
    final recordCategory = category ?? record['category']?.toString();
    final recordSubCategory = subCategory ?? record['sub_category']?.toString();

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
                  onLongPress: () {
                    // Enable delete if category and subCategory are available
                    if (recordCategory != null && recordSubCategory != null) {
                      DeleteConfirmationDialog.showDeleteRecord(
                        context: context,
                        category: recordCategory,
                        subCategory: recordSubCategory,
                        recordTitle: record['record_title'] ?? 'Unknown',
                      );
                    }
                  },
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Colored line indicator - solid if enabled, dashed if disabled
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
                                Text(
                                  '${record['category']} · ${record['sub_category']} · ${record['record_title']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${record['entry_type']}',
                                        style: TextStyle(
                                          color: EntryColors.generateColorFromString(record['entry_type']?.toString() ?? 'default'),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' · ${record['reminder_time']}',
                                        style: TextStyle(
                                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
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
                              ],
                            ),
                          ),
                        ),
                        // Right side with the recurrence graph
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                            child: Center(
                              child: (record['track_dates'] ?? 'last_30') != 'off'
                                ? RecurrenceRadarChart(
                                    key: ValueKey('chart_${record['category']}_${record['record_title']}_${record['dates_updated']?.length ?? 0}_${record['dates_missed_reviews']?.length ?? 0}_${record['skipped_dates']?.length ?? 0}'),
                                    dateInitiated: record['date_initiated'],
                                    datesMissedReviews: List<String>.from(record['dates_missed_reviews'] ?? []),
                                    datesReviewed: List<String>.from(record['dates_updated'] ?? []),
                                    datesSkipped: List<String>.from(record['skipped_dates'] ?? []),
                                    showLabels: false,
                                  )
                                : Icon(
                                    Icons.history_toggle_off,
                                    size: 32,
                                    color: Colors.grey.withOpacity(0.4),
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

  // Build status indicator line - solid if enabled, dashed if disabled
  Widget _buildStatusIndicatorLine() {
    final bool isEnabled = record['status']?.toString().toLowerCase() == 'enabled';
    final Color lineColor = EntryColors.generateColorFromString(
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
            const int dashCount = 4;
            final totalHeight = constraints.maxHeight;
            final dashHeight = totalHeight / (dashCount * 2 - 1);

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
                    if (index < dashCount - 1) SizedBox(height: dashHeight),
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
          ),
        ],
      ),
    );
  }
}
