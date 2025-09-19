package com.imnexerio.revix

import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject

class CalendarListViewService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return CalendarListViewFactory(this.applicationContext, intent)
    }
}

class CalendarListViewFactory(
    private val context: Context,
    private val intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private var allItems = mutableListOf<CalendarItem>()

    sealed class CalendarItem {
        data class Record(
            val time: String,
            val category: String,
            val subCategory: String,
            val title: String,
            val color: Int,
            val recordData: Map<String, String> // Store all record data for AlarmScreenActivity
        ) : CalendarItem()

        data class Separator(val text: String) : CalendarItem()
    }

    override fun onCreate() {
        Log.d("CalendarListViewFactory", "onCreate called")
    }

    override fun onDataSetChanged() {
        Log.d("CalendarListViewFactory", "onDataSetChanged called")
        loadAllRecords()
    }

    override fun onDestroy() {
        allItems.clear()
    }

    override fun getCount(): Int = allItems.size

    override fun getViewAt(position: Int): RemoteViews? {
        
        if (position >= allItems.size) {
            return null
        }

        return when (val item = allItems[position]) {
            is CalendarItem.Record -> {
                createRecordView(item)
            }
            is CalendarItem.Separator -> {
                createSeparatorView(item.text)
            }
        }
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 2 // Records and Separators

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    private fun loadAllRecords() {
        try {
            allItems.clear()
            val sharedPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

            // Load today records (no divider needed - they go at the top)
            val todayRecords = loadRecordsFromJson(sharedPrefs.getString("todayRecords", "[]") ?: "[]")
            allItems.addAll(todayRecords)
            Log.d("CalendarListViewFactory", "Added ${todayRecords.size} today records")

            // Load missed records with divider
            val missedRecords = loadRecordsFromJson(sharedPrefs.getString("missedRecords", "[]") ?: "[]")
            if (missedRecords.isNotEmpty()) {
                allItems.add(CalendarItem.Separator("— MISSED —"))
                allItems.addAll(missedRecords)
                Log.d("CalendarListViewFactory", "Added divider and ${missedRecords.size} missed records")
            }

            // Load no reminder records with divider
            val noReminderRecords = loadRecordsFromJson(sharedPrefs.getString("noreminderdate", "[]") ?: "[]")
            if (noReminderRecords.isNotEmpty()) {
                allItems.add(CalendarItem.Separator("— NO REMINDER —"))
                allItems.addAll(noReminderRecords)
                Log.d("CalendarListViewFactory", "Added divider and ${noReminderRecords.size} no reminder records")
            }

            Log.d("CalendarListViewFactory", "Loaded ${allItems.size} total items")
        } catch (e: Exception) {
            Log.e("CalendarListViewFactory", "Error loading records: ${e.message}", e)
        }
    }

    private fun loadRecordsFromJson(jsonString: String): List<CalendarItem.Record> {
        val records = mutableListOf<CalendarItem.Record>()
        
        try {
            val jsonArray = JSONArray(jsonString)
            val tempRecords = mutableListOf<CalendarItem.Record>()
            
            for (i in 0 until jsonArray.length()) {
                val record = jsonArray.getJSONObject(i)
                val category = record.optString("category", "")
                val subCategory = record.optString("sub_category", "")
                val title = record.optString("record_title", "")
                val reminderTime = record.optString("reminder_time", "")
                
                if (category.isNotEmpty() && subCategory.isNotEmpty() && title.isNotEmpty()) {
                    val entryType = record.optString("entry_type", "")
                    val color = LectureColors.getLectureTypeColorSync(context, entryType)
                    
                    // Create recordData map with all JSON fields for AlarmScreenActivity
                    val recordData = mutableMapOf<String, String>()
                    val keys = record.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        recordData[key] = record.optString(key, "")
                    }
                    
                    Log.d("CalendarListViewFactory", "Created record: $title with ${recordData.size} data fields")
                    tempRecords.add(CalendarItem.Record(reminderTime, category, subCategory, title, color, recordData))
                }
            }
            
            // Sort records by time (same logic as WidgetListViewService)
            tempRecords.sortWith(compareBy<CalendarItem.Record> { record ->
                when {
                    record.time.isEmpty() -> "99:99" // Empty times go last
                    record.time == "All Day" -> "99:98" // "All Day" goes last (but before empty times)
                    else -> record.time // Regular times are compared normally
                }
            }.thenBy { it.category }
                .thenBy { it.subCategory }
                .thenBy { it.title })
            
            records.addAll(tempRecords)
            Log.d("CalendarListViewFactory", "Parsed and sorted ${records.size} records from JSON")
        } catch (e: Exception) {
            Log.e("CalendarListViewFactory", "Error parsing JSON: ${e.message}", e)
        }
        
        return records
    }

    private fun createRecordView(record: CalendarItem.Record): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.calendar_record_item)
        
        try {
            // Set the colored stick
            views.setInt(R.id.calendar_record_stick, "setColorFilter", record.color)
            
            // Set the record text in format: Time · Category · Subcategory · Title
            val recordText = if (record.time.isNotEmpty()) {
                "${record.time} · ${record.category} · ${record.subCategory} · ${record.title}"
            } else {
                "${record.category} · ${record.subCategory} · ${record.title}"
            }
            views.setTextViewText(R.id.calendar_record_text, recordText)
            
            // Set up click intent for details view (calendar always shows details)
            val detailsIntent = Intent()
            
            for ((key, value) in record.recordData) {
                detailsIntent.putExtra(key, value)
            }
            // Note: No ACTION_TYPE needed - calendar always goes to details mode
            views.setOnClickFillInIntent(R.id.calendar_record_container, detailsIntent)
            
        } catch (e: Exception) {
            Log.e("CalendarListViewFactory", "Error creating record view: ${e.message}", e)
        }
        
        return views
    }

    private fun createSeparatorView(text: String): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.calendar_separator_item)
        views.setTextViewText(R.id.separator_text, text)
        Log.d("CalendarListViewFactory", "Created separator view: $text")
        return views
    }
}