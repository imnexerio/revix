package com.imnexerio.retracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONException

class TodayWidget : AppWidgetProvider() {
    companion object {
        const val ACTION_REFRESH = "com.imnexerio.retracker.ACTION_REFRESH"
        const val ACTION_ITEM_CLICK = "com.imnexerio.retracker.ACTION_ITEM_CLICK"
        const val ACTION_ADD_RECORD = "com.imnexerio.retracker.ACTION_ADD_RECORD"

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

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_REFRESH -> {
                // Use foreground service for Android 8+ to ensure reliable execution
                val serviceIntent = Intent(context, WidgetRefreshService::class.java)
                context.startService(serviceIntent)

                // Update the refresh button to show it's working
                val views = RemoteViews(context.packageName, R.layout.today_widget)
                views.setTextViewText(R.id.title_text_n_refresh, "Refreshing...")

                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, TodayWidget::class.java)
                )

                // Update each widget
                for (appWidgetId in appWidgetIds) {
                    appWidgetManager.partiallyUpdateAppWidget(appWidgetId, views)
                }
            }
            ACTION_ITEM_CLICK -> {
                // Extract record details from intent
                val subject = intent.getStringExtra("subject") ?: ""
                val subjectCode = intent.getStringExtra("subject_code") ?: ""
                val lectureNo = intent.getStringExtra("lecture_no") ?: ""

                // Start the service to handle the item click
                val clickIntent = Intent(context, RecordUpdateService::class.java)
                clickIntent.putExtra("subject", subject)
                clickIntent.putExtra("subject_code", subjectCode)
                clickIntent.putExtra("lecture_no", lectureNo)
                context.startService(clickIntent)

                // Show a temporary message
                Toast.makeText(context, "Processing record: $subject > $subjectCode > $lectureNo", Toast.LENGTH_SHORT).show()
            }
            ACTION_ADD_RECORD -> {
                // Launch the AddLectureActivity
                val addIntent = Intent(context, AddLectureActivity::class.java)
                addIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(addIntent)
            }
        }
    }

    // Other methods remain unchanged
    override fun onEnabled(context: Context) {
        val serviceIntent = Intent(context, WidgetRefreshService::class.java)
        context.startService(serviceIntent)
    }

    override fun onDisabled(context: Context) {
        // Cleanup if needed
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
        views.setTextViewText(R.id.title_text_n_refresh, "Today's Schedule (${count})")

        if (!isLoggedIn) {
            views.setTextViewText(R.id.empty_view, "Please login to view your schedule")
        } else {
            views.setTextViewText(R.id.empty_view, "No tasks for today, enjoy your day")
        }

        // Add last updated timestamp if available
        if (lastUpdated > 0) {
            val dateFormat = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault())
            val lastUpdateTime = dateFormat.format(java.util.Date(lastUpdated))
            views.setTextViewText(R.id.title_text_n_refresh, "${count} @ ${lastUpdateTime}")
        }
    } catch (e: JSONException) {
        views.setTextViewText(R.id.title_text_n_refresh, "${count} @ ${e.message}")
    }

    // Set up the refresh button click
    val refreshIntent = Intent(context, TodayWidget::class.java)
    refreshIntent.action = TodayWidget.ACTION_REFRESH
    val refreshRequestCode = appWidgetId + System.currentTimeMillis().toInt()
    val refreshPendingIntent = PendingIntent.getBroadcast(
        context,
        refreshRequestCode,
        refreshIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.title_text_n_refresh, refreshPendingIntent)

    // Set up the add record button click
    val addIntent = Intent(context, TodayWidget::class.java)
    addIntent.action = TodayWidget.ACTION_ADD_RECORD
    val addRequestCode = appWidgetId + 100 + System.currentTimeMillis().toInt()
    val addPendingIntent = PendingIntent.getBroadcast(
        context,
        addRequestCode,
        addIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.add_record_button, addPendingIntent)

    // Set up ListView and its adapter
    val intent = Intent(context, WidgetListViewService::class.java)
    intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
    intent.data = android.net.Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME))
    views.setRemoteAdapter(R.id.widget_listview, intent)
    views.setEmptyView(R.id.widget_listview, R.id.empty_view)

    // Set up the PendingIntent template for item clicks
    val clickIntent = Intent(context, TodayWidget::class.java)
    clickIntent.action = TodayWidget.ACTION_ITEM_CLICK
    clickIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
    clickIntent.data = Uri.parse(clickIntent.toUri(Intent.URI_INTENT_SCHEME))

    // Create a template PendingIntent which the RemoteViews factory will fill in
    val clickPendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        clickIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
    )

    // Set the pending intent template on the ListView
    views.setPendingIntentTemplate(R.id.widget_listview, clickPendingIntent)

    // Update the widget
    appWidgetManager.updateAppWidget(appWidgetId, views)
    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_listview)
}