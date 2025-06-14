package com.imnexerio.revix

import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.widget.Toast
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicInteger

class RecordUpdateService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var activeTaskCount = AtomicInteger(0)
    private val lock = Any()

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Track active task
        synchronized(lock) {
            activeTaskCount.incrementAndGet()
        }

        if (intent == null) {
            finishTask(startId)
            return START_NOT_STICKY
        }

        val category = intent.getStringExtra("category") ?: ""
        val subCategory = intent.getStringExtra("sub_category") ?: ""
        val lectureNo = intent.getStringExtra("record_title") ?: ""

        if (category.isEmpty() || subCategory.isEmpty() || lectureNo.isEmpty()) {
            Toast.makeText(this, "Invalid record information", Toast.LENGTH_SHORT).show()
            finishTask(startId)
            return START_NOT_STICKY
        }

        // Extract additional fields from intent
        val extras = HashMap<String, String>()
        intent.extras?.let { bundle ->
            for (key in bundle.keySet()) {
                if (key != "category" && key != "sub_category" && key != "record_title") {
                    val value = bundle.getString(key)
                    if (value != null) {
                        extras[key] = value
                    }
                }
            }
        }

        handleRecordClick(category, subCategory, lectureNo, extras, startId)
        return START_STICKY
    }

    private fun finishTask(startId: Int) {
        synchronized(lock) {
            val remainingTasks = activeTaskCount.decrementAndGet()
            if (remainingTasks <= 0) {
                // Make sure we use a new handler to avoid timing issues
                handler.post {
                    handler.postDelayed({
                        stopSelf()
                    }, 1000)
                }
            } else {
                // Only stop this specific task
                stopSelf(startId)
            }
        }
    }

    private fun refreshWidgets(startId: Int) {
        try {
            // Instead of direct widget updates, send a broadcast
            val context = applicationContext
            val intent = Intent(context, TodayWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, TodayWidget::class.java)
                )
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
            }
            context.sendBroadcast(intent)

            // Widget refresh will be handled by Flutter background callback
            // No need for separate service

            // Complete this task
            finishTask(startId)
        } catch (e: Exception) {
            // Handle any exceptions that occur during the refresh
            Toast.makeText(this, "Error refreshing widgets: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    private fun handleRecordClick(
        category: String,
        subCategory: String,
        lectureNo: String,
        extras: Map<String, String>,
        startId: Int
    ) {
        // Get record data from TodayWidget's SharedPreferences instead of Firebase
        val sharedPreferences = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val recordDetails = getRecordFromWidget(category, subCategory, lectureNo, sharedPreferences)

        if (recordDetails == null) {
            Toast.makeText(applicationContext, "Record not found in widget data", Toast.LENGTH_SHORT).show()
            stopSelf(startId)
            return
        }

        try {
            // Convert the record details to the expected format
            val details = recordDetails.toMutableMap<String, Any>()

            // Check if today's date is already in dates_updated
            val dateRevised = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
            val datesRevisedString = details["dates_updated"] as? String ?: "[]"
            val datesRevised = try {
                org.json.JSONArray(datesRevisedString).let { jsonArray ->
                    (0 until jsonArray.length()).map { jsonArray.getString(it) }
                }
            } catch (e: Exception) {
                listOf<String>()
            }

            // Check if the record has been revised today
            val revisedToday = datesRevised.any { it.startsWith(dateRevised) }

            if (revisedToday) {
                // Already revised today, just refresh
                Toast.makeText(applicationContext, "Already revised today. Refreshing data...", Toast.LENGTH_SHORT).show()
                clearProcessingState(category, subCategory, lectureNo)
                refreshWidgets(startId)
            } else {
                updateRecord(details, category, subCategory, lectureNo, extras, startId)
            }
        } catch (e: Exception) {
            Toast.makeText(applicationContext, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
            e.printStackTrace()
            stopSelf(startId)
        }
    }

    private fun getRecordFromWidget(
        category: String,
        subCategory: String,
        lectureNo: String,
        sharedPreferences: SharedPreferences
    ): Map<String, String>? {
        // Check all possible widget data sources
        val dataSources = listOf("todayRecords", "missedRecords", "noreminderdate")
        
        for (dataSource in dataSources) {
            val jsonData = sharedPreferences.getString(dataSource, "[]") ?: "[]"
            try {
                val jsonArray = org.json.JSONArray(jsonData)
                for (i in 0 until jsonArray.length()) {
                    val jsonObject = jsonArray.getJSONObject(i)
                    val recordCategory = jsonObject.optString("category", "")
                    val recordSubCategory = jsonObject.optString("sub_category", "")
                    val recordTitle = jsonObject.optString("record_title", "")
                    
                    if (recordCategory == category && recordSubCategory == subCategory && recordTitle == lectureNo) {
                        // Found the record, convert it to a map
                        val record = mutableMapOf<String, String>()
                        val keys = jsonObject.keys()
                        while (keys.hasNext()) {
                            val key = keys.next()
                            record[key] = jsonObject.optString(key, "")
                        }
                        return record
                    }
                }
            } catch (e: Exception) {
                Log.e("RecordUpdateService", "Error parsing JSON data from $dataSource: ${e.message}")
            }
        }
        return null
    }    private fun updateRecord(
        details: Map<*, *>,
        category: String,
        subCategory: String,
        lectureNo: String,
        extras: Map<String, String>,
        startId: Int
    ) {
        try {
            // First check for "Unspecified" date_initiated
            if (details["date_initiated"] == "Unspecified") {
                processRecordDeletion(category, subCategory, lectureNo, details, startId, "marked as done and moved to deleted data")
                return
            }

            // Then check for "No Repetition" revision frequency
            if (details["recurrence_frequency"] == "No Repetition") {
                processRecordDeletion(category, subCategory, lectureNo, details, startId, "marked as done and deleted")
                return
            }

            // Get current date-time in the format needed
            val currentDateTime = SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.getDefault()).format(Date())
            val currentDate = currentDateTime.split("T")[0]

            // Process data - convert string values to appropriate types
            val missedRevision = (details["missed_counts"] as? String)?.toIntOrNull() ?: 0
            val scheduledDateStr = details["scheduled_date"] as? String ?: currentDate
            val scheduledDate = try {
                SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse(scheduledDateStr) ?: Date()
            } catch (e: Exception) {
                Date()
            }

            // Get revision frequency and revision count
            val revisionFrequency = details["recurrence_frequency"]?.toString() ?:
                extras["recurrence_frequency"] ?: "daily"

            val noRevision = (details["completion_counts"] as? String)?.toIntOrNull() ?: 0

            // Calculate next revision date based on frequency type
            if (revisionFrequency == "Custom") {
                // Handle custom revision frequency
                val revisionDataStr = details["recurrence_data"] as? String ?: "{}"
                val revisionData = try {
                    val jsonObject = org.json.JSONObject(revisionDataStr)
                    val map = mutableMapOf<String, Any?>()
                    val keys = jsonObject.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        map[key] = jsonObject.get(key)
                    }
                    map
                } catch (e: Exception) {
                    emptyMap<String, Any?>()
                }

                val dateScheduled = try {
                    SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse(scheduledDateStr) ?: Date()
                } catch (e: Exception) {
                    Date()
                }
                val scheduledCalendar = Calendar.getInstance()
                scheduledCalendar.time = dateScheduled

                val nextDate = CalculateCustomNextDate.calculateCustomNextDate(scheduledCalendar, revisionData)
                val nextRevisionDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(nextDate.time)

                processRecordUpdate(
                    details, category, subCategory, lectureNo,
                    currentDateTime, currentDate, missedRevision,
                    scheduledDate, noRevision, nextRevisionDate, startId
                )
            } else {
                // Use the direct frequency calculation for non-custom frequencies
                FrequencyCalculationUtils.calculateNextRevisionDate(
                    this,
                    revisionFrequency,
                    noRevision + 1,
                    scheduledDate
                ) { nextRevisionDate ->
                    processRecordUpdate(
                        details, category, subCategory, lectureNo,
                        currentDateTime, currentDate, missedRevision,
                        scheduledDate, noRevision, nextRevisionDate, startId
                    )
                }
            }
        } catch (e: Exception) {
            Toast.makeText(applicationContext, "Error updating record: ${e.message}", Toast.LENGTH_SHORT).show()
            refreshWidgets(startId)
            e.printStackTrace()
            stopSelf(startId)
        }
    }    private fun processRecordDeletion(
        category: String,
        subCategory: String,
        lectureNo: String,
        details: Map<*, *>,
        startId: Int,
        actionDescription: String
    ) {
        // Use background callback mechanism like TodayWidget
        try {
            // Show processing message
            handler.post {
                Toast.makeText(
                    applicationContext,
                    "Processing deletion...",
                    Toast.LENGTH_SHORT
                ).show()
            }

            // Create unique request ID for tracking this delete operation
            val requestId = System.currentTimeMillis().toString()
            
            // Trigger background callback to handle record deletion
            val uri = android.net.Uri.parse("homeWidget://record_delete")
                .buildUpon()
                .appendQueryParameter("category", category)
                .appendQueryParameter("sub_category", subCategory)
                .appendQueryParameter("record_title", lectureNo)
                .appendQueryParameter("action", actionDescription)
                .appendQueryParameter("requestId", requestId)
                .build()

            val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                applicationContext,
                uri
            )
            backgroundIntent.send()

            // Wait for deletion result in background thread
            Thread {
                var retryCount = 0
                val maxRetries = 50 // 10 seconds max wait time
                var deleteCompleted = false
                var deleteSuccess = false
                var errorMessage = ""
                
                while (retryCount < maxRetries && !deleteCompleted) {
                    try {
                        Thread.sleep(200) // Wait 200ms between checks
                        
                        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                        val resultKey = "record_delete_result_$requestId"
                        val result = prefs.getString(resultKey, null)
                        
                        if (result != null) {
                            deleteCompleted = true
                            if (result.startsWith("SUCCESS")) {
                                deleteSuccess = true
                            } else if (result.startsWith("ERROR:")) {
                                deleteSuccess = false
                                errorMessage = result.substring(6) // Remove "ERROR:" prefix
                            }
                            
                            // Clean up the result from preferences
                            prefs.edit().remove(resultKey).apply()
                            break
                        }
                        
                        retryCount++
                    } catch (e: InterruptedException) {
                        Log.e("RecordUpdateService", "Delete result waiting interrupted: ${e.message}")
                        break
                    }
                }
                
                // Show result on main thread
                handler.post {
                    if (deleteCompleted) {
                        if (deleteSuccess) {
                            Toast.makeText(
                                applicationContext,
                                "$category $subCategory $lectureNo has been $actionDescription.",
                                Toast.LENGTH_LONG
                            ).show()
                        } else {
                            val displayError = if (errorMessage.isNotEmpty()) errorMessage else "Unknown error occurred"
                            Toast.makeText(
                                applicationContext,
                                "Failed to process deletion: $displayError",
                                Toast.LENGTH_SHORT
                            ).show()
                        }
                    } else {
                        // Timeout occurred
                        Toast.makeText(
                            applicationContext,
                            "Delete operation timed out. Please try again.",
                            Toast.LENGTH_SHORT
                        ).show()
                    }
                }
                  // Clear processing state and refresh widgets
                clearProcessingState(category, subCategory, lectureNo)
                refreshWidgets(startId)
                
            }.start()

        } catch (e: Exception) {
            Log.e("RecordUpdateService", "Error triggering background deletion: ${e.message}")
            handler.post {
                Toast.makeText(
                    applicationContext,
                    "Failed to process deletion: ${e.message}",
                    Toast.LENGTH_SHORT
                ).show()
            }
            clearProcessingState(category, subCategory, lectureNo)
            refreshWidgets(startId)
            stopSelf(startId)
        }
    }private fun processRecordUpdate(
        details: Map<*, *>,
        category: String,
        subCategory: String,
        lectureNo: String,
        currentDateTime: String,
        currentDate: String,
        missedRevision: Int,
        scheduledDate: Date,
        noRevision: Int,
        nextRevisionDate: String,
        startId: Int
    ) {
        try {
            // Show processing message
            handler.post {
                Toast.makeText(
                    applicationContext,
                    "Updating record...",
                    Toast.LENGTH_SHORT
                ).show()
            }

            // Use background callback mechanism for record updates
            val updateData = createUpdateData(
                details, currentDateTime, currentDate, missedRevision,
                scheduledDate, noRevision, nextRevisionDate
            )

            // Create URI with update data and request ID for tracking
            val requestId = System.currentTimeMillis().toString()
            val uriBuilder = android.net.Uri.parse("homeWidget://record_update")
                .buildUpon()
                .appendQueryParameter("category", category)
                .appendQueryParameter("sub_category", subCategory)
                .appendQueryParameter("record_title", lectureNo)
                .appendQueryParameter("next_revision_date", nextRevisionDate)
                .appendQueryParameter("update_data", org.json.JSONObject(updateData).toString())
                .appendQueryParameter("requestId", requestId)

            val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                applicationContext,
                uriBuilder.build()
            )
            backgroundIntent.send()

            // Wait for update result in background thread
            Thread {
                var retryCount = 0
                val maxRetries = 50 // 10 seconds max wait time
                var updateCompleted = false
                var updateSuccess = false
                var errorMessage = ""
                
                while (retryCount < maxRetries && !updateCompleted) {
                    try {
                        Thread.sleep(200) // Wait 200ms between checks
                        
                        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                        val resultKey = "record_update_result_$requestId"
                        val result = prefs.getString(resultKey, null)
                        
                        if (result != null) {
                            updateCompleted = true
                            if (result.startsWith("SUCCESS")) {
                                updateSuccess = true
                            } else if (result.startsWith("ERROR:")) {
                                updateSuccess = false
                                errorMessage = result.substring(6) // Remove "ERROR:" prefix
                            }
                            
                            // Clean up the result from preferences
                            prefs.edit().remove(resultKey).apply()
                            break
                        }
                        
                        retryCount++
                    } catch (e: InterruptedException) {
                        Log.e("RecordUpdateService", "Update result waiting interrupted: ${e.message}")
                        break
                    }
                }
                
                // Show result on main thread
                handler.post {
                    if (updateCompleted) {
                        if (updateSuccess) {
                            Toast.makeText(
                                applicationContext,
                                "Record updated successfully! Scheduled for $nextRevisionDate",
                                Toast.LENGTH_SHORT
                            ).show()
                        } else {
                            val displayError = if (errorMessage.isNotEmpty()) errorMessage else "Unknown error occurred"
                            Toast.makeText(
                                applicationContext,
                                "Update failed: $displayError",
                                Toast.LENGTH_SHORT
                            ).show()
                        }
                    } else {
                        // Timeout occurred
                        Toast.makeText(
                            applicationContext,
                            "Update operation timed out. Please try again.",
                            Toast.LENGTH_SHORT
                        ).show()
                    }
                }
                  // Clear processing state and refresh widgets
                clearProcessingState(category, subCategory, lectureNo)
                refreshWidgets(startId)
                
            }.start()

        } catch (e: Exception) {
            Log.e("RecordUpdateService", "Error triggering background update: ${e.message}")
            handler.post {
                Toast.makeText(
                    applicationContext,
                    "Update failed: ${e.message}",
                    Toast.LENGTH_SHORT
                ).show()
            }
            clearProcessingState(category, subCategory, lectureNo)
            refreshWidgets(startId)
            stopSelf(startId)
        }
    }

    private fun createUpdateData(
        details: Map<*, *>,
        currentDateTime: String,
        currentDate: String,
        missedRevision: Int,
        scheduledDate: Date,
        noRevision: Int,
        nextRevisionDate: String
    ): Map<String, Any> {
        val updatedValues = HashMap<String, Any>()

        // Update date_updated
        updatedValues["date_updated"] = currentDateTime

        // Handle missed revisions if scheduled date is in the past
        var newMissedRevision = missedRevision
        val datesMissedRevisionsStr = details["dates_missed_revisions"] as? String ?: "[]"
        val datesMissedRevisions = try {
            org.json.JSONArray(datesMissedRevisionsStr).let { jsonArray ->
                (0 until jsonArray.length()).map { jsonArray.getString(it) }.toMutableList()
            }
        } catch (e: Exception) {
            mutableListOf<String>()
        }

        val scheduledDateStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(scheduledDate)
        if (scheduledDateStr.compareTo(currentDate) < 0) {
            newMissedRevision += 1
            if (!datesMissedRevisions.contains(scheduledDateStr)) {
                datesMissedRevisions.add(scheduledDateStr)
            }
        }

        updatedValues["missed_counts"] = newMissedRevision
        updatedValues["dates_missed_revisions"] = datesMissedRevisions

        // Update dates_updated
        val datesRevisedStr = details["dates_updated"] as? String ?: "[]"
        val datesRevised = try {
            org.json.JSONArray(datesRevisedStr).let { jsonArray ->
                (0 until jsonArray.length()).map { jsonArray.getString(it) }.toMutableList()
            }
        } catch (e: Exception) {
            mutableListOf<String>()
        }
        
        datesRevised.add(currentDateTime)
        if (noRevision == -1) {
            datesRevised.clear()
        }
        updatedValues["dates_updated"] = datesRevised

        // Update completion_counts
        updatedValues["completion_counts"] = noRevision + 1

        // Update scheduled_date with next revision date
        updatedValues["scheduled_date"] = nextRevisionDate

        // Convert details to proper format for status determination
        val detailsForStatus = details.toMutableMap().apply {
            this["completion_counts"] = (noRevision + 1).toString()
        }

        val newEnabledStatus = determineEnabledStatus(detailsForStatus)

        if (!newEnabledStatus && (details["status"] as? String) == "Enabled") {
            updatedValues["status"] = "Disabled"
        }

        return updatedValues
    }

    private fun determineEnabledStatus(details: Map<*, *>): Boolean {
        var isEnabled = (details["status"] as? String) == "Enabled"
        
        // Parse duration data from JSON string
        val durationDataStr = details["duration"] as? String ?: "{\"type\":\"forever\"}"
        val durationData = try {
            val jsonObject = org.json.JSONObject(durationDataStr)
            val map = mutableMapOf<String, Any?>()
            val keys = jsonObject.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                map[key] = jsonObject.get(key)
            }
            map
        } catch (e: Exception) {
            mapOf("type" to "forever")
        }

        val durationType = durationData["type"] as? String ?: "forever"

        when (durationType) {
            "specificTimes" -> {
                val numberOfTimes = when (val times = durationData["numberOfTimes"]) {
                    is Number -> times.toInt()
                    is String -> times.toIntOrNull()
                    else -> null
                }
                val currentRevisions = (details["completion_counts"] as? String)?.toIntOrNull() ?: 0
                if (numberOfTimes != null && currentRevisions >= numberOfTimes) {
                    isEnabled = false
                }
            }
            "until" -> {
                val endDateStr = durationData["endDate"] as? String
                if (endDateStr != null) {
                    try {
                        val endDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse(endDateStr)
                        val today = Date()
                        val endCalendar = Calendar.getInstance()
                        endCalendar.time = endDate ?: today
                        endCalendar.set(Calendar.HOUR_OF_DAY, 0)
                        endCalendar.set(Calendar.MINUTE, 0)
                        endCalendar.set(Calendar.SECOND, 0)
                        endCalendar.set(Calendar.MILLISECOND, 0)

                        val todayCalendar = Calendar.getInstance()
                        todayCalendar.time = today
                        todayCalendar.set(Calendar.HOUR_OF_DAY, 0)
                        todayCalendar.set(Calendar.MINUTE, 0)
                        todayCalendar.set(Calendar.SECOND, 0)
                        todayCalendar.set(Calendar.MILLISECOND, 0)

                        // Disable if today is on or after the end date
                        if (todayCalendar.after(endCalendar) || todayCalendar.equals(endCalendar)) {
                            isEnabled = false
                        }
                    } catch (e: Exception) {
//                        Log.e("RecordUpdateService", "Error parsing end date: ${e.message}")
                    }
                }
            }
        }

        return isEnabled
    }    private fun clearProcessingState(category: String, subCategory: String, lectureNo: String) {
        val prefs = applicationContext.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val processingItems = prefs.getStringSet(TodayWidget.PREF_PROCESSING_ITEMS, mutableSetOf()) ?: mutableSetOf()
        val itemKey = "${category}_${subCategory}_${lectureNo}"
        val newProcessingItems = processingItems.toMutableSet()
        newProcessingItems.remove(itemKey)
        prefs.edit().putStringSet(TodayWidget.PREF_PROCESSING_ITEMS, newProcessingItems).apply()
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up any stale result entries
        cleanupOldResults()
    }

    private fun cleanupOldResults() {
        try {
            val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            val allKeys = prefs.all.keys
            val currentTime = System.currentTimeMillis()
            
            // Remove result entries older than 1 minute
            for (key in allKeys) {
                if (key.startsWith("record_save_result_") || 
                    key.startsWith("record_update_result_") || 
                    key.startsWith("record_delete_result_")) {
                    try {
                        val parts = key.split("_")
                        if (parts.size >= 4) {
                            val timestamp = parts[3].toLongOrNull()
                            if (timestamp != null && (currentTime - timestamp) > 60000) { // 1 minute
                                editor.remove(key)
                            }
                        }
                    } catch (e: Exception) {
                        // If we can't parse the timestamp, remove the entry
                        editor.remove(key)
                    }
                }
            }
            editor.apply()
        } catch (e: Exception) {
            Log.e("RecordUpdateService", "Error cleaning up old results: ${e.message}")
        }
    }
}
