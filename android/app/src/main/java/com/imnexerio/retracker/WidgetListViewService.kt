package com.imnexerio.retracker

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONException
import android.content.SharedPreferences

class WidgetListViewService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return WidgetListViewFactory(this.applicationContext)
    }
}

class WidgetListViewFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val todayRecords = ArrayList<Map<String, String>>()

    private val sharedPreferences: SharedPreferences = context.getSharedPreferences(
        "HomeWidgetPreferences", Context.MODE_PRIVATE)

    private var lastRefreshTimestamp = 0L

    override fun onDataSetChanged() {
        todayRecords.clear()

        try {
            val jsonData = sharedPreferences.getString("todayRecords", "[]")
            lastRefreshTimestamp = sharedPreferences.getLong("lastUpdated", 0L)

            if (jsonData != null && jsonData.isNotEmpty() && jsonData != "[]") {
                val jsonArray = JSONArray(jsonData)

                for (i in 0 until jsonArray.length()) {
                    try {
                        val jsonObject = jsonArray.getJSONObject(i)
                        val record = mapOf(
                            "subject" to jsonObject.optString("subject", ""),
                            "subject_code" to jsonObject.optString("subject_code", ""),
                            "lecture_no" to jsonObject.optString("lecture_no", ""),
                            "reminder_time" to jsonObject.optString("reminder_time", "")
                        )
                        todayRecords.add(record)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            }
        } catch (e: JSONException) {
            e.printStackTrace()
        }
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
        rv.setTextViewText(R.id.item_reminder_time, record["reminder_time"])

        val fillInIntent = Intent()
        fillInIntent.putExtra("subject", record["subject"])
        fillInIntent.putExtra("subject_code", record["subject_code"])
        fillInIntent.putExtra("lecture_no", record["lecture_no"])
        fillInIntent.putExtra("reminder_time", record["reminder_time"])
        rv.setOnClickFillInIntent(R.id.list_item_container, fillInIntent)

        return rv
    }

    override fun onCreate() {}
    override fun onDestroy() { todayRecords.clear() }
    override fun getCount(): Int { return todayRecords.size }
    override fun getLoadingView(): RemoteViews? { return null }
    override fun getViewTypeCount(): Int { return 1 }
    override fun getItemId(position: Int): Long { return position.toLong() }
    override fun hasStableIds(): Boolean { return true }
}

