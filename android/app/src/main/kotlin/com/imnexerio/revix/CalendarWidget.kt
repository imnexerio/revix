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
import java.text.SimpleDateFormat
import java.util.*

class CalendarWidget : AppWidgetProvider() {

    companion object {
        const val ACTION_CALENDAR_REFRESH = "revix.ACTION_CALENDAR_REFRESH"
        
        fun updateCalendarWidgets(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, CalendarWidget::class.java)
                )

                for (appWidgetId in appWidgetIds) {
                    updateCalendarWidget(context, appWidgetManager, appWidgetId)
                }

                // Notify ListView data changes
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.calendar_records_listview)

                Log.d("CalendarWidget", "Updated ${appWidgetIds.size} calendar widgets")
            } catch (e: Exception) {
                Log.e("CalendarWidget", "Error updating calendar widgets: ${e.message}", e)
            }
        }

        private fun updateCalendarWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.calendar_widget)

                // Set current date in DD MM YYYY format
                val currentDate = SimpleDateFormat("dd MM yyyy", Locale.getDefault()).format(Date())
                views.setTextViewText(R.id.calendar_date_header, currentDate)

                // Setup calendar grid with current month
                setupCalendarGrid(context, views)

                // Setup records ListView
                setupRecordsList(context, views, appWidgetId)

                // Setup add record button (calls TodayWidget)
                setupAddButton(context, views, appWidgetId)

                // Update the widget
                appWidgetManager.updateAppWidget(appWidgetId, views)

                Log.d("CalendarWidget", "Calendar widget $appWidgetId updated successfully")
            } catch (e: Exception) {
                Log.e("CalendarWidget", "Error updating calendar widget $appWidgetId: ${e.message}", e)
            }
        }

        private fun setupCalendarGrid(context: Context, views: RemoteViews) {
            try {
                val calendar = Calendar.getInstance()
                val today = calendar.get(Calendar.DAY_OF_MONTH)
                
                // Set current month and year for calendar display
                calendar.set(Calendar.DAY_OF_MONTH, 1)
                // Get first day of week and convert to Monday-first calendar (0=Monday, 1=Tuesday...)
                // Java Calendar: 1=Sunday, 2=Monday, 3=Tuesday, 4=Wednesday, 5=Thursday, 6=Friday, 7=Saturday
                // Our Layout: M T W T F S S (Monday=0, Tuesday=1, Wednesday=2, Thursday=3, Friday=4, Saturday=5, Sunday=6)
                val javaFirstDay = calendar.get(Calendar.DAY_OF_WEEK) // 1=Sunday, 2=Monday...
                val firstDayOfWeek = if (javaFirstDay == Calendar.SUNDAY) 6 else javaFirstDay - 2
                val daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)

                // Reset all day TextViews first
                val dayIds = arrayOf(
                    R.id.day_1, R.id.day_2, R.id.day_3, R.id.day_4, R.id.day_5, R.id.day_6, R.id.day_7,
                    R.id.day_8, R.id.day_9, R.id.day_10, R.id.day_11, R.id.day_12, R.id.day_13, R.id.day_14,
                    R.id.day_15, R.id.day_16, R.id.day_17, R.id.day_18, R.id.day_19, R.id.day_20, R.id.day_21,
                    R.id.day_22, R.id.day_23, R.id.day_24, R.id.day_25, R.id.day_26, R.id.day_27, R.id.day_28,
                    R.id.day_29, R.id.day_30, R.id.day_31, R.id.day_32, R.id.day_33, R.id.day_34, R.id.day_35,
                    R.id.day_36, R.id.day_37, R.id.day_38, R.id.day_39, R.id.day_40, R.id.day_41, R.id.day_42
                )

                // Clear all day slots first
                for (i in dayIds.indices) {
                    views.setTextViewText(dayIds[i], "")
                    views.setInt(dayIds[i], "setBackgroundResource", 0) // Clear background
                }

                // Fill calendar with days
                for (day in 1..daysInMonth) {
                    val position = firstDayOfWeek + day - 1
                    if (position < dayIds.size) {
                        views.setTextViewText(dayIds[position], day.toString())
                        
                        // Highlight today's date with colorOnPrimary background
                        if (day == today) {
                            views.setInt(dayIds[position], "setBackgroundResource", R.color.colorOnPrimary)
                        }
                    }
                }

                Log.d("CalendarWidget", "Calendar grid setup completed for month with $daysInMonth days, today is $today, first day position: $firstDayOfWeek")
            } catch (e: Exception) {
                Log.e("CalendarWidget", "Error setting up calendar grid: ${e.message}", e)
            }
        }

        private fun setupRecordsList(context: Context, views: RemoteViews, appWidgetId: Int) {
            try {
                // Setup ListView with CalendarListViewService
                val intent = Intent(context, CalendarListViewService::class.java)
                intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                intent.data = Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME))
                views.setRemoteAdapter(R.id.calendar_records_listview, intent)

                // Set empty view
                views.setEmptyView(R.id.calendar_records_listview, R.id.calendar_empty_view)

                Log.d("CalendarWidget", "Records list setup completed for widget $appWidgetId")
            } catch (e: Exception) {
                Log.e("CalendarWidget", "Error setting up records list: ${e.message}", e)
            }
        }

        private fun setupAddButton(context: Context, views: RemoteViews, appWidgetId: Int) {
            try {
                // Set up add button to call TodayWidget's ACTION_ADD_RECORD
                val addIntent = Intent(context, TodayWidget::class.java)
                addIntent.action = TodayWidget.ACTION_ADD_RECORD
                val addRequestCode = appWidgetId + 400 + System.currentTimeMillis().toInt()
                val addPendingIntent = PendingIntent.getBroadcast(
                    context,
                    addRequestCode,
                    addIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.calendar_add_record_button, addPendingIntent)

                Log.d("CalendarWidget", "Add button setup completed for widget $appWidgetId")
            } catch (e: Exception) {
                Log.e("CalendarWidget", "Error setting up add button: ${e.message}", e)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateCalendarWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            ACTION_CALENDAR_REFRESH -> {
                Log.d("CalendarWidget", "Calendar refresh requested")
                updateCalendarWidgets(context)
            }
        }
    }

    override fun onEnabled(context: Context) {
        Log.d("CalendarWidget", "Calendar widget enabled")
    }

    override fun onDisabled(context: Context) {
        Log.d("CalendarWidget", "Calendar widget disabled")
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        Log.d("CalendarWidget", "Calendar widgets deleted: ${appWidgetIds.contentToString()}")
    }
}