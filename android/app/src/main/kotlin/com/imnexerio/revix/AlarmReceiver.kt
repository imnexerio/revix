package com.imnexerio.revix

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {    companion object {
        const val ACTION_RECORD_ALARM = "revix.ACTION_RECORD_ALARM"
        const val ACTION_WARNING_NOTIFICATION = "revix.ACTION_WARNING_NOTIFICATION"
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
            ACTION_WARNING_NOTIFICATION -> {
                handleWarningNotification(context, intent)
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
            "ACTION_SNOOZE_CHECK" -> {
                handleSnoozeCheck(context, intent)
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

        // Cancel any pending alarms for this record since it's being marked as done
        cancelSnoozeAlarms(context, category, subCategory, recordTitle)

        // Dismiss the current notification
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val notificationId = (category + subCategory + recordTitle).hashCode()
        notificationManager.cancel(notificationId)

        // Use RecordUpdateService directly - much cleaner and more efficient
        val serviceIntent = Intent(context, RecordUpdateService::class.java).apply {
            putExtra("category", category)
            putExtra("sub_category", subCategory)
            putExtra("record_title", recordTitle)
        }
        context.startService(serviceIntent)
        
        Log.d(TAG, "RecordUpdateService started for: $recordTitle")
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

        // Trigger widget refresh to check if record still exists
        triggerWidgetRefresh(context)

        // Schedule the snooze check after a short delay to allow widget refresh to complete
        val snoozeCheckIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = "ACTION_SNOOZE_CHECK"
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
            putExtra(EXTRA_DESCRIPTION, description)
            putExtra(EXTRA_ALARM_TYPE, alarmType)
            putExtra("SNOOZE_COUNT", snoozeCount)
        }

        val checkPendingIntent = android.app.PendingIntent.getBroadcast(
            context,
            ("snooze_check_$category$subCategory$recordTitle$snoozeCount").hashCode(),
            snoozeCheckIntent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val checkTime = System.currentTimeMillis() + 3000 // 3 seconds delay for widget refresh

        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    android.app.AlarmManager.RTC_WAKEUP,
                    checkTime,
                    checkPendingIntent
                )
            } else {
                alarmManager.setExact(android.app.AlarmManager.RTC_WAKEUP, checkTime, checkPendingIntent)
            }
            Log.d(TAG, "Snooze check scheduled for $recordTitle")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule snooze check", e)
        }
    }

    private fun cancelSnoozeAlarms(context: Context, category: String, subCategory: String, recordTitle: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
          // Cancel all possible snooze alarms (1-6)
        for (snoozeCount in 1..6) {
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

    private fun handleWarningNotification(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""

        Log.d(TAG, "Warning notification triggered: $category - $subCategory - $recordTitle")

        // Show warning notification
        showWarningNotification(context, category, subCategory, recordTitle)

        // Trigger widget refresh to update data
        triggerWidgetRefresh(context)
    }

    private fun showWarningNotification(context: Context, category: String, subCategory: String, recordTitle: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        
        // Create notification channel if needed
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                "warning_notifications",
                "Upcoming Reminders",
                android.app.NotificationManager.IMPORTANCE_DEFAULT
            )
            notificationManager.createNotificationChannel(channel)
        }

        val notification = androidx.core.app.NotificationCompat.Builder(context, "warning_notifications")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Upcoming Reminder")
            .setContentText("$recordTitle in 5 minutes")
            .setStyle(androidx.core.app.NotificationCompat.BigTextStyle()
                .bigText("You have an upcoming reminder for: $recordTitle\nCategory: $category - $subCategory\n\nThis will alert you in 5 minutes."))
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setTimeoutAfter(5 * 60 * 1000) // Auto-dismiss after 5 minutes
            .build()

        val notificationId = ("warning_$category$subCategory$recordTitle").hashCode()
        notificationManager.notify(notificationId, notification)
        
        Log.d(TAG, "Warning notification shown for: $recordTitle")
    }

    private fun triggerWidgetRefresh(context: Context) {
        try {
            // Trigger widget refresh using the same mechanism as in TodayWidget
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

    private fun handleSnoozeCheck(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""
        val description = intent.getStringExtra(EXTRA_DESCRIPTION) ?: ""
        val alarmType = intent.getIntExtra(EXTRA_ALARM_TYPE, 0)
        val snoozeCount = intent.getIntExtra("SNOOZE_COUNT", 1)

        Log.d(TAG, "Snooze check triggered: $category - $subCategory - $recordTitle (Snooze #$snoozeCount)")

        // Check if we've reached the maximum snooze limit (6 times)
        if (snoozeCount >= 6) {
            Log.d(TAG, "Maximum snooze limit reached for $recordTitle")
            return
        }
        
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
            putExtra("SNOOZE_COUNT", snoozeCount + 1)
        }

        val snoozePendingIntent = android.app.PendingIntent.getBroadcast(
            context,
            ("$category$subCategory$recordTitle${snoozeCount + 1}").hashCode(),
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
            Log.d(TAG, "Snooze scheduled for $recordTitle in 5 minutes (attempt ${snoozeCount + 1}/6)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule snooze", e)
        }
    }

}
