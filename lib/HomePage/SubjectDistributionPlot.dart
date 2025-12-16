import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

List<PieChartSectionData> createPieChartSections(
    Map<String, int> subjectCounts,
    double radius,
    ThemeData theme
    ) {
  // Modern color palette
  final colors = [
    const Color(0xFF5038BC),  // Deep purple
    const Color(0xFF4ECDC4),  // Teal
    const Color(0xFFFF6B6B),  // Coral
    const Color(0xFFFFD166),  // Yellow
    const Color(0xFF118AB2),  // Blue
    const Color(0xFFEF8354),  // Orange
    const Color(0xFF06D6A0),  // Mint
    const Color(0xFFDA627D),  // Pink
  ];

  List<PieChartSectionData> sections = [];
  int totalEntries = subjectCounts.values.fold(0, (sum, count) => sum + count);
  int colorIndex = 0;

  // If there's no data, return an empty chart
  if (totalEntries == 0) {
    return [
      PieChartSectionData(
        color: Colors.grey.withOpacity(0.2),
        value: 100,
        title: 'No Data',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: theme.textTheme.bodyLarge?.color ?? Colors.grey,
        ),
      )
    ];
  }

  var sortedEntries = subjectCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  for (var entry in sortedEntries) {
    int count = entry.value;
    double percentage = (count / totalEntries) * 100;
    Color sectionColor = colors[colorIndex % colors.length];

    sections.add(
      PieChartSectionData(
        color: sectionColor,
        value: percentage,
        title: '',  // No title on the chart sections
        radius: radius,
        titleStyle: const TextStyle(fontSize: 0),
        badgeWidget: null,  // No badge widgets
      ),
    );
    colorIndex++;
  }

  return sections;
}