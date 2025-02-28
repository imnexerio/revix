// lib/chart_utils.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

List<PieChartSectionData> createPieChartSections(Map<String, int> subjectCounts) {
  final colors = [
    Colors.purple,
    Colors.green,
    Colors.red,
    Colors.yellow,
    Colors.blue,
  ];

  List<PieChartSectionData> sections = [];
  int totalLectures = subjectCounts.values.fold(0, (sum, count) => sum + count);
  int colorIndex = 0;

  subjectCounts.forEach((subject, count) {
    double percentage = (count / totalLectures) * 100;
    sections.add(
      PieChartSectionData(
        color: colors[colorIndex % colors.length],
        value: percentage,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
    colorIndex++;
  });

  return sections;
}

Widget buildPieChartLegend(Map<String, int> subjectCounts, BuildContext context) {
  final colors = [
    Colors.purple,
    Colors.green,
    Colors.red,
    Colors.yellow,
    Colors.blue,
  ];

  return Wrap(
    spacing: 16,
    runSpacing: 8,
    children: subjectCounts.entries.map((entry) {
      int index = subjectCounts.keys.toList().indexOf(entry.key);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: colors[index % colors.length],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          SizedBox(width: 8),
          Text(
            '${entry.key} (${entry.value})',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }).toList(),
  );
}