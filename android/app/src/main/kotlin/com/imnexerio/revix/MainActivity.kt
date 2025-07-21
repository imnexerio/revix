package com.imnexerio.revix

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.imnexerio.revix/widget_refresh"
    private val UPDATE_RECORDS_CHANNEL = "revix/update_records"
    private val AUTO_REFRESH_CHANNEL = "com.imnexerio.revix/auto_refresh"
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

        // Initialize update records channel for communication with services
        updateRecordsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_RECORDS_CHANNEL)
        
        // Setup auto-refresh method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTO_REFRESH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAutoRefresh" -> {
                    val intervalMinutes = call.argument<Int>("intervalMinutes") ?: 1440
                    AutoRefreshManager.startAutoRefreshImmediately(this, intervalMinutes)
                    result.success(true)
                }
                "stopAutoRefresh" -> {
                    AutoRefreshManager.cancelAutoRefresh(this)
                    result.success(true)
                }
                "scheduleAutoRefresh" -> {
                    val intervalMinutes = call.argument<Int>("intervalMinutes") ?: 1440
                    AutoRefreshManager.scheduleAutoRefresh(this, intervalMinutes)
                    result.success(true)
                }
                "scheduleAutoRefreshFromLastUpdate" -> {
                    val intervalMinutes = call.argument<Int>("intervalMinutes") ?: 1440
                    val lastUpdated = call.argument<Long>("lastUpdated") ?: 0L
                    AutoRefreshManager.scheduleAutoRefreshFromLastUpdate(this, intervalMinutes, lastUpdated)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Register AlarmSchedulerPlugin
        flutterEngine.plugins.add(AlarmSchedulerPlugin())
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        permissionManager.checkAndRequestAllPermissions()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        permissionManager.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onResume() {
        super.onResume()
        // Resume permission flow when returning from system settings
        permissionManager.resumePermissionFlow()
    }
}