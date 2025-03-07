import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'ScheduleTable.dart';
import 'showLectureDetails.dart';

class TodayPage extends StatefulWidget {
  @override
  _TodayPageState createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  // Stream controller for record updates
  late StreamController<Map<String, List<Map<String, dynamic>>>> _recordsController;
  late Stream<Map<String, List<Map<String, dynamic>>>> _recordsStream;
  DatabaseReference? _databaseRef;

  // Cached dates to avoid recreating on every data update
  final String _todayStr = DateTime.now().toIso8601String().split('T')[0];
  final String _nextDayStr = DateTime.now().add(Duration(days: 1)).toIso8601String().split('T')[0];
  final DateTime _today = DateTime.now();
  final DateTime _next7Days = DateTime.now().add(Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _recordsController = StreamController<Map<String, List<Map<String, dynamic>>>>();
    _recordsStream = _recordsController.stream;
    _setupDatabaseListener();
  }

  @override
  void dispose() {
    _recordsController.close();
    _databaseRef?.onValue.listen(null)?.cancel(); // Cancel the listener
    super.dispose();
  }

  void _setupDatabaseListener() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _recordsController.addError('No authenticated user');
      return;
    }

    String uid = user.uid;
    _databaseRef = FirebaseDatabase.instance.ref('users/$uid/user_data');

    _databaseRef!.onValue.listen((event) {
      if (!event.snapshot.exists) {
        _recordsController.add({
          'today': [], 'missed': [], 'nextDay': [], 'next7Days': [], 'todayAdded': []
        });
        return;
      }

      // Process data and add to stream
      Map<String, List<Map<String, dynamic>>> processedData = _processSnapshot(event.snapshot);
      _recordsController.add(processedData);
    }, onError: (error) {
      _recordsController.addError('Failed to fetch records: $error');
    });
  }

  // Optimized data processing with better initial capacity allocation
  Map<String, List<Map<String, dynamic>>> _processSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) {
      return {'today': [], 'missed': [], 'nextDay': [], 'next7Days': [], 'todayAdded': []};
    }

    Map<Object?, Object?> rawData = snapshot.value as Map<Object?, Object?>;

    // Pre-allocate with estimated capacity
    List<Map<String, dynamic>> todayRecords = [];
    List<Map<String, dynamic>> missedRecords = [];
    List<Map<String, dynamic>> nextDayRecords = [];
    List<Map<String, dynamic>> next7DaysRecords = [];
    List<Map<String, dynamic>> todayAddedRecords = [];

    // Process records more efficiently
    rawData.forEach((subjectKey, subjectValue) {
      if (subjectValue is! Map) return;

      subjectValue.forEach((codeKey, codeValue) {
        if (codeValue is! Map) return;

        codeValue.forEach((recordKey, recordValue) {
          if (recordValue is! Map) return;

          final dateScheduled = recordValue['date_scheduled'];
          final dateLearnt = recordValue['date_learnt'];
          final status = recordValue['status'];

          // Early filtering - skip disabled records
          if (dateScheduled == null || status != 'Enabled') return;

          // Create record map - only once per record
          final Map<String, dynamic> record = {
            'subject': subjectKey.toString(),
            'subject_code': codeKey.toString(),
            'lecture_no': recordKey.toString(),
            'date_scheduled': dateScheduled.toString(),
            'lecture_type': recordValue['lecture_type'],
            'date_learnt': recordValue['date_learnt'],
            'date_revised': recordValue['date_revised'],
            'description': recordValue['description'],
            'missed_revision': recordValue['missed_revision'],
            'dates_missed_revisions': recordValue['dates_missed_revisions'] ?? [],
            'dates_revised': recordValue['dates_revised'] ?? [],
            'no_revision': recordValue['no_revision'],
            'revision_frequency': recordValue['revision_frequency'],
            'status': recordValue['status'],
          };

          // Parse date only once
          final scheduledDateStr = dateScheduled.toString().split('T')[0];

          // Efficient categorization
          if (scheduledDateStr == _todayStr) {
            todayRecords.add(record);
          } else if (scheduledDateStr.compareTo(_todayStr) < 0) {
            // If scheduled date is before today
            missedRecords.add(record);
          } else if (dateLearnt != null &&
              dateLearnt.toString().split('T')[0] == _todayStr) {
            todayAddedRecords.add(record);
          } else if (scheduledDateStr == _nextDayStr) {
            nextDayRecords.add(record);
          } else {
            // Only parse full date object if needed for the 7-day comparison
            final scheduledDate = DateTime.parse(dateScheduled.toString());
            if (scheduledDate.isAfter(_today) && scheduledDate.isBefore(_next7Days)) {
              next7DaysRecords.add(record);
            }
          }
        });
      });
    });

    return {
      'today': todayRecords,
      'missed': missedRecords,
      'nextDay': nextDayRecords,
      'next7Days': next7DaysRecords,
      'todayAdded': todayAddedRecords,
    };
  }

  Future<void> _refreshRecords() async {
    // Trigger a database refresh
    _databaseRef?.get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          await _databaseRef?.get(); // This will trigger the listener
          // Add small delay to ensure UI shows the refresh indicator
          return Future.delayed(Duration(milliseconds: 300));
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

  // Helper method to check if there are any records
  bool _hasNoRecords(Map<String, List<Map<String, dynamic>>> data) {
    return data['today']!.isEmpty &&
        data['missed']!.isEmpty &&
        data['nextDay']!.isEmpty &&
        data['next7Days']!.isEmpty &&
        data['todayAdded']!.isEmpty;
  }

  // Extracted widget for empty state
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

  // Extracted widget for building the schedules list
  Widget _buildSchedulesList(Map<String, List<Map<String, dynamic>>> data) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        children: [
          if (data['missed']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['missed']!,
              title: 'Missed Schedule (${data['missed']!.length})',
              onSelect: (context, record) => showLectureDetails(context, record, _refreshRecords),
            ),
          if (data['today']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['today']!,
              title: 'Today\'s Schedule (${data['today']!.length})',
              onSelect: (context, record) => showLectureDetails(context, record, _refreshRecords),
            ),
          if (data['todayAdded']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['todayAdded']!,
              title: 'Today\'s Added Records (${data['todayAdded']!.length})',
              onSelect: (context, record) => showLectureDetails(context, record, _refreshRecords),
            ),
          if (data['nextDay']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['nextDay']!,
              title: 'Next Day Schedule (${data['nextDay']!.length})',
              onSelect: (context, record) => showLectureDetails(context, record, _refreshRecords),
            ),
          if (data['next7Days']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['next7Days']!,
              title: 'Next 7 Days Schedule (${data['next7Days']!.length})',
              onSelect: (context, record) => showLectureDetails(context, record, _refreshRecords),
            ),
        ],
      ),
    );
  }
}