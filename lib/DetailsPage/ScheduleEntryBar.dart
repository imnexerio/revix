import 'package:flutter/material.dart';
import 'dart:async';
import '../Utils/UnifiedDatabaseService.dart';
import 'ScheduleTable.dart';
import 'showEntryScheduleP.dart';

class ScheduleEntryBar extends StatefulWidget {
  final String scheduleType; // 'missed', 'today', 'todayAdded', 'nextDay', 'next7Days', 'noreminderdate'
  final String title;

  const ScheduleEntryBar({
    Key? key,
    required this.scheduleType,
    required this.title,
  }) : super(key: key);

  @override
  _ScheduleEntryBarState createState() => _ScheduleEntryBarState();
}

class _ScheduleEntryBarState extends State<ScheduleEntryBar> {
  List<Map<String, dynamic>> _records = [];
  final UnifiedDatabaseService _databaseService = UnifiedDatabaseService();
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _databaseService.initialize();
    _subscribeToStream();
  }

  @override
  void didUpdateWidget(ScheduleEntryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scheduleType != widget.scheduleType) {
      // Schedule type changed, re-subscribe to get correct data
      _subscribeToStream();
    }
  }

  void _subscribeToStream() {
    _subscription?.cancel();
    // BehaviorSubject automatically replays the last value to new subscribers
    _subscription = _databaseService.categorizedRecordsStream.listen((data) {
      setState(() {
        _records = List<Map<String, dynamic>>.from(data[widget.scheduleType] ?? []);
      });
    }, onError: (e) {
      // Handle error silently
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            ScheduleTable(
              initialRecords: _records,
              title: '${widget.title} (${_records.length})',
              tableId: 'details_${widget.scheduleType}',
              onSelect: (context, record) => showEntryScheduleP(context, record),
            ),
            const SizedBox(height: 88.0),
          ],
        ),
      ),
    );
  }
}
