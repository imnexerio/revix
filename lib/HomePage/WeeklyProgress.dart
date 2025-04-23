import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class WeeklyProgressData {
  final int weekIndex;
  final int lectures;
  final int revisions;
  final int missed;
  final int scheduled;

  WeeklyProgressData(this.weekIndex, this.lectures, this.revisions, this.missed, this.scheduled);
}

// Updated chart creation function
BarChartData createBarChartWeeklyData(List<Map<String, dynamic>> records) {
  Map<int, WeeklyProgressData> weeklyData = {};
  DateTime now = DateTime.now();

  // Find the next Sunday
  DateTime nextSunday = now.add(Duration(days: 7 - (now.weekday % 7)));
  nextSunday = DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 23, 59, 59);

  // Initialize the last 4 complete weeks of data
  for (int i = 0; i < 4; i++) {
    weeklyData[i] = WeeklyProgressData(i, 0, 0, 0, 0);
  }

  // Calculate the start date (Monday) of the earliest week we want to track
  DateTime startDate = nextSunday.subtract(const Duration(days: (4 * 7) - 1));
  startDate = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);

  for (var record in records) {
    // Extract dates for different actions
    String? dateLearnt;
    List<dynamic>? datesRevised;
    List<dynamic>? datesMissedRevisions;
    String? dateScheduled;

    if (record['details'] != null) {
      dateLearnt = record['details']['date_learnt'];
      datesRevised = record['details']['dates_revised'];
      datesMissedRevisions = record['details']['dates_missed_revisions'];
      dateScheduled = record['details']['date_scheduled'];
    }

    // Process lecture date
    if (dateLearnt!='Unspecified')
    if (dateLearnt != null) {
      DateTime lectureDate = DateTime.parse(dateLearnt);
      if (lectureDate.isAfter(startDate) && lectureDate.isBefore(nextSunday.add(const Duration(days: 1)))) {
        // Calculate which week this date belongs to
        int daysFromNextSunday = nextSunday.difference(lectureDate).inDays;
        int weekIndex = 3 - (daysFromNextSunday ~/ 7); // Reverse the index so newest week is at index 3

        if (weekIndex >= 0 && weekIndex < 4) {
          var currentData = weeklyData[weekIndex]!;
          weeklyData[weekIndex] = WeeklyProgressData(
            weekIndex,
            currentData.lectures + 1,
            currentData.revisions,
            currentData.missed,
            currentData.scheduled,
          );
        }
      }
    }

    // Process revision dates
    if (datesRevised != null) {
      for (var revisionDateStr in datesRevised) {
        if (revisionDateStr is String) {
          DateTime revisionDate = DateTime.parse(revisionDateStr);
          if (revisionDate.isAfter(startDate) && revisionDate.isBefore(nextSunday.add(const Duration(days: 1)))) {
            int daysFromNextSunday = nextSunday.difference(revisionDate).inDays;
            int weekIndex = 3 - (daysFromNextSunday ~/ 7);

            if (weekIndex >= 0 && weekIndex < 4) {
              var currentData = weeklyData[weekIndex]!;
              weeklyData[weekIndex] = WeeklyProgressData(
                weekIndex,
                currentData.lectures,
                currentData.revisions + 1,
                currentData.missed,
                currentData.scheduled,
              );
            }
          }
        }
      }
    }

    // Process missed revisions using dates_missed_revisions array
    if (datesMissedRevisions != null) {
      for (var missedDateStr in datesMissedRevisions) {
        if (missedDateStr is String) {
          DateTime missedDate = DateTime.parse(missedDateStr);
          if (missedDate.isAfter(startDate) && missedDate.isBefore(nextSunday.add(const Duration(days: 1)))) {
            int daysFromNextSunday = nextSunday.difference(missedDate).inDays;
            int weekIndex = 3 - (daysFromNextSunday ~/ 7);

            if (weekIndex >= 0 && weekIndex < 4) {
              var currentData = weeklyData[weekIndex]!;
              weeklyData[weekIndex] = WeeklyProgressData(
                weekIndex,
                currentData.lectures,
                currentData.revisions,
                currentData.missed + 1,
                currentData.scheduled,
              );
            }
          }
        }
      }
    }

    // Process scheduled date
    if (dateLearnt!='Unspecified')
    if (dateScheduled != null) {
      DateTime scheduledDate = DateTime.parse(dateScheduled);
      if (scheduledDate.isAfter(startDate) && scheduledDate.isBefore(nextSunday.add(const Duration(days: 7)))) {
        int daysFromNextSunday = nextSunday.difference(scheduledDate).inDays;
        int weekIndex = 3 - (daysFromNextSunday ~/ 7);

        // Scheduled dates might be in the future week
        if (daysFromNextSunday < 0) {
          weekIndex = 3; // Current week (if in the future)
        }

        if (weekIndex >= 0 && weekIndex < 4) {
          var currentData = weeklyData[weekIndex]!;
          weeklyData[weekIndex] = WeeklyProgressData(
            weekIndex,
            currentData.lectures,
            currentData.revisions,
            currentData.missed,
            currentData.scheduled + 1,
          );
        }
      }
    }
  }

  // Calculate maxY from the data for all categories
  double maxY = 0;
  weeklyData.values.forEach((data) {
    maxY = max(maxY, data.lectures.toDouble());
    maxY = max(maxY, data.revisions.toDouble());
    maxY = max(maxY, data.missed.toDouble());
    maxY = max(maxY, data.scheduled.toDouble());
  });

  // Add padding to maxY to prevent bars from touching the top
  maxY = maxY + (maxY * 0.2);
  if (maxY == 0) maxY = 5; // Default if no data

  return BarChartData(
    alignment: BarChartAlignment.spaceAround,
    maxY: maxY,
    barTouchData: BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          String label;
          switch (rodIndex) {
            case 0:
              label = 'Initiatives';
              break;
            case 1:
              label = 'Reviewed';
              break;
            case 2:
              label = 'Missed';
              break;
            case 3:
              label = 'Scheduled';
              break;
            default:
              label = 'Unknown';
          }
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
                style: const TextStyle(
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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            );
          },
          reservedSize: 30,
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
            width: 12,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          BarChartRodData(
            toY: data.revisions.toDouble(),
            color: Colors.green,
            width: 12,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          BarChartRodData(
            toY: data.missed.toDouble(),
            color: Colors.red,
            width: 12,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          BarChartRodData(
            toY: data.scheduled.toDouble(),
            color: Colors.orange,
            width: 12,
            borderRadius: const BorderRadius.only(
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