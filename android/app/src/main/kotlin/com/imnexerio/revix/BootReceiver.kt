package com.imnexerio.revix

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "BootReceiver"
        private const val BOOT_REFRESH_DELAY_MS = 60000L // 60 seconds delay for system stability
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "Boot completed - scheduling widget refresh in 60 seconds")
            
            Handler(Looper.getMainLooper()).postDelayed({
                simulateCounterWidgetClick(context)
            }, BOOT_REFRESH_DELAY_MS)
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
