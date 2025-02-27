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
        child: Padding(
          padding: const EdgeInsets.all(0.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
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
                  } else if (!snapshot.hasData || (snapshot.data!['today']!.isEmpty && snapshot.data!['missed']!.isEmpty && snapshot.data!['nextDay']!.isEmpty && snapshot.data!['next7Days']!.isEmpty && snapshot.data!['todayAdded']!.isEmpty)) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            'No scheduled found',
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
                    List<Map<String, dynamic>> todayRecords = snapshot.data!['today']!;
                    List<Map<String, dynamic>> missedRecords = snapshot.data!['missed']!;
                    List<Map<String, dynamic>> nextDayRecords = snapshot.data!['nextDay']!;
                    List<Map<String, dynamic>> next7DaysRecords = snapshot.data!['next7Days']!;
                    List<Map<String, dynamic>> todayAddedRecords = snapshot.data!['todayAdded']!;
                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        children: [
                          if (missedRecords.isNotEmpty)
                            ScheduleTable(
                              records: missedRecords,
                              title: 'Missed Schedule (${missedRecords.length})',
                              onSelect: (context, record) => showLectureDetails(context, record, _refreshRecords),
                            ),
                          if (todayRecords.isNotEmpty)
                            ScheduleTable(
                              records: todayRecords,
                              title: 'Today\'s Schedule (${todayRecords.length})',
                              onSelect: (context, record) => showLectureDetails(context, record, _refreshRecords),
                            ),
                          if (todayAddedRecords.isNotEmpty)
                            ScheduleTable(
                              records: todayAddedRecords,
                              title: 'Today\'s Added Records (${todayAddedRecords.length})',
                              onSelect: (context, record) => showLectureDetails(context, record, _refreshRecords),
                            ),
                          if (nextDayRecords.isNotEmpty)
                            ScheduleTable(
                              records: nextDayRecords,
                              title: 'Next Day Schedule (${nextDayRecords.length})',
                              onSelect: (context, record) => showLectureDetails(context, record, _refreshRecords),
                            ),
                          if (next7DaysRecords.isNotEmpty)
                            ScheduleTable(
                              records: next7DaysRecords,
                              title: 'Next 7 Days Schedule (${next7DaysRecords.length})',
                              onSelect: (context, record) => showLectureDetails(context, record, _refreshRecords),
                            ),
                        ],
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }
}