package com.imnexerio.retracker

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONException
import android.content.SharedPreferences
import android.graphics.Paint

class WidgetListViewService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val viewType = intent.getStringExtra("viewType") ?: "today"
        return WidgetListViewFactory(this.applicationContext, viewType)
    }
}

class WidgetListViewFactory(
    private val context: Context,
    private val viewType: String = "today"
) : RemoteViewsService.RemoteViewsFactory {
    private val todayRecords = ArrayList<Map<String, String>>()
    private val missedRecords = ArrayList<Map<String, String>>()
    private val noReminderDateRecords = ArrayList<Map<String, String>>()

    private val sharedPreferences: SharedPreferences = context.getSharedPreferences(
        "HomeWidgetPreferences", Context.MODE_PRIVATE)

    private var lastRefreshTimestamp = 0L

    override fun onDataSetChanged() {
        todayRecords.clear()
        missedRecords.clear()
        noReminderDateRecords.clear()

        try {
            // Load today's records
            loadRecords("todayRecords", todayRecords)

            // Load missed records
            loadRecords("missedRecords", missedRecords)

            // Load no reminder date records
            loadRecords("noreminderdate", noReminderDateRecords)

            // Update last refresh timestamp
            lastRefreshTimestamp = sharedPreferences.getLong("lastUpdated", 0L)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun loadRecords(key: String, recordsList: ArrayList<Map<String, String>>) {
        val jsonData = sharedPreferences.getString(key, "[]")

        if (jsonData != null && jsonData.isNotEmpty() && jsonData != "[]") {
            try {
                val jsonArray = JSONArray(jsonData)
                val tempRecords = ArrayList<Map<String, String>>()

                for (i in 0 until jsonArray.length()) {
                    try {
                        val jsonObject = jsonArray.getJSONObject(i)
                        val record = mutableMapOf<String, String>()

                        // Iterate through all fields in the JSON object
                        val keys = jsonObject.keys()
                        while (keys.hasNext()) {
                            val fieldKey = keys.next()
                            record[fieldKey] = jsonObject.optString(fieldKey, "")
                        }

                        // Ensure essential fields are present
                        val essentialFields = listOf("subject", "subject_code", "lecture_no")
                        var hasAllEssentialFields = true

                        for (field in essentialFields) {
                            if (!record.containsKey(field) || record[field].isNullOrEmpty()) {
                                hasAllEssentialFields = false
                                break
                            }
                        }

                        if (hasAllEssentialFields) {
                            tempRecords.add(record)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }

                // Sort the records based on reminder_time, subject, subject_code, and lecture_no
                tempRecords.sortWith(compareBy<Map<String, String>> { map ->
                    val reminderTime = map["reminder_time"] ?: ""
                    when {
                        reminderTime.isEmpty() -> "99:99" // Empty times go last
                        reminderTime == "All Day" -> "99:98" // "All Day" goes last (but before empty times)
                        else -> reminderTime // Regular times are compared normally
                    }
                }.thenBy { it["subject"] ?: "" }
                    .thenBy { it["subject_code"] ?: "" }
                    .thenBy { it["lecture_no"] ?: "" })

                // Add all sorted records to the final list
                recordsList.addAll(tempRecords)
            } catch (e: JSONException) {
                e.printStackTrace()
            }
        }
    }

    override fun getViewAt(position: Int): RemoteViews {
        val records = when (viewType) {
            "missed" -> missedRecords
            "noreminder" -> noReminderDateRecords
            else -> todayRecords
        }

        if (position >= records.size) {
            return RemoteViews(context.packageName, R.layout.widget_list_item)
        }

        val record = records[position]
        val rv = RemoteViews(context.packageName, R.layout.widget_list_item)

        // NEW CODE: Check if this item is being processed
        val processingItems = sharedPreferences.getStringSet(TodayWidget.PREF_PROCESSING_ITEMS, emptySet()) ?: emptySet()
        val itemKey = "${record["subject"]}_${record["subject_code"]}_${record["lecture_no"]}"
        val isProcessing = processingItems.contains(itemKey)

        // Set all the available fields to the corresponding TextViews
        rv.setTextViewText(R.id.item_subject, record["subject"])
        rv.setTextViewText(R.id.item_subject_code, record["subject_code"])
        rv.setTextViewText(R.id.item_lecture_no, record["lecture_no"])

        // Check if the fields exist before setting them
        if (record.containsKey("reminder_time")) {
            rv.setTextViewText(R.id.item_reminder_time, record["reminder_time"])
        }

        if (record.containsKey("date_scheduled")) {
            rv.setTextViewText(R.id.item_reminder_date, record["date_scheduled"])
        }

        if (record.containsKey("revision_frequency")) {
            rv.setTextViewText(R.id.item_reminder_frequency, record["revision_frequency"])
        }

        val normalFlags = Paint.ANTI_ALIAS_FLAG
        val strikethroughFlags = Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG

        // Set the paint flags based on whether the item is being processed
        rv.setInt(R.id.item_subject, "setPaintFlags", if (isProcessing) strikethroughFlags else normalFlags)
        rv.setInt(R.id.item_subject_code, "setPaintFlags", if (isProcessing) strikethroughFlags else normalFlags)
        rv.setInt(R.id.item_lecture_no, "setPaintFlags", if (isProcessing) strikethroughFlags else normalFlags)

        // Apply paint flags to the optional fields as well
        rv.setInt(R.id.item_reminder_time, "setPaintFlags", if (isProcessing) strikethroughFlags else normalFlags)
        rv.setInt(R.id.item_reminder_date, "setPaintFlags", if (isProcessing) strikethroughFlags else normalFlags)
        rv.setInt(R.id.item_reminder_frequency, "setPaintFlags", if (isProcessing) strikethroughFlags else normalFlags)

        // Create and fill the intent with all record data
        val fillInIntent = Intent()
        for ((key, value) in record) {
            fillInIntent.putExtra(key, value)
        }

        // Set the click intent on mark_as_done button
        rv.setOnClickFillInIntent(R.id.mark_as_done, fillInIntent)

        return rv
    }

    override fun onCreate() {}
    override fun onDestroy() {
        todayRecords.clear()
        missedRecords.clear()
        noReminderDateRecords.clear()
    }
    override fun getCount(): Int {
        return when (viewType) {
            "missed" -> missedRecords.size
            "noreminder" -> noReminderDateRecords.size
            else -> todayRecords.size
        }
    }
    override fun getLoadingView(): RemoteViews? { return null }
    override fun getViewTypeCount(): Int { return 1 }
    override fun getItemId(position: Int): Long { return position.toLong() }
    override fun hasStableIds(): Boolean { return true }
}