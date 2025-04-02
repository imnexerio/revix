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
        if (intent?.extras?.getBoolean("widget_refresh") == true) {

        }
    }

    override fun onDestroy() {
        super.onDestroy()
    }
}