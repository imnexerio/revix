import 'package:flutter/material.dart';
import 'FirebaseDatabaseService.dart';
import 'UnifiedDatabaseService.dart';

class LectureColors {
  // Cache for tracking types and colors to avoid repeated database calls
  static List<String>? _cachedTrackingTypes;
  static Map<String, Color> _colorCache = {};
  static DateTime? _lastFetchTime;
  static const Duration _cacheExpireDuration = Duration(minutes: 10);

  /// Get color for a lecture type with caching mechanism
  static Future<Color> getLectureTypeColor(BuildContext context, String type) async {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    
    // Check if we have a cached color for this type
    if (_colorCache.containsKey(type)) {
      return _colorCache[type]!;
    }

    // Check if we need to refresh tracking types cache
    final now = DateTime.now();
    if (_cachedTrackingTypes == null || 
        _lastFetchTime == null || 
        now.difference(_lastFetchTime!) > _cacheExpireDuration) {
      await _refreshTrackingTypesCache();
    }

    Color color;
    if (_cachedTrackingTypes!.contains(type)) {
      color = _generateColorFromString(type);
    } else {
      // Default color for unknown types
      color = colorScheme.surfaceVariant.withOpacity(0.3);
    }

    // Cache the color for future use
    _colorCache[type] = color;
    return color;
  }

  /// Refresh the tracking types cache from database
  static Future<void> _refreshTrackingTypesCache() async {
    try {
      final databaseService = FirebaseDatabaseService();
      _cachedTrackingTypes = await databaseService.fetchCustomTrackingTypes();
      _lastFetchTime = DateTime.now();
    } catch (e) {
      // Fallback to empty list if fetch fails
      _cachedTrackingTypes = [];
    }
  }

  /// Clear all cached data (useful for testing or when tracking types change)
  static void clearCache() {
    _cachedTrackingTypes = null;
    _colorCache.clear();
    _lastFetchTime = null;
  }

  /// Get color synchronously if already cached, otherwise return default
  static Color getLectureTypeColorSync(BuildContext context, String type) {
    if (_colorCache.containsKey(type)) {
      return _colorCache[type]!;
    }
    
    // Return default color if not cached
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return colorScheme.surfaceVariant.withOpacity(0.3);
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