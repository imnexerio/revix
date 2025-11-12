package com.imnexerio.revix

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import java.time.LocalDate
import java.time.temporal.ChronoUnit

sealed class ValidationResult {
    object NO_SELECTION : ValidationResult()
    object RECORD_DELETED : ValidationResult()
    data class DATE_CHANGED(val newDate: String) : ValidationResult()
    object VALID : ValidationResult()
}

class CounterWidget : AppWidgetProvider() {

    companion object {
        const val ACTION_SELECT_RECORD = "revix.ACTION_SELECT_RECORD"

        // Per-widget storage keys
        fun getSelectedRecordKey(appWidgetId: Int) = "counter_widget_${appWidgetId}_record"
        fun getTargetDateKey(appWidgetId: Int) = "counter_widget_${appWidgetId}_target_date"
        fun getRecordTitleKey(appWidgetId: Int) = "counter_widget_${appWidgetId}_title"
        fun getCategoryKey(appWidgetId: Int) = "counter_widget_${appWidgetId}_category"
        fun getSubCategoryKey(appWidgetId: Int) = "counter_widget_${appWidgetId}_subcategory"

        private fun validateWidgetRecord(context: Context, appWidgetId: Int): ValidationResult {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            
            // Get stored widget data
            val storedCategory = prefs.getString(getCategoryKey(appWidgetId), "") ?: ""
            val storedSubcategory = prefs.getString(getSubCategoryKey(appWidgetId), "") ?: ""
            val storedTitle = prefs.getString(getRecordTitleKey(appWidgetId), "") ?: ""
            val storedDate = prefs.getString(getTargetDateKey(appWidgetId), "") ?: ""
            
            if (storedCategory.isEmpty() || storedSubcategory.isEmpty() || storedTitle.isEmpty()) {
                return ValidationResult.NO_SELECTION
            }
            
            // Lookup current scheduled_date for this record
            val currentDate = lookupScheduledDate(context, storedCategory, storedSubcategory, storedTitle)
            
            return when {
                currentDate == null -> ValidationResult.RECORD_DELETED
                currentDate != storedDate -> ValidationResult.DATE_CHANGED(currentDate)
                else -> ValidationResult.VALID
            }
        }

        private fun lookupScheduledDate(context: Context, category: String, subcategory: String, title: String): String? {
            try {
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val allRecordsJson = prefs.getString("allRecords", "{}") ?: "{}"
                
                // Parse nested structure: { "category": { "subcategory": { "title": {...} } } }
                val allRecordsObject = org.json.JSONObject(allRecordsJson)
                
                // Navigate: allRecords → category → subcategory → title
                if (!allRecordsObject.has(category)) {
                    Log.d("CounterWidget", "Category '$category' not found in allRecords")
                    return null
                }
                val categoryObject = allRecordsObject.getJSONObject(category)
                
                if (!categoryObject.has(subcategory)) {
                    Log.d("CounterWidget", "Subcategory '$subcategory' not found in category '$category'")
                    return null
                }
                val subcategoryObject = categoryObject.getJSONObject(subcategory)
                
                if (!subcategoryObject.has(title)) {
                    Log.d("CounterWidget", "Record '$title' not found in '$category'→'$subcategory'")
                    return null
                }
                val recordObject = subcategoryObject.getJSONObject(title)
                
                // Extract scheduled_date directly from record object (Option A)
                var scheduledDate = recordObject.optString("scheduled_date", "")
                
                // Normalize empty dates to "Unspecified"
                if (scheduledDate.isEmpty()) {
                    scheduledDate = "Unspecified"
                }
                
                Log.d("CounterWidget", "Found scheduled_date for $category→$subcategory→$title: $scheduledDate")
                return scheduledDate
                
            } catch (e: Exception) {
                Log.e("CounterWidget", "Error looking up scheduled date: ${e.message}", e)
                return null
            }
        }

        private fun resetWidgetPreferences(context: Context, appWidgetId: Int) {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            
            editor.remove(getSelectedRecordKey(appWidgetId))
            editor.remove(getTargetDateKey(appWidgetId))
            editor.remove(getRecordTitleKey(appWidgetId))
            editor.remove(getCategoryKey(appWidgetId))
            editor.remove(getSubCategoryKey(appWidgetId))
            editor.apply()
            
            Log.d("CounterWidget", "Reset preferences for widget $appWidgetId")
        }

        private fun updateStoredDate(context: Context, appWidgetId: Int, newDate: String) {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            prefs.edit()
                .putString(getTargetDateKey(appWidgetId), newDate)
                .apply()
            
            Log.d("CounterWidget", "Updated stored date for widget $appWidgetId: $newDate")
        }

        fun updateCounterWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.counter_widget)
                
                // Validate widget record before displaying
                when (val validationResult = validateWidgetRecord(context, appWidgetId)) {
                    is ValidationResult.NO_SELECTION -> {
                        showSelectionPrompt(views)
                    }
                    
                    is ValidationResult.RECORD_DELETED -> {
                        Log.w("CounterWidget", "Record deleted for widget $appWidgetId, resetting")
                        resetWidgetPreferences(context, appWidgetId)
                        showSelectionPrompt(views)
                    }
                    
                    is ValidationResult.DATE_CHANGED -> {
                        Log.i("CounterWidget", "Date changed for widget $appWidgetId: ${validationResult.newDate}")
                        updateStoredDate(context, appWidgetId, validationResult.newDate)
                        displayValidRecord(context, views, appWidgetId, validationResult.newDate)
                    }
                    
                    is ValidationResult.VALID -> {
                        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                        val storedDate = prefs.getString(getTargetDateKey(appWidgetId), "") ?: ""
                        displayValidRecord(context, views, appWidgetId, storedDate)
                    }
                }

                // Set up click listeners
                setupSelectRecordListener(context, views, appWidgetId)
                setupRefreshListener(context, views, appWidgetId)
                setupAddButtonListener(context, views, appWidgetId)
                setupStickClickListener(context, views, appWidgetId)
                appWidgetManager.updateAppWidget(appWidgetId, views)

            } catch (e: Exception) {
                Log.e("CounterWidget", "Error updating counter widget $appWidgetId: ${e.message}", e)
            }
        }

        private fun showSelectionPrompt(views: RemoteViews) {
            views.setTextViewText(R.id.counter_text, "Tap\nselect")
            views.setTextViewText(R.id.category_text, "Category")
            views.setTextViewText(R.id.subcategory_text, "Subcategory")
            views.setTextViewText(R.id.record_title, "Record Title")
            views.setInt(R.id.lecture_type_indicator, "setColorFilter", android.graphics.Color.parseColor("#666666"))
        }

        private fun displayValidRecord(context: Context, views: RemoteViews, appWidgetId: Int, scheduledDate: String) {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val recordTitle = prefs.getString(getRecordTitleKey(appWidgetId), "") ?: ""
            val category = prefs.getString(getCategoryKey(appWidgetId), "") ?: ""
            val subCategory = prefs.getString(getSubCategoryKey(appWidgetId), "") ?: ""

            // Get entry_type for coloring from allRecords
            val entryType = lookupEntryType(context, category, subCategory, recordTitle)
            
            // Handle different date types
            when (scheduledDate) {
                "Unspecified", "" -> {
                    // Show infinity symbol with colorOnPrimary (special case)
                    views.setTextViewText(R.id.counter_text, "∞")
//                    views.setTextColor(R.id.counter_text, context.getColor(R.color.colorOnPrimary))
                }
                else -> {
                    // Normal countdown calculation
                    val daysRemaining = calculateDaysRemaining(scheduledDate)
                    val counterText = formatCounterText(daysRemaining)
                    views.setTextViewText(R.id.counter_text, counterText)
                    
//                    if (daysRemaining < 0) {
//                        val overdueColor = context.getColor(R.color.overdue)
//                        views.setTextColor(R.id.counter_text, overdueColor)
//                        views.setTextColor(R.id.category_text, overdueColor)
//                        views.setTextColor(R.id.subcategory_text, overdueColor)
//                        views.setTextColor(R.id.record_title, overdueColor)
//                    }
                }
            }
            
            // Apply entry_type color to stick indicator
            val stickColor = LectureColors.getLectureTypeColorSync(context, entryType)
            views.setInt(R.id.lecture_type_indicator, "setColorFilter", stickColor)

            // Set all text fields: Category / Subcategory / Record Title
            views.setTextViewText(R.id.category_text, category)
            views.setTextViewText(R.id.subcategory_text, subCategory)
            views.setTextViewText(R.id.record_title, recordTitle)

            Log.d("CounterWidget", "Updated widget $appWidgetId: $category→$subCategory→$recordTitle (date: $scheduledDate)")
        }

        private fun lookupEntryType(context: Context, category: String, subcategory: String, title: String): String {
            try {
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val allRecordsJson = prefs.getString("allRecords", "{}") ?: "{}"
                val allRecordsObject = org.json.JSONObject(allRecordsJson)
                
                val recordObject = allRecordsObject
                    .optJSONObject(category)
                    ?.optJSONObject(subcategory)
                    ?.optJSONObject(title)
                
                return recordObject?.optString("entry_type", "") ?: ""
            } catch (e: Exception) {
                Log.e("CounterWidget", "Error looking up entry_type: ${e.message}")
                return ""
            }
        }

        fun updateAllCounterWidgets(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, CounterWidget::class.java)
                )

                for (appWidgetId in appWidgetIds) {
                    updateCounterWidget(context, appWidgetManager, appWidgetId)
                }

                Log.d("CounterWidget", "Updated ${appWidgetIds.size} counter widgets")
            } catch (e: Exception) {
                Log.e("CounterWidget", "Error updating all counter widgets: ${e.message}", e)
            }
        }

        fun clearAllCounterWidgets(context: Context) {
            try {
                Log.d("CounterWidget", "Clearing all counter widget preferences...")
                
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, CounterWidget::class.java)
                )
                
                // Clear preferences for each widget
                for (appWidgetId in appWidgetIds) {
                    resetWidgetPreferences(context, appWidgetId)
                }
                
                // Update all widgets to show selection prompt
                for (appWidgetId in appWidgetIds) {
                    updateCounterWidget(context, appWidgetManager, appWidgetId)
                }
                
                Log.d("CounterWidget", "Cleared ${appWidgetIds.size} counter widgets")
            } catch (e: Exception) {
                Log.e("CounterWidget", "Error clearing all counter widgets: ${e.message}", e)
            }
        }

        private fun setupSelectRecordListener(context: Context, views: RemoteViews, appWidgetId: Int) {
            // Click on container (category/subcategory/title area) to select different record
            val selectIntent = Intent(context, CounterWidget::class.java)
            selectIntent.action = ACTION_SELECT_RECORD
            selectIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            selectIntent.data = Uri.parse("counter_widget://select/$appWidgetId")

            val selectPendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                selectIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Attach to text area (category, subcategory, title)
            views.setOnClickPendingIntent(R.id.category_text, selectPendingIntent)
            views.setOnClickPendingIntent(R.id.subcategory_text, selectPendingIntent)
            views.setOnClickPendingIntent(R.id.record_title, selectPendingIntent)
        }

        private fun setupRefreshListener(context: Context, views: RemoteViews, appWidgetId: Int) {
            // Click on counter text to trigger refresh (like tapping date in other widgets)
            val refreshIntent = Intent(context, TodayWidget::class.java)
            refreshIntent.action = TodayWidget.ACTION_REFRESH
            val refreshRequestCode = appWidgetId + 600 + System.currentTimeMillis().toInt()
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context,
                refreshRequestCode,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.counter_text, refreshPendingIntent)
            
            Log.d("CounterWidget", "Counter refresh listener setup completed for widget $appWidgetId")
        }

        private fun setupAddButtonListener(context: Context, views: RemoteViews, appWidgetId: Int) {
            // '+' button to add new record
            val addIntent = Intent(context, TodayWidget::class.java)
            addIntent.action = TodayWidget.ACTION_ADD_RECORD
            val addRequestCode = appWidgetId + 800 + System.currentTimeMillis().toInt()
            val addPendingIntent = PendingIntent.getBroadcast(
                context,
                addRequestCode,
                addIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.counter_add_record_button, addPendingIntent)
            
            Log.d("CounterWidget", "Add button setup completed for widget $appWidgetId")
        }

        private fun setupStickClickListener(context: Context, views: RemoteViews, appWidgetId: Int) {
            // Stick indicator to open CalendarViewActivity
            val calendarIntent = Intent(context, CalendarViewActivity::class.java)
            calendarIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            val calendarRequestCode = appWidgetId + 900 + System.currentTimeMillis().toInt()
            val calendarPendingIntent = PendingIntent.getActivity(
                context,
                calendarRequestCode,
                calendarIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.lecture_type_indicator, calendarPendingIntent)
            
            Log.d("CounterWidget", "Stick click listener setup completed for widget $appWidgetId")
        }

        private fun calculateDaysRemaining(scheduledDateStr: String): Int {
            return try {
                if (scheduledDateStr.isEmpty() || scheduledDateStr == "Unspecified") return 0

                val today = LocalDate.now()
                val scheduledDate = LocalDate.parse(scheduledDateStr) // Expects ISO: yyyy-MM-dd

                ChronoUnit.DAYS.between(today, scheduledDate).toInt()
            } catch (e: Exception) {
                Log.e("CounterWidget", "Error calculating days for date: $scheduledDateStr", e)
                0
            }
        }

        private fun formatCounterText(days: Int): String {
            return when {
                days < 0 -> "-${Math.abs(days)}\ndays"  // Overdue with minus sign
                days == 0 -> "Today!"
                days == 1 -> "1\nday"
                else -> "$days\ndays"
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateCounterWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_SELECT_RECORD -> {
                val appWidgetId = intent.getIntExtra(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID
                )

                if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    // Launch record selection activity
                    val selectIntent = Intent(context, RecordSelectionActivity::class.java)
                    selectIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    selectIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    context.startActivity(selectIntent)
                }
            }
        }
    }

    override fun onEnabled(context: Context) {
        Log.d("CounterWidget", "Counter widget enabled")
    }

    override fun onDisabled(context: Context) {
        try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            val allKeys = prefs.all.keys

            // Remove all counter widget preferences
            for (key in allKeys) {
                if (key.startsWith("counter_widget_")) {
                    editor.remove(key)
                }
            }
            editor.apply()

            Log.d("CounterWidget", "Counter widget preferences cleaned up")
        } catch (e: Exception) {
            Log.e("CounterWidget", "Error cleaning up preferences: ${e.message}", e)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val editor = prefs.edit()

            for (appWidgetId in appWidgetIds) {
                editor.remove(getSelectedRecordKey(appWidgetId))
                editor.remove(getTargetDateKey(appWidgetId))
                editor.remove(getRecordTitleKey(appWidgetId))
                editor.remove(getCategoryKey(appWidgetId))
                editor.remove(getSubCategoryKey(appWidgetId))
            }
            editor.apply()

            Log.d("CounterWidget", "Cleaned up preferences for deleted widgets: ${appWidgetIds.contentToString()}")
        } catch (e: Exception) {
            Log.e("CounterWidget", "Error cleaning up deleted widget preferences: ${e.message}", e)
        }
    }
}
