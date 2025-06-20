package com.imnexerio.revix

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {    companion object {
        const val ACTION_ALARM_TRIGGER = "revix.ACTION_ALARM_TRIGGER"
        const val ACTION_MARK_AS_DONE = "MARK_AS_DONE"
        const val ACTION_IGNORE_ALARM = "IGNORE_ALARM"
        const val EXTRA_ALARM_TYPE = "alarm_type"
        const val EXTRA_CATEGORY = "category"
        const val EXTRA_SUB_CATEGORY = "sub_category"
        const val EXTRA_RECORD_TITLE = "record_title"
        private const val TAG = "AlarmReceiver"
    }    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "AlarmReceiver triggered with action: ${intent.action}")
        when (intent.action) {
            ACTION_ALARM_TRIGGER -> {
                handleAlarmTrigger(context, intent)
            }
            ACTION_MARK_AS_DONE -> {
                handleMarkAsDone(context, intent)
            }
            ACTION_IGNORE_ALARM -> {
                handleIgnoreAlarm(context, intent)
            }
        }
    }    private fun handleAlarmTrigger(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""
        val alarmType = intent.getIntExtra(EXTRA_ALARM_TYPE, 0)

        Log.d(TAG, "Alarm triggered: $recordTitle (type: $alarmType)")

        // Start the alarm service to handle the alarm behavior
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra(EXTRA_ALARM_TYPE, alarmType)
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
        }
        context.startForegroundService(serviceIntent)
    }    private fun handleMarkAsDone(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""

        Log.d(TAG, "Mark as done triggered: $category - $subCategory - $recordTitle")

        // Try to stop alarm service if it's still running (for active alarms)
        try {
            val stopAlarmIntent = Intent(context, AlarmService::class.java).apply {
                action = "STOP_SPECIFIC_ALARM"
                putExtra(EXTRA_CATEGORY, category)
                putExtra(EXTRA_SUB_CATEGORY, subCategory)
                putExtra(EXTRA_RECORD_TITLE, recordTitle)
            }
            context.startForegroundService(stopAlarmIntent)
        } catch (e: Exception) {
            Log.d(TAG, "Service not running, handling directly: ${e.message}")
        }

        // Cancel all future alarms for this record
        val alarmHelper = AlarmManagerHelper(context)
        alarmHelper.cancelAlarmByRecord(category, subCategory, recordTitle)

        // Dismiss the notification
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val notificationId = (category + subCategory + recordTitle).hashCode()
        notificationManager.cancel(notificationId)

        // Update the database
        val serviceIntent = Intent(context, RecordUpdateService::class.java).apply {
            putExtra("category", category)
            putExtra("sub_category", subCategory)
            putExtra("record_title", recordTitle)
        }
        context.startService(serviceIntent)
        
        Log.d(TAG, "Task completed for: $recordTitle")
    }    private fun handleIgnoreAlarm(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""

        Log.d(TAG, "Ignore alarm triggered: $category - $subCategory - $recordTitle")

        // Try to stop alarm service if it's still running (for active alarms)
        try {
            val stopAlarmIntent = Intent(context, AlarmService::class.java).apply {
                action = "STOP_SPECIFIC_ALARM"
                putExtra(EXTRA_CATEGORY, category)
                putExtra(EXTRA_SUB_CATEGORY, subCategory)
                putExtra(EXTRA_RECORD_TITLE, recordTitle)
            }
            context.startForegroundService(stopAlarmIntent)
        } catch (e: Exception) {
            Log.d(TAG, "Service not running, handling directly: ${e.message}")
        }

        // Dismiss the notification
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val notificationId = (category + subCategory + recordTitle).hashCode()
        notificationManager.cancel(notificationId)

        // Cancel alarm to prevent it from triggering again
        val alarmHelper = AlarmManagerHelper(context)
        alarmHelper.cancelAlarmByRecord(category, subCategory, recordTitle)

        Log.d(TAG, "Alarm ignored and cancelled for: $recordTitle")
    }
}
