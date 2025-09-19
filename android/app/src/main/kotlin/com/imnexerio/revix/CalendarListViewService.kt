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
            val category: String,
            val subCategory: String,
            val title: String,
            val color: Int
        ) : CalendarItem()

        object Separator : CalendarItem()
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
        if (position >= allItems.size) return null

        return when (val item = allItems[position]) {
            is CalendarItem.Record -> createRecordView(item)
            is CalendarItem.Separator -> createSeparatorView()
        }
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 2 // Record and Separator

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    private fun loadAllRecords() {
        try {
            allItems.clear()
            val sharedPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

            // Load today records
            val todayRecords = loadRecordsFromJson(sharedPrefs.getString("todayRecords", "[]") ?: "[]")
            if (todayRecords.isNotEmpty()) {
                allItems.addAll(todayRecords)
                allItems.add(CalendarItem.Separator)
            }

            // Load missed records
            val missedRecords = loadRecordsFromJson(sharedPrefs.getString("missedRecords", "[]") ?: "[]")
            if (missedRecords.isNotEmpty()) {
                allItems.addAll(missedRecords)
                allItems.add(CalendarItem.Separator)
            }

            // Load no reminder records
            val noReminderRecords = loadRecordsFromJson(sharedPrefs.getString("noreminderdate", "[]") ?: "[]")
            if (noReminderRecords.isNotEmpty()) {
                allItems.addAll(noReminderRecords)
            }

            // Remove trailing separator if exists
            if (allItems.isNotEmpty() && allItems.last() is CalendarItem.Separator) {
                allItems.removeAt(allItems.size - 1)
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
            
            for (i in 0 until jsonArray.length()) {
                val record = jsonArray.getJSONObject(i)
                val category = record.optString("category", "")
                val subCategory = record.optString("sub_category", "")
                val title = record.optString("record_title", "")
                
                if (category.isNotEmpty() && subCategory.isNotEmpty() && title.isNotEmpty()) {
                    val color = LectureColors.getLectureTypeColorSync(context, category)
                    records.add(CalendarItem.Record(category, subCategory, title, color))
                }
            }
            
            Log.d("CalendarListViewFactory", "Parsed ${records.size} records from JSON")
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
            
            // Set the record text in format: Category · Subcategory · Title
            val recordText = "${record.category} · ${record.subCategory} · ${record.title}"
            views.setTextViewText(R.id.calendar_record_text, recordText)
            
        } catch (e: Exception) {
            Log.e("CalendarListViewFactory", "Error creating record view: ${e.message}", e)
        }
        
        return views
    }

    private fun createSeparatorView(): RemoteViews {
        return RemoteViews(context.packageName, R.layout.calendar_separator_item)
    }
}