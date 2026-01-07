import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'CalendarDataHelper.dart';
import 'CalendarEventCard.dart';
import '../showEntryScheduleP.dart';

/// Week view showing 7 days with events
class CalendarWeekView extends StatefulWidget {
  final Map<DateTime, List<Map<String, dynamic>>> groupedRecords;
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;

  const CalendarWeekView({
    Key? key,
    required this.groupedRecords,
    required this.selectedDate,
    required this.onDateChanged,
  }) : super(key: key);

  @override
  State<CalendarWeekView> createState() => _CalendarWeekViewState();
}

class _CalendarWeekViewState extends State<CalendarWeekView> {
  late ScrollController _scrollController;
  static const double _hourHeight = 50.0;
  static const double _headerHeight = 70.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final targetOffset = (now.hour * _hourHeight) - 100;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final weekDates = CalendarDataHelper.getWeekDates(widget.selectedDate);

    return Column(
      children: [
        // Week navigation header
        _buildWeekNavigation(context, weekDates, colorScheme),
        
        // Day headers
        _buildDayHeaders(weekDates, colorScheme),
        
        Divider(height: 1, color: colorScheme.outlineVariant),
        
        // Scrollable timeline
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: _buildWeekTimeline(weekDates, colorScheme),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekNavigation(BuildContext context, List<DateTime> weekDates, ColorScheme colorScheme) {
    final startDate = weekDates.first;
    final endDate = weekDates.last;
    final monthYear = startDate.month == endDate.month
        ? DateFormat('MMMM yyyy').format(startDate)
        : '${DateFormat('MMM').format(startDate)} - ${DateFormat('MMM yyyy').format(endDate)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: colorScheme.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              widget.onDateChanged(widget.selectedDate.subtract(const Duration(days: 7)));
            },
          ),
          Expanded(
            child: Text(
              monthYear,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Today',
            onPressed: () {
              widget.onDateChanged(DateTime.now());
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              widget.onDateChanged(widget.selectedDate.add(const Duration(days: 7)));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders(List<DateTime> weekDates, ColorScheme colorScheme) {
    final now = DateTime.now();
    
    return Container(
      height: _headerHeight,
      color: colorScheme.surface,
      child: Row(
        children: [
          // Time column spacer
          const SizedBox(width: 44),
          // Day columns
          ...weekDates.map((date) {
            final isToday = _isSameDay(date, now);
            final isSelected = _isSameDay(date, widget.selectedDate);
            
            return Expanded(
              child: GestureDetector(
                onTap: () => widget.onDateChanged(date),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? colorScheme.primaryContainer.withOpacity(0.3) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isToday ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isToday ? colorScheme.primary : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            date.day.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isToday ? colorScheme.onPrimary : colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeekTimeline(List<DateTime> weekDates, ColorScheme colorScheme) {
    final now = DateTime.now();
    final isCurrentWeek = weekDates.any((d) => _isSameDay(d, now));

    return Stack(
      children: [
        // Hour grid
        Column(
          children: List.generate(24, (hour) => _buildHourRow(hour, weekDates.length, colorScheme)),
        ),
        
        // Current time indicator
        if (isCurrentWeek) _buildCurrentTimeIndicator(now, weekDates, colorScheme),
        
        // Events for each day
        ..._buildWeekEvents(weekDates, colorScheme),
      ],
    );
  }

  Widget _buildHourRow(int hour, int dayCount, ColorScheme colorScheme) {
    final timeStr = '${hour.toString().padLeft(2, '0')}';
    
    return SizedBox(
      height: _hourHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                timeStr,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          ...List.generate(dayCount, (index) => Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
                  left: index > 0 ? BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)) : BorderSide.none,
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(DateTime now, List<DateTime> weekDates, ColorScheme colorScheme) {
    final dayIndex = weekDates.indexWhere((d) => _isSameDay(d, now));
    if (dayIndex == -1) return const SizedBox.shrink();
    
    final top = (now.hour + now.minute / 60) * _hourHeight;
    final dayWidth = (MediaQuery.of(context).size.width - 44) / 7;
    
    return Positioned(
      top: top,
      left: 44 + (dayIndex * dayWidth),
      width: dayWidth,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWeekEvents(List<DateTime> weekDates, ColorScheme colorScheme) {
    final List<Widget> eventWidgets = [];
    final dayWidth = (MediaQuery.of(context).size.width - 44) / 7;

    for (int i = 0; i < weekDates.length; i++) {
      final date = weekDates[i];
      final events = CalendarDataHelper.getEventsForDate(widget.groupedRecords, date);
      final timedEvents = events.where((e) => CalendarDataHelper.getEventHour(e) != -1).toList();

      for (final event in timedEvents) {
        final (startHour, endHour) = CalendarDataHelper.getEventHourRange(event);
        final duration = (endHour - startHour).clamp(1, 24);
        
        eventWidgets.add(
          Positioned(
            top: startHour * _hourHeight + 2,
            left: 44 + (i * dayWidth) + 2,
            width: dayWidth - 4,
            height: duration * _hourHeight - 4,
            child: CalendarEventCard(
              record: event,
              onTap: () => showEntryScheduleP(context, event),
              isCompact: true,
            ),
          ),
        );
      }
    }

    return eventWidgets;
  }
}
