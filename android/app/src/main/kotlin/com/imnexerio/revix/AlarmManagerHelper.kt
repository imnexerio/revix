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
        private const val LAST_PROCESSED_DATES_KEY = "last_processed_dates"  // NEW
    }

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    fun scheduleAlarmsForTodayRecords(todayRecords: List<Map<String, Any>>) {
        Log.d(TAG, "Processing ${todayRecords.size} today records with simplified alarm management")

        val currentAlarms = getStoredAlarmMetadata()
        val newAlarmMetadata = mutableMapOf<String, AlarmMetadata>()
        val currentDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val currentTimeHHMM = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())

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
                val alarmTimeHHMM = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(actualTime))
                
                // Skip past alarms using HH:mm comparison
                if (alarmTimeHHMM <= currentTimeHHMM) {
                    Log.d(TAG, "Skipping past alarm for $recordTitle (alarm: $alarmTimeHHMM, current: $currentTimeHHMM)")
                    return@forEach
                }

                val newMetadata = AlarmMetadata(
                    key = uniqueKey,
                    category = category,
                    subCategory = subCategory,
                    recordTitle = recordTitle,
                    scheduledDate = scheduledDate,  // FIX: Add missing parameter
                    actualTime = actualTime,
                    alarmType = alarmType
                )

                newAlarmMetadata[uniqueKey] = newMetadata
                val existingAlarm = currentAlarms[uniqueKey]
                
                when {
                    existingAlarm == null -> {
                        // New alarm - schedule it
                        scheduleAlarm(newMetadata)
                        Log.d(TAG, "Scheduled new alarm for $recordTitle at $alarmTimeHHMM")
                    }
                    existingAlarm.actualTime != actualTime -> {
                        // Time changed - cancel old and reschedule
                        Log.d(TAG, "Time changed for $recordTitle, rescheduling")
                        
                        // Dismiss any active notification for this record
                        dismissNotificationForRecord(category, subCategory, recordTitle)
                        
                        // Cancel old alarm
                        cancelAlarm(uniqueKey)
                        
                        // Schedule new alarm
                        scheduleAlarm(newMetadata)
                        Log.d(TAG, "Updated alarm time for $recordTitle to $alarmTimeHHMM")
                    }
                    // else: No change needed
                }

            } catch (e: Exception) {
                Log.e(TAG, "Error processing record", e)
            }
        }

        // Cancel alarms for records that no longer exist
        currentAlarms.keys.minus(newAlarmMetadata.keys).forEach { obsoleteKey ->
            val obsoleteAlarm = currentAlarms[obsoleteKey]
            if (obsoleteAlarm != null) {
                // Dismiss any active notification for deleted record
                dismissNotificationForRecord(obsoleteAlarm.category, obsoleteAlarm.subCategory, obsoleteAlarm.recordTitle)
                
                // Cancel scheduled alarm
                cancelAlarm(obsoleteKey)
                Log.d(TAG, "Cancelled obsolete alarm: ${obsoleteAlarm.recordTitle}")
            }
        }

        // Save updated metadata
        saveAlarmMetadata(newAlarmMetadata.values.toList())
          Log.d(TAG, "Alarm management completed. Active alarms: ${newAlarmMetadata.size}")
    }

    // NEW METHOD: Enhanced two-day alarm scheduling with date-based cleanup
    fun scheduleAlarmsForTwoDays(
        todayRecords: List<Map<String, Any>>,
        tomorrowRecords: List<Map<String, Any>>
    ) {
        Log.d(TAG, "Processing two-day alarm scheduling with ${todayRecords.size} today + ${tomorrowRecords.size} tomorrow records")
        
        // Get current dates from the actual data
        val todayDate = getTodayDateFromRecords(todayRecords)
        val tomorrowDate = getTomorrowDateFromRecords(tomorrowRecords)
        
        Log.d(TAG, "Current data dates - Today: $todayDate, Tomorrow: $tomorrowDate")
        
        // Check if dates changed from last processing
        val lastProcessedDates = getLastProcessedDates()
        val datesChanged = lastProcessedDates != "$todayDate,$tomorrowDate"
        
        if (datesChanged) {
            Log.d(TAG, "Date change detected! Last: $lastProcessedDates, Current: $todayDate,$tomorrowDate")
            cleanupOldDateAlarms(todayDate, tomorrowDate)
            saveLastProcessedDates(todayDate, tomorrowDate)
        }

        val currentAlarms = getStoredAlarmMetadata()
        val newAlarmMetadata = mutableMapOf<String, AlarmMetadata>()
        val currentTimeMillis = System.currentTimeMillis()
        
        // Process both days
        processDayRecords(todayRecords, todayDate, newAlarmMetadata, currentTimeMillis)
        processDayRecords(tomorrowRecords, tomorrowDate, newAlarmMetadata, currentTimeMillis)
        
        // Handle add/remove/update for current date window
        handleAlarmUpdates(currentAlarms, newAlarmMetadata, currentTimeMillis)
        
        // Save updated metadata
        saveAlarmMetadata(newAlarmMetadata.values.toList())
        
        Log.d(TAG, "Two-day alarm management completed. Active alarms: ${newAlarmMetadata.size}")
    }

    private fun getTodayDateFromRecords(todayRecords: List<Map<String, Any>>): String {
        return todayRecords.firstOrNull()?.get("scheduled_date")?.toString()
            ?: SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
    }

    private fun getTomorrowDateFromRecords(tomorrowRecords: List<Map<String, Any>>): String {
        return tomorrowRecords.firstOrNull()?.get("scheduled_date")?.toString()
            ?: SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(
                Date(System.currentTimeMillis() + 24 * 60 * 60 * 1000)
            )
    }

    private fun getLastProcessedDates(): String {
        return prefs.getString(LAST_PROCESSED_DATES_KEY, "") ?: ""
    }

    private fun saveLastProcessedDates(todayDate: String, tomorrowDate: String) {
        prefs.edit().putString(LAST_PROCESSED_DATES_KEY, "$todayDate,$tomorrowDate").apply()
    }

    private fun cleanupOldDateAlarms(currentTodayDate: String, currentTomorrowDate: String) {
        Log.d(TAG, "Cleaning up alarms outside current date window")
        
        val currentAlarms = getStoredAlarmMetadata()
        val validDates = setOf(currentTodayDate, currentTomorrowDate)
        
        val oldAlarms = currentAlarms.values.filter { alarm ->
            alarm.scheduledDate.isNotEmpty() && alarm.scheduledDate !in validDates
        }
        
        oldAlarms.forEach { oldAlarm ->
            Log.d(TAG, "Removing outdated alarm: ${oldAlarm.recordTitle} on ${oldAlarm.scheduledDate}")
            cancelAlarm(oldAlarm.key)
        }
        
        // Remove old alarms from storage
        val remainingAlarms = currentAlarms.values.filter { alarm ->
            alarm.scheduledDate.isEmpty() || alarm.scheduledDate in validDates
        }
        saveAlarmMetadata(remainingAlarms)
        
        Log.d(TAG, "Cleaned up ${oldAlarms.size} outdated alarms")
    }

    private fun processDayRecords(
        records: List<Map<String, Any>>, 
        dateString: String,
        newAlarmMetadata: MutableMap<String, AlarmMetadata>,
        currentTimeMillis: Long
    ) {
        val currentTimeHHMM = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
        val currentDateString = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val isToday = dateString == currentDateString
        
        Log.d(TAG, "Processing ${records.size} records for $dateString (isToday: $isToday)")
        
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
                val alarmTimeHHMM = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(actualTime))
                
                if (isToday && alarmTimeHHMM <= currentTimeHHMM) {
                    Log.d(TAG, "Skipping past alarm for $recordTitle (alarm: $alarmTimeHHMM, current: $currentTimeHHMM)")
                    return@forEach
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
                
                newAlarmMetadata[uniqueKey] = newMetadata
                
            } catch (e: Exception) {
                Log.e(TAG, "Error processing record for $dateString", e)
            }
        }
    }

    private fun handleAlarmUpdates(
        currentAlarms: Map<String, AlarmMetadata>,
        newAlarmMetadata: Map<String, AlarmMetadata>,
        currentTimeMillis: Long
    ) {
        newAlarmMetadata.values.forEach { newAlarm ->
            val existingAlarm = currentAlarms[newAlarm.key]
            
            when {
                existingAlarm == null -> {
                    scheduleAlarm(newAlarm)
                    Log.d(TAG, "Scheduled NEW alarm: ${newAlarm.recordTitle} on ${newAlarm.scheduledDate}")
                }
                existingAlarm.actualTime != newAlarm.actualTime -> {
                    cancelAlarm(existingAlarm.key)
                    scheduleAlarm(newAlarm)
                    Log.d(TAG, "Updated alarm time: ${newAlarm.recordTitle} on ${newAlarm.scheduledDate}")
                }
            }
        }

        currentAlarms.keys.minus(newAlarmMetadata.keys).forEach { removedKey ->
            val removedAlarm = currentAlarms[removedKey]
            if (removedAlarm != null) {
                cancelAlarm(removedKey)
                Log.d(TAG, "Cancelled REMOVED alarm: ${removedAlarm.recordTitle}")
            }
        }
    }

    private fun generateUniqueKeyWithDate(
        category: String, 
        subCategory: String, 
        recordTitle: String, 
        scheduledDate: String
    ): String {
        return "${category}_${subCategory}_${recordTitle}_${scheduledDate}".hashCode().toString()
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
        }.timeInMillis    }private fun scheduleAlarm(metadata: AlarmMetadata) {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_ALARM_TRIGGER
            putExtra(AlarmReceiver.EXTRA_CATEGORY, metadata.category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, metadata.subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, metadata.recordTitle)
            putExtra("scheduled_date", metadata.scheduledDate)  // NEW
            putExtra(AlarmReceiver.EXTRA_ALARM_TYPE, metadata.alarmType)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            metadata.key.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        scheduleExactAlarm(metadata.actualTime, pendingIntent)
        
        Log.d(TAG, "Scheduled alarm for ${metadata.recordTitle} on ${metadata.scheduledDate} at ${Date(metadata.actualTime)}")
    }fun cancelAlarmByRecord(category: String, subCategory: String, recordTitle: String) {
        val uniqueKey = generateUniqueKey(category, subCategory, recordTitle)
        val currentMetadata = getStoredAlarmMetadata().toMutableMap()
        
        // Cancel alarm
        cancelAlarm(uniqueKey)
        currentMetadata.remove(uniqueKey)
        
        saveAlarmMetadata(currentMetadata.values.toList())
        Log.d(TAG, "Cancelled alarm for record: $recordTitle")
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
    }
}
