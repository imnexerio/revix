import 'package:flutter/material.dart';
import 'FetchTypesUtils.dart';

class LectureColors {
  static Future<Color> getLectureTypeColor(BuildContext context, String type) async {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    List<String> trackingTypes = await FetchtrackingTypeUtils.fetchtrackingType();

    if (trackingTypes.contains(type)) {
      return _generateColorFromString(type);
    } else {
      return colorScheme.surface;
    }
  }

  static Color _generateColorFromString(String input) {
    final int hash = input.hashCode;
    final int g = ((hash & 0xFF0000) >> 16) % 150 + 64; // Ensures g is between 64 and 191
    final int b = ((hash & 0x00FF00) >> 8) % 150 + 64;  // Ensures b is between 64 and 191
    final int r = (hash & 0x0000FF) % 150 + 64;         // Ensures r is between 64 and 191
    return Color.fromARGB(255, r, g, b);
  }
}