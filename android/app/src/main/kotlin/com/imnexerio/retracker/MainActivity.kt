package com.imnexerio.retracker

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.imnexerio.retracker/widget_refresh"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "refreshCompleted") {
                // Notify widgets that refresh is complete with timestamp
                val sharedPreferences = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                if (!sharedPreferences.contains("lastUpdated")) {
                    val editor = sharedPreferences.edit()
                    editor.putLong("lastUpdated", System.currentTimeMillis())
                    editor.apply()
                }

                TodayWidget.updateWidgets(this)
                result.success(true)
            } else if (call.method == "manualRefresh") {
                // Trigger manual refresh from Flutter side
                val serviceIntent = Intent(this, WidgetRefreshService::class.java)
                startService(serviceIntent)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // No longer registering the screen on receiver

        // Handle the widget refresh intent
        if (intent?.extras?.getBoolean("widget_refresh") == true) {
            // We need to keep the app in the background
            // The HomeWidget plugin will handle the actual data refresh
        }
    }

    override fun onDestroy() {
        // No need to unregister the receiver anymore
        super.onDestroy()
    }
}