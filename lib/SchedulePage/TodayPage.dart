import 'package:flutter/material.dart';
import '../Utils/UnifiedDatabaseService.dart';
import '../widgets/EntryDetailsModal.dart';
import 'ScheduleTable.dart';

class TodayPage extends StatefulWidget {
  @override
  _TodayPageState createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final UnifiedDatabaseService _databaseService = UnifiedDatabaseService();

  @override
  void initState() {
    super.initState();
    _databaseService.initialize();
  }

  void _showEntryDetails(BuildContext context, Map<String, dynamic> record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return EntryDetailsModal(
          entryTitle: record['record_title'],
          details: record,
          selectedCategory: record['category'],
          selectedCategoryCode: record['sub_category'],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          _databaseService.forceDataReprocessing();
        },
        child: StreamBuilder<Map<String, List<Map<String, dynamic>>>>(
          stream: _databaseService.categorizedRecordsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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
              tableId: 'missed',
              onSelect: (context, record) => _showEntryDetails(context, record),
            ),
          if (data['today']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['today']!,
              title: 'Today\'s (${data['today']!.length})',
              tableId: 'today',
              onSelect: (context, record) => _showEntryDetails(context, record),
            ),
          if (data['todayAdded']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['todayAdded']!,
              title: 'Today\'s Added Records (${data['todayAdded']!.length})',
              tableId: 'todayAdded',
              onSelect: (context, record) => _showEntryDetails(context, record),
            ),
          if (data['nextDay']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['nextDay']!,
              title: 'Next Day (${data['nextDay']!.length})',
              tableId: 'nextDay',
              onSelect: (context, record) => _showEntryDetails(context, record),
            ),
          if (data['next7Days']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['next7Days']!,
              title: 'Next Week (${data['next7Days']!.length})',
              tableId: 'next7Days',
              onSelect: (context, record) => _showEntryDetails(context, record),
            ),
          if (data['noreminderdate']!.isNotEmpty)
            ScheduleTable(
              initialRecords: data['noreminderdate']!,
              title: 'Unspecified Date (${data['noreminderdate']!.length})',
              tableId: 'noreminderdate',
              onSelect: (context, record) => _showEntryDetails(context, record),
            ),
          // Extra scrollable space for bottom navigation
          const SizedBox(height: 88.0),
        ],
      ),
    );
  }
}