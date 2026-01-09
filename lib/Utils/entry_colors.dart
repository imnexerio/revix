import 'package:flutter/material.dart';

class EntryColors {
  static const Color _primaryColor = Color.fromARGB(255, 0, 255, 252);
  static const double _goldenRatioConjugate = 0.618033988749895;
  static const List<double> _saturations = [0.55, 0.62, 0.70, 0.78, 0.85];
  static const List<double> _lightnesses = [0.42, 0.48, 0.54, 0.60, 0.66];

  static Color generateColorFromString(String input) {
    if (input.isEmpty) {
      return _primaryColor;
    }
    
    final int hash1 = _customHash(input, 1836311903);
    final int hash2 = _customHash(input, 1952879633);
    
    final double hueRaw = (hash1 * _goldenRatioConjugate) % 1.0;
    final double hue = hueRaw * 360.0;
    
    final int satIndex = hash2 % 5;  // 5 saturation levels
    final int lightIndex = (hash2 >> 8) % 5;  // 5 lightness levels
    
    final double saturation = _saturations[satIndex];
    final double lightness = _lightnesses[lightIndex];
    
    // Use manual HSL to RGB for cross-platform consistency
    return _hslToRgb(hue, saturation, lightness);
  }

  /// Cross-platform hash - works identically on Web, Android, iOS, Desktop
  /// Uses only operations that stay within JavaScript's safe integer range
  static int _customHash(String input, int seed) {
    int hash = seed;
    for (int i = 0; i < input.length; i++) {
      // Classic DJB2-style hash with safe multiplier
      hash = ((hash << 5) - hash + input.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    // Simple mixing using only bit operations (no large multiplies)
    hash ^= (hash >> 11);
    hash = ((hash << 5) - hash) & 0x7FFFFFFF;  // Same as hash * 31
    hash ^= (hash >> 13);
    hash = ((hash << 5) - hash) & 0x7FFFFFFF;
    hash ^= (hash >> 7);
    return hash;
  }

  static Color _hslToRgb(double hue, double saturation, double lightness) {
    final double h = hue / 360.0;
    final double s = saturation;
    final double l = lightness;
    
    double r, g, b;
    
    if (s == 0.0) {
      // Achromatic (gray)
      r = l;
      g = l;
      b = l;
    } else {
      final double q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      final double p = 2 * l - q;
      r = _hueToRgb(p, q, h + 1.0 / 3.0);
      g = _hueToRgb(p, q, h);
      b = _hueToRgb(p, q, h - 1.0 / 3.0);
    }
    
    return Color.fromARGB(
      255,
      (r * 255).toInt().clamp(0, 255),
      (g * 255).toInt().clamp(0, 255),
      (b * 255).toInt().clamp(0, 255),
    );
  }
  
  /// Helper function for HSL to RGB conversion.
  static double _hueToRgb(double p, double q, double t) {
    double tNorm = t;
    if (tNorm < 0) tNorm += 1.0;
    if (tNorm > 1) tNorm -= 1.0;
    
    if (tNorm < 1.0 / 6.0) return p + (q - p) * 6.0 * tNorm;
    if (tNorm < 1.0 / 2.0) return q;
    if (tNorm < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - tNorm) * 6.0;
    return p;
  }
}
