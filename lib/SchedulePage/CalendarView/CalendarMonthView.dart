import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'CalendarDataHelper.dart';
import 'CalendarEventCard.dart';
import '../showEntryScheduleP.dart';

/// Month grid view with event previews
class CalendarMonthView extends StatelessWidget {
  final Map<DateTime, List<Map<String, dynamic>>> groupedRecords;
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;

  const CalendarMonthView({
    Key? key,
    required this.groupedRecords,
    required this.selectedDate,
    required this.onDateChanged,
  }) : super(key: key);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final monthDates = CalendarDataHelper.getMonthGridDates(selectedDate);

    return Column(
      children: [
        // Month navigation header
        _buildMonthNavigation(context, colorScheme),
        
        // Weekday headers
        _buildWeekdayHeaders(colorScheme),
        
        Divider(height: 1, color: colorScheme.outlineVariant),
        
        // Month grid
        Expanded(
          child: _buildMonthGrid(monthDates, colorScheme, context),
        ),
      ],
    );
  }

  Widget _buildMonthNavigation(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: colorScheme.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final prevMonth = DateTime(selectedDate.year, selectedDate.month - 1, 1);
              onDateChanged(prevMonth);
            },
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _selectMonth(context),
              child: Text(
                DateFormat('MMMM yyyy').format(selectedDate),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Today',
            onPressed: () {
              onDateChanged(DateTime.now());
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final nextMonth = DateTime(selectedDate.year, selectedDate.month + 1, 1);
              onDateChanged(nextMonth);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _selectMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      onDateChanged(picked);
    }
  }

  Widget _buildWeekdayHeaders(ColorScheme colorScheme) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: colorScheme.surface,
      child: Row(
        children: weekdays.map((day) => Expanded(
          child: Text(
            day,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildMonthGrid(List<DateTime> monthDates, ColorScheme colorScheme, BuildContext context) {
    final now = DateTime.now();
    
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.7,
      ),
      itemCount: monthDates.length,
      itemBuilder: (context, index) {
        final date = monthDates[index];
        final isCurrentMonth = _isSameMonth(date, selectedDate);
        final isToday = _isSameDay(date, now);
        final isSelected = _isSameDay(date, selectedDate);
        final events = CalendarDataHelper.getEventsForDate(groupedRecords, date);

        return GestureDetector(
          onTap: () => onDateChanged(date),
          child: Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: isSelected 
                  ? colorScheme.primaryContainer.withOpacity(0.3) 
                  : (isCurrentMonth ? null : colorScheme.surfaceContainerLow.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(4),
              border: isToday 
                  ? Border.all(color: colorScheme.primary, width: 2)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date number
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isToday ? colorScheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        date.day.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday 
                              ? colorScheme.onPrimary 
                              : (isCurrentMonth 
                                  ? colorScheme.onSurface 
                                  : colorScheme.onSurfaceVariant.withOpacity(0.5)),
                        ),
                      ),
                    ),
                  ),
                ),
                // Events preview
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...events.take(3).map((event) => Padding(
                          padding: const EdgeInsets.only(bottom: 1),
                          child: CalendarEventCard(
                            record: event,
                            onTap: () => showEntryScheduleP(context, event),
                            isCompact: true,
                            showTime: false,
                          ),
                        )),
                        if (events.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '+${events.length - 3} more',
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
