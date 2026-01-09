package com.imnexerio.revix

import android.graphics.Color
import kotlin.math.abs

object EntryColors {
    
    private val PRIMARY_COLOR = Color.rgb(0, 255, 252)
    private const val GOLDEN_RATIO_CONJUGATE = 0.618033988749895
    private val SATURATIONS = doubleArrayOf(0.55, 0.62, 0.70, 0.78, 0.85)
    private val LIGHTNESSES = doubleArrayOf(0.42, 0.48, 0.54, 0.60, 0.66)

    fun getEntryTypeColor(entryType: String): Int {
        if (entryType.isEmpty()) {
            return PRIMARY_COLOR
        }
        return generateColorFromString(entryType)
    }

    fun generateColorFromString(input: String): Int {
        if (input.isEmpty()) {
            return PRIMARY_COLOR
        }
        
        val hash1 = customHash(input, 2166136261L)
        val hash2 = customHash(input, 1952879633L)
        
        // Use golden ratio to spread hue values maximally
        val hueRaw = (hash1 * GOLDEN_RATIO_CONJUGATE) % 1.0
        val hue = hueRaw * 360.0
        
        // Use second hash for saturation and lightness variation
        val satIndex = hash2 % 5
        val lightIndex = (hash2 shr 8) % 5
        
        val saturation = SATURATIONS[satIndex]
        val lightness = LIGHTNESSES[lightIndex]
        
        return hslToRgb(hue, saturation, lightness)
    }

    private fun customHash(input: String, seed: Long): Int {
        var hash = seed.toInt()  // Safe: all seeds are < 2^31
        for (char in input) {
            hash = hash xor char.code
            hash = ((hash.toLong() * 16777619L) and 0x7FFFFFFF).toInt()
        }
        // Extra mixing for better distribution
        hash = hash xor (hash shr 15)
        hash = ((hash.toLong() * 2246822519L) and 0x7FFFFFFF).toInt()
        hash = hash xor (hash shr 13)
        return hash
    }

    private fun hslToRgb(hue: Double, saturation: Double, lightness: Double): Int {
        val h = hue / 360.0
        val s = saturation
        val l = lightness
        
        val r: Double
        val g: Double
        val b: Double
        
        if (s == 0.0) {
            // Achromatic (gray)
            r = l
            g = l
            b = l
        } else {
            val q = if (l < 0.5) l * (1 + s) else l + s - l * s
            val p = 2 * l - q
            r = hueToRgb(p, q, h + 1.0 / 3.0)
            g = hueToRgb(p, q, h)
            b = hueToRgb(p, q, h - 1.0 / 3.0)
        }
        
        return Color.rgb(
            (r * 255).toInt().coerceIn(0, 255),
            (g * 255).toInt().coerceIn(0, 255),
            (b * 255).toInt().coerceIn(0, 255)
        )
    }
    
    /**
     * Helper function for HSL to RGB conversion.
     */
    private fun hueToRgb(p: Double, q: Double, t: Double): Double {
        var tNorm = t
        if (tNorm < 0) tNorm += 1.0
        if (tNorm > 1) tNorm -= 1.0
        
        return when {
            tNorm < 1.0 / 6.0 -> p + (q - p) * 6.0 * tNorm
            tNorm < 1.0 / 2.0 -> q
            tNorm < 2.0 / 3.0 -> p + (q - p) * (2.0 / 3.0 - tNorm) * 6.0
            else -> p
        }
    }
}
