import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'CalendarDataHelper.dart';
import 'CalendarEventCard.dart';
import '../showEntryScheduleP.dart';

/// Day view showing hourly timeline with events
class CalendarDayView extends StatefulWidget {
  final Map<DateTime, List<Map<String, dynamic>>> groupedRecords;
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;

  const CalendarDayView({
    Key? key,
    required this.groupedRecords,
    required this.selectedDate,
    required this.onDateChanged,
  }) : super(key: key);

  @override
  State<CalendarDayView> createState() => _CalendarDayViewState();
}

class _CalendarDayViewState extends State<CalendarDayView> {
  late ScrollController _scrollController;
  static const double _hourHeight = 60.0;
  static const double _timeColumnWidth = 56.0;

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
    if (_isSameDay(widget.selectedDate, now)) {
      final targetOffset = (now.hour * _hourHeight) - 100;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final events = CalendarDataHelper.getEventsForDate(widget.groupedRecords, widget.selectedDate);
    final allDayEvents = events.where((e) => CalendarDataHelper.getEventHour(e) == -1).toList();
    final timedEvents = events.where((e) => CalendarDataHelper.getEventHour(e) != -1).toList();

    return Column(
      children: [
        // Date navigation header
        _buildDateHeader(context, colorScheme),
        
        // All-day events section
        if (allDayEvents.isNotEmpty) _buildAllDaySection(allDayEvents, colorScheme),
        
        Divider(height: 1, color: colorScheme.outlineVariant),
        
        // Hourly timeline
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: _buildTimeline(timedEvents, colorScheme),
          ),
        ),
      ],
    );
  }

  Widget _buildDateHeader(BuildContext context, ColorScheme colorScheme) {
    final isToday = _isSameDay(widget.selectedDate, DateTime.now());
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: colorScheme.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              widget.onDateChanged(widget.selectedDate.subtract(const Duration(days: 1)));
            },
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _selectDate(context),
              child: Column(
                children: [
                  Text(
                    DateFormat('EEEE').format(widget.selectedDate),
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isToday ? colorScheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat('MMM d, yyyy').format(widget.selectedDate),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isToday ? colorScheme.onPrimary : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              widget.onDateChanged(widget.selectedDate.add(const Duration(days: 1)));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      widget.onDateChanged(picked);
    }
  }

  Widget _buildAllDaySection(List<Map<String, dynamic>> allDayEvents, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              'All Day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ...allDayEvents.map((event) => CalendarEventCard(
            record: event,
            onTap: () => showEntryScheduleP(context, event),
            showTime: false,
          )),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<Map<String, dynamic>> timedEvents, ColorScheme colorScheme) {
    final now = DateTime.now();
    final isToday = _isSameDay(widget.selectedDate, now);

    return Stack(
      children: [
        // Hour grid
        Column(
          children: List.generate(24, (hour) => _buildHourRow(hour, colorScheme)),
        ),
        
        // Current time indicator
        if (isToday) _buildCurrentTimeIndicator(now, colorScheme),
        
        // Events
        ..._buildEventPositioned(timedEvents, colorScheme),
      ],
    );
  }

  Widget _buildHourRow(int hour, ColorScheme colorScheme) {
    final timeStr = '${hour.toString().padLeft(2, '0')}:00';
    
    return SizedBox(
      height: _hourHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _timeColumnWidth,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 0),
              child: Text(
                timeStr,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(DateTime now, ColorScheme colorScheme) {
    final top = (now.hour + now.minute / 60) * _hourHeight;
    
    return Positioned(
      top: top,
      left: _timeColumnWidth - 4,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
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

  List<Widget> _buildEventPositioned(List<Map<String, dynamic>> events, ColorScheme colorScheme) {
    return events.map((event) {
      final (startHour, endHour) = CalendarDataHelper.getEventHourRange(event);
      final duration = (endHour - startHour).clamp(1, 24);
      
      return Positioned(
        top: startHour * _hourHeight + 2,
        left: _timeColumnWidth + 4,
        right: 8,
        height: duration * _hourHeight - 4,
        child: CalendarEventCard(
          record: event,
          onTap: () => showEntryScheduleP(context, event),
        ),
      );
    }).toList();
  }
}
