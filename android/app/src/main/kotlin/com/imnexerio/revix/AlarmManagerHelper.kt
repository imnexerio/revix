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
    val actualTime: Long,
    val alarmType: Int,
    val isSnoozeAlarm: Boolean = false,
    val snoozeCount: Int = 0
)

class AlarmManagerHelper(private val context: Context) {
    companion object {
        private const val TAG = "AlarmManagerHelper"
        private const val PREFS_NAME = "record_alarms"
        private const val ALARM_METADATA_KEY = "alarm_metadata"
        private const val REQUEST_CODE_BASE = 10000
    }

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun scheduleAlarmsForTodayRecords(todayRecords: List<Map<String, Any>>) {
        Log.d(TAG, "Processing ${todayRecords.size} today records with smart alarm management")

        // First, check for imminent alarms in new data and trigger them immediately
        checkAndTriggerImminentAlarms(todayRecords)

        val currentAlarms = getStoredAlarmMetadata()
        val newAlarmMetadata = mutableMapOf<String, AlarmMetadata>()
        val currentDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

        todayRecords.forEach { record ->
            try {
                val category = record["category"]?.toString() ?: ""
                val subCategory = record["sub_category"]?.toString() ?: ""
                val recordTitle = record["record_title"]?.toString() ?: ""
                val reminderTime = record["reminder_time"]?.toString() ?: ""
                val alarmType = (record["alarm_type"]?.toString()?.toIntOrNull()) ?: 0
                val scheduledDate = record["scheduled_date"]?.toString() ?: ""

                // Skip if no reminder or all day
                if (alarmType == 0 || reminderTime.lowercase() == "all day" || reminderTime.isEmpty()) {
                    return@forEach
                }

                // Only process today's records
                if (scheduledDate != currentDate) {
                    return@forEach
                }

                val uniqueKey = generateUniqueKey(category, subCategory, recordTitle)
                val actualTime = parseTimeToday(reminderTime)
                
                if (actualTime <= System.currentTimeMillis()) {
                    Log.d(TAG, "Skipping past alarm for $recordTitle")
                    return@forEach
                }

                val newMetadata = AlarmMetadata(
                    key = uniqueKey,
                    category = category,
                    subCategory = subCategory,
                    recordTitle = recordTitle,
                    actualTime = actualTime,
                    alarmType = alarmType
                )

                newAlarmMetadata[uniqueKey] = newMetadata

                val existingAlarm = currentAlarms[uniqueKey]
                when {
                    existingAlarm == null -> {
                        // New alarm - schedule it
                        scheduleUpcomingReminderAlarm(newMetadata)
                        Log.d(TAG, "Scheduled new alarm for $recordTitle")
                    }
                    existingAlarm.actualTime != actualTime -> {
                        // Time changed - update alarm
                        cancelAlarm(uniqueKey)
                        scheduleUpcomingReminderAlarm(newMetadata)
                        Log.d(TAG, "Updated alarm time for $recordTitle")
                    }
                    // else: No change needed
                }

            } catch (e: Exception) {
                Log.e(TAG, "Error processing record", e)
            }
        }

        // Handle snooze alarms - keep them unless their parent record is gone
        currentAlarms.values.filter { it.isSnoozeAlarm }.forEach { snoozeAlarm ->
            val parentKey = snoozeAlarm.key.substringBefore("_snooze_")
            if (newAlarmMetadata.containsKey(parentKey)) {
                // Parent record still exists, keep snooze alarm
                newAlarmMetadata[snoozeAlarm.key] = snoozeAlarm
            } else {
                // Parent record gone, cancel snooze alarm
                cancelAlarm(snoozeAlarm.key)
                Log.d(TAG, "Cancelled orphaned snooze alarm: ${snoozeAlarm.recordTitle}")
            }
        }

        // Cancel alarms for records that no longer exist
        currentAlarms.keys.minus(newAlarmMetadata.keys).forEach { obsoleteKey ->
            if (!currentAlarms[obsoleteKey]?.isSnoozeAlarm!!) { // Don't double-cancel snooze alarms
                cancelAlarm(obsoleteKey)
                Log.d(TAG, "Cancelled obsolete alarm: $obsoleteKey")
            }
        }

        // Save updated metadata
        saveAlarmMetadata(newAlarmMetadata.values.toList())
        Log.d(TAG, "Alarm management completed. Active alarms: ${newAlarmMetadata.size}")
    }

    private fun scheduleUpcomingReminderAlarm(metadata: AlarmMetadata) {
        val now = System.currentTimeMillis()
        val timeDiff = metadata.actualTime - now
        val fiveMinutes = 5 * 60 * 1000L

        val triggerTime = if (timeDiff <= fiveMinutes) {
            // Less than 5 minutes left - show upcoming reminder now
            now + 1000L // 1 second delay to ensure proper ordering
        } else {
            // Normal case - 5 minutes before actual time
            metadata.actualTime - fiveMinutes
        }

        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_UPCOMING_REMINDER
            putExtra(AlarmReceiver.EXTRA_CATEGORY, metadata.category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, metadata.subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, metadata.recordTitle)
            putExtra(AlarmReceiver.EXTRA_ALARM_TYPE, metadata.alarmType)
            putExtra("ACTUAL_TIME", metadata.actualTime)
            putExtra("IS_IMMEDIATE", timeDiff <= fiveMinutes)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            metadata.key.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        scheduleExactAlarm(triggerTime, pendingIntent)
        Log.d(TAG, "Scheduled upcoming reminder for ${metadata.recordTitle} at ${Date(triggerTime)}")
    }

    fun scheduleSnoozeAlarm(
        category: String,
        subCategory: String,
        recordTitle: String,
        alarmType: Int,
        snoozeCount: Int
    ) {
        val originalKey = generateUniqueKey(category, subCategory, recordTitle)
        val snoozeKey = "${originalKey}_snooze_${System.currentTimeMillis()}"
        val snoozeTime = System.currentTimeMillis() + (5 * 60 * 1000L) // 5 minutes from now

        val snoozeMetadata = AlarmMetadata(
            key = snoozeKey,
            category = category,
            subCategory = subCategory,
            recordTitle = recordTitle,
            actualTime = snoozeTime,
            alarmType = alarmType,
            isSnoozeAlarm = true,
            snoozeCount = snoozeCount
        )

        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_UPCOMING_REMINDER
            putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
            putExtra(AlarmReceiver.EXTRA_ALARM_TYPE, alarmType)
            putExtra("ACTUAL_TIME", snoozeTime)
            putExtra("IS_SNOOZE", true)
            putExtra("SNOOZE_COUNT", snoozeCount)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            snoozeKey.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        scheduleExactAlarm(snoozeTime, pendingIntent)
        
        // Add snooze alarm to metadata
        val currentMetadata = getStoredAlarmMetadata().toMutableMap()
        currentMetadata[snoozeKey] = snoozeMetadata
        saveAlarmMetadata(currentMetadata.values.toList())
        
        Log.d(TAG, "Scheduled snooze alarm for $recordTitle (count: $snoozeCount)")
    }

    fun cancelAlarmByRecord(category: String, subCategory: String, recordTitle: String) {
        val uniqueKey = generateUniqueKey(category, subCategory, recordTitle)
        val currentMetadata = getStoredAlarmMetadata().toMutableMap()
        
        // Cancel main alarm
        cancelAlarm(uniqueKey)
        currentMetadata.remove(uniqueKey)
        
        // Cancel any snooze alarms for this record
        val snoozeAlarmsToRemove = currentMetadata.keys.filter { 
            it.startsWith("${uniqueKey}_snooze_") 
        }
        snoozeAlarmsToRemove.forEach { snoozeKey ->
            cancelAlarm(snoozeKey)
            currentMetadata.remove(snoozeKey)
        }
        
        saveAlarmMetadata(currentMetadata.values.toList())
        Log.d(TAG, "Cancelled all alarms for record: $recordTitle")
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
    }

    private fun cancelAlarm(alarmKey: String) {
        try {
            val intent = Intent(context, AlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmKey.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel alarm: $alarmKey", e)
        }
    }

    fun cancelAllAlarms() {
        val currentMetadata = getStoredAlarmMetadata()
        currentMetadata.keys.forEach { alarmKey ->
            cancelAlarm(alarmKey)
        }
        saveAlarmMetadata(emptyList())
        Log.d(TAG, "Cancelled all ${currentMetadata.size} alarms")
    }

    private fun generateUniqueKey(category: String, subCategory: String, recordTitle: String): String {
        return "${category}_${subCategory}_${recordTitle}".hashCode().toString()
    }

    private fun parseTimeToday(timeString: String): Long {
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
    }

    private fun saveAlarmMetadata(alarmList: List<AlarmMetadata>) {
        val jsonArray = JSONArray()
        alarmList.forEach { alarm ->
            val jsonObject = JSONObject().apply {
                put("key", alarm.key)
                put("category", alarm.category)
                put("subCategory", alarm.subCategory)
                put("recordTitle", alarm.recordTitle)
                put("actualTime", alarm.actualTime)
                put("alarmType", alarm.alarmType)
                put("isSnoozeAlarm", alarm.isSnoozeAlarm)
                put("snoozeCount", alarm.snoozeCount)
            }
            jsonArray.put(jsonObject)
        }
        prefs.edit().putString(ALARM_METADATA_KEY, jsonArray.toString()).apply()
    }

    private fun getStoredAlarmMetadata(): Map<String, AlarmMetadata> {
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
                    actualTime = jsonObject.getLong("actualTime"),
                    alarmType = jsonObject.getInt("alarmType"),
                    isSnoozeAlarm = jsonObject.optBoolean("isSnoozeAlarm", false),
                    snoozeCount = jsonObject.optInt("snoozeCount", 0)
                )
                alarmMap[alarm.key] = alarm
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse alarm metadata", e)
        }
        
        return alarmMap
    }

    fun requestExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                val intent = Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(intent)
            }
        }
    }

    private fun checkAndTriggerImminentAlarms(todayRecords: List<Map<String, Any>>) {
        val currentTime = System.currentTimeMillis()
        val fiveMinutes = 5 * 60 * 1000L
        val currentDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

        todayRecords.forEach { record ->
            try {
                val category = record["category"]?.toString() ?: ""
                val subCategory = record["sub_category"]?.toString() ?: ""
                val recordTitle = record["record_title"]?.toString() ?: ""
                val reminderTime = record["reminder_time"]?.toString() ?: ""
                val alarmType = (record["alarm_type"]?.toString()?.toIntOrNull()) ?: 0
                val scheduledDate = record["scheduled_date"]?.toString() ?: ""

                // Skip if no reminder, all day, or not today's record
                if (alarmType == 0 || reminderTime.lowercase() == "all day" || 
                    reminderTime.isEmpty() || scheduledDate != currentDate) {
                    return@forEach
                }

                val actualTime = parseTimeToday(reminderTime)
                if (actualTime <= 0) return@forEach
                val timeUntilAlarm = actualTime - currentTime

                // Check if alarm should be triggered immediately
                when {
                    timeUntilAlarm <= 0 -> {
                        // Alarm time has passed - ignore it (no sense storing past alarms)
                        Log.d(TAG, "Ignoring past alarm for $recordTitle")
                        return@forEach
                    }
                    timeUntilAlarm <= fiveMinutes -> {
                        // Less than 5 minutes - show upcoming reminder immediately
                        Log.d(TAG, "Triggering immediate upcoming reminder for $recordTitle (${timeUntilAlarm/60000} min left)")
                        triggerUpcomingReminder(category, subCategory, recordTitle, alarmType, actualTime, timeUntilAlarm)
                    }
                    // If > 5 minutes, normal scheduling will handle it
                }

            } catch (e: Exception) {
                Log.e(TAG, "Error checking imminent alarm for record", e)
            }
        }
    }    private fun triggerUpcomingReminder(
        category: String, 
        subCategory: String, 
        recordTitle: String, 
        alarmType: Int, 
        actualTime: Long, 
        timeUntilAlarm: Long
    ) {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_UPCOMING_REMINDER
            putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
            putExtra(AlarmReceiver.EXTRA_ALARM_TYPE, alarmType)
            putExtra("ACTUAL_TIME", actualTime)
            putExtra("IS_IMMEDIATE", true)
            putExtra("IS_SNOOZE", false)
            putExtra("SNOOZE_COUNT", 0)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            System.currentTimeMillis().toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Trigger immediately
        try {
            pendingIntent.send()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to trigger upcoming reminder", e)
        }
    }

    // ...existing code...
}
