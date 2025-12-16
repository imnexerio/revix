package com.imnexerio.revix

import android.content.Context
import android.graphics.Color
import android.content.SharedPreferences

/**
 * Android/Kotlin version of EntryColors with permanent caching
 * Mirrors the simplified logic from Flutter's entry_colors.dart
 */
class EntryColors private constructor() {
    companion object {
        private const val PREF_COLOR_PREFIX = "entry_color_"
        private const val PREF_INITIALIZED = "colors_initialized"
        
        /**
         * Initialize colors for all existing tracking types (call once on app start)
         */
        fun initializeColors(context: Context) {
            val sharedPrefs = context.getSharedPreferences("EntryColorsCache", Context.MODE_PRIVATE)
            
            // Check if already initialized
            if (sharedPrefs.getBoolean(PREF_INITIALIZED, false)) {
                return
            }
            
            // Note: In Android widgets, we don't typically fetch from Firebase directly
            // Colors will be generated and cached as they're encountered
            // Mark as initialized to avoid repeated checks
            sharedPrefs.edit()
                .putBoolean(PREF_INITIALIZED, true)
                .apply()
        }
        
        /**
         * Get color for an entry type - generates and caches permanently if new
         */
        fun getEntryTypeColor(context: Context, entryType: String): Int {
            if (entryType.isEmpty()) {
                return getDefaultTextColor()
            }
            
            val sharedPrefs = context.getSharedPreferences("EntryColorsCache", Context.MODE_PRIVATE)
            val cacheKey = PREF_COLOR_PREFIX + entryType
            val cachedColor = sharedPrefs.getInt(cacheKey, Int.MIN_VALUE)
            
            // Return cached color if available
            if (cachedColor != Int.MIN_VALUE) {
                return cachedColor
            }
            
            // Generate new color and cache permanently
            val color = generateColorFromString(entryType)
            
            // Cache the color permanently
            sharedPrefs.edit()
                .putInt(cacheKey, color)
                .apply()
                
            return color
        }
        
        /**
         * Add color for a newly created tracking type
         */
        fun cacheColorForNewType(context: Context, trackingType: String) {
            if (trackingType.isEmpty()) return
            
            val sharedPrefs = context.getSharedPreferences("EntryColorsCache", Context.MODE_PRIVATE)
            val cacheKey = PREF_COLOR_PREFIX + trackingType
            
            // Only cache if not already cached
            if (sharedPrefs.getInt(cacheKey, Int.MIN_VALUE) == Int.MIN_VALUE) {
                val color = generateColorFromString(trackingType)
                sharedPrefs.edit()
                    .putInt(cacheKey, color)
                    .apply()
            }
        }
        
        /**
         * Get color synchronously - same as getEntryTypeColor for Android
         */
        fun getEntryTypeColorSync(context: Context, entryType: String): Int {
            return getEntryTypeColor(context, entryType)
        }
        
        /**
         * Generate consistent color from string input (same logic as Flutter version)
         */
        fun generateColorFromString(input: String): Int {
            val hash = customHash(input)
            // Generate more vibrant colors with better contrast (same logic as Flutter)
            val r = ((hash and 0x0000FF) % 120) + 100
            val g = (((hash and 0xFF0000) shr 16) % 120) + 100
            val b = (((hash and 0x00FF00) shr 8) % 120) + 100
            return Color.rgb(r, g, b)
        }
        
        /**
         * Custom hash function for consistent color generation (same as Flutter version)
         */
        private fun customHash(input: String): Int {
            var hash = 0
            for (char in input) {
                hash = 31 * hash + char.code
            }
            return hash
        }
        
        /**
         * Get default text color (system default)
         */
        private fun getDefaultTextColor(): Int {
            return Color.parseColor("#FF000000") // Default black text color
        }
        
        /**
         * Clear all cached colors (useful for testing)
         */
        fun clearCache(context: Context) {
            val sharedPrefs = context.getSharedPreferences("EntryColorsCache", Context.MODE_PRIVATE)
            val editor = sharedPrefs.edit()
            
            // Remove all cached colors and initialization flag
            val allPrefs = sharedPrefs.all
            for ((key, _) in allPrefs) {
                if (key.startsWith(PREF_COLOR_PREFIX) || key == PREF_INITIALIZED) {
                    editor.remove(key)
                }
            }
            editor.apply()
        }
    }
}
