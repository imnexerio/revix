package com.imnexerio.revix

import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.widget.Toast
import java.util.concurrent.atomic.AtomicInteger

class RecordUpdateService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var activeTaskCount = AtomicInteger(0)
    private val lock = Any()

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Track active task
        synchronized(lock) {
            activeTaskCount.incrementAndGet()
        }

        if (intent == null) {
            finishTask(startId)
            return START_NOT_STICKY
        }
        val category = intent.getStringExtra("category") ?: ""
        val subCategory = intent.getStringExtra("sub_category") ?: ""
        val lectureNo = intent.getStringExtra("record_title") ?: ""
        val externalRequestId = intent.getStringExtra("request_id") // Get external request ID if provided

        if (category.isEmpty() || subCategory.isEmpty() || lectureNo.isEmpty()) {
            Toast.makeText(this, "Invalid record information", Toast.LENGTH_SHORT).show()
            finishTask(startId)
            return START_NOT_STICKY
        }

        // Extract additional fields from intent
        val extras = HashMap<String, String>()
        intent.extras?.let { bundle ->
            for (key in bundle.keySet()) {
                if (key != "category" && key != "sub_category" && key != "record_title" && key != "request_id") {
                    val value = bundle.getString(key)
                    if (value != null) {
                        extras[key] = value
                    }
                }
            }
        }

        handleRecordClick(category, subCategory, lectureNo, extras, externalRequestId, startId)
        return START_STICKY
    }

    private fun finishTask(startId: Int) {
        synchronized(lock) {
            val remainingTasks = activeTaskCount.decrementAndGet()
            if (remainingTasks <= 0) {
                // Make sure we use a new handler to avoid timing issues
                handler.post {
                    handler.postDelayed({
                        stopSelf()
                    }, 1000)
                }
            } else {
                // Only stop this specific task
                stopSelf(startId)
            }
        }
    }

    private fun refreshWidgets(startId: Int) {
        try {
            // Instead of direct widget updates, send a broadcast
            val context = applicationContext
            val intent = Intent(context, TodayWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, TodayWidget::class.java)
                )
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
            }
            context.sendBroadcast(intent)

            // Widget refresh will be handled by Flutter background callback
            // No need for separate service            // NEW: Direct alarm scheduling call - works even without widget
            try {
                Log.d("RecordUpdateService", "Scheduling alarms from updated data...")
                val alarmHelper = AlarmManagerHelper(context)
                alarmHelper.scheduleAlarmsFromWidgetData(context)
                Log.d("RecordUpdateService", "Alarms scheduled successfully from RecordUpdateService")
            } catch (e: Exception) {
                Log.e("RecordUpdateService", "Error scheduling alarms: ${e.message}", e)
            }

            // Complete this task
            finishTask(startId)
        } catch (e: Exception) {
            // Handle any exceptions that occur during the refresh
            Toast.makeText(this, "Error refreshing widgets: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    private fun handleRecordClick(
        category: String,
        subCategory: String,
        lectureNo: String,
        extras: Map<String, String>,
        externalRequestId: String?,
        startId: Int
    ) {
        try {
            // Simplified approach - just call updateRecord with minimal data
            // Let Flutter handle all the business logic including checking if already revised today
            updateRecord(emptyMap<String, Any>(), category, subCategory, lectureNo, extras, externalRequestId, startId)
        } catch (e: Exception) {
            Toast.makeText(applicationContext, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
            e.printStackTrace()
            stopSelf(startId)
        }
    }

    private fun updateRecord(
        details: Map<*, *>,
        category: String,
        subCategory: String,
        lectureNo: String,
        extras: Map<String, String>,
        externalRequestId: String?,
        startId: Int
    ) {
        try {
            // Show processing message
            handler.post {
                Toast.makeText(
                    applicationContext,
                    "Updating record...",
                    Toast.LENGTH_SHORT
                ).show()
            }            // Use external request ID if provided, otherwise create new one
            val requestId = externalRequestId ?: System.currentTimeMillis().toString()
            
            // Use simplified approach - just send the essential parameters
            // Let Flutter handle all the complex logic
            val uri = android.net.Uri.parse("homeWidget://record_update")
                .buildUpon()
                .appendQueryParameter("category", category)
                .appendQueryParameter("sub_category", subCategory)
                .appendQueryParameter("record_title", lectureNo)
                .appendQueryParameter("requestId", requestId)
                .build()

            val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                applicationContext,
                uri
            )
            backgroundIntent.send()            // Always monitor results and show status notifications
            // This provides consistent feedback for both widget and notification updates
            Thread {
                var retryCount = 0
                val maxRetries = 300 // 1 minute max wait time (300 * 200ms = 60 seconds)
                var updateCompleted = false
                var updateSuccess = false
                var errorMessage = ""
                
                while (retryCount < maxRetries && !updateCompleted) {
                    try {
                        Thread.sleep(200) // Wait 200ms between checks
                        
                        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                        val resultKey = "record_update_result_$requestId"
                        val result = prefs.getString(resultKey, null)
                        
                        if (result != null) {
                            updateCompleted = true
                            if (result.startsWith("SUCCESS")) {
                                updateSuccess = true
                            } else if (result.startsWith("ERROR:")) {
                                updateSuccess = false
                                errorMessage = result.substring(6) // Remove "ERROR:" prefix
                            }
                            
                            // Clean up the result from preferences
                            prefs.edit().remove(resultKey).apply()
                            break
                        }
                        
                        retryCount++
                    } catch (e: InterruptedException) {
                        Log.e("RecordUpdateService", "Update result waiting interrupted: ${e.message}")
                        break
                    }
                }

                // Show result on main thread
                handler.post {
                    if (updateCompleted) {
                        if (updateSuccess) {
                            // Show both Toast and status notification for consistent feedback
                            Toast.makeText(
                                applicationContext,
                                "Record updated successfully!",
                                Toast.LENGTH_SHORT
                            ).show()
                            showStatusNotification(category,subCategory,lectureNo, "Completed successfully!", true)
                        } else {
                            val displayError = if (errorMessage.isNotEmpty()) errorMessage else "Unknown error occurred"
                            Toast.makeText(
                                applicationContext,
                                "Failed to update record: $displayError",
                                Toast.LENGTH_SHORT
                            ).show()
                            showStatusNotification(category,subCategory,lectureNo, "Failed: $displayError please launch app for more info", false)
                        }
                    } else {
                        // Timeout occurred
                        Toast.makeText(
                            applicationContext,
                            "Update operation timed out. Please try again.",
                            Toast.LENGTH_SHORT
                        ).show()
                        showStatusNotification(category,subCategory,lectureNo, "Operation timed out please launch app for more info.", false)
                    }
                }

                // Clear processing state and refresh widgets
                clearProcessingState(category, subCategory, lectureNo)
                refreshWidgets(startId)
                
            }.start()

        } catch (e: Exception) {
            Toast.makeText(applicationContext, "Error updating record: ${e.message}", Toast.LENGTH_SHORT).show()
            Log.e("RecordUpdateService", "Error triggering background update: ${e.message}")
            clearProcessingState(category, subCategory, lectureNo)
            refreshWidgets(startId)
            stopSelf(startId)
        }
    }

    private fun clearProcessingState(category: String, subCategory: String, lectureNo: String) {
        val prefs = applicationContext.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val processingItems = prefs.getStringSet(TodayWidget.PREF_PROCESSING_ITEMS, mutableSetOf()) ?: mutableSetOf()
        val itemKey = "${category}_${subCategory}_${lectureNo}"
        val newProcessingItems = processingItems.toMutableSet()
        newProcessingItems.remove(itemKey)
        prefs.edit().putStringSet(TodayWidget.PREF_PROCESSING_ITEMS, newProcessingItems).apply()
    }

    private fun showStatusNotification(recordCategory: String,recordSubcategory: String,recordTitle: String, message: String, isComplete: Boolean) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        
        // Create notification channel for status updates
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                "record_update_status",
                "Record Update Status",
                android.app.NotificationManager.IMPORTANCE_LOW // Silent notification
            )
            channel.description = "Status updates for record update operations"
            channel.setSound(null, null) // Silent
            channel.enableVibration(false) // No vibration
            notificationManager.createNotificationChannel(channel)
        }
        val notification = androidx.core.app.NotificationCompat.Builder(this, "record_update_status")
            .setSmallIcon(
                if (isComplete) R.drawable.ic_launcher_icon
                else R.drawable.ic_launcher_icon_error
            )
            .setContentTitle(
                if (isComplete) "Task Completed ✓" 
                else "Task Update Failed ✗"
            )
            .setContentText("$recordCategory · $recordSubcategory · $recordTitle: $message")
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_LOW) // Silent
            .setAutoCancel(true)
            .build()

        val statusNotificationId = ("status_$recordTitle").hashCode()
        notificationManager.notify(statusNotificationId, notification)
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up any stale result entries
        cleanupOldResults()
    }

    private fun cleanupOldResults() {
        try {
            val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            val allKeys = prefs.all.keys
            val currentTime = System.currentTimeMillis()
            
            // Remove result entries older than 1 minute
            for (key in allKeys) {
                if (key.startsWith("record_save_result_") || 
                    key.startsWith("record_update_result_") || 
                    key.startsWith("record_delete_result_")) {
                    try {
                        val parts = key.split("_")
                        if (parts.size >= 4) {
                            val timestamp = parts[3].toLongOrNull()
                            if (timestamp != null && (currentTime - timestamp) > 60000) { // 1 minute
                                editor.remove(key)
                            }
                        }
                    } catch (e: Exception) {
                        // If we can't parse the timestamp, remove the entry
                        editor.remove(key)
                    }
                }
            }
            editor.apply()
        } catch (e: Exception) {
            Log.e("RecordUpdateService", "Error cleaning up old results: ${e.message}")
        }
    }
}
