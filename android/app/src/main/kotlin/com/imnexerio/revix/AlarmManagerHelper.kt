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
    val alarmType: Int
)

class AlarmManagerHelper(private val context: Context) {
    companion object {
        private const val TAG = "AlarmManagerHelper"
        private const val PREFS_NAME = "record_alarms"
        private const val ALARM_METADATA_KEY = "alarm_metadata"
    }

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)    // Smart alarm scheduling - only update what actually changed
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
        val newAlarmMetadata = mutableMapOf<String, AlarmMetadata>()
        
        // Process both days to build new alarm set
        processDayRecords(todayRecords, todayDate, newAlarmMetadata)
        processDayRecords(tomorrowRecords, tomorrowDate, newAlarmMetadata)
        
        // Smart update: only change what's different
        handleSmartAlarmUpdates(currentAlarms, newAlarmMetadata)
        
        // Save updated metadata
        saveAlarmMetadata(newAlarmMetadata.values.toList())
        
        Log.d(TAG, "Smart alarm scheduling completed. Active alarms: ${newAlarmMetadata.size}")
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
    }

    private fun processDayRecords(
        records: List<Map<String, Any>>, 
        dateString: String,
        newAlarmMetadata: MutableMap<String, AlarmMetadata>
    ) {
        Log.d(TAG, "Processing ${records.size} records for $dateString")
        val currentTime = System.currentTimeMillis()

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

                // CRITICAL: Skip alarms that are in the past
                if (actualTime <= currentTime) {
                    Log.d(
                        TAG,
                        "SKIPPING PAST RECORD: $recordTitle on $scheduledDate at ${Date(actualTime)} (current: ${
                            Date(currentTime)
                        })"
                    )
                    return@forEach
                }

                val uniqueKey =
                    generateUniqueKeyWithDate(category, subCategory, recordTitle, scheduledDate)
                val newMetadata = AlarmMetadata(
                    key = uniqueKey,
                    category = category,
                    subCategory = subCategory,
                    recordTitle = recordTitle,
                    scheduledDate = scheduledDate,
                    actualTime = actualTime,
                    alarmType = alarmType
                )

                newAlarmMetadata[uniqueKey] = newMetadata
                Log.d(
                    TAG,
                    "ADDED FUTURE ALARM: $recordTitle on $scheduledDate at ${Date(actualTime)}"
                )

            } catch (e: Exception) {
                Log.e(TAG, "Error processing record for $dateString", e)
            }
        }
    }

    private fun handleSmartAlarmUpdates(
        currentAlarms: MutableMap<String, AlarmMetadata>,
        newAlarmMetadata: Map<String, AlarmMetadata>
    ) {
        var newCount = 0
        var updatedCount = 0
        var unchangedCount = 0
        var removedCount = 0
        
        // Process new/updated alarms
        newAlarmMetadata.values.forEach { newAlarm ->
            val existingAlarm = currentAlarms[newAlarm.key]
            
            when {
                existingAlarm == null -> {
                    // New alarm - schedule it
                    scheduleAlarm(newAlarm)
                    newCount++
                    Log.d(TAG, "NEW alarm: ${newAlarm.recordTitle} on ${newAlarm.scheduledDate}")
                }
                !alarmsAreEqual(existingAlarm, newAlarm) -> {
                    // Alarm changed - cancel old and schedule new
                    cancelAlarm(existingAlarm.key)
                    scheduleAlarm(newAlarm)
                    updatedCount++
                    Log.d(TAG, "UPDATED alarm: ${newAlarm.recordTitle} on ${newAlarm.scheduledDate}")
                    logAlarmChanges(existingAlarm, newAlarm)
                }
                else -> {
                    // Alarm unchanged - keep it
                    unchangedCount++
                    Log.d(TAG, "UNCHANGED alarm: ${newAlarm.recordTitle} on ${newAlarm.scheduledDate}")
                }
            }
        }

        // Remove alarms that are no longer in the new data
        val removedKeys = currentAlarms.keys.minus(newAlarmMetadata.keys)
        removedKeys.forEach { removedKey ->
            val removedAlarm = currentAlarms[removedKey]
            if (removedAlarm != null) {
                cancelAlarm(removedKey)
                removedCount++
                Log.d(TAG, "REMOVED alarm: ${removedAlarm.recordTitle} on ${removedAlarm.scheduledDate}")
            }
        }
        
        Log.d(TAG, "Smart update summary: $newCount new, $updatedCount updated, $unchangedCount unchanged, $removedCount removed")
    }

    private fun alarmsAreEqual(alarm1: AlarmMetadata, alarm2: AlarmMetadata): Boolean {
        return alarm1.actualTime == alarm2.actualTime &&
               alarm1.alarmType == alarm2.alarmType &&
               alarm1.category == alarm2.category &&
               alarm1.subCategory == alarm2.subCategory &&
               alarm1.recordTitle == alarm2.recordTitle &&
               alarm1.scheduledDate == alarm2.scheduledDate
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
        }.timeInMillis    }

    private fun scheduleAlarm(metadata: AlarmMetadata) {
        // CRITICAL: Check if alarm time is in the future before scheduling
        val currentTime = System.currentTimeMillis()
        if (metadata.actualTime <= currentTime) {
            Log.w(TAG, "SKIPPING PAST ALARM: ${metadata.recordTitle} on ${metadata.scheduledDate} at ${Date(metadata.actualTime)} (current time: ${Date(currentTime)})")
            return
        }
        
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_ALARM_TRIGGER
            putExtra(AlarmReceiver.EXTRA_CATEGORY, metadata.category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, metadata.subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, metadata.recordTitle)
            putExtra("scheduled_date", metadata.scheduledDate)
            putExtra(AlarmReceiver.EXTRA_ALARM_TYPE, metadata.alarmType)
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
    }

    // Efficient update for single record changes
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
        
        // CRITICAL: Check if alarm time is in the future
        val currentTime = System.currentTimeMillis()
        if (actualTime <= currentTime) {
            Log.w(TAG, "SKIPPING PAST ALARM UPDATE: $recordTitle on $scheduledDate at ${Date(actualTime)} (current: ${Date(currentTime)})")
            return
        }
        
        val uniqueKey = generateUniqueKeyWithDate(category, subCategory, recordTitle, scheduledDate)
        
        val newMetadata = AlarmMetadata(
            key = uniqueKey,
            category = category,
            subCategory = subCategory,
            recordTitle = recordTitle,
            scheduledDate = scheduledDate,
            actualTime = actualTime,
            alarmType = alarmType
        )
        
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
                    alarmType = jsonObject.getInt("alarmType")
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
            // More comprehensive expiry check:
            // 1. Check if scheduled date is valid and not in the past
            // 2. Check if actual alarm time hasn't passed yet
            val dateValid = alarm.scheduledDate.isNotEmpty() && alarm.scheduledDate >= today
            val timeValid = alarm.actualTime > currentTime
            
            dateValid && timeValid
        }

        if (expiredAlarms.isNotEmpty()) {
            // Cancel expired alarms from AlarmManager before removing metadata
            expiredAlarms.forEach { alarm ->
                cancelAlarm(alarm.key)
                Log.d(TAG, "Cancelled expired alarm: ${alarm.recordTitle} on ${alarm.scheduledDate} at ${Date(alarm.actualTime)} (reason: ${
                    when {
                        alarm.scheduledDate.isEmpty() || alarm.scheduledDate < today -> "past date"
                        alarm.actualTime <= currentTime -> "past time"
                        else -> "unknown"
                    }
                })")
            }
            
            saveAlarmMetadata(validAlarms)
            Log.d(TAG, "Cleaned up ${expiredAlarms.size} expired alarm(s), ${validAlarms.size} remaining")
        }
    }
}
