import 'package:flutter/material.dart';

class ScheduleTable extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final String title;
  final Function(BuildContext, Map<String, dynamic>) onSelect;

  ScheduleTable({required this.records, required this.title, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
              child: DataTable(
                showCheckboxColumn: false,
                columns: [
                  DataColumn(label: Text('Subject', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                  DataColumn(label: Text('Subject Code', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                  DataColumn(label: Text('Lecture No', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                  DataColumn(label: Text('Date Scheduled', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                  DataColumn(label: Text('Date Learnt', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                ],
                rows: records.map((record) {
                  return DataRow(
                    cells: [
                      DataCell(Text(record['subject'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                      DataCell(Text(record['subject_code'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                      DataCell(Text(record['lecture_no'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                      DataCell(Text(record['date_scheduled'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                      DataCell(Text(record['date_learnt'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                    ],
                    onSelectChanged: (_) => onSelect(context, record),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}