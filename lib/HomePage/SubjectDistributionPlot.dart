import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

List<PieChartSectionData> createPieChartSections(
    Map<String, int> subjectCounts,
    double radius,
    ThemeData theme
    ) {
  final colors = [
    Colors.purple,
    Colors.green,
    Colors.red,
    Colors.yellow,
    Colors.blue,
    Colors.orange,
    Colors.teal,
    Colors.pink,
  ];

  List<PieChartSectionData> sections = [];
  int totalLectures = subjectCounts.values.fold(0, (sum, count) => sum + count);
  int colorIndex = 0;

  // If there's no data, return an empty chart
  if (totalLectures == 0) {
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

  subjectCounts.forEach((subject, count) {
    double percentage = (count / totalLectures) * 100;

    // Determine if this section is large enough to fit text
    bool showTitle = percentage > 5;

    sections.add(
      PieChartSectionData(
        color: colors[colorIndex % colors.length],
        value: percentage,
        title: showTitle ? '${percentage.toStringAsFixed(1)}%' : '',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: radius > 90 ? 12 : 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: !showTitle && percentage < 5 ? null : null,
        badgePositionPercentageOffset: 1.1,
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
    Colors.orange,
    Colors.teal,
    Colors.pink,
  ];

  // Calculate total count for percentage calculation
  int totalCount = subjectCounts.values.fold(0, (sum, count) => sum + count);

  return Wrap(
    spacing: 16,
    runSpacing: 12,
    alignment: WrapAlignment.center,
    children: subjectCounts.entries.map((entry) {
      int index = subjectCounts.keys.toList().indexOf(entry.key);
      double percentage = totalCount > 0 ? (entry.value / totalCount * 100) : 0;

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
            '${entry.key} (${entry.value}, ${percentage.toStringAsFixed(1)}%)',
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
