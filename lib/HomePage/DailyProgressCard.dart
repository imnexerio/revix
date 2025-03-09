import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../SchedulePage/LegendItem.dart';
import 'DailyProgress.dart';

Widget buildDailyProgressCard(List<Map<String, dynamic>> allRecords, double cardPadding, BuildContext context) {
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
          'Daily Progress',
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
          child: LineChart(createLineChartData(allRecords)),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const [
            LegendItem(label: 'Lectures', color: Colors.blue, icon: Icons.school),
            LegendItem(label: 'Revisions', color: Colors.green, icon: Icons.check_circle),
          ],
        ),
      ],
    ),
  );
}