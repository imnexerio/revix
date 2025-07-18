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
import android.widget.RemoteViews
import android.widget.Toast
import java.util.concurrent.atomic.AtomicBoolean

class RefreshService : Service() {
    private val handler = Handler(Looper.getMainLooper())
      companion object {
        private val isRefreshing = AtomicBoolean(false)
        private const val PREF_LAST_REFRESH_REQUEST_ID = "last_refresh_request_id"
        
        fun isCurrentlyRefreshing(): Boolean {
            val refreshing = isRefreshing.get()
            Log.d("RefreshService", "isCurrentlyRefreshing() called, returning: $refreshing")
            return refreshing
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("RefreshService", "onStartCommand called with startId: $startId")
        
        if (intent == null) {
            Log.d("RefreshService", "Intent is null, stopping service")
            stopSelf(startId)
            return START_NOT_STICKY
        }

        // Check if already refreshing
        val currentlyRefreshing = isRefreshing.get()
        Log.d("RefreshService", "Currently refreshing: $currentlyRefreshing")
        
        if (currentlyRefreshing) {
            Log.d("RefreshService", "Refresh already in progress, ignoring new request")
            handler.post {
                Toast.makeText(
                    applicationContext,
                    "Refresh already in progress...",
                    Toast.LENGTH_SHORT
                ).show()
            }
            stopSelf(startId)
            return START_NOT_STICKY
        }

        // Start refresh process
        Log.d("RefreshService", "Starting refresh process")
        handleRefresh(startId)
        return START_STICKY
    }    private fun handleRefresh(startId: Int) {
        try {
            // Set refreshing state
            Log.d("RefreshService", "Setting isRefreshing to true")
            isRefreshing.set(true)
            
            // Show refreshing state on widgets
            showRefreshingState()
            
            // Show processing message
            handler.post {
                Toast.makeText(
                    applicationContext,
                    "Refreshing data...",
                    Toast.LENGTH_SHORT
                ).show()
            }

            // Generate unique request ID
            val requestId = System.currentTimeMillis().toString()
            Log.d("RefreshService", "Generated requestId: $requestId")
              // Store request ID for tracking
            val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            prefs.edit().putString(PREF_LAST_REFRESH_REQUEST_ID, requestId).apply()
            
            // Store the current lastUpdated timestamp to detect changes
            val lastUpdatedBefore = prefs.getLong("lastUpdated", 0L)
            Log.d("RefreshService", "lastUpdated before refresh: $lastUpdatedBefore")

            // Trigger Flutter background callback for refresh
            val uri = android.net.Uri.parse("homeWidget://widget_refresh")
                .buildUpon()
                .appendQueryParameter("requestId", requestId)
                .build()

            val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                applicationContext,
                uri
            )
            backgroundIntent.send()

            Log.d("RefreshService", "Background callback triggered with requestId: $requestId")            // Monitor refresh completion
            monitorRefreshCompletion(requestId, startId, lastUpdatedBefore)

        } catch (e: Exception) {
            Log.e("RefreshService", "Error starting refresh: ${e.message}", e)
            handleRefreshError("Error starting refresh: ${e.message}", startId)
        }
    }

    private fun showRefreshingState() {
        try {
            val views = RemoteViews(packageName, R.layout.today_widget)
            views.setTextViewText(R.id.title_text_n_refresh, "Refreshing...")

            val appWidgetManager = AppWidgetManager.getInstance(this)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(this, TodayWidget::class.java)
            )

            // Update each widget to show refreshing state
            for (appWidgetId in appWidgetIds) {
                appWidgetManager.partiallyUpdateAppWidget(appWidgetId, views)
            }
        } catch (e: Exception) {
            Log.e("RefreshService", "Error showing refreshing state: ${e.message}")
        }
    }    private fun monitorRefreshCompletion(requestId: String, startId: Int, lastUpdatedBefore: Long) {
        Log.d("RefreshService", "Starting monitoring thread for requestId: $requestId")

          Thread {
            var retryCount = 0
            val maxRetries = 300 // 60 seconds max wait time (300 * 200ms = 60 seconds)
            var refreshCompleted = false
            var refreshSuccess = false
            var errorMessage = ""
            
            while (retryCount < maxRetries && !refreshCompleted) {
                try {
                    Thread.sleep(200) // Wait 200ms between checks
                    
                    val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                    val resultKey = "widget_refresh_result_$requestId"
                    val result = prefs.getString(resultKey, null)
                    
                    if (result != null) {
                        Log.d("RefreshService", "Refresh result found: $result")
                        refreshCompleted = true
                        if (result.startsWith("SUCCESS")) {
                            refreshSuccess = true
                        } else if (result.startsWith("ERROR:")) {
                            refreshSuccess = false
                            errorMessage = result.substring(6) // Remove "ERROR:" prefix
                        }
                        
                        // Clean up the result from preferences
                        prefs.edit().remove(resultKey).apply()
                        break
                    }
                    
                    // FALLBACK: Check for data changes as indicator of completion
                    // This is a safety net in case the result key is not set properly
                    val lastUpdated = prefs.getLong("lastUpdated", 0L)
                    if (lastUpdated > lastUpdatedBefore && retryCount > 10) {
                        Log.d("RefreshService", "Data updated after request start, assuming success (fallback)")
                        Log.d("RefreshService", "lastUpdatedBefore: $lastUpdatedBefore, lastUpdated: $lastUpdated")
                        refreshCompleted = true
                        refreshSuccess = true
                        break
                    }
                    
                    retryCount++
                    
                    // Log progress every 25 checks (5 seconds)
                    if (retryCount % 25 == 0) {
                        Log.d("RefreshService", "Still waiting for refresh completion... ($retryCount/$maxRetries)")
                    }
                    
                } catch (e: InterruptedException) {
                    Log.e("RefreshService", "Refresh monitoring interrupted: ${e.message}")
                    break
                }
            }

            // Handle completion on main thread
            Log.d("RefreshService", "Monitoring completed. refreshCompleted: $refreshCompleted, refreshSuccess: $refreshSuccess")
            
            handler.post {
                if (refreshCompleted) {
                    if (refreshSuccess) {
                        handleRefreshSuccess(startId)
                    } else {
                        val displayError = if (errorMessage.isNotEmpty()) errorMessage else "Unknown error occurred"
                        handleRefreshError(displayError, startId)
                    }
                } else {
                    // Timeout occurred
                    handleRefreshTimeout(startId)
                }
            }
            
        }.start()
    }private fun handleRefreshSuccess(startId: Int) {
        Log.d("RefreshService", "Refresh completed successfully, resetting isRefreshing to false")
        
        // Reset refreshing state FIRST
        isRefreshing.set(false)
        
        // Show success message
        Toast.makeText(
            applicationContext,
            "Data refreshed successfully!",
            Toast.LENGTH_SHORT
        ).show()

        // Show success notification
        showStatusNotification("Data refresh completed successfully!", true)

        // Update widgets with new data
        updateWidgets()
        
        Log.d("RefreshService", "Stopping service with startId: $startId")
        stopSelf(startId)
    }    private fun handleRefreshError(errorMessage: String, startId: Int) {
        Log.e("RefreshService", "Refresh failed: $errorMessage, resetting isRefreshing to false")
        
        // Reset refreshing state FIRST
        isRefreshing.set(false)
        
        // Show error message
        Toast.makeText(
            applicationContext,
            "Refresh failed: $errorMessage",
            Toast.LENGTH_SHORT
        ).show()

        // Show error notification
        showStatusNotification("Refresh failed: $errorMessage", false)

        // Update widgets to remove refreshing state
        updateWidgets()
        
        Log.d("RefreshService", "Stopping service with startId: $startId")
        stopSelf(startId)
    }    private fun handleRefreshTimeout(startId: Int) {
        Log.w("RefreshService", "Refresh operation timed out, resetting isRefreshing to false")
        
        // Reset refreshing state FIRST
        isRefreshing.set(false)
        
        // Show timeout message
        Toast.makeText(
            applicationContext,
            "Refresh timed out. Please try again.",
            Toast.LENGTH_SHORT
        ).show()

        // Show timeout notification
        showStatusNotification("Refresh operation timed out. Please try again.", false)

        // Update widgets to remove refreshing state
        updateWidgets()
        
        Log.d("RefreshService", "Stopping service with startId: $startId")
        stopSelf(startId)
    }

    private fun updateWidgets() {
        try {
            // Use the same widget update method from TodayWidget
            TodayWidget.updateWidgets(applicationContext)
        } catch (e: Exception) {
            Log.e("RefreshService", "Error updating widgets: ${e.message}")
        }
    }

    private fun showStatusNotification(message: String, isSuccess: Boolean) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        
        // Create notification channel for refresh status
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                "widget_refresh_status",
                "Widget Refresh Status",
                android.app.NotificationManager.IMPORTANCE_LOW // Silent notification
            )
            channel.description = "Status updates for widget refresh operations"
            channel.setSound(null, null) // Silent
            channel.enableVibration(false) // No vibration
            notificationManager.createNotificationChannel(channel)
        }

        val notification = androidx.core.app.NotificationCompat.Builder(this, "widget_refresh_status")
            .setSmallIcon(
                if (isSuccess) R.drawable.ic_launcher_icon
                else R.drawable.ic_launcher_icon_error
            )
            .setContentTitle(
                if (isSuccess) "Widget Refresh Completed ✓" 
                else "Widget Refresh Failed ✗"
            )
            .setContentText(message)
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_LOW) // Silent
            .setAutoCancel(true)
            .build()

        val refreshNotificationId = "widget_refresh_status".hashCode()
        notificationManager.notify(refreshNotificationId, notification)
    }    override fun onDestroy() {
        super.onDestroy()
        Log.d("RefreshService", "Service being destroyed, resetting isRefreshing to false")
        
        // Reset refreshing state when service is destroyed
        isRefreshing.set(false)
        
        // Clean up any stale refresh results
        cleanupOldRefreshResults()
    }

    private fun cleanupOldRefreshResults() {
        try {
            val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            val allKeys = prefs.all.keys
            val currentTime = System.currentTimeMillis()
            
            // Remove refresh result entries older than 2 minutes
            for (key in allKeys) {
                if (key.startsWith("widget_refresh_result_")) {
                    try {
                        val parts = key.split("_")
                        if (parts.size >= 4) {
                            val timestamp = parts[3].toLongOrNull()
                            if (timestamp != null && (currentTime - timestamp) > 120000) { // 2 minutes
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
            Log.e("RefreshService", "Error cleaning up old refresh results: ${e.message}")
        }
    }
}
