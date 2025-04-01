package com.imnexerio.retracker

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
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

/**
 * Implementation of App Widget functionality.
 */
class TodayWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // There may be multiple widgets active, so update all of them
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
}

internal fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    // Create remote views
    val views = RemoteViews(context.packageName, R.layout.today_widget)

    // Set up the intent for the ListView adapter service
    val intent = Intent(context, WidgetListViewService::class.java)
    views.setRemoteAdapter(R.id.widget_listview, intent)

    // Set empty view
    views.setEmptyView(R.id.widget_listview, R.id.empty_view)

    // Instruct the widget manager to update the widget
    appWidgetManager.updateAppWidget(appWidgetId, views)
    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_listview)
}

/**
 * Service that will provide data for the list view
 */
class WidgetListViewService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return WidgetListViewFactory(this.applicationContext)
    }
}

/**
 * Factory for list view items
 */

class WidgetListViewFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val todayRecords = ArrayList<Map<String, String>>()

    // Use the correct preferences name that matches home_widget plugin's storage
    private val sharedPreferences: SharedPreferences = context.getSharedPreferences(
        "HomeWidgetPreferences", Context.MODE_PRIVATE)

    override fun onDataSetChanged() {
        // Clear current data
        todayRecords.clear()

        // Fetch data from shared preferences
        try {
            // Use the correct key that matches what you set in HomeWidgetService
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

        // Set data to views
        rv.setTextViewText(R.id.item_subject, record["subject"])
        rv.setTextViewText(R.id.item_subject_code, record["subject_code"])
        rv.setTextViewText(R.id.item_lecture_no, record["lecture_no"])

        // Set up fill-in intent for item clicks
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