package com.imnexerio.revix

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "BootReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "Boot completed - rescheduling alarms")
            
            try {
                val alarmHelper = AlarmManagerHelper(context)
                alarmHelper.scheduleAlarmsFromWidgetData(context, forceUpdate = true)
                Log.d(TAG, "✓ Alarms rescheduled successfully after boot")
            } catch (e: Exception) {
                Log.e(TAG, "✗ Error rescheduling alarms after boot: ${e.message}", e)
            }
        }
    }
}
