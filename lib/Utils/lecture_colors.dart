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
    final int hash = _customHash(input);
    final int g = ((hash & 0xFF0000) >> 16) % 120 + 64;
    final int b = ((hash & 0x00FF00) >> 8) % 120 + 64;
    final int r = (hash & 0x0000FF) % 120 + 64;
    return Color.fromARGB(255, r, g, b);
  }

  static int _customHash(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = 31 * hash + input.codeUnitAt(i);
    }
    return hash;
  }
}