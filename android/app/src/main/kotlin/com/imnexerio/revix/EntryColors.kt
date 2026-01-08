package com.imnexerio.revix

import android.graphics.Color

object EntryColors {
    
    private val PRIMARY_COLOR = Color.rgb(0, 255, 252)

    fun getEntryTypeColor(entryType: String): Int {
        if (entryType.isEmpty()) {
            return PRIMARY_COLOR
        }
        return generateColorFromString(entryType)
    }

    fun generateColorFromString(input: String): Int {
        val hash = customHash(input)
        // Generate vibrant colors with good contrast (range 100-219)
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
}
