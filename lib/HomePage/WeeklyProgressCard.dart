import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../SchedulePage/LegendItem.dart';
import 'WeeklyProgress.dart';

Widget buildWeeklyProgressCard(List<Map<String, dynamic>> allRecords, double cardPadding, BuildContext context) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: EdgeInsets.all(cardPadding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Progress',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 250,
          width: double.infinity,
          child: BarChart(createBarChartWeeklyData(allRecords)),
        ),
        const SizedBox(height: 16),
        buildLegend(),
        const SizedBox(height: 8),
      ],
    ),
  );
}

Widget buildLegend() {
  return const Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      LegendItem(label: 'Initiatives', color: Colors.blue, icon: Icons.school),
      LegendItem(label: 'Reviews', color: Colors.green, icon: Icons.check_circle),
      LegendItem(label: 'Missed', color: Colors.red, icon: Icons.cancel),
      LegendItem(label: 'Scheduled', color: Colors.orange, icon: Icons.schedule),
    ],
  );
}