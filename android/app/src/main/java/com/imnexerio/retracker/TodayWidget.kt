package com.imnexerio.retracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import android.content.SharedPreferences

class TodayWidget : AppWidgetProvider() {
    companion object {
        const val ACTION_REFRESH = "com.imnexerio.retracker.ACTION_REFRESH"
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
        // Enter relevant functionality for when the first widget is created
    }

    override fun onDisabled(context: Context) {
        // Enter relevant functionality for when the last widget is disabled
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == ACTION_REFRESH) {
            // Launch the background service to fetch data
            val serviceIntent = Intent(context, WidgetRefreshService::class.java)
            context.startService(serviceIntent)

            // Update all widgets
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(context, TodayWidget::class.java)
            )

            for (appWidgetId in appWidgetIds) {
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_listview)
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

    try {
        val jsonArray = JSONArray(jsonData)
        val count = jsonArray.length()

        views.setTextViewText(R.id.title_text, "Today's Schedule (${count})")

        if (!isLoggedIn) {
            views.setTextViewText(R.id.empty_view, "Please login to view your schedule")
        } else {
            views.setTextViewText(R.id.empty_view, "No tasks for today, enjoy your day")
        }
    } catch (e: JSONException) {
        e.printStackTrace()
        views.setTextViewText(R.id.title_text, "Today's Schedule (0)")
    }

    // Set up the refresh button click
    val refreshIntent = Intent(context, TodayWidget::class.java)
    refreshIntent.action = TodayWidget.ACTION_REFRESH
    val refreshPendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        refreshIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)

    val intent = Intent(context, WidgetListViewService::class.java)
    views.setRemoteAdapter(R.id.widget_listview, intent)
    views.setEmptyView(R.id.widget_listview, R.id.empty_view)
    appWidgetManager.updateAppWidget(appWidgetId, views)
    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_listview)
}
class WidgetListViewService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return WidgetListViewFactory(this.applicationContext)
    }
}


class WidgetListViewFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val todayRecords = ArrayList<Map<String, String>>()

    private val sharedPreferences: SharedPreferences = context.getSharedPreferences(
        "HomeWidgetPreferences", Context.MODE_PRIVATE)

    override fun onDataSetChanged() {
        todayRecords.clear()

        try {
            val jsonData = sharedPreferences.getString("todayRecords", "[]")

            if (jsonData != null && jsonData.isNotEmpty() && jsonData != "[]") {
                val jsonArray = JSONArray(jsonData)

                for (i in 0 until jsonArray.length()) {
                    val jsonObject = jsonArray.getJSONObject(i)
                    val record = mapOf(
                        "subject" to jsonObject.optString("subject", ""),
                        "subject_code" to jsonObject.optString("subject_code", ""),
                        "lecture_no" to jsonObject.optString("lecture_no", "")
                    )
                    todayRecords.add(record)
                }
            }
        } catch (e: JSONException) {
            e.printStackTrace()
        }
    }


    override fun onCreate() {
        // Initialize if needed
    }


    override fun onDestroy() {
        todayRecords.clear()
    }

    override fun getCount(): Int {
        return todayRecords.size
    }

    override fun getViewAt(position: Int): RemoteViews {
        if (position >= todayRecords.size) {
            return RemoteViews(context.packageName, R.layout.widget_list_item)
        }

        val record = todayRecords[position]
        val rv = RemoteViews(context.packageName, R.layout.widget_list_item)

        rv.setTextViewText(R.id.item_subject, record["subject"])
        rv.setTextViewText(R.id.item_subject_code, record["subject_code"])
        rv.setTextViewText(R.id.item_lecture_no, record["lecture_no"])

        val fillInIntent = Intent()
        fillInIntent.putExtra("position", position)
        rv.setOnClickFillInIntent(R.id.item_subject, fillInIntent)

        return rv
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun hasStableIds(): Boolean {
        return true
    }
}