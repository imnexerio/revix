package com.imnexerio.revix

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONException
import android.content.SharedPreferences
import android.graphics.Paint
import com.imnexerio.revix.R

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
    private val tomorrowRecords = ArrayList<Map<String, String>>()  // NEW
    private val missedRecords = ArrayList<Map<String, String>>()
    private val noReminderDateRecords = ArrayList<Map<String, String>>()

    private val sharedPreferences: SharedPreferences = context.getSharedPreferences(
        "HomeWidgetPreferences", Context.MODE_PRIVATE)

    private var lastRefreshTimestamp = 0L
    override fun onDataSetChanged() {
        todayRecords.clear()
        tomorrowRecords.clear()  // NEW
        missedRecords.clear()
        noReminderDateRecords.clear()

        try {
            // Load today's records
            loadRecords("todayRecords", todayRecords)

            // Load tomorrow's records  // NEW
            loadRecords("tomorrowRecords", tomorrowRecords)

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
                        val essentialFields = listOf("category", "sub_category", "record_title")
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

                // Sort the records based on reminder_time, category, sub_category, and record_title
                tempRecords.sortWith(compareBy<Map<String, String>> { map ->
                    val reminderTime = map["reminder_time"] ?: ""
                    when {
                        reminderTime.isEmpty() -> "99:99" // Empty times go last
                        reminderTime == "All Day" -> "99:98" // "All Day" goes last (but before empty times)
                        else -> reminderTime // Regular times are compared normally
                    }
                }.thenBy { it["category"] ?: "" }
                    .thenBy { it["sub_category"] ?: "" }
                    .thenBy { it["record_title"] ?: "" })

                // Add all sorted records to the final list
                recordsList.addAll(tempRecords)
            } catch (e: JSONException) {
                e.printStackTrace()
            }
        }
    }    override fun getViewAt(position: Int): RemoteViews {
        val records = when (viewType) {
            "tomorrow" -> tomorrowRecords  // NEW
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
        val itemKey = "${record["category"]}_${record["sub_category"]}_${record["record_title"]}"
        val isProcessing = processingItems.contains(itemKey)        // Set the combined subject info
        val subjectInfo = "${record["category"]} · ${record["sub_category"]} · ${record["record_title"]}"
        rv.setTextViewText(R.id.item_subject_info, subjectInfo)
        
        // Apply lecture type color to the rounded line indicator based on entry_type
        val entryType = record["entry_type"] ?: ""
        val indicatorColor = LectureColors.getLectureTypeColorSync(context, entryType)
        
        // Debug log to check if colors are being generated
        android.util.Log.d("WidgetColors", "Entry Type: $entryType, Color: ${Integer.toHexString(indicatorColor)}")
        
        rv.setInt(R.id.lecture_type_indicator, "setBackgroundColor", indicatorColor)        // Set the combined reminder info
        val reminderInfoParts = mutableListOf<String>()
        if (record.containsKey("reminder_time") && !record["reminder_time"].isNullOrEmpty()) {
            reminderInfoParts.add(record["reminder_time"]!!)
        }
        if (record.containsKey("scheduled_date") && !record["scheduled_date"].isNullOrEmpty()) {
            reminderInfoParts.add(record["scheduled_date"]!!)
        }
        if (record.containsKey("recurrence_frequency") && !record["recurrence_frequency"].isNullOrEmpty()) {
            reminderInfoParts.add(record["recurrence_frequency"]!!)
        }
        val reminderInfo = reminderInfoParts.joinToString(" · ")
        rv.setTextViewText(R.id.item_reminder_info, reminderInfo)

        val normalFlags = Paint.ANTI_ALIAS_FLAG
        val strikethroughFlags = Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG        // Set the paint flags based on whether the item is being processed
        rv.setInt(R.id.item_subject_info, "setPaintFlags", if (isProcessing) strikethroughFlags else normalFlags)

        // Apply paint flags to the reminder info as well
        rv.setInt(R.id.item_reminder_info, "setPaintFlags", if (isProcessing) strikethroughFlags else normalFlags)

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
    }    override fun getCount(): Int {
        return when (viewType) {
            "tomorrow" -> tomorrowRecords.size  // NEW
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