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
        fun updateWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(context, TodayWidget::class.java)
            )
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_listview)
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
                val serviceIntent = Intent(context, WidgetRefreshService::class.java)
                context.startService(serviceIntent)

                val views = RemoteViews(context.packageName, R.layout.today_widget)
                views.setTextViewText(R.id.title_text_n_refresh, "Refreshing...")

                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, TodayWidget::class.java)
                )
                for (appWidgetId in appWidgetIds) {
                    appWidgetManager.partiallyUpdateAppWidget(appWidgetId, views)
                }
            }
            ACTION_ITEM_CLICK -> {
                val subject = intent.getStringExtra("subject") ?: ""
                val subjectCode = intent.getStringExtra("subject_code") ?: ""
                val lectureNo = intent.getStringExtra("lecture_no") ?: ""

                val clickIntent = Intent(context, RecordUpdateService::class.java)
                clickIntent.putExtra("subject", subject)
                clickIntent.putExtra("subject_code", subjectCode)
                clickIntent.putExtra("lecture_no", lectureNo)
                context.startService(clickIntent)

                Toast.makeText(context, "Processing record: $subject > $subjectCode > $lectureNo", Toast.LENGTH_SHORT).show()
            }
        }
    }

    override fun onEnabled(context: Context) {
        val serviceIntent = Intent(context, WidgetRefreshService::class.java)
        context.startService(serviceIntent)
    }

    override fun onDisabled(context: Context) {
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

        if (lastUpdated > 0) {
            val dateFormat = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault())
            val lastUpdateTime = dateFormat.format(java.util.Date(lastUpdated))
            views.setTextViewText(R.id.title_text_n_refresh, "${count} @ ${lastUpdateTime}")
        }
    } catch (e: JSONException) {
        views.setTextViewText(R.id.title_text_n_refresh, "${count} @ ${e.message}")
    }
    val refreshIntent = Intent(context, TodayWidget::class.java)
    refreshIntent.action = TodayWidget.ACTION_REFRESH
    val requestCode = appWidgetId + System.currentTimeMillis().toInt()
    val refreshPendingIntent = PendingIntent.getBroadcast(
        context,
        requestCode,
        refreshIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.title_text_n_refresh, refreshPendingIntent)
    val intent = Intent(context, WidgetListViewService::class.java)
    intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
    intent.data = android.net.Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME))
    views.setRemoteAdapter(R.id.widget_listview, intent)
    views.setEmptyView(R.id.widget_listview, R.id.empty_view)
    val clickIntent = Intent(context, TodayWidget::class.java)
    clickIntent.action = TodayWidget.ACTION_ITEM_CLICK
    clickIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
    clickIntent.data = Uri.parse(clickIntent.toUri(Intent.URI_INTENT_SCHEME))
    val clickPendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        clickIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
    )

    views.setPendingIntentTemplate(R.id.widget_listview, clickPendingIntent)
    appWidgetManager.updateAppWidget(appWidgetId, views)
    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_listview)
}