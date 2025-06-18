package com.imnexerio.revix

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_RECORD_ALARM = "revix.ACTION_RECORD_ALARM"
        const val ACTION_WARNING_NOTIFICATION = "revix.ACTION_WARNING_NOTIFICATION"
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

        // Show immediate status notification
        showStatusNotification(context, recordTitle, "Processing...", false)

        // Create unique request ID for tracking
        val requestId = System.currentTimeMillis().toString()

        // Use RecordUpdateService directly with status tracking
        val serviceIntent = Intent(context, RecordUpdateService::class.java).apply {
            putExtra("category", category)
            putExtra("sub_category", subCategory)
            putExtra("record_title", recordTitle)
            putExtra("request_id", requestId) // Pass request ID for tracking
        }
        context.startService(serviceIntent)

        // Monitor the result in background and update status notification
        monitorMarkAsDoneResult(context, recordTitle, requestId)
        
        Log.d(TAG, "RecordUpdateService started for: $recordTitle with requestId: $requestId")
    }

    private fun showStatusNotification(context: Context, recordTitle: String, message: String, isComplete: Boolean) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        
        // Create notification channel for status updates
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                "mark_as_done_status",
                "Mark as Done Status",
                android.app.NotificationManager.IMPORTANCE_LOW // Silent notification
            )
            channel.description = "Status updates for mark as done operations"
            channel.setSound(null, null) // Silent
            channel.enableVibration(false) // No vibration
            notificationManager.createNotificationChannel(channel)
        }

        val notification = androidx.core.app.NotificationCompat.Builder(context, "mark_as_done_status")
            .setSmallIcon(if (isComplete) android.R.drawable.ic_dialog_info else android.R.drawable.ic_dialog_info)
            .setContentTitle("Mark as Done")
            .setContentText("$recordTitle: $message")
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_LOW) // Silent
            .setAutoCancel(true)
            .build()

        val statusNotificationId = ("status_$recordTitle").hashCode()
        notificationManager.notify(statusNotificationId, notification)
    }

    private fun monitorMarkAsDoneResult(context: Context, recordTitle: String, requestId: String) {
        Thread {
            var retryCount = 0
            val maxRetries = 50 // 10 seconds max wait time
            var resultFound = false
            
            while (retryCount < maxRetries && !resultFound) {
                try {
                    Thread.sleep(200) // Wait 200ms between checks
                    
                    val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                    val resultKey = "record_update_result_$requestId"
                    val result = prefs.getString(resultKey, null)
                    
                    if (result != null) {
                        resultFound = true
                        
                        // Update status notification based on result
                        if (result.startsWith("SUCCESS")) {
                            showStatusNotification(context, recordTitle, "✅ Completed successfully!", true)
                        } else if (result.startsWith("ERROR:")) {
                            val errorMessage = result.substring(6) // Remove "ERROR:" prefix
                            showStatusNotification(context, recordTitle, "❌ Failed: $errorMessage", true)
                        }
                        
                        // Clean up the result from preferences
                        prefs.edit().remove(resultKey).apply()
                        break
                    }
                    
                    retryCount++
                } catch (e: InterruptedException) {
                    Log.e(TAG, "Result monitoring interrupted: ${e.message}")
                    break
                }
            }
            
            // If timeout occurred, show timeout message
            if (!resultFound) {
                showStatusNotification(context, recordTitle, "⏱️ Operation timed out", true)
            }
            
        }.start()
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

        // Trigger widget refresh to update data first
        triggerWidgetRefresh(context)

        // Use AlarmService to show the full notification with all buttons (Mark as Done, Snooze, Ignore)
        // but with modified title and parameters to indicate it's an upcoming reminder
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra(EXTRA_ALARM_TYPE, 1) // Light notification for warning
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
            putExtra(EXTRA_DESCRIPTION, "Upcoming reminder in 5 minutes")
            putExtra(EXTRA_IS_PRECHECK, true) // Mark as precheck to get "Upcoming Reminder" title
            putExtra("IS_WARNING", true) // Add flag to indicate this is a warning notification
        }
        
        context.startForegroundService(serviceIntent)
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
