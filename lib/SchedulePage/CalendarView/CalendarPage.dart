import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Utils/UnifiedDatabaseService.dart';
import 'CalendarDataHelper.dart';
import 'CalendarDayView.dart';
import 'CalendarWeekView.dart';
import 'CalendarMonthView.dart';

enum CalendarViewType { day, week, month }

/// Main Calendar page with Day/Week/Month views and sidebar toggle
class CalendarPage extends StatefulWidget {
  final bool isSidebarVisible;

  const CalendarPage({
    Key? key,
    this.isSidebarVisible = true,
  }) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const String _viewTypeKey = 'calendarViewType';
  
  late StreamController<Map<String, List<Map<String, dynamic>>>> _recordsController;
  late Stream<Map<String, List<Map<String, dynamic>>>> _recordsStream;
  late UnifiedDatabaseService _databaseListener;
  
  CalendarViewType _currentViewType = CalendarViewType.week;
  DateTime _selectedDate = DateTime.now();
  SharedPreferences? _prefs;
  
  Map<DateTime, List<Map<String, dynamic>>> _groupedRecords = {};

  @override
  void initState() {
    super.initState();
    _recordsController = StreamController<Map<String, List<Map<String, dynamic>>>>();
    _recordsStream = _recordsController.stream;
    _databaseListener = UnifiedDatabaseService();
    _databaseListener.initialize();
    
    _databaseListener.categorizedRecordsStream.listen((data) {
      _recordsController.add(data);
      setState(() {
        _groupedRecords = CalendarDataHelper.groupRecordsByDate(data);
      });
    }, onError: (error) {
      _recordsController.addError(error);
    });
    
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    final savedViewType = _prefs?.getInt(_viewTypeKey) ?? 1; // Default to week
    if (mounted) {
      setState(() {
        _currentViewType = CalendarViewType.values[savedViewType.clamp(0, 2)];
      });
    }
  }

  void _setViewType(CalendarViewType type) {
    setState(() {
      _currentViewType = type;
    });
    _prefs?.setInt(_viewTypeKey, type.index);
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
    });
  }

  @override
  void dispose() {
    _recordsController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Sidebar with view type buttons
          if (widget.isSidebarVisible)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: isDesktop ? 48.0 : 40.0,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                ),
              ),
              child: _buildViewTypeSidebar(colorScheme),
            ),
          
          // Main calendar content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _databaseListener.forceDataReprocessing();
              },
              child: _buildCalendarContent(colorScheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewTypeSidebar(ColorScheme colorScheme) {
    return Column(
      children: [
        const SizedBox(height: 16),
        _buildViewTypeButton(
          CalendarViewType.day,
          Icons.view_day,
          'Day',
          colorScheme,
        ),
        const SizedBox(height: 8),
        _buildViewTypeButton(
          CalendarViewType.week,
          Icons.view_week,
          'Week',
          colorScheme,
        ),
        const SizedBox(height: 8),
        _buildViewTypeButton(
          CalendarViewType.month,
          Icons.calendar_view_month,
          'Month',
          colorScheme,
        ),
        const Spacer(),
        // Today button
        IconButton(
          icon: Icon(
            Icons.today,
            color: colorScheme.primary,
          ),
          tooltip: 'Go to Today',
          onPressed: () {
            _onDateChanged(DateTime.now());
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildViewTypeButton(
    CalendarViewType type,
    IconData icon,
    String label,
    ColorScheme colorScheme,
  ) {
    final isSelected = _currentViewType == type;
    
    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: () => _setViewType(type),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarContent(ColorScheme colorScheme) {
    return StreamBuilder<Map<String, List<Map<String, dynamic>>>>(
      stream: _recordsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _groupedRecords.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[400],
                  ),
                ),
              ],
            ),
          );
        }

        switch (_currentViewType) {
          case CalendarViewType.day:
            return CalendarDayView(
              groupedRecords: _groupedRecords,
              selectedDate: _selectedDate,
              onDateChanged: _onDateChanged,
            );
          case CalendarViewType.week:
            return CalendarWeekView(
              groupedRecords: _groupedRecords,
              selectedDate: _selectedDate,
              onDateChanged: _onDateChanged,
            );
          case CalendarViewType.month:
            return CalendarMonthView(
              groupedRecords: _groupedRecords,
              selectedDate: _selectedDate,
              onDateChanged: _onDateChanged,
            );
        }
      },
    );
  }
}
