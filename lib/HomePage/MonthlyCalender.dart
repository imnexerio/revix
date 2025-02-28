import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

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

  void _initializeEvents() {
    _events = {};

    for (var record in widget.records) {
      final details = record['details'] as Map<String, dynamic>;

      // Add date learned events
      if (details.containsKey('date_learnt')) {
        final dateLearnedStr = details['date_learnt'] as String;
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
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return SizedBox.shrink();

              return Positioned(
                bottom: 1,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // lib/HomePage/MonthlyCalender.dart

                    // Fix the argument type mismatch by ensuring the correct type is passed
                    color: _getMarkerColor(events.cast<Map<String, dynamic>>()),
                  ),
                  width: 8,
                  height: 8,
                ),
              );
            },
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
            formatButtonShowsNext: false,
          ),
        ),
        const SizedBox(height: 16),
        _buildEventList(),
      ],
    );
  }

  Color _getMarkerColor(List<Map<String, dynamic>> events) {
    if (events.any((event) => event['type'] == 'missed')) {
      return Colors.red;
    } else if (events.any((event) => event['type'] == 'scheduled')) {
      return Colors.orange;
    } else if (events.any((event) => event['type'] == 'revised')) {
      return Colors.green;
    } else {
      return Colors.blue;
    }
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

    return Expanded(
      child: ListView.builder(
        itemCount: selectedEvents.length,
        itemBuilder: (context, index) {
          final event = selectedEvents[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getEventTypeColor(event['type']),
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
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(event['description'] ?? 'No description'),
                  const SizedBox(height: 2),
                  Text(
                    _getEventTypeText(event['type']),
                    style: TextStyle(
                      color: _getEventTypeColor(event['type']),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  Color _getEventTypeColor(String type) {
    switch (type) {
      case 'learned':
        return Colors.blue;
      case 'revised':
        return Colors.green;
      case 'missed':
        return Colors.red;
      case 'scheduled':
        return Colors.orange;
      default:
        return Colors.grey;
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

  String _getEventTypeText(String type) {
    switch (type) {
      case 'learned':
        return 'Learned';
      case 'revised':
        return 'Revised';
      case 'missed':
        return 'Missed Revision';
      case 'scheduled':
        return 'Scheduled Revision';
      default:
        return 'Event';
    }
  }
}