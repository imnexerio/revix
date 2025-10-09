package com.imnexerio.revix

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "BootReceiver"
        private const val BOOT_REFRESH_DELAY_MS = 60000L // 60 seconds
        const val ACTION_BOOT_REFRESH = "revix.ACTION_BOOT_REFRESH"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.d(TAG, "Boot completed - scheduling widget refresh in 60 seconds")
                scheduleDelayedRefresh(context)
            }
            
            ACTION_BOOT_REFRESH -> {
                Log.d(TAG, "Boot refresh alarm triggered - executing widget refresh")
                simulateCounterWidgetClick(context)
            }
        }
    }

    private fun scheduleDelayedRefresh(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val refreshIntent = Intent(context, BootReceiver::class.java)
            refreshIntent.action = ACTION_BOOT_REFRESH
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                99999,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val triggerTime = SystemClock.elapsedRealtime() + BOOT_REFRESH_DELAY_MS
            alarmManager.setExact(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerTime,
                pendingIntent
            )
            
            Log.d(TAG, "Scheduled boot refresh alarm for 60 seconds from now")
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling boot refresh: ${e.message}", e)
        }
    }

    private fun simulateCounterWidgetClick(context: Context) {
        try {
            Log.d(TAG, "Simulating counter widget click - sending ACTION_REFRESH to TodayWidget")
            
            val refreshIntent = Intent(context, TodayWidget::class.java)
            refreshIntent.action = "revix.ACTION_REFRESH"  // TodayWidget.ACTION_REFRESH
            
            context.sendBroadcast(refreshIntent)
            
            Log.d(TAG, "Refresh broadcast sent to TodayWidget - widget refresh initiated")
        } catch (e: Exception) {
            Log.e(TAG, "Error sending refresh broadcast: ${e.message}", e)
        }
    }
}
