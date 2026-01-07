import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Utils/entry_colors.dart';

/// A compact event card for displaying in calendar views
class CalendarEventCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onTap;
  final bool isCompact;
  final bool showTime;

  const CalendarEventCard({
    Key? key,
    required this.record,
    required this.onTap,
    this.isCompact = false,
    this.showTime = true,
  }) : super(key: key);

  Color _getEntryTypeColor(String entryType) {
    return EntryColors.generateColorFromString(entryType);
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      if (timestamp.contains('T')) {
        final dateTime = DateTime.parse(timestamp);
        return DateFormat('HH:mm').format(dateTime);
      }
      return timestamp;
    } catch (e) {
      return '';
    }
  }

  String _getTimeRange() {
    final startTimestamp = record['start_timestamp'] as String?;
    final endTimestamp = record['end_timestamp'] as String?;
    final reminderTime = record['reminder_time'] as String?;

    if (reminderTime == 'All Day') {
      return 'All Day';
    }

    final startTime = _formatTime(startTimestamp);
    final endTime = _formatTime(endTimestamp);

    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      return '$startTime - $endTime';
    } else if (startTime.isNotEmpty) {
      return startTime;
    } else if (reminderTime != null && reminderTime.isNotEmpty) {
      return reminderTime;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entryType = record['entry_type'] as String? ?? 'default';
    final entryColor = _getEntryTypeColor(entryType);
    
    // Build full title like AnimatedCard: category · sub_category · record_title
    final category = record['category'] as String? ?? '';
    final subCategory = record['sub_category'] as String? ?? '';
    final recordTitle = record['record_title'] as String? ?? 'Untitled';
    final fullTitle = '$category · $subCategory · $recordTitle';
    final timeRange = _getTimeRange();

    if (isCompact) {
      // Compact version for month view - just a colored dot with title
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: entryColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border(
              left: BorderSide(color: entryColor, width: 3),
            ),
          ),
          child: Text(
            fullTitle,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    // Full version for day/week view
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: entryColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: entryColor, width: 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fullTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (showTime && timeRange.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                timeRange,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
