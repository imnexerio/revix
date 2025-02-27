import 'package:flutter/material.dart';

import 'ScheduleTable.dart';
import 'getRecords.dart';
import 'showLectureDetails.dart';

class TodayPage extends StatefulWidget {
  @override
  _TodayPageState createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late Future<Map<String, List<Map<String, dynamic>>>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = getRecords();
  }

  Future<void> _refreshRecords() async {
    setState(() {
      _recordsFuture = getRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshRecords,
        child: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
          future: _recordsFuture,
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
            } else if (!snapshot.hasData || (snapshot.data!['today']!.isEmpty &&
                snapshot.data!['missed']!.isEmpty &&
                snapshot.data!['nextDay']!.isEmpty &&
                snapshot.data!['next7Days']!.isEmpty &&
                snapshot.data!['todayAdded']!.isEmpty)) {
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
            } else {
              // Use ScheduleTable for all categories of records
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  children: [
                    if (snapshot.data!['missed']!.isNotEmpty)
                      ScheduleTable(
                        initialRecords: snapshot.data!['missed']!,
                        title: 'Missed Schedule (${snapshot.data!['missed']!.length})',
                        onSelect: (context, record) => showLectureDetails(context, record, _refreshRecords),
                      ),
                    if (snapshot.data!['today']!.isNotEmpty)
                      ScheduleTable(
                        initialRecords: snapshot.data!['today']!,
                        title: 'Today\'s Schedule (${snapshot.data!['today']!.length})',
                        onSelect: (context, record) => showLectureDetails(context, record, _refreshRecords),
                      ),
                    if (snapshot.data!['todayAdded']!.isNotEmpty)
                      ScheduleTable(
                        initialRecords: snapshot.data!['todayAdded']!,
                        title: 'Today\'s Added Records (${snapshot.data!['todayAdded']!.length})',
                        onSelect: (context, record) => showLectureDetails(context, record, _refreshRecords),
                      ),
                    if (snapshot.data!['nextDay']!.isNotEmpty)
                      ScheduleTable(
                        initialRecords: snapshot.data!['nextDay']!,
                        title: 'Next Day Schedule (${snapshot.data!['nextDay']!.length})',
                        onSelect: (context, record) => showLectureDetails(context, record, _refreshRecords),
                      ),
                    if (snapshot.data!['next7Days']!.isNotEmpty)
                      ScheduleTable(
                        initialRecords: snapshot.data!['next7Days']!,
                        title: 'Next 7 Days Schedule (${snapshot.data!['next7Days']!.length})',
                        onSelect: (context, record) => showLectureDetails(context, record, _refreshRecords),
                      ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}