package com.imnexerio.retracker

import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.IBinder
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import android.os.Handler
import android.os.Looper

class WidgetRefreshService : Service() {
    private val handler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Ensure the service runs even if killed by the system
        fetchDataAndUpdateWidget(startId)
        return START_STICKY
    }

    private fun fetchDataAndUpdateWidget(startId: Int) {
        val firebaseAuth = FirebaseAuth.getInstance()
        if (firebaseAuth.currentUser == null) {
            updateWidgetWithLoginStatus(false)
            stopSelfWithDelay(startId)
            return
        }

        val userId = firebaseAuth.currentUser!!.uid
        val database = FirebaseDatabase.getInstance()
        val databaseRef = database.getReference("users/$userId/user_data")

        databaseRef.addListenerForSingleValueEvent(object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                if (!snapshot.exists()) {
                    updateWidgetWithEmptyData(true)
                    stopSelfWithDelay(startId)
                    return
                }

                try {
                    val rawData = snapshot.value as Map<*, *>

                    // Process data for all three view types
                    val todayRecords = processTodayRecords(rawData)
                    val missedRecords = processMissedRecords(rawData)
                    val noReminderRecords = processNoReminderRecords(rawData)

                    // Update widget with all types of data
                    updateWidgetWithAllData(todayRecords, missedRecords, noReminderRecords, true)
                } catch (e: Exception) {
                    e.printStackTrace()
                    updateWidgetWithEmptyData(true)
                }

                stopSelfWithDelay(startId)
            }

            override fun onCancelled(error: DatabaseError) {
                updateWidgetWithEmptyData(true)
                stopSelfWithDelay(startId)
            }
        })
    }

    // Add a small delay before stopping the service to ensure updates are processed
    private fun stopSelfWithDelay(startId: Int) {
        handler.postDelayed({
            stopSelf(startId)
        }, 1000) // 1 second delay
    }

    // Process data for Today's records
    private fun processTodayRecords(rawData: Map<*, *>): List<Map<String, String>> {
        val today = Calendar.getInstance()
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(today.time)
        val records = mutableListOf<Map<String, String>>()

        rawData.forEach { (subjectKey, subjectValue) ->
            if (subjectValue is Map<*, *>) {
                subjectValue.forEach { (codeKey, codeValue) ->
                    if (codeValue is Map<*, *>) {
                        codeValue.forEach { (recordKey, recordValue) ->
                            if (recordValue is Map<*, *>) {
                                val dateScheduled = recordValue["date_scheduled"]?.toString()
                                val status = recordValue["status"]?.toString()
                                val reminderTime = recordValue["reminder_time"]?.toString()
                                val revisionFrequency = recordValue["revision_frequency"]?.toString()

                                if (dateScheduled != null && status == "Enabled") {
                                    val scheduledDateStr = dateScheduled.split("T")[0]
                                    if (scheduledDateStr == todayStr) {
                                        records.add(
                                            mapOf(
                                                "subject" to subjectKey.toString(),
                                                "subject_code" to codeKey.toString(),
                                                "lecture_no" to recordKey.toString(),
                                                "reminder_time" to (reminderTime ?: "").toString(),
                                                "date_scheduled" to dateScheduled,
                                                "revision_frequency" to (revisionFrequency ?: "").toString()
                                            )
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        return records
    }

    // Process data for Missed records
    private fun processMissedRecords(rawData: Map<*, *>): List<Map<String, String>> {
        val today = Calendar.getInstance()
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(today.time)
        val records = mutableListOf<Map<String, String>>()

        rawData.forEach { (subjectKey, subjectValue) ->
            if (subjectValue is Map<*, *>) {
                subjectValue.forEach { (codeKey, codeValue) ->
                    if (codeValue is Map<*, *>) {
                        codeValue.forEach { (recordKey, recordValue) ->
                            if (recordValue is Map<*, *>) {
                                try {
                                    val dateScheduled = recordValue["date_scheduled"]?.toString()
                                    val status = recordValue["status"]?.toString()
                                    val missedRevision = (recordValue["missed_revision"] as? Number)?.toInt() ?: 0
                                    val reminderTime = recordValue["reminder_time"]?.toString()
                                    val revisionFrequency = recordValue["revision_frequency"]?.toString()

                                    // Skip if no scheduled date or not enabled
                                    if (dateScheduled == null || status != "Enabled") {
                                        return@forEach
                                    }

                                    // Skip records that are marked "Unspecified" for learning date
                                    if (recordValue["date_learnt"] == "Unspecified") {
                                        return@forEach
                                    }

                                    val scheduledDateStr = dateScheduled.split("T")[0]

                                    // Check if the scheduled date is before today (missed)
                                    if (scheduledDateStr.compareTo(todayStr) < 0) {
                                        records.add(
                                                mapOf(
                                                    "subject" to subjectKey.toString(),
                                                    "subject_code" to codeKey.toString(),
                                                    "lecture_no" to recordKey.toString(),
                                                    "reminder_time" to (reminderTime ?: "").toString(),
                                                    "date_scheduled" to dateScheduled,
                                                    "revision_frequency" to (revisionFrequency ?: "").toString(),
                                                    "missed_revision" to missedRevision.toString()
                                                )
                                            )
                                        }
                                    }
                                catch (e: Exception) {
                                    // Handle any parsing errors
//                                    e.printStackTrace()
                                }
                            }
                        }
                    }
                }
            }
        }

        return records
    }

    // Process data for No Reminder Date records
    private fun processNoReminderRecords(rawData: Map<*, *>): List<Map<String, String>> {
        val records = mutableListOf<Map<String, String>>()

        rawData.forEach { (subjectKey, subjectValue) ->
            if (subjectValue is Map<*, *>) {
                subjectValue.forEach { (codeKey, codeValue) ->
                    if (codeValue is Map<*, *>) {
                        codeValue.forEach { (recordKey, recordValue) ->
                            if (recordValue is Map<*, *>) {
                                val dateScheduled = recordValue["date_scheduled"]?.toString()
                                val status = recordValue["status"]?.toString()
                                val reminderTime = recordValue["reminder_time"]?.toString()
                                val revisionFrequency = recordValue["revision_frequency"]?.toString()

                                if (dateScheduled == "Unspecified" && status == "Enabled") {
                                    records.add(
                                        mapOf(
                                            "subject" to subjectKey.toString(),
                                            "subject_code" to codeKey.toString(),
                                            "lecture_no" to recordKey.toString(),
                                            "reminder_time" to (reminderTime ?: "").toString(),
                                            "revision_frequency" to (revisionFrequency ?: "").toString()
                                        )
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        return records
    }

    private fun updateWidgetWithAllData(
        todayRecords: List<Map<String, String>>,
        missedRecords: List<Map<String, String>>,
        noReminderRecords: List<Map<String, String>>,
        isLoggedIn: Boolean
    ) {
        val sharedPreferences = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val editor = sharedPreferences.edit()

        // Store all three types of data
        editor.putString("todayRecords", JSONArray(todayRecords).toString())
        editor.putString("missedRecords", JSONArray(missedRecords).toString())
        editor.putString("noreminderdate", JSONArray(noReminderRecords).toString())

        editor.putBoolean("isLoggedIn", isLoggedIn)
        editor.putLong("lastUpdated", System.currentTimeMillis())
        editor.apply()

        updateWidgets()
    }

    private fun updateWidgetWithEmptyData(isLoggedIn: Boolean) {
        val sharedPreferences = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val editor = sharedPreferences.edit()

        // Clear all three types of data
        editor.putString("todayRecords", "[]")
        editor.putString("missedRecords", "[]")
        editor.putString("noreminderdate", "[]")

        editor.putBoolean("isLoggedIn", isLoggedIn)
        editor.putLong("lastUpdated", System.currentTimeMillis())
        editor.apply()

        updateWidgets()
    }

    private fun updateWidgetWithLoginStatus(isLoggedIn: Boolean) {
        val sharedPreferences = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val editor = sharedPreferences.edit()
        editor.putBoolean("isLoggedIn", isLoggedIn)

        if (!isLoggedIn) {
            // Clear all three types of data if not logged in
            editor.putString("todayRecords", "[]")
            editor.putString("missedRecords", "[]")
            editor.putString("noreminderdate", "[]")
        }

        editor.putLong("lastUpdated", System.currentTimeMillis())
        editor.apply()

        updateWidgets()
    }

    private fun updateWidgets() {
        // Force update all widgets
        TodayWidget.updateWidgets(this)

        // Also explicitly notify data changes for the ListView
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
            ComponentName(this, TodayWidget::class.java)
        )

        for (appWidgetId in appWidgetIds) {
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_listview)
        }
    }
}