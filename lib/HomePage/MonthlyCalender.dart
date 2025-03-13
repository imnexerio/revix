import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../SchedulePage/LegendItem.dart';
import '../SchedulePage/ProportionalRingPainter.dart';

class StudyCalendar extends StatefulWidget {
  final List<Map<String, dynamic>> records;

  const StudyCalendar({
    Key? key,
    required this.records,
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
      if (details.containsKey('initiated_on')) {
        final dateLearnedStr = details['initiated_on'] as String;
        final dateLearned = DateTime.parse(dateLearnedStr);
        final key = DateTime(dateLearned.year, dateLearned.month, dateLearned.day);

        if (_events[key] == null) {
          _events[key] = [];
        }

        _events[key]!.add({
          'type': 'learned',
          'subject': record['subject'],
          'subject_code': record['subject_code'],
          'lecture_no': record['lecture_no'],
          'description': details['description'],
        });
      }

      // Add revision dates
      if (details.containsKey('dates_revised') && details['dates_revised'] is List) {
        for (var dateStr in (details['dates_revised'] as List)) {
          final dateRevised = DateTime.parse(dateStr.toString());
          final key = DateTime(dateRevised.year, dateRevised.month, dateRevised.day);

          if (_events[key] == null) {
            _events[key] = [];
          }

          _events[key]!.add({
            'type': 'revised',
            'subject': record['subject'],
            'subject_code': record['subject_code'],
            'lecture_no': record['lecture_no'],
            'description': details['description'],
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
            'subject': record['subject'],
            'subject_code': record['subject_code'],
            'lecture_no': record['lecture_no'],
            'description': details['description'],
          });
        }
      }

      // Add scheduled dates
      if (details.containsKey('date_scheduled')) {
        final dateScheduledStr = details['date_scheduled'] as String;
        final dateScheduled = DateTime.parse(dateScheduledStr);
        final key = DateTime(dateScheduled.year, dateScheduled.month, dateScheduled.day);

        if (_events[key] == null) {
          _events[key] = [];
        }

        _events[key]!.add({
          'type': 'scheduled',
          'subject': record['subject'],
          'subject_code': record['subject_code'],
          'lecture_no': record['lecture_no'],
          'description': details['description'],
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
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
            ),
            // Add this to hide the default markers
            calendarStyle: CalendarStyle(
              markersMaxCount: 0,
              // Make sure any marker-related properties are set to be invisible
              // markerDecoration: const BoxDecoration(
              //   color: Colors.transparent,
              //   shape: BoxShape.circle,
              // ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color,
              child: Icon(
                _getEventTypeIcon(event['type']),
                color: Theme.of(context).colorScheme.onPrimary,
                size: 20,
              ),
            ),
            title: Text(
              '${event['subject']} (${event['subject_code']}) - ${event['lecture_no']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(event['description'] ?? 'No description'),
          ),
        )).toList(),
        const Divider(thickness: 1),
      ],
    );
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