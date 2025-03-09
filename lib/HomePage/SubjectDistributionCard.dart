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
          'Subject Distribution',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 24),
        // Use LayoutBuilder to make pie chart responsive to its container
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
        ),
        const SizedBox(height: 32),
        Center(
          child: buildPieChartLegend(subjectDistribution, context),
        ),
      ],
    ),
  );
}