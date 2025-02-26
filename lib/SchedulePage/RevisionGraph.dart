import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class RevisionGraph extends StatelessWidget {
  final List<String> datesMissedRevisions;
  final List<String> datesRevised;

  const RevisionGraph({
    Key? key,
    required this.datesMissedRevisions,
    required this.datesRevised,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get all dates for reference
    final allDates = [
      ...datesMissedRevisions.where((d) => d != null).cast<String>(),
      ...datesRevised.where((d) => d != null).cast<String>(),
    ];

    if (allDates.isEmpty) {
      return const SizedBox.shrink(); // Empty widget when no data
    }

    // Find reference date (earliest date)
    final referenceDate = _findEarliestDate(allDates);
    final maxDays = _getMaxDaysDifference(allDates, referenceDate);

    return SizedBox(
      width: 100,
      height: 50,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(enabled: false),
          minX: 0,
          maxX: maxDays.toDouble(),
          minY: 0,
          maxY: 1.2, // Slightly above 1 to see the dots clearly
          lineBarsData: [
            // Missed revisions (if any)
            if (datesMissedRevisions.isNotEmpty && datesMissedRevisions.first != null)
              LineChartBarData(
                spots: _getSpots(datesMissedRevisions, referenceDate),
                isCurved: false,
                color: Colors.red,
                barWidth: 1.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 2,
                        color: Colors.red,
                        strokeWidth: 0,
                      );
                    }
                ),
                belowBarData: BarAreaData(show: false),
              ),
            // Completed revisions
            if (datesRevised.isNotEmpty && datesRevised.first != null)
              LineChartBarData(
                spots: _getSpots(datesRevised, referenceDate),
                isCurved: false,
                color: Colors.blue,
                barWidth: 1.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 2,
                        color: Colors.blue,
                        strokeWidth: 0,
                      );
                    }
                ),
                belowBarData: BarAreaData(show: false),
              ),
          ],
        ),
      ),
    );
  }

  String _findEarliestDate(List<String> dates) {
    if (dates.isEmpty) return DateTime.now().toString();
    return dates.reduce((a, b) => DateTime.parse(a).isBefore(DateTime.parse(b)) ? a : b);
  }

  int _getMaxDaysDifference(List<String> dates, String referenceDate) {
    if (dates.isEmpty) return 7; // Default to 7 days if no data

    final refDate = DateTime.parse(referenceDate);
    int maxDays = 0;

    for (final date in dates) {
      final days = DateTime.parse(date).difference(refDate).inDays;
      if (days > maxDays) maxDays = days;
    }

    return maxDays + 1; // Add 1 for padding
  }

  List<FlSpot> _getSpots(List<String> dates, String referenceDate) {
    if (dates.isEmpty || dates.first == null) return [];

    final refDate = DateTime.parse(referenceDate);
    final spots = <FlSpot>[];

    for (final date in dates) {
      if (date != null) {
        final days = DateTime.parse(date).difference(refDate).inDays;
        // Use y=1 to represent a revision happened on this day
        spots.add(FlSpot(days.toDouble(), 1));
      }
    }

    return spots;
  }
}