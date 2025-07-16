package com.imnexerio.revix

import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.Manifest
import android.app.AlertDialog

class PermissionManager(private val activity: Activity) {
    companion object {
        private const val TAG = "PermissionManager"
        private const val REQUEST_CODE_POST_NOTIFICATIONS = 1001
        private const val REQUEST_CODE_EXACT_ALARM = 1002
    }    fun checkAndRequestAllPermissions() {
        Log.d(TAG, "Checking all alarm-related permissions")
        
        if (!hasPostNotificationPermission()) {
            Log.d(TAG, "Showing notification permission dialog")
            showNotificationDialog()
        } else {
            checkExactAlarmPermission()
        }
    }

    /**
     * Check and request exact alarm permission if needed
     */
    private fun checkExactAlarmPermission() {
        if (!hasExactAlarmPermission()) {
            Log.d(TAG, "Showing exact alarm dialog")
            showExactAlarmDialog()
        } else {
            checkOverlayPermissionFlow()
        }
    }

    /**
     * Check and request overlay permission if needed
     */
    private fun checkOverlayPermissionFlow() {
        if (!checkOverlayPermission()) {
            Log.d(TAG, "Showing overlay permission dialog")
            showOverlayDialog()
        } else {
            checkBatteryOptimizationFlow()
        }
    }

    /**
     * Check and request battery optimization exemption if needed
     */
    private fun checkBatteryOptimizationFlow() {
        if (!isBatteryOptimizationIgnored()) {
            Log.d(TAG, "Showing battery optimization dialog")
            showBatteryOptimizationDialog()
        } else {
            Log.d(TAG, "All permissions granted!")
        }
    }/**
     * Check notification permission (Android 13+)
     */
    fun hasPostNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            // For Android < 13, notification permission is granted by default
            true
        }
    }

    /**
     * Show dialog and request notification permission
     */
    fun showNotificationDialog() {
        AlertDialog.Builder(activity, R.style.DialogWithCenteredTitle)
            .setTitle("Notification Permission")
            .setMessage("To receive important reminders and alerts for your scheduled tasks, please grant notification permission.")
            .setPositiveButton("Grant Permission") { _, _ ->
                requestPostNotificationPermission()
            }
            .setNegativeButton("Cancel") { dialog, _ ->
                dialog.dismiss()
                // Continue to exact alarm permission even if notification was denied
                checkExactAlarmPermission()
            }
            .setCancelable(false)
            .show()
    }

    /**
     * Request notification permission (Android 13+)
     */
    fun requestPostNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (!hasPostNotificationPermission()) {
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_CODE_POST_NOTIFICATIONS
                )
            }
        }
    }

    /**
     * Check exact alarm permission (Android 12+)
     */
    fun hasExactAlarmPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = activity.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            // For Android < 12, exact alarm permission is granted by default
            true
        }
    }    /**
     * Show dialog and request exact alarm permission
     */
    fun showExactAlarmDialog() {
        AlertDialog.Builder(activity, R.style.DialogWithCenteredTitle)
            .setTitle("Alarm Permission")
            .setMessage("To ensure your reminders work precisely at the scheduled time, please grant exact alarm permission.")
            .setPositiveButton("Grant Permission") { _, _ ->
                requestExactAlarmPermission()
            }
            .setNegativeButton("Cancel") { dialog, _ ->
                dialog.dismiss()
                // Continue to overlay permission even if exact alarm was denied
                checkOverlayPermissionFlow()
            }
            .setCancelable(false)
            .show()
    }

    /**
     * Request exact alarm permission
     */
    fun requestExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!hasExactAlarmPermission()) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                        data = Uri.parse("package:${activity.packageName}")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    activity.startActivity(intent)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to open exact alarm settings", e)
                    // Fallback to general alarm settings
                    try {
                        val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:${activity.packageName}")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        activity.startActivity(fallbackIntent)
                    } catch (e2: Exception) {
                        Log.e(TAG, "Failed to open app settings", e2)
                    }
                }
            }
        }
    }

    /**
     * Check if notification channel is enabled
     */
    fun areNotificationsEnabled(): Boolean {
        val notificationManager = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return notificationManager.areNotificationsEnabled()
    }

    /**
     * Open notification settings for the app
     */
    fun openNotificationSettings() {
        try {
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            activity.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open notification settings", e)
        }
    }    /**
     * Get a summary of all permission states
     */
    fun getPermissionStatus(): Map<String, Boolean> {
        return mapOf(
            "notifications" to hasPostNotificationPermission(),
            "exactAlarm" to hasExactAlarmPermission(),
            "notificationsEnabled" to areNotificationsEnabled(),
            "overlay" to checkOverlayPermission(),
            "batteryOptimization" to isBatteryOptimizationIgnored()
        )
    }

    /**
     * Handle permission request results
     */
    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        when (requestCode) {
            REQUEST_CODE_POST_NOTIFICATIONS -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Log.d(TAG, "Notification permission granted")
                    // Continue with next permission check
                    checkExactAlarmPermission()
                } else {
                    Log.w(TAG, "Notification permission denied")
                    // Continue anyway but warn user
                    if (!areNotificationsEnabled()) {
                        showNotificationDisabledDialog()
                    } else {
                        // Still check exact alarm permission even if notification was denied
                        checkExactAlarmPermission()
                    }
                }
            }
        }
    }    /**
     * Show dialog when notifications are disabled
     */
    private fun showNotificationDisabledDialog() {
        AlertDialog.Builder(activity, R.style.DialogWithCenteredTitle)
            .setTitle("Notifications Disabled")
            .setMessage("Notifications are currently disabled for this app. You may not receive alarm notifications. Would you like to enable them?")
            .setPositiveButton("Open Settings") { _, _ ->
                openNotificationSettings()
            }
            .setNegativeButton("Continue") { dialog, _ ->
                dialog.dismiss()
                // Continue with other permission checks
                checkExactAlarmPermission()
            }
            .show()
    }

    /**
     * Check if overlay permission is granted (Android 6.0+)
     */
    fun checkOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(activity)
        } else {
            true // Permission not needed on older versions
        }
    }

    /**
     * Request overlay permission (Android 6.0+)
     */
    fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(activity)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${activity.packageName}")
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
        }
    }    /**
     * Show dialog and request overlay permission
     */
    fun showOverlayDialog() {
        AlertDialog.Builder(activity, R.style.DialogWithCenteredTitle)
            .setTitle("Overlay Permission")
            .setMessage("To display reminders and alerts on top of other apps, please grant overlay permission.")
            .setPositiveButton("Grant Permission") { _, _ ->
                requestOverlayPermission()
            }
            .setNegativeButton("Cancel") { dialog, _ ->
                dialog.dismiss()
                // Continue to battery optimization permission even if overlay was denied
                checkBatteryOptimizationFlow()
            }
            .setCancelable(false)
            .show()
    }

    /**
     * Check if battery optimization is ignored (Android 6.0+)
     */
    fun isBatteryOptimizationIgnored(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(activity.packageName)
        } else {
            true // Not applicable on older versions
        }
    }

    /**
     * Request battery optimization exemption
     */
    fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !isBatteryOptimizationIgnored()) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${activity.packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                activity.startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to open battery optimization settings", e)
                // Fallback to general battery optimization settings
                try {
                    val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    activity.startActivity(fallbackIntent)
                } catch (e2: Exception) {
                    Log.e(TAG, "Failed to open battery optimization settings", e2)
                }
            }
        }
    }

    /**
     * Show dialog and request battery optimization exemption
     */
    fun showBatteryOptimizationDialog() {
        AlertDialog.Builder(activity, R.style.DialogWithCenteredTitle)
            .setTitle("Battery Optimization")
            .setMessage("To ensure your reminders and alarms work reliably in the background, please disable battery optimization for this app.")
            .setPositiveButton("Grant Permission") { _, _ ->
                requestBatteryOptimizationExemption()
            }
            .setNegativeButton("Cancel") { dialog, _ ->
                dialog.dismiss()
                Log.d(TAG, "All permission checks completed!")
            }
            .setCancelable(false)
            .show()
    }
}
