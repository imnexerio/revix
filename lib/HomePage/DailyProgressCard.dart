import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'LegendItem.dart';
import 'DailyProgress.dart';

Widget buildDailyProgressCard(
    List<Map<String, dynamic>> allRecords,
    double cardPadding,
    BuildContext context,
    {required Function() onTitleTap, required String selectedEntryType}  // Add these parameters
    ) {
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
        // Make the title row clickable, similar to the Overview section
        GestureDetector(
          onTap: onTitleTap,
          child: Row(
            children: [
              Text(
                'Daily Progress: $selectedEntryType',  // Include the selected entry type
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.swap_horiz,
                size: 16,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 250,
          width: double.infinity,
          child: LineChart(createLineChartData(allRecords)),
        ),
        const SizedBox(height: 24),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            LegendItem(label: 'Initiatives', color: Colors.blue, icon: Icons.school),
            LegendItem(label: 'Reviewed', color: Colors.green, icon: Icons.check_circle),
          ],
        ),
      ],
    ),
  );
}