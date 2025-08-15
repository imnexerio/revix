import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../SchedulePage/LegendItem.dart';
import '../SchedulePage/ProportionalRingPainter.dart';

class StudyCalendar extends StatefulWidget {
  final List<Map<String, dynamic>> records;
  final String trackingType;
  const StudyCalendar({
    Key? key,
    required this.records,
    this.trackingType = '',
  }) : super(key: key);

  @override
  _StudyCalendarState createState() => _StudyCalendarState();

}

class _StudyCalendarState extends State<StudyCalendar> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late Map<DateTime, List<Map<String, dynamic>>> _events;

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _events = {};
    _initializeEvents();
  }
  @override
  void didUpdateWidget(StudyCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.records != oldWidget.records) {
      _initializeEvents(); // Re-initialize events when records change
    }
  }

  void _initializeEvents() {
    _events = {};

    for (var record in widget.records) {
      final details = record['details'] as Map<String, dynamic>;

      // Add date learned events
      if (details.containsKey('start_timestamp')) {
        final dateLearnedStr = details['start_timestamp'] as String;
        final dateLearned = DateTime.parse(dateLearnedStr);
        final key = DateTime(dateLearned.year, dateLearned.month, dateLearned.day);

        if (_events[key] == null) {
          _events[key] = [];
        }

        _events[key]!.add({
          'type': 'learned',
          'category': record['category'],
          'sub_category': record['sub_category'],
          'record_title': record['record_title'],
          'description': details['description'],
          'status': details['status'] ?? 'Enabled',
        });
      }

      // Add revision dates
      if (details.containsKey('dates_updated') && details['dates_updated'] is List) {
        for (var dateStr in (details['dates_updated'] as List)) {
          final dateRevised = DateTime.parse(dateStr.toString());
          final key = DateTime(dateRevised.year, dateRevised.month, dateRevised.day);

          if (_events[key] == null) {
            _events[key] = [];
          }

          _events[key]!.add({
            'type': 'revised',
            'category': record['category'],
            'sub_category': record['sub_category'],
            'record_title': record['record_title'],
            'description': details['description'],
            'status': details['status'] ?? 'Enabled',
          });
        }
      }

      // Add missed revision dates
      if (details.containsKey('dates_missed_revisions') && details['dates_missed_revisions'] is List) {
        for (var dateStr in (details['dates_missed_revisions'] as List)) {
          final dateMissed = DateTime.parse(dateStr.toString());
          final key = DateTime(dateMissed.year, dateMissed.month, dateMissed.day);

          if (_events[key] == null) {
            _events[key] = [];
          }

          _events[key]!.add({
            'type': 'missed',
            'category': record['category'],
            'sub_category': record['sub_category'],
            'record_title': record['record_title'],
            'description': details['description'],
            'status': details['status'] ?? 'Enabled',
          });
        }
      }

      // Add scheduled dates
      if (details['date_initiated']!='Unspecified')
      if (details.containsKey('scheduled_date')) {
        // Skip records with Disabled status
        final status = details['status'] ?? 'Enabled';
        if (status == 'Disabled') {
          continue;
        }
        
        final dateScheduledStr = details['scheduled_date'] as String;
        final dateScheduled = DateTime.parse(dateScheduledStr);
        final key = DateTime(dateScheduled.year, dateScheduled.month, dateScheduled.day);

        if (_events[key] == null) {
          _events[key] = [];
        }

        _events[key]!.add({
          'type': 'scheduled',
          'category': record['category'],
          'sub_category': record['sub_category'],
          'record_title': record['record_title'],
          'description': details['description'],
          'status': status,
        });
      }
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            eventLoader: _getEventsForDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarBuilders: CalendarBuilders(
              // Custom day builder for the concentric circles effect
              defaultBuilder: (context, day, focusedDay) {
                final events = _getEventsForDay(day);

                return Container(
                  margin: const EdgeInsets.all(4.0),
                  alignment: Alignment.center,
                  child: _buildConcentricDay(day, events, false, false),
                );
              },
              todayBuilder: (context, day, focusedDay) {
                final events = _getEventsForDay(day);

                return Container(
                  margin: const EdgeInsets.all(4.0),
                  alignment: Alignment.center,
                  child: _buildConcentricDay(day, events, true, false),
                );
              },
              selectedBuilder: (context, day, focusedDay) {
                final events = _getEventsForDay(day);

                return Container(
                  margin: const EdgeInsets.all(4.0),
                  alignment: Alignment.center,
                  child: _buildConcentricDay(day, events, false, true),
                );
              },
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
            ),
            // Add this to hide the default markers
            calendarStyle: const CalendarStyle(
              markersMaxCount: 0,
              // Make sure any marker-related properties are set to be invisible
              // markerDecoration: const BoxDecoration(
              //   color: Colors.transparent,
              //   shape: BoxShape.circle,
              // ),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                LegendItem( label: 'Initiated', color: Colors.blue, icon: Icons.school,),
                LegendItem( label: 'Reviewed', color: Colors.green, icon: Icons.check_circle,),
                LegendItem( label: 'Scheduled', color: Colors.orange, icon: Icons.event,),
                LegendItem( label: 'Missed', color: Colors.red, icon: Icons.cancel,),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildEventList(),
        ]
    );
  }

  Widget _buildConcentricDay(DateTime day, List<Map<String, dynamic>> events, bool isToday, bool isSelected) {
    // Count events by type
    int learnedCount = 0;
    int revisedCount = 0;
    int scheduledCount = 0;
    int missedCount = 0;

    for (var event in events) {
      switch (event['type']) {
        case 'learned':
          learnedCount++;
          break;
        case 'revised':
          revisedCount++;
          break;
        case 'scheduled':
          scheduledCount++;
          break;
        case 'missed':
          missedCount++;
          break;
      }
    }

    // Calculate the total count of events
    int totalEvents = learnedCount + revisedCount + scheduledCount + missedCount;

    // Create sorted list of event types by count
    final eventCounts = [
      {'type': 'learned', 'count': learnedCount, 'color': Colors.blue},
      {'type': 'revised', 'count': revisedCount, 'color': Colors.green},
      {'type': 'scheduled', 'count': scheduledCount, 'color': Colors.orange},
      {'type': 'missed', 'count': missedCount, 'color': Colors.red},
    ];

    // Remove zero count events
    final activeEvents = eventCounts.where((e) => (e['count'] as int) > 0).toList();

    // Determine if any events exist
    final bool hasEvents = activeEvents.isNotEmpty;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Add proportional ring if there are events
        if (hasEvents)
          SizedBox(
            width: 40,
            height: 40,
            child: CustomPaint(
              painter: EnhancedRingPainter(
                events: activeEvents,
                totalEvents: totalEvents,
              ),
            ),
          ),

        // Base circle for the day number
        Container(
          width: 35, // Fixed inner circle size
          height: 35,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: (isToday || isSelected)
                ? Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
              width: 6,
            )
                : null,
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildEventList() {
    List<Map<String, dynamic>> selectedEvents = _getEventsForDay(_selectedDay);

    if (selectedEvents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text(
            'No events for this day',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    // Group events by type
    final groupedEvents = {
      'learned': <Map<String, dynamic>>[],
      'revised': <Map<String, dynamic>>[],
      'scheduled': <Map<String, dynamic>>[],
      'missed': <Map<String, dynamic>>[],
    };

    for (var event in selectedEvents) {
      final type = event['type'] as String;
      if (groupedEvents.containsKey(type)) {
        groupedEvents[type]!.add(event);
      }
    }

    return Expanded(
      child: ListView(
        children: [
          // Display events grouped by type with summary count
          if (groupedEvents['learned']!.isNotEmpty)
            _buildEventTypeSection('Initiated', groupedEvents['learned']!, Colors.blue),
          if (groupedEvents['revised']!.isNotEmpty)
            _buildEventTypeSection('Reviewed', groupedEvents['revised']!, Colors.green),
          if (groupedEvents['scheduled']!.isNotEmpty)
            _buildEventTypeSection('Scheduled', groupedEvents['scheduled']!, Colors.orange),
          if (groupedEvents['missed']!.isNotEmpty)
            _buildEventTypeSection('Missed', groupedEvents['missed']!, Colors.red),
        ],
      ),
    );
  }



  Widget _buildEventTypeSection(String title, List<Map<String, dynamic>> events, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$title (${events.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        ...events.map((event) => Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Visual indicator line with status-based appearance (similar to AnimatedCardDetailP)
                _buildStatusIndicatorLine(color, event['status']),
                const SizedBox(width: 12),
                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: color,
                          radius: 20,
                          child: Icon(
                            _getEventTypeIcon(event['type']),
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${event['category']} (${event['sub_category']}) - ${event['record_title']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                event['description'] ?? 'No description',
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
        const Divider(thickness: 1),
      ],
    );
  }

  // Build status indicator line - solid if enabled, dashed if disabled (similar to AnimatedCardDetailP)
  Widget _buildStatusIndicatorLine(Color lineColor, String? status, {int dashCount = 3}) {
    final bool isEnabled = status == 'Enabled';

    if (isEnabled) {
      // Solid line for enabled status
      return Container(
        width: 4,
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
        width: 4,
        child: Column(
          children: List.generate(dashCount, (index) {
            return Expanded(
              child: Container(
                width: 4,
                margin: const EdgeInsets.symmetric(vertical: 0.5),
                decoration: BoxDecoration(
                  color: index % 2 == 0 ? lineColor : Colors.transparent,
                  borderRadius: index == 0 
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(12),
                      )
                    : index == (dashCount - 1)
                      ? const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                        )
                      : BorderRadius.zero,
                ),
              ),
            );
          }),
        ),
      );
    }
  }

  IconData _getEventTypeIcon(String type) {
    switch (type) {
      case 'learned':
        return Icons.school;
      case 'revised':
        return Icons.check_circle;
      case 'missed':
        return Icons.cancel;
      case 'scheduled':
        return Icons.event;
      default:
        return Icons.event_note;
    }
  }
}