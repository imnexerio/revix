package com.imnexerio.revix

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.util.Log
import android.content.Context

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
                "stopAutoRefresh" -> {
                    AutoRefreshManager.cancelAutoRefresh(this)
                    result.success(true)
                }
                "scheduleAutoRefreshFromLastUpdate" -> {
                    val intervalMinutes = call.argument<Int>("intervalMinutes") ?: 1440
                    val lastUpdated = (call.argument<Any>("lastUpdated") as? Number)?.toLong() ?: 0L
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
        
        // Initialize auto-refresh if enabled
        initializeAutoRefresh()
    }
    
    private fun initializeAutoRefresh() {
        try {
            // Check if user is logged in first
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isLoggedIn = flutterPrefs.getBoolean("flutter.isLoggedIn", false)
            
            if (!isLoggedIn) {
                Log.d("MainActivity", "User not logged in, skipping auto-refresh initialization")
                return
            }
            
            // Check if auto-refresh is enabled
            val autoRefreshEnabled = flutterPrefs.getBoolean("flutter.auto_refresh_enabled", true)
            val autoRefreshInterval = try {
                flutterPrefs.getInt("flutter.auto_refresh_interval_minutes", 1440)
            } catch (e: ClassCastException) {
                // Handle Long to Int conversion
                flutterPrefs.getLong("flutter.auto_refresh_interval_minutes", 1440L).toInt()
            }
            
            if (autoRefreshEnabled) {
                Log.d("MainActivity", "Initializing auto-refresh: interval=${autoRefreshInterval}m")
                AutoRefreshManager.scheduleAutoRefreshFromLastUpdate(this, autoRefreshInterval, 0L)
                Log.d("MainActivity", "Auto-refresh initialized successfully")
            } else {
                Log.d("MainActivity", "Auto-refresh is disabled, skipping initialization")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error initializing auto-refresh: ${e.message}", e)
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

    override fun onResume() {
        super.onResume()
        // Resume permission flow when returning from system settings
        permissionManager.resumePermissionFlow()
    }
}