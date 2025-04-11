package com.imnexerio.retracker

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.app.AlertDialog

class BatteryOptimizationManager(private val context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("BatteryOptPrefs", Context.MODE_PRIVATE)

    fun hasWidget(): Boolean {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
            ComponentName(context, TodayWidget::class.java)
        )
        return appWidgetIds.isNotEmpty()
    }

    fun shouldShowOptimizationRequest(): Boolean {
        // Check if we have widget AND haven't asked/granted permission
        return hasWidget() && !isIgnoringBatteryOptimizations() && !hasAskedForPermission()
    }

    fun isIgnoringBatteryOptimizations(): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun hasAskedForPermission(): Boolean {
        return prefs.getBoolean("asked_battery_opt", false)
    }

    fun markAskedForPermission() {
        prefs.edit().putBoolean("asked_battery_opt", true).apply()
    }

    fun requestIgnoreBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
                markAskedForPermission()
            } catch (e: Exception) {
                // Fallback in case the direct request isn't supported
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
                markAskedForPermission()
            }
        }
    }

    fun showBatteryOptimizationDialog() {
        val dialog = AlertDialog.Builder(context, R.style.DialogWithCenteredTitle)
            .setTitle("Keep Widget Updated")
            .setMessage("For the widget to update reliably, please allow this app to run in the background by disabling battery optimization.")
            .setPositiveButton("Settings") { _, _ ->
                requestIgnoreBatteryOptimization()
            }
            .setNegativeButton("Later") { _, _ ->
                markAskedForPermission()
            }
            .create()

        dialog.show()
    }
}