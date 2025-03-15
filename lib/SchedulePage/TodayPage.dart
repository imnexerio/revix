import 'dart:async';
import 'package:flutter/material.dart';
import 'RealtimeDatabaseListener.dart';
import 'ScheduleTable.dart';
import 'showLectureScheduleP.dart';

class TodayPage extends StatefulWidget {
  @override
  _TodayPageState createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late StreamController<Map<String, List<Map<String, dynamic>>>> _recordsController;
  late Stream<Map<String, List<Map<String, dynamic>>>> _recordsStream;
  late RealtimeDatabaseListener _databaseListener;


  @override
  void initState() {
    super.initState();
    _recordsController = StreamController<Map<String, List<Map<String, dynamic>>>>();
    _recordsStream = _recordsController.stream;
    _databaseListener = RealtimeDatabaseListener(_recordsController);
    _databaseListener.setupDatabaseListener();
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
                    SizedBox(height: 16),
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
        data['todayAdded']!.isEmpty;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
          SizedBox(height: 16),
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
              title: 'Missed Schedule (${data['missed']!.length})',
              onSelect: (context, record) => showLectureScheduleP(context, record),
            ),
          if (data['today']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['today']!,
              title: 'Today\'s Schedule (${data['today']!.length})',
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
              title: 'Next Day Schedule (${data['nextDay']!.length})',
              onSelect: (context, record) => showLectureScheduleP(context, record),
            ),
          if (data['next7Days']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['next7Days']!,
              title: 'Next 7 Days Schedule (${data['next7Days']!.length})',
              onSelect: (context, record) => showLectureScheduleP(context, record),
            ),
        ],
      ),
    );
  }
}