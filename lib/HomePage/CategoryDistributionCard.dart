import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:revix/Utils/entry_colors.dart';

Widget buildCategoryDistributionCard(Map<String,
    int> subjectDistribution,
    double cardPadding,
    BuildContext context,
    {required Function() onTitleTap,required String selectedEntryType}) {
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
        GestureDetector(
          onTap: onTitleTap,
          child: Row(
            children: [
              Text(
                'Category Distribution: $selectedEntryType',
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
        if (hasValidData)
          LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: 550,
                  child: PieChart(
                    PieChartData(
                      sections: _createPieChartSections(
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
            child: _buildPieChartLegend(subjectDistribution, context),
          ),
      ],
    ),
  );
}
// ============================================================================
// PIE CHART SECTIONS HELPER
// ============================================================================

List<PieChartSectionData> _createPieChartSections(
    Map<String, int> subjectCounts,
    double radius,
    ThemeData theme,
    ) {
  List<PieChartSectionData> sections = [];
  int totalEntries = subjectCounts.values.fold(0, (sum, count) => sum + count);

  // If there's no data, return an empty chart
  if (totalEntries == 0) {
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

  var sortedEntries = subjectCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  for (var entry in sortedEntries) {
    int count = entry.value;
    double percentage = (count / totalEntries) * 100;
    Color sectionColor = EntryColors.generateColorFromString(entry.key);

    sections.add(
      PieChartSectionData(
        color: sectionColor,
        value: percentage,
        title: '',
        radius: radius,
        titleStyle: const TextStyle(fontSize: 0),
        badgeWidget: null,
      ),
    );
  }

  return sections;
}

// ============================================================================
// PIE CHART LEGEND HELPER
// ============================================================================

String _trimText(String text, int maxLength) {
  if (text.length <= maxLength) {
    return text;
  }
  return '${text.substring(0, maxLength)}...';
}

Widget _buildPieChartLegend(Map<String, int> subjectCounts, BuildContext context) {
  int totalCount = subjectCounts.values.fold(0, (sum, count) => sum + count);

  var sortedEntries = subjectCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: sortedEntries.map((entry) {
        double percentage = totalCount > 0 ? (entry.value / totalCount * 100) : 0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: EntryColors.generateColorFromString(entry.key),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${_trimText(entry.key, 15)} (${percentage.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}