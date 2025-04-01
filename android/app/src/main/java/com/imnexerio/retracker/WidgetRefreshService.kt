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
                    val todayRecords = processCategorizedData(rawData)
                    updateWidgetWithData(todayRecords, true)
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

    private fun processCategorizedData(rawData: Map<*, *>): List<Map<String, String>> {
        val today = Calendar.getInstance()
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(today.time)
        val todayRecords = mutableListOf<Map<String, String>>()

        rawData.forEach { (subjectKey, subjectValue) ->
            if (subjectValue is Map<*, *>) {
                subjectValue.forEach { (codeKey, codeValue) ->
                    if (codeValue is Map<*, *>) {
                        codeValue.forEach { (recordKey, recordValue) ->
                            if (recordValue is Map<*, *>) {
                                val dateScheduled = recordValue["date_scheduled"]?.toString()
                                val status = recordValue["status"]?.toString()

                                if (dateScheduled != null && status == "Enabled") {
                                    val scheduledDateStr = dateScheduled.split("T")[0]
                                    if (scheduledDateStr == todayStr) {
                                        todayRecords.add(
                                            mapOf(
                                                "subject" to subjectKey.toString(),
                                                "subject_code" to codeKey.toString(),
                                                "lecture_no" to recordKey.toString()
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

        return todayRecords
    }

    private fun updateWidgetWithData(todayRecords: List<Map<String, String>>, isLoggedIn: Boolean) {
        val sharedPreferences = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val editor = sharedPreferences.edit()
        editor.putString("todayRecords", JSONArray(todayRecords).toString())
        editor.putBoolean("isLoggedIn", isLoggedIn)
        editor.putLong("lastUpdated", System.currentTimeMillis())
        editor.apply()

        updateWidgets()
    }

    private fun updateWidgetWithEmptyData(isLoggedIn: Boolean) {
        val sharedPreferences = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val editor = sharedPreferences.edit()
        editor.putString("todayRecords", "[]")
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
            editor.putString("todayRecords", "[]")
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