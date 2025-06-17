package com.imnexerio.revix

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {    companion object {
        const val ACTION_RECORD_ALARM = "revix.ACTION_RECORD_ALARM"
        const val ACTION_RECORD_PRECHECK = "revix.ACTION_RECORD_PRECHECK"
        const val ACTION_MARK_AS_DONE = "MARK_AS_DONE"
        const val EXTRA_RECORD_DATA = "record_data"
        const val EXTRA_ALARM_TYPE = "alarm_type"
        const val EXTRA_CATEGORY = "category"
        const val EXTRA_SUB_CATEGORY = "sub_category"
        const val EXTRA_RECORD_TITLE = "record_title"
        const val EXTRA_DESCRIPTION = "description"
        const val EXTRA_IS_PRECHECK = "is_precheck"
        private const val TAG = "AlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "AlarmReceiver triggered with action: ${intent.action}")
          when (intent.action) {
            ACTION_RECORD_ALARM -> {
                handleRecordAlarm(context, intent)
            }
            ACTION_RECORD_PRECHECK -> {
                handleRecordPrecheck(context, intent)
            }
            ACTION_MARK_AS_DONE -> {
                handleMarkAsDone(context, intent)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                handleBootCompleted(context)
            }
        }
    }

    private fun handleRecordAlarm(context: Context, intent: Intent) {
        val alarmType = intent.getIntExtra(EXTRA_ALARM_TYPE, 0)
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""
        val description = intent.getStringExtra(EXTRA_DESCRIPTION) ?: ""
        val isPrecheck = intent.getBooleanExtra(EXTRA_IS_PRECHECK, false)

        Log.d(TAG, "Record alarm triggered: $category - $subCategory - $recordTitle (Type: $alarmType, Precheck: $isPrecheck)")

        // Start the alarm service to handle the notification/alarm
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra(EXTRA_ALARM_TYPE, alarmType)
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
            putExtra(EXTRA_DESCRIPTION, description)
            putExtra(EXTRA_IS_PRECHECK, isPrecheck)
        }
        
        context.startForegroundService(serviceIntent)
    }

    private fun handleRecordPrecheck(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""

        Log.d(TAG, "Record precheck triggered: $category - $subCategory - $recordTitle")

        // Trigger data refresh to check if record is still pending
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            action = "PRECHECK_RECORD_STATUS"
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
        }
        
        context.startForegroundService(serviceIntent)
    }

    private fun handleMarkAsDone(context: Context, intent: Intent) {
        val category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""

        Log.d(TAG, "Mark as done triggered: $category - $subCategory - $recordTitle")

        // Trigger mark as done through Flutter background callback
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            action = "MARK_AS_DONE"
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_SUB_CATEGORY, subCategory)
            putExtra(EXTRA_RECORD_TITLE, recordTitle)
        }
        
        context.startForegroundService(serviceIntent)
    }

    private fun handleBootCompleted(context: Context) {
        Log.d(TAG, "Boot completed - rescheduling alarms")
        
        // Trigger alarm rescheduling after device reboot
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            action = "RESCHEDULE_ALARMS"
        }
        
        context.startForegroundService(serviceIntent)
    }
}
