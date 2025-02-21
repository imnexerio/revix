import 'package:flutter/material.dart';

class LectureColors {
  static Color getLectureTypeColor(BuildContext context, String type) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    switch (type) {
      case 'Lectures':
        return colorScheme.primary;
      case 'Handouts':
        return colorScheme.secondary;
      case 'O-NCERTs':
        return colorScheme.tertiary;
      case 'N-NCERTs':
        return colorScheme.error;
      default:
        return colorScheme.surface;
    }
  }
}