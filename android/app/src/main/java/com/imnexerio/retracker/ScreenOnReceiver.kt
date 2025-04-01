package com.imnexerio.retracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter

class ScreenOnReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_SCREEN_ON) {
            // Start the widget refresh service when screen turns on
            val serviceIntent = Intent(context, WidgetRefreshService::class.java)
            context.startService(serviceIntent)
        }
    }

    companion object {
        // Helper method to register the receiver
        fun register(context: Context): ScreenOnReceiver {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
            }
            val receiver = ScreenOnReceiver()
            context.registerReceiver(receiver, filter)
            return receiver
        }
    }
}