package com.imnexerio.revix

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

data class AlarmMetadata(
    val key: String,
    val category: String,
    val subCategory: String,
    val recordTitle: String,
    val scheduledDate: String,  // NEW - store the date
    val actualTime: Long,
    val alarmType: Int,
    val reminderTime: String  // NEW - store the original reminder time
)

class AlarmManagerHelper(private val context: Context) {
    companion object {
        private const val TAG = "AlarmManagerHelper"
        private const val PREFS_NAME = "record_alarms"
        private const val ALARM_METADATA_KEY = "alarm_metadata"
    }

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)    // NEW: Method to schedule alarms from SharedPreferences data (for RecordUpdateService)
    fun scheduleAlarmsFromWidgetData(context: Context, forceUpdate: Boolean = false) {
        try {
            Log.d(TAG, "Checking if alarm scheduling needed from SharedPreferences...")

            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val todayRecordsJson = prefs.getString("todayRecords", "[]") ?: "[]"
            val tomorrowRecordsJson = prefs.getString("tomorrowRecords", "[]") ?: "[]"

            // Parse JSON to get records
            val todayRecords = parseRecordsFromJson(todayRecordsJson)
            val tomorrowRecords = parseRecordsFromJson(tomorrowRecordsJson)

            Log.d(TAG, "Parsed ${todayRecords.size} today + ${tomorrowRecords.size} tomorrow records from SharedPreferences")

            if (todayRecords.isNotEmpty() || tomorrowRecords.isNotEmpty()) {
                scheduleAlarmsForTwoDays(todayRecords, tomorrowRecords)
                Log.d(TAG, "Successfully scheduled alarms from SharedPreferences")
            } else {
                Log.d(TAG, "No records found for alarm scheduling from SharedPreferences")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling alarms from SharedPreferences: ${e.message}", e)
        }
    }

    private fun parseRecordsFromJson(jsonString: String): List<Map<String, Any>> {
        val records = mutableListOf<Map<String, Any>>()

        try {
            val jsonArray = org.json.JSONArray(jsonString)
            for (i in 0 until jsonArray.length()) {
                val jsonObject = jsonArray.getJSONObject(i)
                val record = mutableMapOf<String, Any>()

                // Extract all fields needed for alarm scheduling
                record["category"] = jsonObject.optString("category", "")
                record["sub_category"] = jsonObject.optString("sub_category", "")
                record["record_title"] = jsonObject.optString("record_title", "")
                record["reminder_time"] = jsonObject.optString("reminder_time", "")
                record["alarm_type"] = jsonObject.optString("alarm_type", "0").toIntOrNull() ?: 0
                record["scheduled_date"] = jsonObject.optString("scheduled_date", "")
                record["status"] = jsonObject.optString("status", "")

                records.add(record)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing records JSON: ${e.message}", e)
        }

        return records
    }

    // Smart alarm scheduling - only update what actually changed
    fun scheduleAlarmsForTwoDays(
        todayRecords: List<Map<String, Any>>,
        tomorrowRecords: List<Map<String, Any>>
    ) {
        Log.d(TAG, "=== Starting Smart Alarm Scheduling ===")
        Log.d(TAG, "Processing alarm scheduling with ${todayRecords.size} today + ${tomorrowRecords.size} tomorrow records")
        
        // Log current state before changes
        logCurrentAlarms()
        
        // Get current dates from the actual data
        val todayDate = getTodayDateFromRecords(todayRecords)
        val tomorrowDate = getTomorrowDateFromRecords(tomorrowRecords)

        Log.d(TAG, "Current data dates - Today: $todayDate, Tomorrow: $tomorrowDate")
        
        // Clean up old alarm metadata first
        cleanupOldAlarmMetadata()
          // Get current alarms AFTER cleanup
        val currentAlarms = getStoredAlarmMetadata().toMutableMap()
        val processedAlarmMetadata = mutableMapOf<String, AlarmMetadata>()
        
        // Process both days to build processed alarm set
        processDayRecords(todayRecords, todayDate, processedAlarmMetadata)
        processDayRecords(tomorrowRecords, tomorrowDate, processedAlarmMetadata)
        
        // Smart update: only change what's different
        handleSmartAlarmUpdates(currentAlarms, processedAlarmMetadata)
        
        // Save updated metadata
        saveAlarmMetadata(processedAlarmMetadata.values.toList())
        
        Log.d(TAG, "Smart alarm scheduling completed. Active alarms: ${processedAlarmMetadata.size}")
        Log.d(TAG, "=== Finished Smart Alarm Scheduling ===")
        
        // Log final state
        logCurrentAlarms()
    }private fun getTodayDateFromRecords(todayRecords: List<Map<String, Any>>): String {
        return todayRecords.firstOrNull()?.get("scheduled_date")?.toString()
            ?: SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
    }

    private fun getTomorrowDateFromRecords(tomorrowRecords: List<Map<String, Any>>): String {
        return tomorrowRecords.firstOrNull()?.get("scheduled_date")?.toString()
            ?: SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(
                Date(System.currentTimeMillis() + 24 * 60 * 60 * 1000)
            )
    }    private fun processDayRecords(
        records: List<Map<String, Any>>, 
        dateString: String,
        processedAlarmMetadata: MutableMap<String, AlarmMetadata>
    ) {
        Log.d(TAG, "Processing ${records.size} records for $dateString")

        records.forEach { record ->
            try {
                val category = record["category"]?.toString() ?: ""
                val subCategory = record["sub_category"]?.toString() ?: ""
                val recordTitle = record["record_title"]?.toString() ?: ""
                val reminderTime = record["reminder_time"]?.toString() ?: ""
                val alarmType = (record["alarm_type"]?.toString()?.toIntOrNull()) ?: 0
                val scheduledDate = record["scheduled_date"]?.toString() ?: dateString

                if (alarmType == 0 || reminderTime.lowercase() == "all day" || reminderTime.isEmpty()) {
                    return@forEach
                }

                val actualTime = parseTimeForDate(reminderTime, scheduledDate)
                val uniqueKey = generateUniqueKeyWithDate(category, subCategory, recordTitle, scheduledDate)
                
                val newMetadata = AlarmMetadata(
                    key = uniqueKey,
                    category = category,
                    subCategory = subCategory,
                    recordTitle = recordTitle,
                    scheduledDate = scheduledDate,
                    actualTime = actualTime,
                    alarmType = alarmType,
                    reminderTime = reminderTime
                )                // Add to processed metadata regardless of time - comparison with old data happens later
                processedAlarmMetadata[uniqueKey] = newMetadata
                Log.d(
                    TAG,
                    "PROCESSED RECORD: $recordTitle on $scheduledDate at ${Date(actualTime)}"
                )

            } catch (e: Exception) {
                Log.e(TAG, "Error processing record for $dateString", e)
            }
        }
    }    private fun handleSmartAlarmUpdates(
        currentAlarms: MutableMap<String, AlarmMetadata>,
        processedAlarmMetadata: Map<String, AlarmMetadata>
    ) {
        var newCount = 0
        var updatedCount = 0
        var unchangedCount = 0
        var removedCount = 0
        var skippedPastCount = 0
        val currentTime = System.currentTimeMillis()
          // Process new/updated alarms
        processedAlarmMetadata.values.forEach { processedAlarm ->
            val existingAlarm = currentAlarms[processedAlarm.key]
            
            when {
                existingAlarm == null -> {
                    // New alarm - check if time is in future before scheduling
                    if (processedAlarm.actualTime <= currentTime) {
                        skippedPastCount++
                        Log.d(TAG, "SKIPPING NEW PAST ALARM: ${processedAlarm.recordTitle} on ${processedAlarm.scheduledDate} at ${Date(processedAlarm.actualTime)} (current: ${Date(currentTime)})")
                    } else {
                        scheduleAlarm(processedAlarm)
                        newCount++
                        Log.d(TAG, "NEW alarm: ${processedAlarm.recordTitle} on ${processedAlarm.scheduledDate}")
                    }
                }
                !alarmsAreEqual(existingAlarm, processedAlarm) -> {
                    // Alarm changed - cancel old and check if new time is valid before scheduling
                    cancelAlarm(existingAlarm.key)
                    if (processedAlarm.actualTime <= currentTime) {
                        skippedPastCount++
                        Log.d(TAG, "SKIPPING UPDATED PAST ALARM: ${processedAlarm.recordTitle} on ${processedAlarm.scheduledDate} at ${Date(processedAlarm.actualTime)} (current: ${Date(currentTime)})")
                    } else {
                        scheduleAlarm(processedAlarm)
                        updatedCount++
                        Log.d(TAG, "UPDATED alarm: ${processedAlarm.recordTitle} on ${processedAlarm.scheduledDate}")
                        logAlarmChanges(existingAlarm, processedAlarm)
                    }
                }
                else -> {
                    // Alarm unchanged - keep existing alarm, no action needed
                    unchangedCount++
                    Log.d(TAG, "UNCHANGED alarm: ${processedAlarm.recordTitle} on ${processedAlarm.scheduledDate} - keeping existing")
                }
            }
        }

        // Remove alarms that are no longer in the new data
        val removedKeys = currentAlarms.keys.minus(processedAlarmMetadata.keys)
        removedKeys.forEach { removedKey ->
            val removedAlarm = currentAlarms[removedKey]
            if (removedAlarm != null) {
                cancelAlarm(removedKey)
                removedCount++
                Log.d(TAG, "REMOVED alarm: ${removedAlarm.recordTitle} on ${removedAlarm.scheduledDate}")
            }
        }
        
        Log.d(TAG, "Smart update summary: $newCount new, $updatedCount updated, $unchangedCount unchanged, $removedCount removed, $skippedPastCount skipped (past time)")
    }

    private fun alarmsAreEqual(alarm1: AlarmMetadata, alarm2: AlarmMetadata): Boolean {
        return alarm1.actualTime == alarm2.actualTime &&
               alarm1.alarmType == alarm2.alarmType &&
               alarm1.category == alarm2.category &&
               alarm1.subCategory == alarm2.subCategory &&
               alarm1.recordTitle == alarm2.recordTitle &&
               alarm1.scheduledDate == alarm2.scheduledDate &&
               alarm1.reminderTime == alarm2.reminderTime
    }

    private fun logAlarmChanges(oldAlarm: AlarmMetadata, newAlarm: AlarmMetadata) {
        if (oldAlarm.actualTime != newAlarm.actualTime) {
            Log.d(TAG, "  Time changed: ${Date(oldAlarm.actualTime)} -> ${Date(newAlarm.actualTime)}")
        }
        if (oldAlarm.alarmType != newAlarm.alarmType) {
            Log.d(TAG, "  Type changed: ${oldAlarm.alarmType} -> ${newAlarm.alarmType}")
        }
        if (oldAlarm.category != newAlarm.category) {
            Log.d(TAG, "  Category changed: ${oldAlarm.category} -> ${newAlarm.category}")
        }
        if (oldAlarm.subCategory != newAlarm.subCategory) {
            Log.d(TAG, "  SubCategory changed: ${oldAlarm.subCategory} -> ${newAlarm.subCategory}")
        }
        if (oldAlarm.recordTitle != newAlarm.recordTitle) {
            Log.d(TAG, "  Title changed: ${oldAlarm.recordTitle} -> ${newAlarm.recordTitle}")
        }
        if (oldAlarm.scheduledDate != newAlarm.scheduledDate) {
            Log.d(TAG, "  Date changed: ${oldAlarm.scheduledDate} -> ${newAlarm.scheduledDate}")
        }
        if (oldAlarm.reminderTime != newAlarm.reminderTime) {
            Log.d(TAG, "  Reminder time changed: ${oldAlarm.reminderTime} -> ${newAlarm.reminderTime}")
        }
    }

    fun cancelAllStoredAlarms() {
        val currentAlarms = getStoredAlarmMetadata()
        currentAlarms.values.forEach { alarm ->
            cancelAlarm(alarm.key)
            Log.d(TAG, "Cancelled stored alarm: ${alarm.recordTitle} on ${alarm.scheduledDate}")
        }
        // Clear all metadata
        prefs.edit().remove(ALARM_METADATA_KEY).apply()
        Log.d(TAG, "Cancelled and cleared all stored alarms: ${currentAlarms.size}")
    }

    fun logCurrentAlarms() {
        val currentAlarms = getStoredAlarmMetadata()
        Log.d(TAG, "=== Current Stored Alarms (${currentAlarms.size}) ===")
        currentAlarms.values.forEach { alarm ->
            Log.d(TAG, "Alarm: ${alarm.recordTitle} | Date: ${alarm.scheduledDate} | Time: ${Date(alarm.actualTime)} | Type: ${alarm.alarmType} | Key: ${alarm.key}")
        }
        Log.d(TAG, "=== End Current Alarms ===")
    }

    private fun generateUniqueKeyWithDate(
        category: String, 
        subCategory: String, 
        recordTitle: String, 
        scheduledDate: String
    ): String {
        // Use a deterministic approach instead of hashCode to ensure consistency
        return "${category}_${subCategory}_${recordTitle}_${scheduledDate}".replace(" ", "_").replace("[^a-zA-Z0-9_]".toRegex(), "")
    }

    private fun parseTimeForDate(timeString: String, dateString: String): Long {
        val timeParts = timeString.split(":")
        if (timeParts.size != 2) return 0L

        val hour = timeParts[0].toIntOrNull() ?: return 0L
        val minute = timeParts[1].toIntOrNull() ?: return 0L

        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val targetDate = dateFormat.parse(dateString) ?: return 0L
        
        return Calendar.getInstance().apply {
            time = targetDate
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis    }    private fun scheduleAlarm(metadata: AlarmMetadata) {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_ALARM_TRIGGER
            putExtra(AlarmReceiver.EXTRA_CATEGORY, metadata.category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, metadata.subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, metadata.recordTitle)
            putExtra("scheduled_date", metadata.scheduledDate)
            putExtra(AlarmReceiver.EXTRA_ALARM_TYPE, metadata.alarmType)
            putExtra("reminder_time", metadata.reminderTime)
        }

        // Use a consistent request code based on the key
        val requestCode = metadata.key.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        scheduleExactAlarm(metadata.actualTime, pendingIntent)
        
        Log.d(TAG, "Scheduled alarm for ${metadata.recordTitle} on ${metadata.scheduledDate} at ${Date(metadata.actualTime)} with requestCode: $requestCode")
    }

    fun cancelAlarmByRecord(category: String, subCategory: String, recordTitle: String) {
        val currentMetadata = getStoredAlarmMetadata().toMutableMap()
        
        // Find all alarms for this record (there might be multiple dates)
        val alarmsToCancel = currentMetadata.values.filter { alarm ->
            alarm.category == category && 
            alarm.subCategory == subCategory && 
            alarm.recordTitle == recordTitle
        }
        
        if (alarmsToCancel.isEmpty()) {
            Log.d(TAG, "No alarms found to cancel for record: $recordTitle")
            return
        }
        
        // Cancel each alarm found
        alarmsToCancel.forEach { alarm ->
            cancelAlarm(alarm.key)
            currentMetadata.remove(alarm.key)
            Log.d(TAG, "Cancelled alarm for record: $recordTitle on ${alarm.scheduledDate}")
        }
        
        saveAlarmMetadata(currentMetadata.values.toList())
        Log.d(TAG, "Successfully cancelled ${alarmsToCancel.size} alarm(s) for record: $recordTitle")
    }    // Efficient update for single record changes
    fun updateAlarmForRecord(
        category: String,
        subCategory: String, 
        recordTitle: String,
        scheduledDate: String,
        reminderTime: String,
        alarmType: Int
    ) {
        Log.d(TAG, "Updating alarm for single record: $recordTitle on $scheduledDate")
        
        // First cancel any existing alarms for this record
        cancelAlarmByRecord(category, subCategory, recordTitle)
        
        // If alarm type is 0 or time is "all day", don't schedule new alarm
        if (alarmType == 0 || reminderTime.lowercase() == "all day" || reminderTime.isEmpty()) {
            Log.d(TAG, "No alarm needed for record: $recordTitle (type: $alarmType, time: $reminderTime)")
            return
        }
        
        // Create and schedule new alarm
        val actualTime = parseTimeForDate(reminderTime, scheduledDate)
        val uniqueKey = generateUniqueKeyWithDate(category, subCategory, recordTitle, scheduledDate)

        val newMetadata = AlarmMetadata(
            key = uniqueKey,
            category = category,
            subCategory = subCategory,
            recordTitle = recordTitle,
            scheduledDate = scheduledDate,
            actualTime = actualTime,
            alarmType = alarmType,
            reminderTime = reminderTime
        )
        
        // Check if alarm time is in the future before scheduling
        val currentTime = System.currentTimeMillis()
        if (actualTime <= currentTime) {
            Log.w(TAG, "SKIPPING PAST ALARM UPDATE: $recordTitle on $scheduledDate at ${Date(actualTime)} (current: ${Date(currentTime)})")
            return
        }
        
        // Schedule the new alarm
        scheduleAlarm(newMetadata)
        
        // Update stored metadata
        val currentMetadata = getStoredAlarmMetadata().toMutableMap()
        currentMetadata[uniqueKey] = newMetadata
        saveAlarmMetadata(currentMetadata.values.toList())
        
        Log.d(TAG, "Successfully updated alarm for record: $recordTitle")
    }

    private fun scheduleExactAlarm(triggerTime: Long, pendingIntent: PendingIntent) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (hasExactAlarmPermission()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                } else {
                    Log.w(TAG, "Exact alarm permission not granted, using inexact alarm")
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                }
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule alarm", e)
        }
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun hasExactAlarmPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }    private fun cancelAlarm(alarmKey: String) {
        try {
            // Get the alarm metadata to recreate the exact intent
            val alarmMetadata = getStoredAlarmMetadata()[alarmKey]
            
            if (alarmMetadata != null) {
                // Create the exact same intent that was used for scheduling
                 val intent = Intent(context, AlarmReceiver::class.java).apply {
                    action = AlarmReceiver.ACTION_ALARM_TRIGGER
                    putExtra(AlarmReceiver.EXTRA_CATEGORY, alarmMetadata.category)
                    putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, alarmMetadata.subCategory)
                    putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, alarmMetadata.recordTitle)
                    putExtra("scheduled_date", alarmMetadata.scheduledDate)
                    putExtra(AlarmReceiver.EXTRA_ALARM_TYPE, alarmMetadata.alarmType)
                    putExtra("reminder_time", alarmMetadata.reminderTime)
                }
                
                // Use the same request code calculation as in scheduleAlarm
                val requestCode = alarmKey.hashCode()
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    requestCode,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
                Log.d(TAG, "Successfully cancelled alarm: $alarmKey with requestCode: $requestCode")
            } else {
                Log.w(TAG, "Alarm metadata not found for key: $alarmKey")
                // Even if metadata is missing, try to cancel with just the key
                val requestCode = alarmKey.hashCode()
                val intent = Intent(context, AlarmReceiver::class.java).apply {
                    action = AlarmReceiver.ACTION_ALARM_TRIGGER
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    requestCode,
                    intent,
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                )
                if (pendingIntent != null) {
                    alarmManager.cancel(pendingIntent)
                    pendingIntent.cancel()
                    Log.d(TAG, "Cancelled alarm by requestCode only: $requestCode")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel alarm: $alarmKey", e)
        }
    }private fun parseTimeToday(timeString: String): Long {
        val timeParts = timeString.split(":")
        if (timeParts.size != 2) return 0L

        val hour = timeParts[0].toIntOrNull() ?: return 0L
        val minute = timeParts[1].toIntOrNull() ?: return 0L

        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }    private fun saveAlarmMetadata(alarmList: List<AlarmMetadata>) {
        val jsonArray = JSONArray()
        alarmList.forEach { alarm ->
            val jsonObject = JSONObject().apply {
                put("key", alarm.key)
                put("category", alarm.category)
                put("subCategory", alarm.subCategory)
                put("recordTitle", alarm.recordTitle)
                put("scheduledDate", alarm.scheduledDate)  // NEW
                put("actualTime", alarm.actualTime)
                put("alarmType", alarm.alarmType)
                put("reminderTime", alarm.reminderTime)  // NEW
            }
            jsonArray.put(jsonObject)
        }
        prefs.edit().putString(ALARM_METADATA_KEY, jsonArray.toString()).apply()
    }private fun getStoredAlarmMetadata(): Map<String, AlarmMetadata> {
        val jsonString = prefs.getString(ALARM_METADATA_KEY, "[]") ?: "[]"
        val alarmMap = mutableMapOf<String, AlarmMetadata>()
        try {
            val jsonArray = JSONArray(jsonString)
            for (i in 0 until jsonArray.length()) {
                val jsonObject = jsonArray.getJSONObject(i)
                val alarm = AlarmMetadata(
                    key = jsonObject.getString("key"),
                    category = jsonObject.getString("category"),
                    subCategory = jsonObject.getString("subCategory"),
                    recordTitle = jsonObject.getString("recordTitle"),
                    scheduledDate = jsonObject.optString("scheduledDate", ""), // Handle old format
                    actualTime = jsonObject.getLong("actualTime"),
                    alarmType = jsonObject.getInt("alarmType"),
                    reminderTime = jsonObject.optString("reminderTime", "") // Handle old format
                )
                alarmMap[alarm.key] = alarm
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse alarm metadata", e)
        }
        
        return alarmMap
    }

    private fun dismissNotificationForRecord(category: String, subCategory: String, recordTitle: String) {
        try {
            val notificationId = (category + subCategory + recordTitle).hashCode()
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.cancel(notificationId)
            Log.d(TAG, "Dismissed notification for updated/deleted record: $recordTitle")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to dismiss notification for $recordTitle", e)
        }
    }    private fun cleanupOldAlarmMetadata() {
        val currentTime = System.currentTimeMillis()
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val currentAlarms = getStoredAlarmMetadata()

        val (validAlarms, expiredAlarms) = currentAlarms.values.partition { alarm ->
            // Only remove alarms that are truly expired (past date, not just past time)
            // This allows alarms scheduled for today to remain even if their time has passed
            // since they might still be valid in the comparison logic
            val dateValid = alarm.scheduledDate.isNotEmpty() && alarm.scheduledDate >= today
            
            dateValid
        }

        if (expiredAlarms.isNotEmpty()) {
            // Cancel expired alarms from AlarmManager before removing metadata
            expiredAlarms.forEach { alarm ->
                cancelAlarm(alarm.key)
                Log.d(TAG, "Cancelled expired alarm: ${alarm.recordTitle} on ${alarm.scheduledDate} (reason: past date)")
            }
            
            saveAlarmMetadata(validAlarms)
            Log.d(TAG, "Cleaned up ${expiredAlarms.size} expired alarm(s) by date, ${validAlarms.size} remaining")
        }
    }
}
