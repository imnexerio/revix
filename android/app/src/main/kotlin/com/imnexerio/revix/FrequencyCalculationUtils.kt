package com.imnexerio.revix

import android.content.Context
import android.util.Log
import kotlinx.coroutines.*
import java.text.SimpleDateFormat
import java.util.*

/**
 * Utility object for frequency-related calculations
 * Consolidates frequency fetching and next revision date calculation logic
 * Used by AddLectureActivity and RecordUpdateService
 */
object FrequencyCalculationUtils {

    /**
     * Calculate next revision date using cached frequency data from SharedPreferences
     * This replaces RevisionScheduler.calculateNextRevisionDate for better performance
     */
    fun calculateNextRevisionDate(
        context: Context,
        frequency: String,
        noRevision: Int,
        scheduledDate: Date,
        callback: (String) -> Unit
    ) {
        fetchCustomFrequencies(context) { frequencyData ->
            try {
                if (frequencyData.containsKey(frequency)) {
                    val intervals = frequencyData[frequency] ?: emptyList()
                    
                    if (intervals.isNotEmpty()) {
                        val nextInterval = if (noRevision < intervals.size) intervals[noRevision] else intervals.last()
                        
                        val calendar = Calendar.getInstance()
                        calendar.time = scheduledDate
                        calendar.add(Calendar.DAY_OF_YEAR, nextInterval)
                        
                        val nextDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(calendar.time)
                        callback(nextDate)
                        return@fetchCustomFrequencies
                    }
                }
                
                // Default fallback
                val nextDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(scheduledDate)
                callback(nextDate)
                
            } catch (e: Exception) {
                Log.e("FrequencyCalculationUtils", "Error calculating next revision date: ${e.message}")
                val nextDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(scheduledDate)
                callback(nextDate)
            }
        }
    }

    /**
     * Fetch custom frequencies directly from SharedPreferences
     * This replaces the need for RevisionScheduler by using cached data
     */
    fun fetchCustomFrequencies(context: Context, callback: (Map<String, List<Int>>) -> Unit) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                // Get frequency data from SharedPreferences that HomeWidgetManager updates
                val sharedPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val frequencyDataJson = sharedPrefs.getString("frequencyData", null)

                val data = mutableMapOf<String, List<Int>>()

                if (frequencyDataJson != null && frequencyDataJson.isNotEmpty() && frequencyDataJson != "{}") {
                    try {
                        Log.d("FrequencyCalculationUtils", "Fetching frequency data from SharedPrefs: $frequencyDataJson")

                        val jsonData = org.json.JSONObject(frequencyDataJson)
                        val keys = jsonData.keys()

                        while (keys.hasNext()) {
                            val key = keys.next()
                            val value = jsonData.get(key)

                            when (value) {
                                is org.json.JSONArray -> {
                                    val intList = mutableListOf<Int>()
                                    for (i in 0 until value.length()) {
                                        intList.add(value.getInt(i))
                                    }
                                    data[key] = intList
                                }
                                is String -> {
                                    // Handle string representation like "[1, 3, 7, 14]"
                                    try {
                                        val cleanValue = value.replace(Regex("[\\[\\]]"), "")
                                        val parts = cleanValue.split(",").map { it.trim() }
                                        val intList = parts.mapNotNull { it.toIntOrNull() }
                                        if (intList.isNotEmpty()) {
                                            data[key] = intList
                                        }
                                    } catch (e: Exception) {
                                        Log.e("FrequencyCalculationUtils", "Error parsing frequency value for $key: $value", e)
                                    }
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.e("FrequencyCalculationUtils", "Error parsing frequency JSON data", e)
                    }
                }

                Log.d("FrequencyCalculationUtils", "Fetched frequency data: $data")

                // Switch back to main thread for callback
                withContext(Dispatchers.Main) {
                    callback(data)
                }
            } catch (e: Exception) {
                Log.e("FrequencyCalculationUtils", "Error fetching custom frequencies: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    callback(emptyMap())
                }
            }
        }
    }

    /**
     * Synchronous version of fetchCustomFrequencies for use when already on a background thread
     */
    fun fetchCustomFrequenciesSync(context: Context): Map<String, List<Int>> {
        return try {
            val sharedPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val frequencyDataJson = sharedPrefs.getString("frequencyData", null)

            val data = mutableMapOf<String, List<Int>>()

            if (frequencyDataJson != null && frequencyDataJson.isNotEmpty() && frequencyDataJson != "{}") {
                try {
                    Log.d("FrequencyCalculationUtils", "Fetching frequency data sync from SharedPrefs: $frequencyDataJson")

                    val jsonData = org.json.JSONObject(frequencyDataJson)
                    val keys = jsonData.keys()

                    while (keys.hasNext()) {
                        val key = keys.next()
                        val value = jsonData.get(key)

                        when (value) {
                            is org.json.JSONArray -> {
                                val intList = mutableListOf<Int>()
                                for (i in 0 until value.length()) {
                                    intList.add(value.getInt(i))
                                }
                                data[key] = intList
                            }
                            is String -> {
                                try {
                                    val cleanValue = value.replace(Regex("[\\[\\]]"), "")
                                    val parts = cleanValue.split(",").map { it.trim() }
                                    val intList = parts.mapNotNull { it.toIntOrNull() }
                                    if (intList.isNotEmpty()) {
                                        data[key] = intList
                                    }
                                } catch (e: Exception) {
                                    Log.e("FrequencyCalculationUtils", "Error parsing frequency value for $key: $value", e)
                                }
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e("FrequencyCalculationUtils", "Error parsing frequency JSON data", e)
                }
            }

            Log.d("FrequencyCalculationUtils", "Fetched frequency data sync: $data")
            data
        } catch (e: Exception) {
            Log.e("FrequencyCalculationUtils", "Error fetching custom frequencies sync: ${e.message}", e)
            emptyMap()
        }
    }

    /**
     * Utility function to get a list of frequency names
     */
    fun getFrequencyNames(frequenciesMap: Map<String, List<Int>>): List<String> {
        return frequenciesMap.keys.toList()
    }

    /**
     * Trigger frequency data refresh in HomeWidgetManager
     */
    fun refreshFrequencyData(context: Context) {
        try {
            Log.d("FrequencyCalculationUtils", "Triggering frequency data refresh...")

            val uri = android.net.Uri.parse("homeWidget://frequency_refresh")
            val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                context,
                uri
            )
            backgroundIntent.send()
            
            Log.d("FrequencyCalculationUtils", "Frequency data refresh triggered")
        } catch (e: Exception) {
            Log.e("FrequencyCalculationUtils", "Error triggering frequency data refresh: ${e.message}")
        }
    }
}
