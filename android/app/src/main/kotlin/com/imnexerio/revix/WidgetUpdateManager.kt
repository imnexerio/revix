package com.imnexerio.revix

import android.content.Context
import android.util.Log

object WidgetUpdateManager {
    
    fun updateAllWidgets(context: Context) {
        try {
            Log.d("WidgetUpdateManager", "Updating all widget types...")
            
            // Update TodayWidget (Records Only - combined data)
            TodayWidget.updateWidgets(context)
            
            // Update CalendarWidget (Calendar + Records - combined data)
            CalendarWidget.updateCalendarWidgets(context)
            
            // Update CalendarOnlyWidget (Calendar Only - no records)
            CalendarOnlyWidget.updateCalendarOnlyWidgets(context)
            
            Log.d("WidgetUpdateManager", "All widget types updated successfully")
        } catch (e: Exception) {
            Log.e("WidgetUpdateManager", "Error updating widgets: ${e.message}", e)
        }
    }
    
    fun clearAllWidgets(context: Context) {
        try {
            Log.d("WidgetUpdateManager", "Clearing all widget types...")
            
            // Clear TodayWidget
            TodayWidget.updateWidgets(context) // Will read empty data after logout
            
            // Clear CalendarWidget
            CalendarWidget.clearAllCalendarWidgets(context)
            
            // Clear CalendarOnlyWidget
            CalendarOnlyWidget.updateCalendarOnlyWidgets(context) // Will read empty data after logout
            
            Log.d("WidgetUpdateManager", "All widget types cleared successfully")
        } catch (e: Exception) {
            Log.e("WidgetUpdateManager", "Error clearing widgets: ${e.message}", e)
        }
    }
}