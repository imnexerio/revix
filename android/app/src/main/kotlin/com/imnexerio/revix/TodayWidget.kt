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

class TodayWidget : AppWidgetProvider() {

    companion object {
        const val ACTION_REFRESH = "revix.ACTION_REFRESH"
        const val ACTION_ITEM_CLICK = "revix.ACTION_ITEM_CLICK"
        const val ACTION_ADD_RECORD = "revix.ACTION_ADD_RECORD"
        const val PREF_PROCESSING_ITEMS = "widget_processing_items"
        
        fun updateWidgets(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, TodayWidget::class.java)
                )

                for (appWidgetId in appWidgetIds) {
                    updateTodayWidget(context, appWidgetManager, appWidgetId)
                }

                // Notify ListView data changes
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_listview)

                Log.d("TodayWidget", "Updated ${appWidgetIds.size} today widgets")
            } catch (e: Exception) {
                Log.e("TodayWidget", "Error updating today widgets: ${e.message}", e)
            }
        }

        private fun updateTodayWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.today_widget)
                val sharedPreferences = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

                // Handle login status and timestamp display
                setupWidgetHeader(context, views, sharedPreferences)

                // Setup records ListView
                setupRecordsList(context, views, appWidgetId)

                // Setup add record button
                setupAddButton(context, views, appWidgetId)

                // Setup refresh functionality on header click
                setupRefreshOnHeaderClick(context, views, appWidgetId)

                // Update the widget
                appWidgetManager.updateAppWidget(appWidgetId, views)

                Log.d("TodayWidget", "Today widget $appWidgetId updated successfully")
            } catch (e: Exception) {
                Log.e("TodayWidget", "Error updating today widget $appWidgetId: ${e.message}", e)
            }
        }

        private fun setupWidgetHeader(context: Context, views: RemoteViews, sharedPreferences: android.content.SharedPreferences) {
            try {
                // Handle potential type mismatch for isLoggedIn value
                val isLoggedIn = try {
                    sharedPreferences.getBoolean("isLoggedIn", false)
                } catch (e: ClassCastException) {
                    sharedPreferences.edit().remove("isLoggedIn").apply()
                    false
                }
                val lastUpdated = sharedPreferences.getLong("lastUpdated", 0L)

                if (!isLoggedIn) {
                    views.setTextViewText(R.id.title_text_n_refresh, "Login Required")
                    views.setTextViewText(R.id.empty_view, "Please login to view your schedule")
                } else {
                    // Show current date and timestamp if available
                    if (lastUpdated > 0) {
                        val currentDate = java.text.SimpleDateFormat("dd MMM yyyy", java.util.Locale.getDefault()).format(java.util.Date())
                        val lastUpdateTime = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date(lastUpdated))
                        views.setTextViewText(R.id.title_text_n_refresh, "$currentDate @ $lastUpdateTime")
                    } else {
                        val currentDate = java.text.SimpleDateFormat("dd MMM yyyy", java.util.Locale.getDefault()).format(java.util.Date())
                        views.setTextViewText(R.id.title_text_n_refresh, "$currentDate @ No Data")
                    }
                    views.setTextViewText(R.id.empty_view, "No tasks scheduled. Enjoy your free time!")
                }
            } catch (e: Exception) {
                Log.e("TodayWidget", "Error setting up widget header: ${e.message}", e)
                views.setTextViewText(R.id.title_text_n_refresh, "Error")
            }
        }

        private fun setupRecordsList(context: Context, views: RemoteViews, appWidgetId: Int) {
            try {
                // Setup ListView with UnifiedWidgetListViewService
                val intent = Intent(context, UnifiedWidgetListViewService::class.java)
                intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                intent.putExtra("viewType", "combined") // Combined data for today widget
                intent.data = Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME))
                views.setRemoteAdapter(R.id.widget_listview, intent)

                // Set empty view
                views.setEmptyView(R.id.widget_listview, R.id.empty_view)

                // Set up PendingIntent template for record clicks
                val clickIntent = Intent(context, TodayWidget::class.java)
                clickIntent.action = ACTION_ITEM_CLICK
                clickIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                clickIntent.data = Uri.parse(clickIntent.toUri(Intent.URI_INTENT_SCHEME))

                val clickPendingIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    clickIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )

                views.setPendingIntentTemplate(R.id.widget_listview, clickPendingIntent)
                Log.d("TodayWidget", "PendingIntent template set for record clicks with action: $ACTION_ITEM_CLICK")

                Log.d("TodayWidget", "Records list setup completed for widget $appWidgetId")
            } catch (e: Exception) {
                Log.e("TodayWidget", "Error setting up records list: ${e.message}", e)
            }
        }

        private fun setupAddButton(context: Context, views: RemoteViews, appWidgetId: Int) {
            try {
                val addIntent = Intent(context, TodayWidget::class.java)
                addIntent.action = ACTION_ADD_RECORD
                val addRequestCode = appWidgetId + 100 + System.currentTimeMillis().toInt()
                val addPendingIntent = PendingIntent.getBroadcast(
                    context,
                    addRequestCode,
                    addIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.add_record_button, addPendingIntent)

                Log.d("TodayWidget", "Add button setup completed for widget $appWidgetId")
            } catch (e: Exception) {
                Log.e("TodayWidget", "Error setting up add button: ${e.message}", e)
            }
        }

        private fun setupRefreshOnHeaderClick(context: Context, views: RemoteViews, appWidgetId: Int) {
            try {
                val refreshIntent = Intent(context, TodayWidget::class.java)
                refreshIntent.action = ACTION_REFRESH
                val refreshRequestCode = appWidgetId + 200 + System.currentTimeMillis().toInt()
                val refreshPendingIntent = PendingIntent.getBroadcast(
                    context,
                    refreshRequestCode,
                    refreshIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.title_text_n_refresh, refreshPendingIntent)

                Log.d("TodayWidget", "Header refresh setup completed for widget $appWidgetId")
            } catch (e: Exception) {
                Log.e("TodayWidget", "Error setting up header refresh: ${e.message}", e)
            }
        }
    }    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateTodayWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            ACTION_REFRESH -> {
                Log.d("TodayWidget", "Refresh requested")
                val refreshIntent = Intent(context, RefreshService::class.java)
                context.startService(refreshIntent)
            }
            ACTION_ITEM_CLICK -> {
                val category = intent.getStringExtra("category") ?: ""
                val subCategory = intent.getStringExtra("sub_category") ?: ""
                val recordTitle = intent.getStringExtra("record_title") ?: ""
                val actionType = intent.getStringExtra("ACTION_TYPE") ?: "MARK_AS_DONE"
                
                if (actionType == "VIEW_DETAILS") {
                    // Always launch AlarmScreenActivity in details mode
                    val alarmIntent = Intent(context, AlarmScreenActivity::class.java)
                    alarmIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    
                    // Copy all record data to alarm intent
                    intent.extras?.let { extras ->
                        for (key in extras.keySet()) {
                            val value = extras.getString(key)
                            if (value != null) {
                                alarmIntent.putExtra(key, value)
                            }
                        }
                    }
                    
                    alarmIntent.putExtra("DETAILS_MODE", true)
                    
                    try {
                        context.startActivity(alarmIntent)
                    } catch (e: Exception) {
                        Log.e("TodayWidget", "Error launching AlarmScreenActivity: ${e.message}", e)
                    }
                } else {
                    // Mark as done functionality for TodayWidget
                    val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                    val processingItems = prefs.getStringSet(PREF_PROCESSING_ITEMS, mutableSetOf()) ?: mutableSetOf()
                    val itemKey = "${category}_${subCategory}_${recordTitle}"
                    val newProcessingItems = processingItems.toMutableSet()
                    newProcessingItems.add(itemKey)
                    prefs.edit().putStringSet(PREF_PROCESSING_ITEMS, newProcessingItems).apply()

                    // Update widget to show processing state
                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(
                        ComponentName(context, TodayWidget::class.java)
                    )
                    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_listview)

                    // Start the service to handle the item click
                    val clickIntent = Intent(context, RecordUpdateService::class.java)
                    clickIntent.putExtra("category", category)
                    clickIntent.putExtra("sub_category", subCategory)
                    clickIntent.putExtra("record_title", recordTitle)

                    // Pass additional data
                    intent.extras?.let { extras ->
                        for (key in extras.keySet()) {
                            if (key !in setOf("category", "sub_category", "record_title", "appWidgetId", "ACTION_TYPE")) {
                                val value = extras.getString(key)
                                if (value != null) {
                                    clickIntent.putExtra(key, value)
                                }
                            }
                        }
                    }

                    context.startService(clickIntent)
                }
            }
            ACTION_ADD_RECORD -> {
                val addIntent = Intent(context, AddLectureActivity::class.java)
                addIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(addIntent)
            }
        }
    }

    override fun onEnabled(context: Context) {
        Log.d("TodayWidget", "Today widget enabled")
    }

    override fun onDisabled(context: Context) {
        Log.d("TodayWidget", "Today widget disabled")
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        Log.d("TodayWidget", "Today widgets deleted: ${appWidgetIds.contentToString()}")
    }
}