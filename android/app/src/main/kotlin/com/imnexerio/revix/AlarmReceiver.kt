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
            }            ACTION_IGNORE_ALARM -> {
                Log.d(TAG, "Ignore alarm action received - could be from button tap or notification dismissal")
                handleIgnoreAlarm(context, intent)
            }
            ACTION_MANUAL_SNOOZE -> {
                Log.d(TAG, "Manual snooze action received - could be from button tap or notification dismissal")
                handleManualSnooze(context, intent)
            }
            "ACTION_SNOOZE_CHECK" -> {
                handleSnoozeCheck(context, intent)
            }
        }
    }    private fun handleUpcomingReminder(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""
        val alarmType = intent.getIntExtra(EXTRA_ALARM_TYPE, 0)
        val actualTime = intent.getLongExtra("ACTUAL_TIME", 0L)
        val isPreAlarm = intent.getBooleanExtra("IS_PRE_ALARM", false)
        val isSnooze = intent.getBooleanExtra("IS_SNOOZE", false)
        val snoozeCount = intent.getIntExtra("SNOOZE_COUNT", 0)

        Log.d(TAG, "Upcoming reminder triggered: $recordTitle (pre-alarm: $isPreAlarm, snooze: $isSnooze)")

        // EXECUTION-LEVEL DEDUPLICATION: Check if this alarm should trigger
        val alarmHelper = AlarmManagerHelper(context)
        val shouldTrigger = alarmHelper.shouldTriggerAlarm(category, subCategory, recordTitle, isPreAlarm)
        Log.d(TAG, "Should trigger check result: $shouldTrigger for $recordTitle (pre-alarm: $isPreAlarm)")
        
        if (!shouldTrigger) {
            Log.d(TAG, "Ignoring duplicate upcoming reminder trigger for $recordTitle (pre-alarm: $isPreAlarm)")
            return // Simply ignore - let existing notification continue as expected
        }

        // Show upcoming reminder notification
        Log.d(TAG, "Starting AlarmService for upcoming reminder: $recordTitle")
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra(EXTRA_ALARM_TYPE, 1) // Light notification for upcoming reminder
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
            putExtra("IS_UPCOMING_REMINDER", true)
            putExtra("IS_PRE_ALARM", isPreAlarm)
            putExtra("ACTUAL_TIME", actualTime)
            putExtra("IS_SNOOZE", isSnooze)
            putExtra("SNOOZE_COUNT", snoozeCount)
        }
        context.startForegroundService(serviceIntent)

        // Mark this alarm as active to prevent future duplicates
        alarmHelper.onAlarmTriggered(category, subCategory, recordTitle, isPreAlarm)
        Log.d(TAG, "Marked alarm as triggered: $recordTitle (pre-alarm: $isPreAlarm)")

        // NOTE: No longer automatically scheduling actual alarm here
        // Both pre-alarm and actual alarm are now scheduled independently in AlarmManagerHelper
    }
    private fun handleActualAlarm(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""
        val alarmType = intent.getIntExtra(EXTRA_ALARM_TYPE, 0)
        val snoozeCount = intent.getIntExtra("SNOOZE_COUNT", 0)
        val isSnooze = intent.getBooleanExtra("IS_SNOOZE", false)

        Log.d(TAG, "Actual alarm triggered: $recordTitle (snooze: $isSnooze, count: $snoozeCount)")

        // EXECUTION-LEVEL DEDUPLICATION: Check if this alarm should trigger
        val alarmHelper = AlarmManagerHelper(context)
        if (!alarmHelper.shouldTriggerAlarm(category, subCategory, recordTitle, false)) {
            Log.d(TAG, "Ignoring duplicate actual alarm trigger for $recordTitle")
            return // Simply ignore - let existing notification continue as expected
        }

        // Show the actual alarm notification
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra(EXTRA_ALARM_TYPE, alarmType)
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
            putExtra(EXTRA_DESCRIPTION, "It's time for your scheduled task")
            putExtra("IS_ACTUAL_ALARM", true)
            putExtra("IS_SNOOZE", isSnooze)
            putExtra("SNOOZE_COUNT", snoozeCount)
        }
        context.startForegroundService(serviceIntent)

        // Mark this alarm as active to prevent future duplicates
        alarmHelper.onAlarmTriggered(category, subCategory, recordTitle, false)
    }

    private fun handleMarkAsDone(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""
        val isPreAlarm = intent.getBooleanExtra("IS_PRE_ALARM", false)
        val isActualAlarm = intent.getBooleanExtra("IS_ACTUAL_ALARM", false)

        Log.d(TAG, "Mark as done triggered: $category - $subCategory - $recordTitle (pre-alarm: $isPreAlarm, actual-alarm: $isActualAlarm)")

        // Only stop alarm service if this is an actual alarm (with sound/vibration)
        if (isActualAlarm) {
            Log.d(TAG, "Stopping actual alarm sound/vibration for: $recordTitle")
            val stopAlarmIntent = Intent(context, AlarmService::class.java).apply {
                action = "STOP_SPECIFIC_ALARM"
                putExtra(EXTRA_CATEGORY, category)
                putExtra(EXTRA_SUB_CATEGORY, subCategory)
                putExtra(EXTRA_RECORD_TITLE, recordTitle)
            }
            context.startForegroundService(stopAlarmIntent)
        } else {
            Log.d(TAG, "Pre-alarm marked as done - no need to stop sound/vibration for: $recordTitle")
        }// Cancel all alarms for this record (both pre-alarm and actual alarm)
        val alarmHelper = AlarmManagerHelper(context)
        alarmHelper.cancelAlarmByRecord(category, subCategory, recordTitle)

        // Update alarm state: user marked as done
        alarmHelper.onUserActionTaken(category, subCategory, recordTitle, "done", isPreAlarm)

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
        
        if (isPreAlarm) {
            Log.d(TAG, "Task completed from pre-alarm, cancelled actual alarm too for: $recordTitle")
        } else {
            Log.d(TAG, "Task completed from actual alarm for: $recordTitle")
        }
    }    private fun handleIgnoreAlarm(context: Context, intent: Intent) {        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""
        val isActualAlarm = intent.getBooleanExtra("IS_ACTUAL_ALARM", false)
        val isPreAlarm = intent.getBooleanExtra("IS_PRE_ALARM", false)

        Log.d(TAG, "Ignore alarm triggered: $category - $subCategory - $recordTitle (actual: $isActualAlarm, pre-alarm: $isPreAlarm)")

        // Only stop alarm sound/vibration for actual alarms that might be playing sound
        // Pre-alarms are just light notifications and don't need foreground service to stop
        if (isActualAlarm && !isPreAlarm) {
            Log.d(TAG, "Stopping alarm sound/vibration for actual alarm: $recordTitle")
            val stopAlarmIntent = Intent(context, AlarmService::class.java).apply {
                action = "STOP_SPECIFIC_ALARM"
                putExtra(EXTRA_CATEGORY, category)
                putExtra(EXTRA_SUB_CATEGORY, subCategory)
                putExtra(EXTRA_RECORD_TITLE, recordTitle)
            }
            context.startForegroundService(stopAlarmIntent)
        } else {
            Log.d(TAG, "Pre-alarm ignore - no sound/vibration to stop for: $recordTitle")
        }

        // Dismiss the notification directly
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val notificationId = (category + subCategory + recordTitle).hashCode()
        notificationManager.cancel(notificationId)
        val alarmHelper = AlarmManagerHelper(context)

        // Update alarm state: user ignored
        alarmHelper.onUserActionTaken(category, subCategory, recordTitle, "ignore", isPreAlarm)

        // Handle different behavior based on alarm type
        if (isPreAlarm) {
            // For pre-alarms, ignore means dismiss notification only, let actual alarm proceed
            Log.d(TAG, "Pre-alarm ignored, actual alarm will still trigger for: $recordTitle")
        } else {
            // For actual alarms, ignore means cancel completely
            alarmHelper.cancelAlarmByRecord(category, subCategory, recordTitle)
            Log.d(TAG, "Actual alarm ignored and cancelled for: $recordTitle")
        }

            alarmHelper.scheduleSnoozeAlarm(category, subCategory, recordTitle, 1, 1) // Light notification
            Log.d(TAG, "Upcoming reminder ignored, scheduled as snooze for: $recordTitle")
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
        }        // Stop current alarm sound/vibration immediately
        // Manual snooze is typically for actual alarms that are playing sound/vibration
        Log.d(TAG, "Stopping alarm sound/vibration for snooze: $recordTitle")
        val stopAlarmIntent = Intent(context, AlarmService::class.java).apply {
            action = "STOP_SPECIFIC_ALARM"
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
        }
        context.startForegroundService(stopAlarmIntent)

        // Cancel current notification
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val notificationId = (category + subCategory + recordTitle).hashCode()
        notificationManager.cancel(notificationId)        // Schedule snooze alarm using the new alarm manager
        val alarmHelper = AlarmManagerHelper(context)
        
        // Update alarm state: user snoozed
        alarmHelper.onUserActionTaken(category, subCategory, recordTitle, "snooze", false) // Assuming snooze is from actual alarm
        
        alarmHelper.scheduleSnoozeAlarm(category, subCategory, recordTitle, alarmType, newSnoozeCount)

        Log.d(TAG, "Alarm stopped and snooze scheduled for $recordTitle")
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
