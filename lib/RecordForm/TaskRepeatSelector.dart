import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class TaskRepeatSelector extends StatefulWidget {
  final Map<String, dynamic> initialParams;

  const TaskRepeatSelector({
    Key? key,
    this.initialParams = const {},
  }) : super(key: key);

  @override
  State<TaskRepeatSelector> createState() => _TaskRepeatSelectorState();
}

class _TaskRepeatSelectorState extends State<TaskRepeatSelector> {
  // Repeat options
  String _repeatOption = 'untilDate'; // 'forever', 'specific', 'untilDate'
  int _specificTimes = 1;
  DateTime _untilDate = DateTime(2025, 5, 4); // Default to May 4, 2025

  // Calendar variables
  DateTime _focusedDay = DateTime(2025, 5, 1);
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Custom frequency selector parameters (from original code)
  final TextEditingController _dayController = TextEditingController(text: '1');
  final TextEditingController _weekController = TextEditingController(text: '1');
  final TextEditingController _monthController = TextEditingController(text: '1');
  final TextEditingController _yearController = TextEditingController(text: '1');

  String _frequencyType = 'week'; // Default to weekly
  List<bool> _selectedDaysOfWeek = List.filled(7, false);

  // Monthly options
  String _monthlyOption = 'day'; // 'day' or 'weekday'
  int _selectedDayOfMonth = 4; // Default to 4th day
  int _selectedWeekOfMonth = 1; // Default to 1st week
  String _selectedDayOfWeek = 'Friday'; // Default to Friday

  // Yearly options
  String _yearlyOption = 'day'; // 'day' or 'weekday'
  int _selectedMonthDay = 4; // Default to 4th day
  String _selectedMonth = 'May'; // Default to May
  int _selectedWeekOfYear = 1; // Default to 1st week
  String _selectedDayOfWeekForYear = 'Friday'; // Default to Friday

  @override
  void initState() {
    super.initState();
    _loadInitialParams();
    // Set Sunday as selected by default
    _selectedDaysOfWeek[0] = true;
  }

  void _loadInitialParams() {
    if (widget.initialParams.isNotEmpty) {
      _repeatOption = widget.initialParams['repeatOption'] ?? 'untilDate';
      _specificTimes = widget.initialParams['specificTimes'] ?? 1;

      if (widget.initialParams['untilDate'] != null) {
        _untilDate = DateTime.parse(widget.initialParams['untilDate']);
        _focusedDay = DateTime(_untilDate.year, _untilDate.month, 1);
      }

      _frequencyType = widget.initialParams['frequencyType'] ?? 'week';

      // Load the appropriate controller value
      switch (_frequencyType) {
        case 'day':
          _dayController.text = (widget.initialParams['value'] ?? 1).toString();
          break;
        case 'week':
          _weekController.text = (widget.initialParams['value'] ?? 1).toString();
          break;
        case 'month':
          _monthController.text = (widget.initialParams['value'] ?? 1).toString();
          _monthlyOption = widget.initialParams['monthlyOption'] ?? 'day';
          _selectedDayOfMonth = widget.initialParams['dayOfMonth'] ?? 4;
          _selectedWeekOfMonth = widget.initialParams['weekOfMonth'] ?? 1;
          _selectedDayOfWeek = widget.initialParams['dayOfWeek'] ?? 'Friday';
          break;
        case 'year':
          _yearController.text = (widget.initialParams['value'] ?? 1).toString();
          _yearlyOption = widget.initialParams['yearlyOption'] ?? 'day';
          _selectedMonthDay = widget.initialParams['monthDay'] ?? 4;
          _selectedMonth = widget.initialParams['month'] ?? 'May';
          _selectedWeekOfYear = widget.initialParams['weekOfYear'] ?? 1;
          _selectedDayOfWeekForYear = widget.initialParams['dayOfWeekForYear'] ?? 'Friday';
          break;
      }

      if (widget.initialParams['daysOfWeek'] != null) {
        _selectedDaysOfWeek = List<bool>.from(widget.initialParams['daysOfWeek']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // Forever Option
                    _buildRepeatOption(
                      'forever',
                      'Forever',
                    ),

                    Divider(color: colorScheme.onSurface.withOpacity(0.5), height: 40),

                    // Specific number of times Option
                    _buildSpecificNumberOption(),

                    Divider(color: colorScheme.onSurface.withOpacity(0.5), height: 40),

                    // Until date Option
                    _buildRepeatOption(
                      'untilDate',
                      'Until ${DateFormat('E, d MMM, yyyy').format(_untilDate)}',
                    ),

                    // Calendar - only visible when untilDate is selected
                    if (_repeatOption == 'untilDate')
                      _buildTableCalendar(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurface.withOpacity(0.7),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Create task repeat data
                      Map<String, dynamic> repeatData = {
                        'repeatOption': _repeatOption,
                      };

                      // Add additional data based on repeat option
                      if (_repeatOption == 'specific') {
                        repeatData['specificTimes'] = _specificTimes;
                      } else if (_repeatOption == 'untilDate') {
                        repeatData['untilDate'] = _untilDate.toIso8601String();
                      }

                      // Pass the data back
                      Navigator.of(context).pop(repeatData);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatOption(
      String type,
      String label,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isSelected = _repeatOption == type;

    return Row(
      children: [
        // Radio button
        GestureDetector(
          onTap: () {
            setState(() {
              _repeatOption = type;
            });
          },
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                width: 2,
              ),
              color: isSelected ? colorScheme.primary.withOpacity(0.2) : Colors.transparent,
            ),
            child: isSelected
                ? Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary,
                ),
              ),
            )
                : null,
          ),
        ),
        const SizedBox(width: 15),

        // Label
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildSpecificNumberOption() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isSelected = _repeatOption == 'specific';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Radio button
            GestureDetector(
              onTap: () {
                setState(() {
                  _repeatOption = 'specific';
                });
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                    width: 2,
                  ),
                  color: isSelected ? colorScheme.primary.withOpacity(0.2) : Colors.transparent,
                ),
                child: isSelected
                    ? Center(
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary,
                    ),
                  ),
                )
                    : null,
              ),
            ),
            const SizedBox(width: 15),

            // Label
            Text(
              'Specific number of times',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 22,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),

        // Number selector - only visible when specific is selected
        if (isSelected)
          Padding(
            padding: const EdgeInsets.only(left: 45, top: 15),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: colorScheme.primary),
                  onPressed: () {
                    if (_specificTimes > 1) {
                      setState(() {
                        _specificTimes--;
                      });
                    }
                  },
                ),
                Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.primary),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _specificTimes.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: colorScheme.primary),
                  onPressed: () {
                    setState(() {
                      _specificTimes++;
                    });
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTableCalendar() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) {
          return isSameDay(_untilDate, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _untilDate = selectedDay;
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
        calendarStyle: CalendarStyle(
          // Weekend days (Saturday and Sunday)
          weekendTextStyle: TextStyle(color: Theme.of(context).colorScheme.error),
          // Selected day
          selectedDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          // Today
          todayDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          // Outside days (days that belong to the previous or next month)
          outsideTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          formatButtonTextStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
          titleTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontStyle: FontStyle.italic,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            fontWeight: FontWeight.bold,
          ),
          weekendStyle: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}