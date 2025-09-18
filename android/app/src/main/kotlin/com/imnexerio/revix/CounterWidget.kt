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
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

class CounterWidget : AppWidgetProvider() {

    companion object {
        const val ACTION_SELECT_RECORD = "revix.ACTION_SELECT_RECORD"
        const val ACTION_COUNTER_REFRESH = "revix.ACTION_COUNTER_REFRESH"

        // Per-widget storage keys (simplified)
        fun getSelectedRecordKey(appWidgetId: Int) = "counter_widget_${appWidgetId}_record"
        fun getTargetDateKey(appWidgetId: Int) = "counter_widget_${appWidgetId}_target_date"
        fun getRecordTitleKey(appWidgetId: Int) = "counter_widget_${appWidgetId}_title"
        fun getCategoryKey(appWidgetId: Int) = "counter_widget_${appWidgetId}_category"
        fun getSubCategoryKey(appWidgetId: Int) = "counter_widget_${appWidgetId}_subcategory"

        fun updateCounterWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.counter_widget)
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

                val selectedRecord = prefs.getString(getSelectedRecordKey(appWidgetId), null)

                if (selectedRecord != null) {
                    // Get record data
                    val scheduledDate = prefs.getString(getTargetDateKey(appWidgetId), "") ?: ""
                    val recordTitle = prefs.getString(getRecordTitleKey(appWidgetId), "") ?: ""
                    val category = prefs.getString(getCategoryKey(appWidgetId), "") ?: ""
                    val subCategory = prefs.getString(getSubCategoryKey(appWidgetId), "") ?: ""

                    // Calculate days remaining: scheduled_date - current_date
                    val daysRemaining = calculateDaysRemaining(scheduledDate)
                    val counterText = formatCounterText(daysRemaining)
                    
                    // Apply LectureColors to the colored stick indicator
                    val stickColor = LectureColors.getLectureTypeColorSync(context, category)
                    views.setInt(R.id.lecture_type_indicator, "setColorFilter", stickColor)
                    
                    // Only override color if overdue (red), otherwise let @color/text from layout handle theme
                    if (daysRemaining < 0) {
                        views.setTextColor(R.id.counter_text, 0xFFFF0000.toInt()) // Red for overdue
                    }
                    // Note: Normal state uses @color/text from layout (theme-aware)
                    
                    // Only override color if overdue (red), otherwise let @color/text from layout handle theme
                    if (daysRemaining < 0) {
                        val redColor = 0xFFFF0000.toInt()
                        views.setTextColor(R.id.category_text, redColor)
                        views.setTextColor(R.id.subcategory_text, redColor)
                        views.setTextColor(R.id.record_title, redColor)
                    }
                    // Note: Normal state uses @color/text from layout (theme-aware)

                    // Populate all text fields
                    views.setTextViewText(R.id.counter_text, counterText)
                    views.setTextViewText(R.id.category_text, category)
                    views.setTextViewText(R.id.subcategory_text, subCategory)
                    views.setTextViewText(R.id.record_title, recordTitle)

                    Log.d("CounterWidget", "Updated widget $appWidgetId: $category-$subCategory-$recordTitle → $counterText")
                } else {
                    // Show selection prompt
                    views.setTextViewText(R.id.counter_text, "Tap\nselect")
                    views.setTextViewText(R.id.category_text, "Category")
                    views.setTextViewText(R.id.subcategory_text, "Subcategory") 
                    views.setTextViewText(R.id.record_title, "Record Title")
                    
                    // Default gray stick color (text colors use @color/text from layout)
                    views.setInt(R.id.lecture_type_indicator, "setColorFilter", 0xFF666666.toInt())
                    // Note: Text colors use @color/text from layout (theme-aware)
                }

                // Set up click listener
                setupClickListener(context, views, appWidgetId)

                appWidgetManager.updateAppWidget(appWidgetId, views)

            } catch (e: Exception) {
                Log.e("CounterWidget", "Error updating counter widget $appWidgetId: ${e.message}", e)
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

            } catch (e: Exception) {
                Log.e("CounterWidget", "Error updating all counter widgets: ${e.message}", e)
            }
        }

        private fun setupClickListener(context: Context, views: RemoteViews, appWidgetId: Int) {
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

            views.setOnClickPendingIntent(R.id.counter_widget_container, selectPendingIntent)
        }

        private fun calculateDaysRemaining(scheduledDateStr: String): Int {
            return try {
                if (scheduledDateStr.isEmpty()) return 0

                val today = LocalDate.now()
                val scheduledDate = LocalDate.parse(scheduledDateStr)

                // Simple calculation: scheduled_date - current_date
                ChronoUnit.DAYS.between(today, scheduledDate).toInt()
            } catch (e: Exception) {
                Log.e("CounterWidget", "Error calculating days for date: $scheduledDateStr, error: ${e.message}", e)
                0
            }
        }

        private fun formatCounterText(days: Int): String {
            return when {
                days < 0 -> "${Math.abs(days)}\ndays"  // Overdue 
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

            ACTION_COUNTER_REFRESH -> {
                // Trigger refresh just like TodayWidget
                val refreshIntent = Intent(context, RefreshService::class.java)
                context.startService(refreshIntent)
            }
        }
    }

    override fun onEnabled(context: Context) {
        // Widget enabled - no special action needed
        Log.d("CounterWidget", "Counter widget enabled")
    }

    override fun onDisabled(context: Context) {
        // Clean up widget preferences when all counter widgets are removed
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
        // Clean up preferences for specific deleted widgets
        try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val editor = prefs.edit()

            for (appWidgetId in appWidgetIds) {
                editor.remove(getSelectedRecordKey(appWidgetId))
                editor.remove(getTargetDateKey(appWidgetId))
                editor.remove(getRecordTitleKey(appWidgetId))
                editor.remove(getCategoryKey(appWidgetId))
                editor.remove(getSubCategoryKey(appWidgetId))
                // Clean up old counterType key if it exists
                editor.remove("counter_widget_${appWidgetId}_type")
            }
            editor.apply()

            Log.d("CounterWidget", "Cleaned up preferences for deleted widgets: ${appWidgetIds.contentToString()}")
        } catch (e: Exception) {
            Log.e("CounterWidget", "Error cleaning up deleted widget preferences: ${e.message}", e)
        }
    }
}