package com.imnexerio.revix

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class AlarmSchedulerPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var alarmHelper: AlarmManagerHelper

    companion object {
        private const val TAG = "AlarmSchedulerPlugin"
        private const val CHANNEL_NAME = "alarm_scheduler"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        alarmHelper = AlarmManagerHelper(context)
        
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        
        Log.d(TAG, "AlarmSchedulerPlugin attached to engine")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "scheduleAlarms" -> {
                try {
                    val todayRecords = call.argument<List<Map<String, Any>>>("todayRecords") ?: emptyList()
                    val tomorrowRecords = call.argument<List<Map<String, Any>>>("tomorrowRecords") ?: emptyList()
                    
                    Log.d(TAG, "Received alarm scheduling request: ${todayRecords.size} today + ${tomorrowRecords.size} tomorrow records")
                    
                    alarmHelper.scheduleAlarmsForTwoDays(todayRecords, tomorrowRecords)
                    
                    Log.d(TAG, "Alarms scheduled successfully via method channel")
                    result.success(null)
                } catch (e: Exception) {
                    Log.e(TAG, "Error scheduling alarms via method channel: ${e.message}", e)
                    result.error("ALARM_SCHEDULING_ERROR", "Failed to schedule alarms: ${e.message}", null)
                }
            }
            "cancelAllAlarms" -> {
                try {
                    Log.d(TAG, "Received cancel all alarms request")
                    alarmHelper.cancelAllStoredAlarms()
                    Log.d(TAG, "All alarms cancelled successfully via method channel")
                    result.success(null)
                } catch (e: Exception) {
                    Log.e(TAG, "Error cancelling alarms via method channel: ${e.message}", e)
                    result.error("ALARM_CANCEL_ERROR", "Failed to cancel alarms: ${e.message}", null)
                }
            }
            else -> {
                Log.w(TAG, "Unknown method: ${call.method}")
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        Log.d(TAG, "AlarmSchedulerPlugin detached from engine")
    }
}
