package com.imnexerio.retracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.appwidget.AppWidgetManager
import android.content.ComponentName

class ScreenOnReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SCREEN_ON, Intent.ACTION_BOOT_COMPLETED -> {
                // Check if we have any widgets installed
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, TodayWidget::class.java)
                )

                if (appWidgetIds.isNotEmpty()) {
                    // Only update if we have widgets
                    val serviceIntent = Intent(context, WidgetRefreshService::class.java)
                    context.startService(serviceIntent)
                }
            }
        }
    }
}