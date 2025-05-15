import 'package:flutter/material.dart';

import 'MonthlyCalender.dart';

Widget buildProgressCalendarCard(List<Map<String,
    dynamic>> allRecords,
    double cardPadding,
    BuildContext context,
    {required Function() onTitleTap, required String selectedLectureType}) {
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
                'Progress Calendar: $selectedLectureType',
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