package com.imnexerio.revix

import android.content.Context
import android.graphics.Color
import android.content.SharedPreferences

/**
 * Android/Kotlin version of LectureColors with caching
 * Mirrors the logic from Flutter's lecture_colors.dart
 */
class LectureColors private constructor() {
    companion object {
        private const val CACHE_EXPIRY_MINUTES = 10
        private const val PREF_CACHE_PREFIX = "lecture_color_"
        private const val PREF_CACHE_TIME_PREFIX = "lecture_color_time_"
        
        /**
         * Get color for a lecture type with caching mechanism
         */
        fun getLectureTypeColor(context: Context, entryType: String): Int {
            if (entryType.isEmpty()) {
                return getDefaultTextColor()
            }
            
            val sharedPrefs = context.getSharedPreferences("LectureColorsCache", Context.MODE_PRIVATE)
            
            // Check cache first
            val cacheKey = PREF_CACHE_PREFIX + entryType
            val cacheTimeKey = PREF_CACHE_TIME_PREFIX + entryType
            val cachedColor = sharedPrefs.getInt(cacheKey, Int.MIN_VALUE)
            val cacheTime = sharedPrefs.getLong(cacheTimeKey, 0)
            
            val currentTime = System.currentTimeMillis()
            val cacheExpiryTime = CACHE_EXPIRY_MINUTES * 60 * 1000 // Convert to milliseconds
            
            // Return cached color if valid and not expired
            if (cachedColor != Int.MIN_VALUE && (currentTime - cacheTime) < cacheExpiryTime) {
                return cachedColor
            }
            
            // Generate new color for any non-empty entry_type (no validation needed)
            val color = generateColorFromString(entryType)
            
            // Cache the color
            sharedPrefs.edit()
                .putInt(cacheKey, color)
                .putLong(cacheTimeKey, currentTime)
                .apply()
                
            return color
        }
        
        /**
         * Get color synchronously if already cached, otherwise return default
         */
        fun getLectureTypeColorSync(context: Context, entryType: String): Int {
            if (entryType.isEmpty()) {
                return getDefaultTextColor()
            }
            
            val sharedPrefs = context.getSharedPreferences("LectureColorsCache", Context.MODE_PRIVATE)
            val cacheKey = PREF_CACHE_PREFIX + entryType
            val cachedColor = sharedPrefs.getInt(cacheKey, Int.MIN_VALUE)
            
            return if (cachedColor != Int.MIN_VALUE) {
                cachedColor
            } else {
                // Generate and cache immediately
                getLectureTypeColor(context, entryType)
            }
        }
        
        /**
         * Generate consistent color from string input (same logic as Flutter version)
         */
        private fun generateColorFromString(input: String): Int {
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
         * Clear color cache (useful for testing or when tracking types change)
         */
        fun clearCache(context: Context) {
            val sharedPrefs = context.getSharedPreferences("LectureColorsCache", Context.MODE_PRIVATE)
            val editor = sharedPrefs.edit()
            
            // Remove all cached colors
            val allPrefs = sharedPrefs.all
            for ((key, _) in allPrefs) {
                if (key.startsWith(PREF_CACHE_PREFIX) || key.startsWith(PREF_CACHE_TIME_PREFIX)) {
                    editor.remove(key)
                }
            }
            editor.apply()
        }
    }
}
