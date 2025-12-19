import 'package:flutter/material.dart';

class EntryColors {

  static Color generateColorFromString(String input) {
    if (input.isEmpty) {
      return const Color(0x4D6496C8); // Default grey with opacity
    }
    
    final int hash = _customHash(input);
    // Generate more vibrant colors with better contrast
    final int r = ((hash & 0x0000FF) % 120) + 100;
    final int g = (((hash & 0xFF0000) >> 16) % 120) + 100;
    final int b = (((hash & 0x00FF00) >> 8) % 120) + 100;
    return Color.fromARGB(255, r, g, b);
  }

  /// Custom hash function for consistent color generation
  static int _customHash(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = 31 * hash + input.codeUnitAt(i);
    }
    return hash;
  }
}
