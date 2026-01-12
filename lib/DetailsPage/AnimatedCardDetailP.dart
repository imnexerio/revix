import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../SchedulePage/RecurrenceGraph.dart';
import '../Utils/entry_colors.dart';
import '../Utils/DeleteConfirmationDialog.dart';
import '../Utils/FrequencyFormatter.dart';
import '../widgets/FrequencyIndicator.dart';

class AnimatedCardDetailP extends StatelessWidget {
  final Animation<double> animation;
  final Map<String, dynamic> record;
  final bool isCompleted;
  final Function(BuildContext, Map<String, dynamic>) onSelect;
  final String? category;
  final String? subCategory;
  final bool showCategoryPath;

  const AnimatedCardDetailP({
    Key? key,
    required this.animation,
    required this.record,
    required this.isCompleted,
    required this.onSelect,
    this.category,
    this.subCategory,
    this.showCategoryPath = false,
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
                  onLongPress: () {
                    // Check if category and subCategory are available, otherwise skip delete
                    if (category != null && subCategory != null) {
                      DeleteConfirmationDialog.showDeleteRecord(
                        context: context,
                        category: category!,
                        subCategory: subCategory!,
                        recordTitle: record['record_title'] ?? 'Unknown',
                      );
                    }
                  },
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
                                // Line 1: Category path OR Entry type + Title
                                showCategoryPath
                                    ? Text(
                                        '${record['category'] ?? ''} · ${record['sub_category'] ?? ''} · ${record['record_title'] ?? 'Untitled'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '${record['entry_type'] ?? 'Unknown'}',
                                              style: TextStyle(
                                                color: EntryColors.generateColorFromString(
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
                                // Usage info: date_initiated · completion · missed
                                Row(
                                  children: [
                                    Text(
                                      formatDateOnly(record['date_initiated']?.toString() ?? ''),
                                      style: TextStyle(
                                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      ' · ',
                                      style: TextStyle(
                                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                    Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.green,
                                    ),
                                    Text(
                                      '${record['completion_counts']?.toString() ?? '0'}',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      ' · ',
                                      style: TextStyle(
                                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                    Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.red,
                                    ),
                                    Text(
                                      '${record['missed_counts']?.toString() ?? '0'}',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _buildDateInfo(
                                  context,
                                  'Scheduled',
                                  _combineDateTime(
                                    record['scheduled_date']?.toString() ?? '',
                                    record['reminder_time']?.toString() ?? '',
                                  ),
                                  Icons.calendar_today,
                                  showDaysIndicator: true,
                                ),
                                _buildFrequencyInfo(context),
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
                              // Add a key to force rebuild of RecurrenceRadarChart when data changes
                              child: (record['track_dates'] ?? 'last_30') != 'off'
                                ? RecurrenceRadarChart(
                                    key: ValueKey(
                                        'chart_${record['category'] ?? ''}_${record['record_title'] ?? ''}_${(record['dates_updated'] as List?)?.length ?? 0}_${(record['dates_missed_reviews'] as List?)?.length ?? 0}_${(record['skipped_dates'] as List?)?.length ?? 0}'
                                    ),
                                    dateInitiated: record['date_initiated'],
                                    datesMissedReviews: _safeListConversion(record['dates_missed_reviews']),
                                    datesReviewed: _safeListConversion(record['dates_updated']),
                                    datesSkipped: _safeListConversion(record['skipped_dates']),
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

  /// Combines scheduled date with reminder time
  String _combineDateTime(String scheduledDate, String reminderTime) {
    if (scheduledDate.isEmpty) return '';
    
    try {
      final DateTime parsedDate = DateTime.parse(scheduledDate);
      final String dateOnly = DateFormat('yyyy-MM-dd').format(parsedDate);
      
      if (reminderTime.isNotEmpty) {
        return '$dateOnly $reminderTime';
      }
      return dateOnly;
    } catch (e) {
      if (reminderTime.isNotEmpty) {
        return '$scheduledDate $reminderTime';
      }
      return scheduledDate;
    }
  }

  /// Builds the frequency info display widget
  Widget _buildFrequencyInfo(BuildContext context) {
    if (!FrequencyFormatter.hasFrequency(record)) return const SizedBox.shrink();
    
    final String prefix = FrequencyIndicator.getPrefix(record);
    final bool hasVisual = FrequencyIndicator.hasVisualIndicator(record);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.repeat,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Frequency',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      prefix,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                if (hasVisual)
                  FrequencyIndicator(
                    record: record,
                    fontSize: 13,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(BuildContext context, String label, String date, IconData icon, {bool showDaysIndicator = false}) {
    if (date.isEmpty) return const SizedBox.shrink();

    // Calculate days difference for scheduled date
    Widget? daysIndicator;
    if (showDaysIndicator) {
      daysIndicator = _buildDaysIndicator(context, date);
    }

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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                      ),
                    ),
                    if (daysIndicator != null) ...[
                      const SizedBox(width: 6),
                      daysIndicator,
                    ],
                  ],
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

  String formatDateOnly(String date) {
    if (date.isEmpty) return '';

    try {
      final DateTime parsedDate = DateTime.parse(date);
      final DateFormat formatter = DateFormat('yyyy-MM-dd');
      return formatter.format(parsedDate);
    } catch (e) {
      return date; // Return original string if parsing fails
    }
  }

  /// Builds the days left/overdue indicator
  Widget _buildDaysIndicator(BuildContext context, String dateString) {
    try {
      // Parse the date (handle both date-only and datetime formats)
      final DateTime scheduledDate = DateTime.parse(dateString.split(' ').first);
      final DateTime today = DateTime.now();
      
      // Calculate difference in days (ignoring time)
      final DateTime scheduledDateOnly = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
      final DateTime todayOnly = DateTime(today.year, today.month, today.day);
      final int daysDiff = scheduledDateOnly.difference(todayOnly).inDays;
      
      String text;
      Color color;
      
      if (daysDiff > 0) {
        // Future
        text = 'in ${daysDiff}d';
        color = Colors.green;
      } else if (daysDiff == 0) {
        // Today
        text = 'Today';
        color = Colors.orange;
      } else {
        // Overdue
        text = '${-daysDiff}d ago';
        color = Colors.red;
      }
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}