package com.imnexerio.revix

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.*

class CalendarOnlyWidget : AppWidgetProvider() {

    companion object {
        const val ACTION_OPEN_CALENDAR_VIEW = "revix.ACTION_OPEN_CALENDAR_VIEW_CALENDAR_ONLY"
        
        fun updateCalendarOnlyWidgets(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, CalendarOnlyWidget::class.java)
                )

                for (appWidgetId in appWidgetIds) {
                    updateCalendarOnlyWidget(context, appWidgetManager, appWidgetId)
                }

                Log.d("CalendarOnlyWidget", "Updated ${appWidgetIds.size} calendar-only widgets")
            } catch (e: Exception) {
                Log.e("CalendarOnlyWidget", "Error updating calendar-only widgets: ${e.message}", e)
            }
        }

        private fun updateCalendarOnlyWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.calendar_only_widget)

                // Set current date in DD MMM YYYY format (4-letter month abbreviation)
                val currentDate = SimpleDateFormat("dd MMM yyyy", Locale.getDefault()).format(Date())
                views.setTextViewText(R.id.calendar_date_header, currentDate)

                // Setup calendar grid with current month (reuse from CalendarWidget)
                CalendarWidget.setupCalendarGrid(context, views)

                // Setup calendar grid click to open CalendarViewActivity
                setupCalendarGridClick(context, views, appWidgetId)

                // Setup add record button (calls TodayWidget)
                setupAddButton(context, views, appWidgetId)

                // Setup refresh functionality on date header click (calls TodayWidget refresh)
                setupRefreshOnDateClick(context, views, appWidgetId)

                // Update the widget
                appWidgetManager.updateAppWidget(appWidgetId, views)

                Log.d("CalendarOnlyWidget", "Calendar-only widget $appWidgetId updated successfully")
            } catch (e: Exception) {
                Log.e("CalendarOnlyWidget", "Error updating calendar-only widget $appWidgetId: ${e.message}", e)
            }
        }

        private fun setupCalendarGridClick(context: Context, views: RemoteViews, appWidgetId: Int) {
            try {
                // Set up calendar grid container click to open CalendarViewActivity
                val calendarViewIntent = Intent(context, CalendarOnlyWidget::class.java)
                calendarViewIntent.action = ACTION_OPEN_CALENDAR_VIEW
                val calendarViewRequestCode = appWidgetId + 800 + System.currentTimeMillis().toInt()
                val calendarViewPendingIntent = PendingIntent.getBroadcast(
                    context,
                    calendarViewRequestCode,
                    calendarViewIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                // Set click on the calendar grid rows to open CalendarViewActivity
                views.setOnClickPendingIntent(R.id.calendar_row_1, calendarViewPendingIntent)
                views.setOnClickPendingIntent(R.id.calendar_row_2, calendarViewPendingIntent)
                views.setOnClickPendingIntent(R.id.calendar_row_3, calendarViewPendingIntent)
                views.setOnClickPendingIntent(R.id.calendar_row_4, calendarViewPendingIntent)
                views.setOnClickPendingIntent(R.id.calendar_row_5, calendarViewPendingIntent)
                views.setOnClickPendingIntent(R.id.calendar_row_6, calendarViewPendingIntent)
                
                Log.d("CalendarOnlyWidget", "Calendar grid click setup completed for widget $appWidgetId")
            } catch (e: Exception) {
                Log.e("CalendarOnlyWidget", "Error setting up calendar grid click: ${e.message}", e)
            }
        }

        private fun setupAddButton(context: Context, views: RemoteViews, appWidgetId: Int) {
            try {
                // Set up add button to call TodayWidget's ACTION_ADD_RECORD
                val addIntent = Intent(context, TodayWidget::class.java)
                addIntent.action = TodayWidget.ACTION_ADD_RECORD
                val addRequestCode = appWidgetId + 600 + System.currentTimeMillis().toInt()
                val addPendingIntent = PendingIntent.getBroadcast(
                    context,
                    addRequestCode,
                    addIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.calendar_add_record_button_top, addPendingIntent)

                Log.d("CalendarOnlyWidget", "Add button setup completed for widget $appWidgetId")
            } catch (e: Exception) {
                Log.e("CalendarOnlyWidget", "Error setting up add button: ${e.message}", e)
            }
        }

        private fun setupRefreshOnDateClick(context: Context, views: RemoteViews, appWidgetId: Int) {
            try {
                // Set up date header click to call TodayWidget's ACTION_REFRESH
                val refreshIntent = Intent(context, TodayWidget::class.java)
                refreshIntent.action = TodayWidget.ACTION_REFRESH
                val refreshRequestCode = appWidgetId + 700 + System.currentTimeMillis().toInt()
                val refreshPendingIntent = PendingIntent.getBroadcast(
                    context,
                    refreshRequestCode,
                    refreshIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.calendar_date_header, refreshPendingIntent)

                Log.d("CalendarOnlyWidget", "Date header refresh setup completed for widget $appWidgetId")
            } catch (e: Exception) {
                Log.e("CalendarOnlyWidget", "Error setting up date header refresh: ${e.message}", e)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_OPEN_CALENDAR_VIEW -> {
                try {
                    // Launch CalendarViewActivity
                    val activityIntent = Intent(context, CalendarViewActivity::class.java)
                    activityIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    context.startActivity(activityIntent)
                    Log.d("CalendarOnlyWidget", "Launching CalendarViewActivity")
                } catch (e: Exception) {
                    Log.e("CalendarOnlyWidget", "Error launching CalendarViewActivity: ${e.message}", e)
                }
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateCalendarOnlyWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        Log.d("CalendarOnlyWidget", "Calendar-only widget enabled")
    }

    override fun onDisabled(context: Context) {
        Log.d("CalendarOnlyWidget", "Calendar-only widget disabled")
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        Log.d("CalendarOnlyWidget", "Calendar-only widgets deleted: ${appWidgetIds.contentToString()}")
    }
}