package com.imnexerio.revix

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_RECORD_ALARM = "revix.ACTION_RECORD_ALARM"
        const val ACTION_WARNING_NOTIFICATION = "revix.ACTION_WARNING_NOTIFICATION"
        const val ACTION_UPCOMING_REMINDER = "revix.ACTION_UPCOMING_REMINDER"
        const val ACTION_ACTUAL_ALARM = "revix.ACTION_ACTUAL_ALARM"
        const val ACTION_MARK_AS_DONE = "MARK_AS_DONE"
        const val ACTION_IGNORE_ALARM = "IGNORE_ALARM"
        const val ACTION_MANUAL_SNOOZE = "MANUAL_SNOOZE"
        const val EXTRA_ALARM_TYPE = "alarm_type"
        const val EXTRA_CATEGORY = "category"
        const val EXTRA_SUB_CATEGORY = "sub_category"
        const val EXTRA_RECORD_TITLE = "record_title"
        const val EXTRA_DESCRIPTION = "description"
        const val EXTRA_IS_PRECHECK = "is_precheck"
        private const val TAG = "AlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "AlarmReceiver triggered with action: ${intent.action}")
        when (intent.action) {
            ACTION_RECORD_ALARM -> {
                handleRecordAlarm(context, intent)
            }
            ACTION_WARNING_NOTIFICATION -> {
                handleWarningNotification(context, intent)
            }
            ACTION_UPCOMING_REMINDER -> {
                handleUpcomingReminder(context, intent)
            }
            ACTION_ACTUAL_ALARM -> {
                handleActualAlarm(context, intent)
            }
            ACTION_MARK_AS_DONE -> {
                handleMarkAsDone(context, intent)
            }
            ACTION_IGNORE_ALARM -> {
                handleIgnoreAlarm(context, intent)
            }
            ACTION_MANUAL_SNOOZE -> {
                handleManualSnooze(context, intent)
            }
            "ACTION_SNOOZE_CHECK" -> {
                handleSnoozeCheck(context, intent)
            }
        }
    }

    private fun handleUpcomingReminder(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""
        val alarmType = intent.getIntExtra(EXTRA_ALARM_TYPE, 0)
        val actualTime = intent.getLongExtra("ACTUAL_TIME", 0L)
        val isImmediate = intent.getBooleanExtra("IS_IMMEDIATE", false)
        val isSnooze = intent.getBooleanExtra("IS_SNOOZE", false)
        val snoozeCount = intent.getIntExtra("SNOOZE_COUNT", 0)

        Log.d(TAG, "Upcoming reminder triggered: $recordTitle (immediate: $isImmediate, snooze: $isSnooze)")

        // Show upcoming reminder notification
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra(EXTRA_ALARM_TYPE, 1) // Light notification for upcoming reminder
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
            putExtra("IS_UPCOMING_REMINDER", true)
            putExtra("ACTUAL_TIME", actualTime)
            putExtra("IS_SNOOZE", isSnooze)
            putExtra("SNOOZE_COUNT", snoozeCount)
        }
        context.startForegroundService(serviceIntent)

        // Schedule the actual alarm if not immediate
        if (!isImmediate) {
            scheduleActualAlarm(context, category, subCategory, recordTitle, alarmType, actualTime, snoozeCount)
        }
    }

    private fun scheduleActualAlarm(
        context: Context,
        category: String,
        subCategory: String,
        recordTitle: String,
        alarmType: Int,
        actualTime: Long,
        snoozeCount: Int
    ) {
        val actualAlarmIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_ACTUAL_ALARM
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
            putExtra(EXTRA_ALARM_TYPE, alarmType)
            putExtra("SNOOZE_COUNT", snoozeCount)
        }

        val actualPendingIntent = android.app.PendingIntent.getBroadcast(
            context,
            ("actual_${category}_${subCategory}_${recordTitle}_${snoozeCount}").hashCode(),
            actualAlarmIntent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    android.app.AlarmManager.RTC_WAKEUP,
                    actualTime,
                    actualPendingIntent
                )
            } else {
                alarmManager.setExact(android.app.AlarmManager.RTC_WAKEUP, actualTime, actualPendingIntent)
            }
            Log.d(TAG, "Scheduled actual alarm for $recordTitle at ${java.util.Date(actualTime)}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule actual alarm", e)
        }
    }

    private fun handleActualAlarm(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""
        val alarmType = intent.getIntExtra(EXTRA_ALARM_TYPE, 0)
        val snoozeCount = intent.getIntExtra("SNOOZE_COUNT", 0)

        Log.d(TAG, "Actual alarm triggered: $recordTitle")

        // Show the actual alarm notification
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra(EXTRA_ALARM_TYPE, alarmType)
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
            putExtra(EXTRA_DESCRIPTION, "It's time for your scheduled task")
            putExtra("IS_ACTUAL_ALARM", true)
            putExtra("SNOOZE_COUNT", snoozeCount)
        }
        context.startForegroundService(serviceIntent)
    }

    private fun handleMarkAsDone(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""

        Log.d(TAG, "Mark as done triggered: $category - $subCategory - $recordTitle")

        // Cancel all alarms for this record using the new alarm manager
        val alarmHelper = AlarmManagerHelper(context)
        alarmHelper.cancelAlarmByRecord(category, subCategory, recordTitle)

        // Dismiss the current notification
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val notificationId = (category + subCategory + recordTitle).hashCode()
        notificationManager.cancel(notificationId)

        // Let RecordUpdateService handle the database update
        val serviceIntent = Intent(context, RecordUpdateService::class.java).apply {
            putExtra("category", category)
            putExtra("sub_category", subCategory)
            putExtra("record_title", recordTitle)
        }
        context.startService(serviceIntent)
        
        Log.d(TAG, "All alarms cancelled and RecordUpdateService started for: $recordTitle")
    }

    private fun handleIgnoreAlarm(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""

        Log.d(TAG, "Ignore alarm triggered: $category - $subCategory - $recordTitle")

        // Cancel any pending snooze alarms for this record
        cancelSnoozeAlarms(context, category, subCategory, recordTitle)

        // Just dismiss the notification - no need to mark as done or trigger callbacks
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val notificationId = (category + subCategory + recordTitle).hashCode()
        notificationManager.cancel(notificationId)
          Log.d(TAG, "Alarm ignored and notification dismissed for: $recordTitle")
    }

    private fun handleManualSnooze(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""
        val alarmType = intent.getIntExtra(EXTRA_ALARM_TYPE, 0)
        val currentSnoozeCount = intent.getIntExtra("SNOOZE_COUNT", 0)
        val newSnoozeCount = currentSnoozeCount + 1

        Log.d(TAG, "Manual snooze triggered: $recordTitle (snooze #$newSnoozeCount)")

        // Check snooze limit
        if (newSnoozeCount > 6) {
            Log.d(TAG, "Maximum snooze limit reached for $recordTitle")
            return
        }

        // Cancel current notification
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val notificationId = (category + subCategory + recordTitle).hashCode()
        notificationManager.cancel(notificationId)

        // Schedule snooze alarm using the new alarm manager
        val alarmHelper = AlarmManagerHelper(context)
        alarmHelper.scheduleSnoozeAlarm(category, subCategory, recordTitle, alarmType, newSnoozeCount)

        Log.d(TAG, "Snooze alarm scheduled for $recordTitle")
    }
    // Legacy handler for backward compatibility
    private fun handleRecordAlarm(context: Context, intent: Intent) {
        val alarmType = intent.getIntExtra(EXTRA_ALARM_TYPE, 0)
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""
        val description = intent.getStringExtra(EXTRA_DESCRIPTION) ?: ""
        val isPrecheck = intent.getBooleanExtra(EXTRA_IS_PRECHECK, false)

        Log.d(TAG, "Legacy record alarm triggered: $recordTitle")

        // Start the alarm service to handle the notification/alarm
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra(EXTRA_ALARM_TYPE, alarmType)
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
            putExtra(EXTRA_DESCRIPTION, description)
            putExtra(EXTRA_IS_PRECHECK, isPrecheck)
        }
        
        context.startForegroundService(serviceIntent)
    }

    // Legacy handler for backward compatibility  
    private fun handleWarningNotification(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""

        Log.d(TAG, "Legacy warning notification triggered: $recordTitle")

        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra(EXTRA_ALARM_TYPE, 1)
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
            putExtra(EXTRA_DESCRIPTION, "Upcoming reminder in 5 minutes")
            putExtra(EXTRA_IS_PRECHECK, true)
            putExtra("IS_WARNING", true)
        }
        
        context.startForegroundService(serviceIntent)
    }

    private fun triggerWidgetRefresh(context: Context) {
        try {
            val uri = android.net.Uri.parse("homeWidget://widget_refresh")
            val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                context,
                uri
            )
            backgroundIntent.send()
            Log.d(TAG, "Widget refresh triggered")
        } catch (e: Exception) {
            Log.e(TAG, "Error triggering widget refresh: ${e.message}")
        }
    }

    // Legacy handler for backward compatibility
    private fun handleSnoozeCheck(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""
        val description = intent.getStringExtra(EXTRA_DESCRIPTION) ?: ""
        val alarmType = intent.getIntExtra(EXTRA_ALARM_TYPE, 0)
        val snoozeCount = intent.getIntExtra("SNOOZE_COUNT", 1)

        Log.d(TAG, "Legacy snooze check triggered: $recordTitle")

        if (snoozeCount >= 6) {
            Log.d(TAG, "Maximum snooze limit reached for $recordTitle")
            return
        }
        
        // Use new snooze system
        val alarmHelper = AlarmManagerHelper(context)
        alarmHelper.scheduleSnoozeAlarm(category, subCategory, recordTitle, alarmType, snoozeCount)
    }

}
