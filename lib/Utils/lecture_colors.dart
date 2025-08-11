import 'package:flutter/material.dart';
import 'FirebaseDatabaseService.dart';
import 'UnifiedDatabaseService.dart';

class LectureColors {
  // Permanent color cache - colors are cached forever once generated
  static Map<String, Color> _colorCache = {};
  static bool _isInitialized = false;

  /// Initialize colors for all existing tracking types (call once on app start)
  static Future<void> initializeColors() async {
    if (_isInitialized) return;
    
    try {
      final databaseService = FirebaseDatabaseService();
      final trackingTypes = await databaseService.fetchCustomTrackingTypes();
      
      // Generate and cache colors for all existing tracking types
      for (String trackingType in trackingTypes) {
        if (!_colorCache.containsKey(trackingType)) {
          _colorCache[trackingType] = _generateColorFromString(trackingType);
        }
      }
      
      _isInitialized = true;
    } catch (e) {
      // Even if fetch fails, mark as initialized to avoid repeated attempts
      _isInitialized = true;
    }
  }

  /// Get color for a lecture type - generates and caches if new
  static Future<Color> getLectureTypeColor(BuildContext context, String type) async {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    
    if (type.isEmpty) {
      return colorScheme.surfaceVariant.withOpacity(0.3);
    }
    
    // Check if color is already cached
    if (_colorCache.containsKey(type)) {
      return _colorCache[type]!;
    }
    
    // If not cached, this might be a new tracking type
    // Fetch latest tracking types to verify it exists
    try {
      final databaseService = FirebaseDatabaseService();
      final trackingTypes = await databaseService.fetchCustomTrackingTypes();
      
      if (trackingTypes.contains(type)) {
        // It's a valid tracking type - generate and cache color permanently
        final color = _generateColorFromString(type);
        _colorCache[type] = color;
        return color;
      } else {
        // Unknown type - return default color (don't cache)
        return colorScheme.surfaceVariant.withOpacity(0.3);
      }
    } catch (e) {
      // If fetch fails, generate color anyway (might be valid)
      final color = _generateColorFromString(type);
      _colorCache[type] = color;
      return color;
    }
  }

  /// Add color for a newly created tracking type
  static void cacheColorForNewType(String trackingType) {
    if (trackingType.isNotEmpty && !_colorCache.containsKey(trackingType)) {
      _colorCache[trackingType] = _generateColorFromString(trackingType);
    }
  }

  /// Get color synchronously if already cached, otherwise generate and cache
  static Color getLectureTypeColorSync(BuildContext context, String type) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    
    if (type.isEmpty) {
      return colorScheme.surfaceVariant.withOpacity(0.3);
    }
    
    // Return cached color if available
    if (_colorCache.containsKey(type)) {
      return _colorCache[type]!;
    }
    
    // Generate and cache color immediately for sync usage
    final color = _generateColorFromString(type);
    _colorCache[type] = color;
    return color;
  }

  /// Clear all cached colors (useful for testing)
  static void clearCache() {
    _colorCache.clear();
    _isInitialized = false;
  }

  /// Generate a consistent color from string input
  static Color generateColorFromString(String input) {
    return _generateColorFromString(input);
  }

  /// Generate a consistent color from string input
  static Color _generateColorFromString(String input) {
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