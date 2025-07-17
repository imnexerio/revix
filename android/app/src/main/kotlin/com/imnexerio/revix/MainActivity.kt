package com.imnexerio.revix

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.imnexerio.revix/widget_refresh"
    private val UPDATE_RECORDS_CHANNEL = "revix/update_records"
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