import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

LineChartData createLineChartData(List<Map<String, dynamic>> records) {
  Map<String, int> lectureCounts = {};
  Map<String, int> revisionCounts = {};

  DateTime today = DateTime.now();
  for (int i = 0; i < 14; i++) {
    DateTime date = today.subtract(Duration(days: i));
    String dateStr = date.toIso8601String().split('T')[0];
    lectureCounts[dateStr] = 0;
    revisionCounts[dateStr] = 0;
  }

  for (var record in records) {
    String? dateLearnt = record['details']['date_initiated'];
    List<dynamic>? datesRevised = record['details']['dates_updated'];
    // print('record: $record');

    if (dateLearnt != null && lectureCounts.containsKey(dateLearnt)) {
      lectureCounts[dateLearnt] = lectureCounts[dateLearnt]! + 1;
    }

    if (datesRevised != null) {
      for (var dateRevised in datesRevised) {
        String dateRevisedStr = DateTime.parse(dateRevised).toIso8601String().split('T')[0];
        if (revisionCounts.containsKey(dateRevisedStr)) {
          revisionCounts[dateRevisedStr] = revisionCounts[dateRevisedStr]! + 1;
        }
      }
    }
  }

  List<FlSpot> lectureSpots = [];
  List<FlSpot> revisionSpots = [];

  int index = 6; // Start from the rightmost position
  lectureCounts.forEach((date, count) {
    lectureSpots.add(FlSpot(index.toDouble(), count.toDouble()));
    index--;
  });

  index = 6; // Start from the rightmost position
  revisionCounts.forEach((date, count) {
    revisionSpots.add(FlSpot(index.toDouble(), count.toDouble()));
    index--;
  });

  return LineChartData(
    titlesData: FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Text(value.toInt().toString())),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
          DateTime date = today.subtract(Duration(days: 6 - value.toInt()));
          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              date.day.toString(), // Only show the day
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          );
        }),
      ),
    ),
    lineBarsData: [
      LineChartBarData(
        spots: lectureSpots,
        isCurved: true,
        color: Colors.blue,
        barWidth: 3,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(
          show: true,
          color: Colors.blue.withOpacity(0.1),
        ),
      ),
      LineChartBarData(
        spots: revisionSpots,
        isCurved: true,
        color: Colors.orange,
        barWidth: 3,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(
          show: true,
          color: Colors.orange.withOpacity(0.1),
        ),
      ),
    ],
    lineTouchData: const LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(),
    ),
  );
}