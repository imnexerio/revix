import 'package:flutter/material.dart';

import 'MonthlyCalender.dart';

Widget buildProgressCalendarCard(List<Map<String, dynamic>> allRecords, double cardPadding, BuildContext context) {
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
          'Progress Calendar',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 750,
          child: StudyCalendar(
            records: allRecords
          ),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}