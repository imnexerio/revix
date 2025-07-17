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
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

class TodayWidget : AppWidgetProvider() {    companion object {
        const val ACTION_REFRESH = "revix.ACTION_REFRESH"
        const val ACTION_ITEM_CLICK = "revix.ACTION_ITEM_CLICK"
        const val ACTION_ADD_RECORD = "revix.ACTION_ADD_RECORD"
        const val ACTION_SWITCH_VIEW = "revix.ACTION_SWITCH_VIEW"
        const val PREF_PROCESSING_ITEMS = "widget_processing_items"

        private const val VIEW_TODAY = "today"
        private const val VIEW_TOMORROW = "tomorrow"  // NEW
        private const val VIEW_MISSED = "missed"
        private const val VIEW_NO_REMINDER = "noreminder"
        const val PREF_CURRENT_VIEW = "widget_current_view"
        
        // Add this new preference key for alarm data hash tracking
        private const val PREF_LAST_ALARM_DATA_HASH = "last_alarm_data_hash"

        // Enhanced method to schedule alarms for two days with change detection
        fun scheduleAlarmsFromWidgetData(context: Context, forceUpdate: Boolean = false) {
            try {
                Log.d("TodayWidget", "Checking if alarm scheduling needed...")

                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val todayRecordsJson = prefs.getString("todayRecords", "[]") ?: "[]"
                val tomorrowRecordsJson = prefs.getString("tomorrowRecords", "[]") ?: "[]"  // NEW

                // Calculate hash of current data (both days)
                val currentDataHash = (todayRecordsJson + tomorrowRecordsJson).hashCode()
                val lastDataHash = prefs.getInt(PREF_LAST_ALARM_DATA_HASH, -1)

                // Only schedule alarms if data has changed or forced update
                if (forceUpdate || currentDataHash != lastDataHash) {
                    Log.d("TodayWidget", "Data changed, scheduling alarms for two days...")
                    
                    val todayRecords = parseRecordsFromJson(todayRecordsJson)
                    val tomorrowRecords = parseRecordsFromJson(tomorrowRecordsJson)  // NEW
                    Log.d("TodayWidget", "Parsed ${todayRecords.size} today + ${tomorrowRecords.size} tomorrow records")

                    if (todayRecords.isNotEmpty() || tomorrowRecords.isNotEmpty()) {
                        val alarmHelper = AlarmManagerHelper(context)
                        alarmHelper.scheduleAlarmsForTwoDays(todayRecords, tomorrowRecords)  // NEW METHOD
                        Log.d("TodayWidget", "Successfully scheduled alarms for two days")
                    } else {
                        Log.d("TodayWidget", "No records found for alarm scheduling")
                    }

                    // Save the new data hash
                    prefs.edit().putInt(PREF_LAST_ALARM_DATA_HASH, currentDataHash).apply()
                } else {
                    Log.d("TodayWidget", "No data changes detected, skipping alarm scheduling")
                }
            } catch (e: Exception) {
                Log.e("TodayWidget", "Error scheduling alarms from widget data: ${e.message}", e)
            }
        }

    private fun parseRecordsFromJson(jsonString: String): List<Map<String, Any>> {
        val records = mutableListOf<Map<String, Any>>()

        try {
            val jsonArray = JSONArray(jsonString)
            for (i in 0 until jsonArray.length()) {
                val jsonObject = jsonArray.getJSONObject(i)
                val record = mutableMapOf<String, Any>()

                // Extract all fields needed for alarm scheduling
                record["category"] = jsonObject.optString("category", "")
                record["sub_category"] = jsonObject.optString("sub_category", "")
                record["record_title"] = jsonObject.optString("record_title", "")
                record["reminder_time"] = jsonObject.optString("reminder_time", "")
                record["alarm_type"] = jsonObject.optString("alarm_type", "0").toIntOrNull() ?: 0
                record["scheduled_date"] = jsonObject.optString("scheduled_date", "")
                record["status"] = jsonObject.optString("status", "")

                records.add(record)
            }
        } catch (e: JSONException) {
            Log.e("TodayWidget", "Error parsing records JSON: ${e.message}", e)
        }

        return records
    }        // Modified updateWidgets method
        fun updateWidgets(context: Context, scheduleAlarms: Boolean = false) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(context, TodayWidget::class.java)
            )

            // Force a full update for each widget
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }

            // Ensure data changes for the ListView are notified
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_listview)

            // Send a broadcast to update all widgets
            val updateIntent = Intent(context, TodayWidget::class.java)
            updateIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            updateIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
            context.sendBroadcast(updateIntent)

            // Only schedule alarms if explicitly requested
            if (scheduleAlarms) {
                scheduleAlarmsFromWidgetData(context)
            }
        }
    }override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray
) {
    for (appWidgetId in appWidgetIds) {
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    // Schedule alarms from widget data after update
    scheduleAlarmsFromWidgetData(context)
}

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {            ACTION_REFRESH -> {
                // Check if already refreshing
                val currentlyRefreshing = RefreshService.isCurrentlyRefreshing()
                Log.d("TodayWidget", "Refresh requested, currently refreshing: $currentlyRefreshing")
                
                if (currentlyRefreshing) {
                    Log.d("TodayWidget", "Refresh already in progress, ignoring request")
                    Toast.makeText(context, "Refresh already in progress...", Toast.LENGTH_SHORT).show()
                    return
                }

                // Start the RefreshService to handle the refresh operation
                try {
                    Log.d("TodayWidget", "Starting refresh service...")
                    val refreshIntent = Intent(context, RefreshService::class.java)
                    context.startService(refreshIntent)
                    Log.d("TodayWidget", "Refresh service started successfully")
                } catch (e: Exception) {
                    Log.e("TodayWidget", "Error starting refresh service: ${e.message}")
                    Toast.makeText(context, "Error starting refresh: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            }
            ACTION_ITEM_CLICK -> {
                // Extract record details from intent
                val category = intent.getStringExtra("category") ?: ""
                val subCategory = intent.getStringExtra("sub_category") ?: ""
                val lectureNo = intent.getStringExtra("record_title") ?: ""

                // NEW CODE: Mark this item as being processed
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val processingItems = prefs.getStringSet(PREF_PROCESSING_ITEMS, mutableSetOf()) ?: mutableSetOf()
                val itemKey = "${category}_${subCategory}_${lectureNo}"
                val newProcessingItems = processingItems.toMutableSet()
                newProcessingItems.add(itemKey)
                prefs.edit().putStringSet(PREF_PROCESSING_ITEMS, newProcessingItems).apply()

                // Force update widget to show strikethrough
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, TodayWidget::class.java)
                )
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_listview)

                // Start the service to handle the item click
                val clickIntent = Intent(context, RecordUpdateService::class.java)
                clickIntent.putExtra("category", category)
                clickIntent.putExtra("sub_category", subCategory)
                clickIntent.putExtra("record_title", lectureNo)

                // Pass all additional data from the intent
                intent.extras?.let { extras ->
                    val keys = extras.keySet()
                    for (key in keys) {
                        if (key != "category" && key != "sub_category" && key != "record_title") {
                            // Handle different value types properly
                            when (val value = extras.get(key)) {
                                is String -> clickIntent.putExtra(key, value)
                                is Int -> clickIntent.putExtra(key, value.toString())
                                is Long -> clickIntent.putExtra(key, value.toString())
                                is Float -> clickIntent.putExtra(key, value.toString())
                                is Double -> clickIntent.putExtra(key, value.toString())
                                is Boolean -> clickIntent.putExtra(key, value.toString())
                                // Skip appWidgetId and other non-string types we don't need
                                else -> {
                                    if (key != "appWidgetId") {
                                        Log.d("TodayWidget", "Skipping non-string extra: $key with type ${value?.javaClass?.simpleName}")
                                    }
                                }
                            }
                        }
                    }
                }

                context.startService(clickIntent)
            }
            ACTION_ADD_RECORD -> {
                // Launch the AddLectureActivity
                val addIntent = Intent(context, AddLectureActivity::class.java)
                addIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(addIntent)
            }            ACTION_SWITCH_VIEW -> {
                // Get the current view type from preferences
                val prefs = context.getSharedPreferences("WidgetPreferences", Context.MODE_PRIVATE)
                val currentView = prefs.getString(PREF_CURRENT_VIEW, VIEW_TODAY) ?: VIEW_TODAY

                // Cycle through view types (updated order with tomorrow)
                val nextView = when (currentView) {
                    VIEW_TODAY -> VIEW_TOMORROW      // NEW
                    VIEW_TOMORROW -> VIEW_MISSED     // MODIFIED  
                    VIEW_MISSED -> VIEW_NO_REMINDER
                    else -> VIEW_TODAY
                }

                // Save the new view type
                prefs.edit().putString(PREF_CURRENT_VIEW, nextView).apply()

                // Update all widgets (no alarm scheduling needed for view switch)
                updateWidgets(context, scheduleAlarms = false)

                // Show toast with the new view type
                val viewName = when (nextView) {
                    VIEW_TODAY -> "Today's Schedule"
                    VIEW_TOMORROW -> "Tomorrow's Schedule"  // NEW
                    VIEW_MISSED -> "Missed Revisions"
                    VIEW_NO_REMINDER -> "No Reminder Date"
                    else -> "Unknown View"
                }
                Toast.makeText(context, "Switched to: $viewName", Toast.LENGTH_SHORT).show()
            }
        }
    }

    // Other methods remain unchanged
    override fun onEnabled(context: Context) {
        // Widget enabled - trigger initial data load through Flutter
        // The data will be loaded when the app next starts or through background callback
    }

    override fun onDisabled(context: Context) {
        // Cleanup if needed
    }
}

internal fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    val views = RemoteViews(context.packageName, R.layout.today_widget)

    val sharedPreferences = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    val viewPrefs = context.getSharedPreferences("WidgetPreferences", Context.MODE_PRIVATE)
    val currentView = viewPrefs.getString(TodayWidget.Companion.PREF_CURRENT_VIEW, "today") ?: "today"

    // Handle potential type mismatch for isLoggedIn value
    val isLoggedIn = try {
        sharedPreferences.getBoolean("isLoggedIn", false)
    } catch (e: ClassCastException) {
        // If there's a type mismatch, clear the incorrect value and use default
        sharedPreferences.edit().remove("isLoggedIn").apply()
        false
    }
    val lastUpdated = sharedPreferences.getLong("lastUpdated", 0L)    // Get appropriate data based on current view
    val jsonDataKey = when (currentView) {
        "tomorrow" -> "tomorrowRecords"  // NEW
        "missed" -> "missedRecords"
        "noreminder" -> "noreminderdate"
        else -> "todayRecords"
    }

    val jsonData = sharedPreferences.getString(jsonDataKey, "[]")
    val jsonArray = JSONArray(jsonData)
    val count = jsonArray.length()

    // Set view title based on current view
    val viewTitle = when (currentView) {
        "tomorrow" -> "Tomorrow's Schedule"  // NEW
        "missed" -> "Missed Revisions"
        "noreminder" -> "No Reminder Date"
        else -> "Today's Schedule"
    }

    try {
        views.setTextViewText(R.id.title_text_n_refresh, "($count)")

        if (!isLoggedIn) {
            views.setTextViewText(R.id.empty_view, "Please login to view your schedule")
        } else {
            val emptyMessage = when (currentView) {
                "tomorrow" -> "No tasks for tomorrow"  // NEW
                "missed" -> "No missed revisions. Great job!"
                "noreminder" -> "No records without reminder dates"
                else -> "No tasks for today, enjoy your day"
            }
            views.setTextViewText(R.id.empty_view, emptyMessage)
        }

        // Add last updated timestamp if available
        if (lastUpdated > 0) {
            val dateFormat = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault())
            val lastUpdateTime = dateFormat.format(java.util.Date(lastUpdated))
            views.setTextViewText(R.id.title_text_n_refresh, "($count) @ $lastUpdateTime")
        }
    } catch (e: JSONException) {
        views.setTextViewText(R.id.title_text_n_refresh, "($count) @ ${e.message}")
    }

    // Set up the refresh button click
    val refreshIntent = Intent(context, TodayWidget::class.java)
    refreshIntent.action = TodayWidget.ACTION_REFRESH
    val refreshRequestCode = appWidgetId + System.currentTimeMillis().toInt()
    val refreshPendingIntent = PendingIntent.getBroadcast(
        context,
        refreshRequestCode,
        refreshIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.title_text_n_refresh, refreshPendingIntent)

    // Set up the add record button click
    val addIntent = Intent(context, TodayWidget::class.java)
    addIntent.action = TodayWidget.ACTION_ADD_RECORD
    val addRequestCode = appWidgetId + 100 + System.currentTimeMillis().toInt()
    val addPendingIntent = PendingIntent.getBroadcast(
        context,
        addRequestCode,
        addIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.add_record_button, addPendingIntent)

    // Set up view switching button
    val switchViewIntent = Intent(context, TodayWidget::class.java)
    switchViewIntent.action = TodayWidget.ACTION_SWITCH_VIEW
    val switchViewRequestCode = appWidgetId + 200 + System.currentTimeMillis().toInt()
    val switchViewPendingIntent = PendingIntent.getBroadcast(
        context,
        switchViewRequestCode,
        switchViewIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.switch_view_button, switchViewPendingIntent)    // Set the icon based on current view type
    when (currentView) {
        "today" -> views.setImageViewResource(R.id.switch_view_button, R.drawable.baseline_today_24)
        "tomorrow" -> views.setImageViewResource(R.id.switch_view_button, R.drawable.baseline_upcoming_24)  // NEW - can use same icon or create new one
        "missed" -> views.setImageViewResource(R.id.switch_view_button, R.drawable.baseline_history_toggle_off_24)
        "noreminder" -> views.setImageViewResource(R.id.switch_view_button, R.drawable.baseline_alarm_off_24)
    }

    // Set up ListView and its adapter with extra parameters for the current view
    val intent = Intent(context, WidgetListViewService::class.java)
    intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
    intent.putExtra("viewType", currentView) // Pass the current view type
    intent.data = android.net.Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME))
    views.setRemoteAdapter(R.id.widget_listview, intent)
    views.setEmptyView(R.id.widget_listview, R.id.empty_view)

    // Set up the PendingIntent template for item clicks
    val clickIntent = Intent(context, TodayWidget::class.java)
    clickIntent.action = TodayWidget.ACTION_ITEM_CLICK
    clickIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
    clickIntent.data = Uri.parse(clickIntent.toUri(Intent.URI_INTENT_SCHEME))

    // Create a template PendingIntent which the RemoteViews factory will fill in
    val clickPendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        clickIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
    )

    // Set the pending intent template on the ListView
    views.setPendingIntentTemplate(R.id.widget_listview, clickPendingIntent)

    // Update the widget
    appWidgetManager.updateAppWidget(appWidgetId, views)
    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_listview)
}