import 'dart:async';
import 'package:flutter/material.dart';
import '../Utils/UnifiedDatabaseService.dart';
import '../Utils/lecture_colors.dart';
import 'ScheduleTable.dart';
import 'showLectureScheduleP.dart';

class TodayPage extends StatefulWidget {
  @override
  _TodayPageState createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late StreamController<Map<String, List<Map<String, dynamic>>>> _recordsController;
  late Stream<Map<String, List<Map<String, dynamic>>>> _recordsStream;
  late UnifiedDatabaseService _databaseListener;

  @override
  void initState() {
    super.initState();
    _recordsController = StreamController<Map<String, List<Map<String, dynamic>>>>();
    _recordsStream = _recordsController.stream;
    _databaseListener = UnifiedDatabaseService();
    _databaseListener.initialize();
    _databaseListener.categorizedRecordsStream.listen((data) {
      _recordsController.add(data);
      // Preload colors for all entry types when new data arrives
      _preloadColors(data);
    }, onError: (error) {
      _recordsController.addError(error);
    });
  }

  /// Preload colors for all unique entry types to improve performance
  Future<void> _preloadColors(Map<String, List<Map<String, dynamic>>> data) async {
    if (!mounted) return;
    
    // Extract all unique entry types from the data
    Set<String> entryTypes = {};
    for (var recordList in data.values) {
      for (var record in recordList) {
        final entryType = record['entry_type']?.toString();
        if (entryType != null && entryType.isNotEmpty) {
          entryTypes.add(entryType);
        }
      }
    }

    // Preload colors for all entry types
    for (String entryType in entryTypes) {
      try {
        await LectureColors.getLectureTypeColor(context, entryType);
      } catch (e) {
        // Silently handle errors during preloading
        print('Error preloading color for $entryType: $e');
      }
    }
  }

  @override
  void dispose() {
    _recordsController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          _databaseListener.forceDataReprocessing();
          // return Future.delayed(const Duration(milliseconds: 300));
        },
        child: StreamBuilder<Map<String, List<Map<String, dynamic>>>>(
          stream: _recordsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
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
            } else if (!snapshot.hasData || _hasNoRecords(snapshot.data!)) {
              return _buildEmptyState();
            } else {
              return _buildSchedulesList(snapshot.data!);
            }
          },
        ),
      ),
    );
  }

  bool _hasNoRecords(Map<String, List<Map<String, dynamic>>> data) {
    return data['today']!.isEmpty &&
        data['missed']!.isEmpty &&
        data['nextDay']!.isEmpty &&
        data['next7Days']!.isEmpty &&
        data['todayAdded']!.isEmpty &&
        data['noreminderdate']!.isEmpty;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No schedules found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildSchedulesList(Map<String, List<Map<String, dynamic>>> data) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        children: [
          if (data['missed']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['missed']!,
              title: 'Missed (${data['missed']!.length})',
              onSelect: (context, record) => showLectureScheduleP(context, record),
            ),
          if (data['today']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['today']!,
              title: 'Today\'s (${data['today']!.length})',
              onSelect: (context, record) => showLectureScheduleP(context, record),
            ),
          if (data['todayAdded']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['todayAdded']!,
              title: 'Today\'s Added Records (${data['todayAdded']!.length})',
              onSelect: (context, record) => showLectureScheduleP(context, record),
            ),
          if (data['nextDay']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['nextDay']!,
              title: 'Next Day (${data['nextDay']!.length})',
              onSelect: (context, record) => showLectureScheduleP(context, record),
            ),
          if (data['next7Days']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['next7Days']!,
              title: 'Next Week (${data['next7Days']!.length})',
              onSelect: (context, record) => showLectureScheduleP(context, record),
            ),
          if (data['noreminderdate']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['noreminderdate']!,
              title: 'Unspecified Date (${data['noreminderdate']!.length})',
              onSelect: (context, record) => showLectureScheduleP(context, record),
            ),
        ],
      ),
    );
  }
}