package com.imnexerio.revix

import android.content.Context
import android.util.Log

object WidgetUpdateManager {
    
    fun updateAllWidgets(context: Context) {
        try {
            Log.d("WidgetUpdateManager", "Updating all widget types...")

            // Check if alarms are allowed on this device
            val sharedPreferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val allowAlarmsOnDevice = sharedPreferences.getBoolean("flutter.allow_alarms_on_device", true)
            
            Log.d("WidgetUpdateManager", "Allow alarms on device: $allowAlarmsOnDevice")

            // Schedule alarms from updated data (only if enabled)
            if (allowAlarmsOnDevice) {
                try {
                    Log.d("WidgetUpdateManager", "Scheduling alarms from updated data...")
                    val alarmHelper = AlarmManagerHelper(context)
                    alarmHelper.scheduleAlarmsFromWidgetData(context)
                    Log.d("WidgetUpdateManager", "Alarms scheduled successfully from RefreshService")
                } catch (e: Exception) {
                    Log.e("WidgetUpdateManager", "Error scheduling alarms: ${e.message}", e)
                }
            } else {
                Log.d("WidgetUpdateManager", "Alarm scheduling skipped - disabled by user")
            }
            
            // Update TodayWidget (Records Only - combined data)
            TodayWidget.updateWidgets(context)
            
            // Update CalendarWidget (Calendar + Records - combined data)
            CalendarWidget.updateCalendarWidgets(context)
            
            // Update CalendarOnlyWidget (Calendar Only - no records)
            CalendarOnlyWidget.updateCalendarOnlyWidgets(context)
            
            // Update CounterWidget (Countdown Timer - all records data)
            CounterWidget.updateAllCounterWidgets(context)
            
            Log.d("WidgetUpdateManager", "All widget types updated successfully")
        } catch (e: Exception) {
            Log.e("WidgetUpdateManager", "Error updating widgets: ${e.message}", e)
        }
    }
    
    fun clearAllWidgets(context: Context) {
        try {
            Log.d("WidgetUpdateManager", "Clearing all widget types...")

            // Cancel alarms from updated data
            try {
                Log.d("WidgetUpdateManager", "Scheduling alarms from updated data...")
                val alarmHelper = AlarmManagerHelper(context)
                alarmHelper.cancelAllStoredAlarms()
                Log.d("WidgetUpdateManager", "Alarms scheduled successfully from RefreshService")
            } catch (e: Exception) {
                Log.e("WidgetUpdateManager", "Error scheduling alarms: ${e.message}", e)
            }
            
            // Clear TodayWidget
            TodayWidget.updateWidgets(context) // Will read empty data after logout
            
            // Clear CalendarWidget
            CalendarWidget.clearAllCalendarWidgets(context)
            
            // Clear CalendarOnlyWidget
            CalendarOnlyWidget.updateCalendarOnlyWidgets(context) // Will read empty data after logout
            
            // Clear CounterWidget
            CounterWidget.clearAllCounterWidgets(context)
            
            Log.d("WidgetUpdateManager", "All widget types cleared successfully")
        } catch (e: Exception) {
            Log.e("WidgetUpdateManager", "Error clearing widgets: ${e.message}", e)
        }
    }
}