import 'package:flutter/material.dart';

Widget buildPieChartLegend(Map<String, int> subjectCounts, BuildContext context) {
  // Modern color palette - same as in createPieChartSections
  final colors = [
    const Color(0xFF5038BC),  // Deep purple
    const Color(0xFF4ECDC4),  // Teal
    const Color(0xFFFF6B6B),  // Coral
    const Color(0xFFFFD166),  // Yellow
    const Color(0xFF118AB2),  // Blue
    const Color(0xFFEF8354),  // Orange
    const Color(0xFF06D6A0),  // Mint
    const Color(0xFFDA627D),  // Pink
  ];

  // Calculate total count for percentage calculation
  int totalCount = subjectCounts.values.fold(0, (sum, count) => sum + count);

  // Sort entries by count for better visualization (matching the pie chart order)
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
      children: sortedEntries.asMap().entries.map((mapEntry) {
        int index = mapEntry.key;
        var entry = mapEntry.value;
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
                  color: colors[index % colors.length],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.key} (${percentage.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}