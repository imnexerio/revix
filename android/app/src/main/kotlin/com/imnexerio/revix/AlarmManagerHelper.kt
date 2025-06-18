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

class AlarmManagerHelper(private val context: Context) {
    companion object {
        private const val TAG = "AlarmManagerHelper"
        private const val PREFS_NAME = "record_alarms"
        private const val ACTIVE_ALARMS_KEY = "active_alarms"
        private const val REQUEST_CODE_BASE = 10000
    }

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun scheduleAlarmsForTodayRecords(todayRecords: List<Map<String, Any>>) {
        Log.d(TAG, "Scheduling alarms for ${todayRecords.size} today records")

        val newAlarmIds = mutableSetOf<String>()
        val currentDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

        todayRecords.forEach { record ->
            try {
                val category = record["category"]?.toString() ?: ""
                val subCategory = record["sub_category"]?.toString() ?: ""
                val recordTitle = record["record_title"]?.toString() ?: ""
                val reminderTime = record["reminder_time"]?.toString() ?: ""
                val alarmType = (record["alarm_type"]?.toString()?.toIntOrNull()) ?: 0
                val description = record["description"]?.toString() ?: ""
                val scheduledDate = record["scheduled_date"]?.toString() ?: ""

                Log.d(TAG, "Processing record: $recordTitle, Category: $category, SubCategory: $subCategory, Reminder: $reminderTime")
                Log.d(TAG, "Scheduled Date: $scheduledDate, Alarm Type: $alarmType")

                // Skip if no reminder or all day
                if (alarmType == 0 || reminderTime.lowercase() == "all day" || reminderTime.isEmpty()) {
                    Log.d(TAG, "Skipping alarm for $recordTitle - no reminder or all day")
                    return@forEach
                }

                // Only schedule alarms for today's records
                if (scheduledDate != currentDate) {
                    Log.d(TAG, "Skipping alarm for $recordTitle - not scheduled for today")
                    return@forEach
                }

                val alarmId = generateAlarmId(category, subCategory, recordTitle)
                val precheckAlarmId = generatePrecheckAlarmId(category, subCategory, recordTitle)

                // Parse time (format: HH:mm)
                val timeParts = reminderTime.split(":")
                if (timeParts.size != 2) {
                    Log.w(TAG, "Invalid time format for $recordTitle: $reminderTime")
                    return@forEach
                }

                val hour = timeParts[0].toIntOrNull() ?: return@forEach
                val minute = timeParts[1].toIntOrNull() ?: return@forEach

                // Create calendar instances for today with the specified time
                val alarmCalendar = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, hour)
                    set(Calendar.MINUTE, minute)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                val warningCalendar = Calendar.getInstance().apply {
                    timeInMillis = alarmCalendar.timeInMillis - (5 * 60 * 1000) // 5 minutes before
                }

                val now = System.currentTimeMillis()

                // Only schedule if the alarm time is in the future
                if (alarmCalendar.timeInMillis > now) {
                    // Schedule warning alarm (5 minutes before)
                    if (warningCalendar.timeInMillis > now) {
                        scheduleWarningAlarm(
                            precheckAlarmId,
                            warningCalendar.timeInMillis,
                            category,
                            subCategory,
                            recordTitle
                        )
                        newAlarmIds.add(precheckAlarmId)
                    }

                    // Schedule main alarm
                    scheduleMainAlarm(
                        alarmId,
                        alarmCalendar.timeInMillis,
                        category,
                        subCategory,
                        recordTitle,
                        description,
                        alarmType
                    )
                    newAlarmIds.add(alarmId)

                    Log.d(TAG, "Scheduled alarms for $recordTitle at ${alarmCalendar.time}")
                } else {
                    Log.d(TAG, "Skipping past alarm for $recordTitle")
                }

            } catch (e: Exception) {
                Log.e(TAG, "Error scheduling alarm for record", e)
            }
        }

        // Clean up old alarms that are no longer needed
        cleanupOldAlarms(newAlarmIds)

        // Save active alarm IDs
        saveActiveAlarms(newAlarmIds)
    }

    private fun scheduleMainAlarm(
        alarmId: String,
        triggerTime: Long,
        category: String,
        subCategory: String,
        recordTitle: String,
        description: String,
        alarmType: Int
    ) {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_RECORD_ALARM
            putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
            putExtra(AlarmReceiver.EXTRA_DESCRIPTION, description)
            putExtra(AlarmReceiver.EXTRA_ALARM_TYPE, alarmType)
            putExtra(AlarmReceiver.EXTRA_IS_PRECHECK, false)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarmId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        scheduleExactAlarm(triggerTime, pendingIntent)
    }    private fun scheduleWarningAlarm(
        warningAlarmId: String,
        triggerTime: Long,
        category: String,
        subCategory: String,
        recordTitle: String
    ) {        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_WARNING_NOTIFICATION
            putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
            putExtra(AlarmReceiver.EXTRA_IS_PRECHECK, true)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            warningAlarmId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        scheduleExactAlarm(triggerTime, pendingIntent)
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

    private fun cleanupOldAlarms(activeAlarmIds: Set<String>) {
        val previousAlarmIds = getActiveAlarms()
        val toRemove = previousAlarmIds - activeAlarmIds

        toRemove.forEach { alarmId ->
            cancelAlarm(alarmId)
        }

        if (toRemove.isNotEmpty()) {
            Log.d(TAG, "Cleaned up ${toRemove.size} old alarms")
        }
    }

    private fun cancelAlarm(alarmId: String) {
        try {
            val intent = Intent(context, AlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel alarm: $alarmId", e)
        }
    }

    fun cancelAllAlarms() {
        val activeAlarms = getActiveAlarms()
        activeAlarms.forEach { alarmId ->
            cancelAlarm(alarmId)
        }
        saveActiveAlarms(emptySet())
        Log.d(TAG, "Cancelled all ${activeAlarms.size} alarms")
    }

    private fun generateAlarmId(category: String, subCategory: String, recordTitle: String): String {
        return "alarm_${category}_${subCategory}_$recordTitle"
    }

    private fun generatePrecheckAlarmId(category: String, subCategory: String, recordTitle: String): String {
        return "precheck_${category}_${subCategory}_$recordTitle"
    }

    private fun saveActiveAlarms(alarmIds: Set<String>) {
        val jsonArray = JSONArray()
        alarmIds.forEach { jsonArray.put(it) }
        prefs.edit().putString(ACTIVE_ALARMS_KEY, jsonArray.toString()).apply()
    }

    private fun getActiveAlarms(): Set<String> {
        val jsonString = prefs.getString(ACTIVE_ALARMS_KEY, "[]") ?: "[]"
        val alarmIds = mutableSetOf<String>()
        
        try {
            val jsonArray = JSONArray(jsonString)
            for (i in 0 until jsonArray.length()) {
                alarmIds.add(jsonArray.getString(i))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse active alarms", e)
        }
        
        return alarmIds
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
}
