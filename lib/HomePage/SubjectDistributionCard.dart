import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'PieChartLegend.dart';
import 'SubjectDistributionPlot.dart';

Widget buildSubjectDistributionCard(Map<String, int> subjectDistribution, double cardPadding, BuildContext context) {
  // Get the screen width to calculate responsive sizes
  final screenWidth = MediaQuery.of(context).size.width;

  // Calculate dynamic radius based on screen width
  final bool isSmallScreen = screenWidth < 600;
  final double chartRadius = isSmallScreen ? 80 : 100;
  final double centerRadius = isSmallScreen ? 60 : 80;

  // Check if we have valid data
  final bool hasValidData = subjectDistribution.isNotEmpty &&
      subjectDistribution.values.any((value) => value > 0);

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
          'Category Distribution',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 24),
        if (hasValidData)
          LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: 550,
                  child: PieChart(
                    PieChartData(
                      sections: createPieChartSections(
                        subjectDistribution,
                        chartRadius,
                        Theme.of(context),
                      ),
                      sectionsSpace: 2,
                      centerSpaceRadius: centerRadius,
                      borderData: FlBorderData(show: false),
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          // Could implement hover effects or selection here
                        },
                        enabled: true,
                      ),
                    ),
                  ),
                );
              }
          )
        else
        // Show a message when no data is available
          Center(
            child: Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No category data available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 32),
        // Only show legend if we have data
        if (hasValidData)
          Center(
            child: buildPieChartLegend(subjectDistribution, context),
          ),
      ],
    ),
  );
}