package com.imnexerio.revix

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

object AutoRefreshManager {
    private const val TAG = "AutoRefreshManager"
    private const val AUTO_REFRESH_REQUEST_CODE = 9876

    fun scheduleAutoRefreshFromLastUpdate(context: Context, intervalMinutes: Int, lastUpdated: Long) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // Create intent for AutoRefreshService
            val intent = Intent(context, AutoRefreshService::class.java)
            val pendingIntent = PendingIntent.getService(
                context,
                AUTO_REFRESH_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val intervalMillis = intervalMinutes * 60 * 1000L
            val currentTime = System.currentTimeMillis()
            
            // Get the actual lastUpdated from HomeWidgetPreferences if not provided
            val actualLastUpdated = if (lastUpdated == 0L) {
                try {
                    val widgetPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                    widgetPrefs.getLong("lastUpdated", 0L)
                } catch (e: Exception) {
                    Log.w(TAG, "Could not read lastUpdated from HomeWidgetPreferences: ${e.message}")
                    0L
                }
            } else {
                lastUpdated
            }
            
            // Calculate next trigger time based on lastUpdated
            val triggerTime = if (actualLastUpdated == 0L) {
                // Fallback to current time + interval if no lastUpdated
                Log.d(TAG, "No lastUpdated timestamp, using current time + interval")
                currentTime + intervalMillis
            } else {
                val calculatedTime = actualLastUpdated + intervalMillis
                if (calculatedTime < currentTime) {
                    // If calculated time is in the past, schedule immediately
                    Log.d(TAG, "Calculated time is in past, scheduling immediately")
                    currentTime
                } else {
                    calculatedTime
                }
            }
            
            Log.d(TAG, "Scheduling auto-refresh based on lastUpdated: ${java.util.Date(actualLastUpdated)}")
            Log.d(TAG, "Next refresh scheduled for: ${java.util.Date(triggerTime)}")
            
            // Schedule the alarm
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            }
            
            Log.d(TAG, "Auto-refresh scheduled successfully for ${java.util.Date(triggerTime)}")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling auto-refresh from lastUpdate: ${e.message}", e)
        }
    }
    
    fun cancelAutoRefresh(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            val intent = Intent(context, AutoRefreshService::class.java)
            val pendingIntent = PendingIntent.getService(
                context,
                AUTO_REFRESH_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
            
            Log.d(TAG, "Auto-refresh cancelled successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error cancelling auto-refresh: ${e.message}", e)
        }
    }

    fun scheduleAutoRefreshAtSpecificTime(context: Context, triggerTimeMillis: Long) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // Create intent for AutoRefreshService
            val intent = Intent(context, AutoRefreshService::class.java)
            val pendingIntent = PendingIntent.getService(
                context,
                AUTO_REFRESH_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            Log.d(TAG, "Scheduling auto-refresh for specific time: ${java.util.Date(triggerTimeMillis)}")
            
            // Schedule the alarm
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTimeMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent)
            }
            
            Log.d(TAG, "Auto-refresh scheduled successfully for ${java.util.Date(triggerTimeMillis)}")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling auto-refresh at specific time: ${e.message}", e)
        }
    }

}
