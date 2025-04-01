package com.imnexerio.retracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONException

class TodayWidget : AppWidgetProvider() {
    companion object {
        const val ACTION_REFRESH = "com.imnexerio.retracker.ACTION_REFRESH"

        // Add a method to force widget update from anywhere in the app
        fun updateWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(context, TodayWidget::class.java)
            )

            // Force a full update for each widget
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }

            // Ensure data changes for the ListView are notified
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_listview)

            // Send a broadcast to update all widgets
            val updateIntent = Intent(context, TodayWidget::class.java)
            updateIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            updateIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
            context.sendBroadcast(updateIntent)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Initial refresh when widget is first added
        val serviceIntent = Intent(context, WidgetRefreshService::class.java)
        context.startService(serviceIntent)
    }

    override fun onDisabled(context: Context) {
        // Cleanup if needed
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == ACTION_REFRESH) {
            // Use foreground service for Android 8+ to ensure reliable execution
            val serviceIntent = Intent(context, WidgetRefreshService::class.java)
            context.startService(serviceIntent)

            // Update the refresh button to show it's working
            val views = RemoteViews(context.packageName, R.layout.today_widget)
            views.setTextViewText(R.id.title_text, "Refreshing...")

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(context, TodayWidget::class.java)
            )

            // Update each widget
            for (appWidgetId in appWidgetIds) {
                appWidgetManager.partiallyUpdateAppWidget(appWidgetId, views)
            }
        }
    }
}
internal fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    val views = RemoteViews(context.packageName, R.layout.today_widget)

    val sharedPreferences = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    val jsonData = sharedPreferences.getString("todayRecords", "[]")
    val isLoggedIn = sharedPreferences.getBoolean("isLoggedIn", false)
    val lastUpdated = sharedPreferences.getLong("lastUpdated", 0L)
    val jsonArray = JSONArray(jsonData)
    val count = jsonArray.length()

    try {


        views.setTextViewText(R.id.title_text, "Today's Schedule (${count})")

        if (!isLoggedIn) {
            views.setTextViewText(R.id.empty_view, "Please login to view your schedule")
        } else {
            views.setTextViewText(R.id.empty_view, "No tasks for today, enjoy your day")
        }

        // Add last updated timestamp if available
        if (lastUpdated > 0) {
            val dateFormat = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault())
            val lastUpdateTime = dateFormat.format(java.util.Date(lastUpdated))
            views.setTextViewText(R.id.title_text, "${count} @ ${lastUpdateTime}")
        }
    } catch (e: JSONException) {
//        e.printStackTrace()
        views.setTextViewText(R.id.title_text, "${count} @ ${e.message}")
    }

    // Set up the refresh button click with a unique request code for each widget
    val refreshIntent = Intent(context, TodayWidget::class.java)
    refreshIntent.action = TodayWidget.ACTION_REFRESH

    // Use a unique request code based on widget ID and current time to avoid PendingIntent caching issues
    val requestCode = appWidgetId + System.currentTimeMillis().toInt()

    val refreshPendingIntent = PendingIntent.getBroadcast(
        context,
        requestCode,
        refreshIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)

    val intent = Intent(context, WidgetListViewService::class.java)
    intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
    intent.data = android.net.Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME))

    views.setRemoteAdapter(R.id.widget_listview, intent)
    views.setEmptyView(R.id.widget_listview, R.id.empty_view)

    appWidgetManager.updateAppWidget(appWidgetId, views)
    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_listview)
}