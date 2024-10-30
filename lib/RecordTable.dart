import 'package:flutter/material.dart';

class RecordTable extends StatelessWidget {
  final Map<String, dynamic> record;

  RecordTable({required this.record});

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: [
        DataColumn(label: Text('Field')),
        DataColumn(label: Text('Value')),
      ],
      rows: record.entries.map((entry) {
        return DataRow(cells: [
          DataCell(Text(entry.key)),
          DataCell(Text(entry.value.toString())),
        ]);
      }).toList(),
    );
  }
}