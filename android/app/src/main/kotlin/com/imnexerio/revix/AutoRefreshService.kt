package com.imnexerio.revix

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.widget.Toast

class AutoRefreshService : Service() {
    private val handler = Handler(Looper.getMainLooper())

    companion object {
        private const val TAG = "AutoRefreshService"
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "AutoRefreshService started")
        
        if (intent == null) {
            Log.d(TAG, "Intent is null, stopping service")
            stopSelf(startId)
            return START_NOT_STICKY
        }

        // Check if auto-refresh is still enabled
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val autoRefreshEnabled = prefs.getBoolean("flutter.auto_refresh_enabled", true)
        
        // Handle potential Long to Int conversion issue
        val intervalMinutes = try {
            prefs.getInt("flutter.auto_refresh_interval_minutes", 1440)
        } catch (e: ClassCastException) {
            // If stored as Long, get it as Long and convert to Int
            prefs.getLong("flutter.auto_refresh_interval_minutes", 1440L).toInt()
        }

        if (!autoRefreshEnabled) {
            Log.d(TAG, "Auto-refresh is disabled, not triggering refresh")
            stopSelf(startId)
            return START_NOT_STICKY
        }

        Log.d(TAG, "Auto-refresh enabled, interval: ${intervalMinutes}m, triggering refresh...")

        // Simulate refresh button click
        triggerWidgetRefresh()

        // Schedule next auto-refresh
        scheduleNextAutoRefresh(intervalMinutes)

        stopSelf(startId)
        return START_NOT_STICKY
    }

    private fun triggerWidgetRefresh() {
        try {
            Log.d(TAG, "Triggering widget refresh...")
            
            // Simulate refresh button tap by sending refresh action to TodayWidget
            val refreshIntent = Intent(applicationContext, TodayWidget::class.java)
            refreshIntent.action = TodayWidget.ACTION_REFRESH
            applicationContext.sendBroadcast(refreshIntent)
            
            Log.d(TAG, "Widget refresh triggered successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error triggering widget refresh: ${e.message}", e)
        }
    }

    private fun scheduleNextAutoRefresh(intervalMinutes: Int) {
        try {
            Log.d(TAG, "Scheduling next auto-refresh in ${intervalMinutes} minutes")
            AutoRefreshManager.scheduleAutoRefresh(applicationContext, intervalMinutes)
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling next auto-refresh: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "AutoRefreshService destroyed")
    }
}
