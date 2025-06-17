package com.imnexerio.revix

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {    companion object {
        const val ACTION_RECORD_ALARM = "revix.ACTION_RECORD_ALARM"
        const val ACTION_RECORD_PRECHECK = "revix.ACTION_RECORD_PRECHECK"
        const val ACTION_MARK_AS_DONE = "MARK_AS_DONE"
        const val ACTION_IGNORE_ALARM = "IGNORE_ALARM"
        const val ACTION_MANUAL_SNOOZE = "MANUAL_SNOOZE"
        const val EXTRA_RECORD_DATA = "record_data"
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
            ACTION_RECORD_PRECHECK -> {
                handleRecordPrecheck(context, intent)
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
            Intent.ACTION_BOOT_COMPLETED -> {
                handleBootCompleted(context)
            }
        }
    }

    private fun handleRecordAlarm(context: Context, intent: Intent) {
        val alarmType = intent.getIntExtra(EXTRA_ALARM_TYPE, 0)
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""
        val description = intent.getStringExtra(EXTRA_DESCRIPTION) ?: ""
        val isPrecheck = intent.getBooleanExtra(EXTRA_IS_PRECHECK, false)

        Log.d(TAG, "Record alarm triggered: $category - $subCategory - $recordTitle (Type: $alarmType, Precheck: $isPrecheck)")

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

    private fun handleRecordPrecheck(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""

        Log.d(TAG, "Record precheck triggered: $category - $subCategory - $recordTitle")

        // Trigger data refresh to check if record is still pending
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            action = "PRECHECK_RECORD_STATUS"
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
        }
        
        context.startForegroundService(serviceIntent)
    }

    private fun handleMarkAsDone(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""

        Log.d(TAG, "Mark as done triggered: $category - $subCategory - $recordTitle")

        // Trigger mark as done through Flutter background callback
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            action = "MARK_AS_DONE"
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
        }
          context.startForegroundService(serviceIntent)
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
        val description = intent.getStringExtra(EXTRA_DESCRIPTION) ?: ""
        val alarmType = intent.getIntExtra(EXTRA_ALARM_TYPE, 0)
        val snoozeCount = intent.getIntExtra("SNOOZE_COUNT", 1)

        Log.d(TAG, "Manual snooze triggered: $category - $subCategory - $recordTitle (Snooze #$snoozeCount)")

        // Cancel current notification
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val notificationId = (category + subCategory + recordTitle).hashCode()
        notificationManager.cancel(notificationId)

        // Cancel any pending auto-snooze alarms for this record to avoid duplicates
        cancelSnoozeAlarms(context, category, subCategory, recordTitle)

        // Schedule the snooze alarm for 5 minutes from now
        val snoozeTime = System.currentTimeMillis() + (5 * 60 * 1000) // 5 minutes
        
        val snoozeIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_RECORD_ALARM
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
            putExtra(EXTRA_DESCRIPTION, description)
            putExtra(EXTRA_ALARM_TYPE, alarmType)
            putExtra(EXTRA_IS_PRECHECK, false)
            putExtra("SNOOZE_COUNT", snoozeCount)
        }

        val snoozePendingIntent = android.app.PendingIntent.getBroadcast(
            context,
            ("$category$subCategory$recordTitle$snoozeCount").hashCode(),
            snoozeIntent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    android.app.AlarmManager.RTC_WAKEUP,
                    snoozeTime,
                    snoozePendingIntent
                )
            } else {
                alarmManager.setExact(android.app.AlarmManager.RTC_WAKEUP, snoozeTime, snoozePendingIntent)
            }
            Log.d(TAG, "Manual snooze scheduled for $recordTitle in 5 minutes (attempt $snoozeCount/5)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule manual snooze", e)
        }
    }

    private fun cancelSnoozeAlarms(context: Context, category: String, subCategory: String, recordTitle: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        
        // Cancel all possible snooze alarms (1-5)
        for (snoozeCount in 1..5) {
            val snoozeIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_RECORD_ALARM
                putExtra(EXTRA_CATEGORY, category)
                putExtra(EXTRA_SUB_CATEGORY, subCategory)
                putExtra(EXTRA_RECORD_TITLE, recordTitle)
                putExtra("SNOOZE_COUNT", snoozeCount)
            }
            
            val pendingIntent = android.app.PendingIntent.getBroadcast(
                context,
                ("$category$subCategory$recordTitle$snoozeCount").hashCode(),
                snoozeIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            
            alarmManager.cancel(pendingIntent)
        }
        
        Log.d(TAG, "Cancelled all snooze alarms for: $recordTitle")
    }

    private fun handleBootCompleted(context: Context) {
        Log.d(TAG, "Boot completed - rescheduling alarms")
        
        // Trigger alarm rescheduling after device reboot
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            action = "RESCHEDULE_ALARMS"
        }
        
        context.startForegroundService(serviceIntent)
    }
}
