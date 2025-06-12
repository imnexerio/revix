package com.imnexerio.revix

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle

class MainActivity : FlutterActivity() {
    private val CHANNEL = "revix/widget_refresh"
    private lateinit var batteryOptManager: BatteryOptimizationManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize the battery optimization manager
        batteryOptManager = BatteryOptimizationManager(this)

        // Check if we need to request battery optimization exemption
        if (batteryOptManager.shouldShowOptimizationRequest()) {
            batteryOptManager.showBatteryOptimizationDialog()
        }

        if (intent?.extras?.getBoolean("widget_refresh") == true) {
            // Handle any widget-initiated refresh
        }
    }

}