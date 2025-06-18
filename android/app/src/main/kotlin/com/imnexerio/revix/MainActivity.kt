package com.imnexerio.revix

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.imnexerio.revix/widget_refresh"
    private val UPDATE_RECORDS_CHANNEL = "revix/update_records"
    private val ALARM_MANAGER_CHANNEL = "revix/alarm_manager"
    private val PERMISSION_CHANNEL = "revix/permissions"
    private lateinit var alarmManagerHelper: AlarmManagerHelper
    private lateinit var permissionManager: PermissionManager

    companion object {
        @JvmStatic
        var updateRecordsChannel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize managers
        alarmManagerHelper = AlarmManagerHelper(this)
        permissionManager = PermissionManager(this)

        // Widget refresh channel (for manual refresh from main app context only)
        // Note: Background widget updates use HomeWidget package directly, not this channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "refreshCompleted") {
                val sharedPreferences = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                if (!sharedPreferences.contains("lastUpdated")) {
                    val editor = sharedPreferences.edit()
                    editor.putLong("lastUpdated", System.currentTimeMillis())
                    editor.apply()
                }
                TodayWidget.updateWidgets(this)
                result.success(true)
            } else if (call.method == "manualRefresh") {
                // Trigger refresh through Flutter background callback
                try {
                    // The refresh will be handled by Flutter's background callback
                    // Just trigger the widget update mechanism
                    val sharedPreferences = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                    val editor = sharedPreferences.edit()
                    editor.putLong("lastUpdated", System.currentTimeMillis())
                    editor.apply()

                    TodayWidget.updateWidgets(this)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("REFRESH_ERROR", "Failed to refresh widget: ${e.message}", null)
                }
            }else {
                result.notImplemented()
            }
        }

        // Alarm manager channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_MANAGER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    try {
                        // Initialization happens in constructor
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INIT_ERROR", "Failed to initialize alarm manager: ${e.message}", null)
                    }
                }
                "scheduleAlarmsForTodayRecords" -> {
                    try {
                        val todayRecords = call.argument<List<Map<String, Any>>>("todayRecords") ?: emptyList()
                        alarmManagerHelper.scheduleAlarmsForTodayRecords(todayRecords)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SCHEDULE_ERROR", "Failed to schedule alarms: ${e.message}", null)
                    }
                }
                "cancelAllAlarms" -> {
                    try {
                        alarmManagerHelper.cancelAllAlarms()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CANCEL_ERROR", "Failed to cancel alarms: ${e.message}", null)
                    }
                }
                "requestExactAlarmPermission" -> {
                    try {
                        alarmManagerHelper.requestExactAlarmPermission()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PERMISSION_ERROR", "Failed to request permission: ${e.message}", null)
                    }
                }
                "hasExactAlarmPermission" -> {
                    try {
                        val hasPermission = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                            alarmManager.canScheduleExactAlarms()
                        } else {
                            true
                        }
                        result.success(hasPermission)
                    } catch (e: Exception) {
                        result.error("PERMISSION_CHECK_ERROR", "Failed to check permission: ${e.message}", null)
                    }
                }
                "markRecordAsDone" -> {
                    try {
                        val category = call.argument<String>("category") ?: ""
                        val subCategory = call.argument<String>("sub_category") ?: ""
                        val recordTitle = call.argument<String>("record_title") ?: ""

                        // Trigger the mark as done action through the existing update records channel
                        updateRecordsChannel?.invokeMethod("markRecordAsDone", mapOf(
                            "category" to category,
                            "subCategory" to subCategory,
                            "recordTitle" to recordTitle
                        ))

                        result.success(true)
                    } catch (e: Exception) {
                        result.error("MARK_DONE_ERROR", "Failed to mark record as done: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Permission manager channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAndRequestAllPermissions" -> {
                    try {
                        permissionManager.checkAndRequestAllPermissions()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PERMISSION_ERROR", "Failed to check permissions: ${e.message}", null)
                    }
                }
                "getPermissionStatus" -> {
                    try {
                        val status = permissionManager.getPermissionStatus()
                        result.success(status)
                    } catch (e: Exception) {
                        result.error("STATUS_ERROR", "Failed to get permission status: ${e.message}", null)
                    }
                }
                "requestNotificationPermission" -> {
                    try {
                        permissionManager.requestPostNotificationPermission()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PERMISSION_ERROR", "Failed to request notification permission: ${e.message}", null)
                    }
                }
                "requestExactAlarmPermission" -> {
                    try {
                        permissionManager.requestExactAlarmPermission()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PERMISSION_ERROR", "Failed to request exact alarm permission: ${e.message}", null)
                    }
                }
                "openNotificationSettings" -> {
                    try {
                        permissionManager.openNotificationSettings()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", "Failed to open notification settings: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }        }

        // Initialize update records channel for communication with services
        updateRecordsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_RECORDS_CHANNEL)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        permissionManager.checkAndRequestAllPermissions()

        if (intent?.extras?.getBoolean("widget_refresh") == true) {
            // Handle any widget-initiated refresh
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        permissionManager.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

}