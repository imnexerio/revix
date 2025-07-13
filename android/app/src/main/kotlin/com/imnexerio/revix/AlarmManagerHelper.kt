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
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // Simplified alarm scheduling - just schedule based on provided data
    fun scheduleAlarmsForTwoDays(
        todayRecords: List<Map<String, Any>>,
        tomorrowRecords: List<Map<String, Any>>
    ) {
        Log.d(TAG, "Processing alarm scheduling with ${todayRecords.size} today + ${tomorrowRecords.size} tomorrow records")
        
        // Get current dates from the actual data
        val todayDate = getTodayDateFromRecords(todayRecords)
        val tomorrowDate = getTomorrowDateFromRecords(tomorrowRecords)

        Log.d(TAG, "Current data dates - Today: $todayDate, Tomorrow: $tomorrowDate")
        
        // Clean up old alarm metadata first
        cleanupOldAlarmMetadata()
        
        // Get current alarms AFTER cleanup
        val currentAlarms = getStoredAlarmMetadata()
        val newAlarmMetadata = mutableMapOf<String, AlarmMetadata>()
        
        // Process both days
        processDayRecords(todayRecords, todayDate, newAlarmMetadata)
        processDayRecords(tomorrowRecords, tomorrowDate, newAlarmMetadata)
        
        // Handle add/remove/update for current records
        handleAlarmUpdates(currentAlarms, newAlarmMetadata)
        
        // Save updated metadata
        saveAlarmMetadata(newAlarmMetadata.values.toList())
        
        Log.d(TAG, "Alarm scheduling completed. Active alarms: ${newAlarmMetadata.size}")
    }    private fun getTodayDateFromRecords(todayRecords: List<Map<String, Any>>): String {
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
        newAlarmMetadata: Map<String, AlarmMetadata>
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

    private fun cleanupOldAlarmMetadata() {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val currentAlarms = getStoredAlarmMetadata()
        
        val validAlarms = currentAlarms.values.filter { alarm =>
            alarm.scheduledDate.isEmpty() || alarm.scheduledDate >= today
        }
        
        if (validAlarms.size < currentAlarms.size) {
            saveAlarmMetadata(validAlarms)
            Log.d(TAG, "Cleaned up ${currentAlarms.size - validAlarms.size} old alarm metadata entries")
        }
    }
}
