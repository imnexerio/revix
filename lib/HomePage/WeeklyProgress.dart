// lib/chart_utils.dart
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'WeeklyProgressData.dart';

BarChartData createBarChartWeeklyData(List<Map<String, dynamic>> records) {
  Map<int, WeeklyProgressData> weeklyData = {};
  DateTime now = DateTime.now();

  // Find the next Sunday instead of the last Sunday
  DateTime nextSunday = now.add(Duration(days: 7 - (now.weekday % 7)));
  nextSunday = DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 23, 59, 59);

  // Initialize the last 4 complete weeks of data
  for (int i = 0; i < 4; i++) {
    weeklyData[i] = WeeklyProgressData(i, 0);
  }

  // Calculate the start date (Monday) of the earliest week we want to track
  DateTime startDate = nextSunday.subtract(Duration(days: (4 * 7) - 1));
  startDate = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);

  for (var record in records) {
    String? dateLearnt;
    if (record['details']['lecture_type'] == 'Lectures') {
      dateLearnt = record['details']['date_learnt'];
    }

    if (dateLearnt != null) {
      DateTime lectureDate = DateTime.parse(dateLearnt);
      if (lectureDate.isAfter(startDate) && lectureDate.isBefore(nextSunday.add(Duration(days: 1)))) {
        // Calculate which week this date belongs to
        int daysFromNextSunday = nextSunday.difference(lectureDate).inDays;
        int weekIndex = 3 - (daysFromNextSunday ~/ 7); // Reverse the index so newest week is at index 3

        if (weekIndex >= 0) {
          var currentData = weeklyData[weekIndex]!;
          weeklyData[weekIndex] = WeeklyProgressData(
            weekIndex,
            currentData.lectures + 1,
          );
        }
      }
    }
  }

  // Calculate maxY from the data
  double maxY = 0;
  weeklyData.values.forEach((data) {
    maxY = max(maxY, data.lectures.toDouble());
  });

  // Add padding to maxY to prevent bars from touching the top
  maxY = maxY + (maxY * 0.2);

  return BarChartData(
    alignment: BarChartAlignment.spaceAround,
    maxY: maxY,
    barTouchData: BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          String label = rodIndex == 0 ? 'Lectures' : 'Revisions';
          return BarTooltipItem(
            '${label}: ${rod.toY.toInt()}',
            const TextStyle(color: Colors.white),
          );
        },
      ),
    ),
    titlesData: FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            int weekIndex = value.toInt();
            DateTime weekStart = nextSunday.subtract(Duration(days: ((3 - weekIndex) * 7) + 6));
            DateTime weekEnd = nextSunday.subtract(Duration(days: (3 - weekIndex) * 7));

            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '${weekStart.day}/${weekStart.month}-${weekEnd.day}/${weekEnd.month}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
          reservedSize: 40,
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            return Text(
              value.toInt().toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            );
          },
          reservedSize: 30,
        ),
      ),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    ),
    borderData: FlBorderData(show: false),
    barGroups: weeklyData.entries.map((entry) {
      final data = entry.value;
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: data.lectures.toDouble(),
            color: Colors.blue,
            width: 16,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList(),
    gridData: FlGridData(
      show: true,
      drawHorizontalLine: true,
      horizontalInterval: 1,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Colors.grey.withOpacity(0.2),
          strokeWidth: 1,
        );
      },
    ),
  );
}