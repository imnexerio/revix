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

class WidgetRefreshService : Service() {
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        fetchDataAndUpdateWidget()
        return START_NOT_STICKY
    }

    private fun fetchDataAndUpdateWidget() {
        val firebaseAuth = FirebaseAuth.getInstance()
        if (firebaseAuth.currentUser == null) {
            updateWidgetWithLoginStatus(false)
            stopSelf()
            return
        }

        val userId = firebaseAuth.currentUser!!.uid
        val database = FirebaseDatabase.getInstance()
        val databaseRef = database.getReference("users/$userId/user_data")

        databaseRef.addListenerForSingleValueEvent(object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                if (!snapshot.exists()) {
                    updateWidgetWithEmptyData(true)
                    stopSelf()
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

                stopSelf()
            }

            override fun onCancelled(error: DatabaseError) {
                updateWidgetWithEmptyData(true)
                stopSelf()
            }
        })
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
        editor.apply()

        updateWidgets()
    }

    private fun updateWidgetWithEmptyData(isLoggedIn: Boolean) {
        val sharedPreferences = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val editor = sharedPreferences.edit()
        editor.putString("todayRecords", "[]")
        editor.putBoolean("isLoggedIn", isLoggedIn)
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
        editor.apply()

        updateWidgets()
    }

    private fun updateWidgets() {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
            ComponentName(this, TodayWidget::class.java)
        )

        val updateIntent = Intent(this, TodayWidget::class.java)
        updateIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        updateIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
        sendBroadcast(updateIntent)
    }
}