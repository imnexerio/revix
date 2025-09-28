package com.imnexerio.revix

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONException
import android.content.SharedPreferences
import android.graphics.Paint
import android.util.Log

class UnifiedWidgetListViewService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val viewType = intent.getStringExtra("viewType") ?: "combined"
        return UnifiedWidgetListViewFactory(this.applicationContext, viewType)
    }
}

class UnifiedWidgetListViewFactory(
    private val context: Context,
    private val viewType: String = "combined"
) : RemoteViewsService.RemoteViewsFactory {
    
    private val allItems = mutableListOf<WidgetItem>()
    private val sharedPreferences: SharedPreferences = context.getSharedPreferences(
        "HomeWidgetPreferences", Context.MODE_PRIVATE)

    private var lastRefreshTimestamp = 0L

    sealed class WidgetItem {
        data class Record(
            val recordData: Map<String, String>
        ) : WidgetItem()

        data class Separator(val text: String) : WidgetItem()
    }

    override fun onDataSetChanged() {
        allItems.clear()

        try {
            when (viewType) {
                "combined", "calendar" -> {
                    // Load all records with separators in priority order: Today -> Tomorrow -> Missed -> No Reminder
                    loadCombinedRecordsWithSeparators()
                }
                "calendar_only" -> {
                    // Calendar-only widget has no records
                    // Keep allItems empty
                }
                else -> {
                    // Fallback to combined for unknown view types
                    loadCombinedRecordsWithSeparators()
                }
            }

            // Update last refresh timestamp
            lastRefreshTimestamp = sharedPreferences.getLong("lastUpdated", 0L)
            
            Log.d("UnifiedWidgetListViewFactory", "Data loaded for viewType: $viewType, items count: ${allItems.size}")
        } catch (e: Exception) {
            Log.e("UnifiedWidgetListViewFactory", "Error loading data for viewType: $viewType", e)
        }
    }

    private fun loadCombinedRecordsWithSeparators() {
        // Load records for each category with separators (skip separator for today records - they go first)
        val categoryData = mapOf(
            "todayRecords" to null, // No separator for today records - they go at the top
            "tomorrowRecords" to "— TOMORROW —", 
            "missedRecords" to "— MISSED —",
            "noreminderdate" to "— NO REMINDER —"
        )

        for ((dataKey, separatorText) in categoryData) {
            val records = loadRecordsFromKey(dataKey)
            if (records.isNotEmpty()) {
                // Add separator only if separatorText is not null (skip for today records)
                if (separatorText != null) {
                    allItems.add(WidgetItem.Separator(separatorText))
                }
                
                // Sort records within this category by reminder_time, category, sub_category, record_title
                val sortedRecords = records.sortedWith(compareBy<Map<String, String>> { map ->
                    val reminderTime = map["reminder_time"] ?: ""
                    when {
                        reminderTime.isEmpty() -> "99:99" // Empty times go last
                        reminderTime == "All Day" -> "99:98" // "All Day" goes last (but before empty times)
                        else -> reminderTime // Regular times are compared normally
                    }
                }.thenBy { it["category"] ?: "" }
                    .thenBy { it["sub_category"] ?: "" }
                    .thenBy { it["record_title"] ?: "" })

                // Add all sorted records for this category
                sortedRecords.forEach { record ->
                    allItems.add(WidgetItem.Record(record))
                }

                val logMessage = if (separatorText != null) {
                    "Added separator '$separatorText' and ${sortedRecords.size} records"
                } else {
                    "Added ${sortedRecords.size} today records (no separator)"
                }
                Log.d("UnifiedWidgetListViewFactory", logMessage)
            }
        }
    }

    private fun loadRecordsFromKey(key: String): List<Map<String, String>> {
        val recordsList = mutableListOf<Map<String, String>>()
        val jsonData = sharedPreferences.getString(key, "[]")

        if (jsonData != null && jsonData.isNotEmpty() && jsonData != "[]") {
            try {
                val jsonArray = JSONArray(jsonData)

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
                            recordsList.add(record)
                        }
                    } catch (e: Exception) {
                        Log.e("UnifiedWidgetListViewFactory", "Error parsing individual record from $key", e)
                    }
                }
            } catch (e: JSONException) {
                Log.e("UnifiedWidgetListViewFactory", "Error parsing JSON from $key", e)
            }
        }

        return recordsList
    }

    override fun getViewAt(position: Int): RemoteViews {
        if (position >= allItems.size) {
            return RemoteViews(context.packageName, R.layout.widget_list_item)
        }

        val item = allItems[position]

        return when (item) {
            is WidgetItem.Record -> {
                createRecordView(item.recordData)
            }
            is WidgetItem.Separator -> {
                createSeparatorView(item.text)
            }
        }
    }

    private fun createRecordView(record: Map<String, String>): RemoteViews {
        val rv = RemoteViews(context.packageName, R.layout.widget_list_item)

        // Apply lecture type color to the colored stick based on entry_type
        val entryType = record["entry_type"] ?: ""
        val indicatorColor = LectureColors.getLectureTypeColorSync(context, entryType)
        
        // Debug log to check if colors are being generated
        Log.d("WidgetColors", "Entry Type: $entryType, Color: ${Integer.toHexString(indicatorColor)}")
        
        // Set the colored stick
        rv.setInt(R.id.calendar_record_stick, "setColorFilter", indicatorColor)
        
        // Set the record text in format: Time · Category · Subcategory · Title (exactly like your sample)
        val time = record["reminder_time"] ?: ""
        val category = record["category"] ?: ""
        val subCategory = record["sub_category"] ?: ""
        val title = record["record_title"] ?: ""
        
        val recordText = if (time.isNotEmpty()) {
            "$time · $category · $subCategory · $title"
        } else {
            "$category · $subCategory · $title"
        }
        rv.setTextViewText(R.id.calendar_record_text, recordText)

        // Check if this item is being processed and apply strikethrough
        val processingItems = sharedPreferences.getStringSet(TodayWidget.PREF_PROCESSING_ITEMS, emptySet()) ?: emptySet()
        val itemKey = "${category}_${subCategory}_${title}"
        val isProcessing = processingItems.contains(itemKey)

        val normalFlags = Paint.ANTI_ALIAS_FLAG
        val strikethroughFlags = Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG

        // Set the paint flags based on whether the item is being processed
        rv.setInt(R.id.calendar_record_text, "setPaintFlags", if (isProcessing) strikethroughFlags else normalFlags)

        // Show mark as done button only for TodayWidget (viewType = "combined")
        if (viewType == "combined") {
            rv.setViewVisibility(R.id.mark_as_done_circle, android.view.View.VISIBLE)
            
            // Create and fill the intent with all record data for mark as done
            val markAsDoneIntent = Intent()
            for ((key, value) in record) {
                markAsDoneIntent.putExtra(key, value)
            }
            // Set click intent on the mark as done button
            rv.setOnClickFillInIntent(R.id.mark_as_done_circle, markAsDoneIntent)
        } else {
            rv.setViewVisibility(R.id.mark_as_done_circle, android.view.View.GONE)
        }

        // Set the click intent on the container for details view
        val detailsIntent = Intent()
        for ((key, value) in record) {
            detailsIntent.putExtra(key, value)
        }
        detailsIntent.putExtra("ACTION_TYPE", "VIEW_DETAILS") // Add flag to distinguish
        rv.setOnClickFillInIntent(R.id.calendar_record_text, detailsIntent)

        return rv
    }

    private fun createSeparatorView(text: String): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.calendar_separator_item)
        views.setTextViewText(R.id.separator_text, text)
        Log.d("UnifiedWidgetListViewFactory", "Created separator view: $text")
        return views
    }

    override fun onCreate() {
        Log.d("UnifiedWidgetListViewFactory", "Factory created for viewType: $viewType")
    }
    
    override fun onDestroy() {
        allItems.clear()
        Log.d("UnifiedWidgetListViewFactory", "Factory destroyed for viewType: $viewType")
    }

    override fun getCount(): Int {
        return allItems.size
    }
    
    override fun getLoadingView(): RemoteViews? { return null }
    override fun getViewTypeCount(): Int { return 2 } // Records and Separators
    override fun getItemId(position: Int): Long { return position.toLong() }
    override fun hasStableIds(): Boolean { return true }
}