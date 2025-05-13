package com.imnexerio.retracker

import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.widget.Toast
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener
import com.imnexerio.retracker.CalculateCustomNextDate.Companion.calculateCustomNextDate
import com.imnexerio.retracker.utils.RevisionScheduler
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicInteger

class RecordUpdateService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var activeTaskCount = AtomicInteger(0)
    private val lock = Any()

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Track active task
        synchronized(lock) {
            activeTaskCount.incrementAndGet()
        }

        if (intent == null) {
            finishTask(startId)
            return START_NOT_STICKY
        }

        val subject = intent.getStringExtra("subject") ?: ""
        val subjectCode = intent.getStringExtra("subject_code") ?: ""
        val lectureNo = intent.getStringExtra("lecture_no") ?: ""

        if (subject.isEmpty() || subjectCode.isEmpty() || lectureNo.isEmpty()) {
            Toast.makeText(this, "Invalid record information", Toast.LENGTH_SHORT).show()
            finishTask(startId)
            return START_NOT_STICKY
        }

        // Extract additional fields from intent
        val extras = HashMap<String, String>()
        intent.extras?.let { bundle ->
            for (key in bundle.keySet()) {
                if (key != "subject" && key != "subject_code" && key != "lecture_no") {
                    val value = bundle.getString(key)
                    if (value != null) {
                        extras[key] = value
                    }
                }
            }
        }

        handleRecordClick(subject, subjectCode, lectureNo, extras, startId)
        return START_STICKY
    }

    private fun finishTask(startId: Int) {
        synchronized(lock) {
            val remainingTasks = activeTaskCount.decrementAndGet()
            if (remainingTasks <= 0) {
                // Make sure we use a new handler to avoid timing issues
                handler.post {
                    handler.postDelayed({
                        stopSelf()
                    }, 1000)
                }
            } else {
                // Only stop this specific task
                stopSelf(startId)
            }
        }
    }

    private fun refreshWidgets(startId: Int) {
        try {
            // Instead of direct widget updates, send a broadcast
            val context = applicationContext
            val intent = Intent(context, TodayWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, TodayWidget::class.java)
                )
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
            }
            context.sendBroadcast(intent)

            // Start refresh service after handling our task
            val refreshIntent = Intent(this, WidgetRefreshService::class.java)
            startService(refreshIntent)

            // Complete this task
            finishTask(startId)
        } catch (e: Exception) {
            // Handle any exceptions that occur during the refresh
            Toast.makeText(this, "Error refreshing widgets: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    private fun handleRecordClick(
        subject: String,
        subjectCode: String,
        lectureNo: String,
        extras: Map<String, String>,
        startId: Int
    ) {
        val firebaseAuth = FirebaseAuth.getInstance()
        if (firebaseAuth.currentUser == null) {
            Toast.makeText(this, "Please login to update records", Toast.LENGTH_SHORT).show()
            stopSelf(startId)
            return
        }

        val userId = firebaseAuth.currentUser!!.uid
        val recordPath = "users/$userId/user_data/$subject/$subjectCode/$lectureNo"
        val database = FirebaseDatabase.getInstance()
        val recordRef = database.getReference(recordPath)

        recordRef.addListenerForSingleValueEvent(object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                if (!snapshot.exists()) {
                    Toast.makeText(applicationContext, "Record not found", Toast.LENGTH_SHORT).show()
                    stopSelf(startId)
                    return
                }

                try {
                    val details = snapshot.value as Map<*, *>

                    // Check if today's date is already in dates_revised
                    val dateRevised = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(
                        Date()
                    )
                    val datesRevised = details["dates_revised"] as? List<*> ?: listOf<String>()

                    // Check if the record has been revised today
                    val revisedToday = datesRevised.any {
                        (it as? String)?.startsWith(dateRevised) == true
                    }

                    if (revisedToday) {
                        // Already revised today, just refresh
                        Toast.makeText(applicationContext, "Already revised today. Refreshing data...", Toast.LENGTH_SHORT).show()
                        clearProcessingState(subject, subjectCode, lectureNo) // NEW LINE
                        refreshWidgets(startId)
                    } else {
                        updateRecord(details, subject, subjectCode, lectureNo, extras, startId)
                    }
                } catch (e: Exception) {
                    Toast.makeText(applicationContext, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
                    e.printStackTrace()
                    stopSelf(startId)
                }
            }

            override fun onCancelled(error: DatabaseError) {
                Toast.makeText(applicationContext, "Database error: ${error.message}", Toast.LENGTH_SHORT).show()
                stopSelf(startId)
            }
        })
    }

    private fun updateRecord(
        details: Map<*, *>,
        subject: String,
        subjectCode: String,
        lectureNo: String,
        extras: Map<String, String>,
        startId: Int
    ) {
        try {
            // First check for "Unspecified" date_learnt
            if (details["date_learnt"] == "Unspecified") {
                moveToDeletedData(subject, subjectCode, lectureNo, details) { success ->
                    if (success) {
                        handler.post {
                            Toast.makeText(
                                applicationContext,
                                "$subject $subjectCode $lectureNo has been marked as done and moved to deleted data.",
                                Toast.LENGTH_LONG
                            ).show()
                        }
                        refreshWidgets(startId)
                    } else {
                        handler.post {
                            Toast.makeText(
                                applicationContext,
                                "Failed to move record to deleted data",
                                Toast.LENGTH_SHORT
                            ).show()
                        }
                        stopSelf(startId)
                    }
                }
                return
            }

            // Then check for "No Repetition" revision frequency
            if (details["revision_frequency"] == "No Repetition") {
                moveToDeletedData(subject, subjectCode, lectureNo, details) { success ->
                    if (success) {
                        handler.post {
                            Toast.makeText(
                                applicationContext,
                                "$subject $subjectCode $lectureNo has been marked as done and moved to deleted data.",
                                Toast.LENGTH_LONG
                            ).show()
                        }
                        refreshWidgets(startId)
                    } else {
                        handler.post {
                            Toast.makeText(
                                applicationContext,
                                "Failed to move record to deleted data",
                                Toast.LENGTH_SHORT
                            ).show()
                        }
                        stopSelf(startId)
                    }
                }
                return
            }

            // Get current date-time in the format needed
            val currentDateTime = SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.getDefault()).format(Date())
            val currentDate = currentDateTime.split("T")[0]

            // Process data
            val missedRevision = (details["missed_revision"] as? Number)?.toInt() ?: 0
            val scheduledDate = (details["date_scheduled"] as? String)?.let {
                SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse(it)
            } ?: Date()

            // Get revision frequency and revision count
            val revisionFrequency = details["revision_frequency"]?.toString() ?:
                extras["revision_frequency"] ?: "daily"

            val noRevision = (details["no_revision"] as? Number)?.toInt() ?: 0

            // Calculate next revision date based on frequency type
            if (revisionFrequency == "Custom") {
                // Handle custom revision frequency
                @Suppress("UNCHECKED_CAST")
                val revisionData = details["revision_data"] as? Map<String, Any?> ?: emptyMap()

                val dateScheduledStr = details["date_scheduled"] as? String ?: currentDate
                val dateScheduled = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse(dateScheduledStr)
                val scheduledCalendar = Calendar.getInstance()
                scheduledCalendar.time = dateScheduled ?: Date()

                val nextDate = calculateCustomNextDate(scheduledCalendar, revisionData)
                val nextRevisionDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(nextDate.time)

                updateRecordWithNextDate(
                    details, subject, subjectCode, lectureNo,
                    currentDateTime, currentDate, missedRevision,
                    scheduledDate, noRevision, nextRevisionDate, startId
                )
            } else {
                // Use the standard revision scheduler for non-custom frequencies
                RevisionScheduler.calculateNextRevisionDate(
                    applicationContext,
                    revisionFrequency,
                    noRevision + 1,
                    scheduledDate
                ) { nextRevisionDate ->
                    updateRecordWithNextDate(
                        details, subject, subjectCode, lectureNo,
                        currentDateTime, currentDate, missedRevision,
                        scheduledDate, noRevision, nextRevisionDate, startId
                    )
                }
            }
        } catch (e: Exception) {
            Toast.makeText(applicationContext, "Error updating record: ${e.message}", Toast.LENGTH_SHORT).show()
            refreshWidgets(startId)
            e.printStackTrace()
            stopSelf(startId)
        }
    }


    // Helper method to update the record with the calculated next date
    private fun updateRecordWithNextDate(
        details: Map<*, *>,
        subject: String,
        subjectCode: String,
        lectureNo: String,
        currentDateTime: String,
        currentDate: String,
        missedRevision: Int,
        scheduledDate: Date,
        noRevision: Int,
        nextRevisionDate: String,
        startId: Int
    ) {
        // Create updated values map
        val updatedValues = HashMap<String, Any>()

        // Update date_revised
        updatedValues["date_revised"] = currentDateTime

        // Handle missed revisions if scheduled date is in the past
        var newMissedRevision = missedRevision
        val datesMissedRevisions = details["dates_missed_revisions"] as? List<*> ?: listOf<String>()
        val newDatesMissedRevisions = ArrayList<String>(datesMissedRevisions.map { it.toString() })

        val scheduledDateStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(scheduledDate)
        if (scheduledDateStr.compareTo(currentDate) < 0) {
            newMissedRevision += 1
            if (!newDatesMissedRevisions.contains(scheduledDateStr)) {
                newDatesMissedRevisions.add(scheduledDateStr)
            }
        }

        updatedValues["missed_revision"] = newMissedRevision
        updatedValues["dates_missed_revisions"] = newDatesMissedRevisions

        // Update dates_revised
        val datesRevised = details["dates_revised"] as? List<*> ?: listOf<String>()
        val newDatesRevised = ArrayList<String>(datesRevised.map { it.toString() })
        newDatesRevised.add(currentDateTime)
        if(noRevision==-1){
            newDatesRevised.clear()
        }
        updatedValues["dates_revised"] = newDatesRevised

        // Update no_revision
        updatedValues["no_revision"] = noRevision + 1

        // Update date_scheduled with next revision date
        updatedValues["date_scheduled"] = nextRevisionDate
        // Update the record in Firebase
        val userId = FirebaseAuth.getInstance().currentUser!!.uid
        val recordPath = "users/$userId/user_data/$subject/$subjectCode/$lectureNo"
        FirebaseDatabase.getInstance().getReference(recordPath)
            .updateChildren(updatedValues)
            .addOnSuccessListener {
                clearProcessingState(subject, subjectCode, lectureNo) // NEW LINE
                Toast.makeText(applicationContext, "Record updated successfully! Scheduled for $nextRevisionDate", Toast.LENGTH_SHORT).show()
                refreshWidgets(startId)
            }
            .addOnFailureListener { e ->
                clearProcessingState(subject, subjectCode, lectureNo) // NEW LINE
                Toast.makeText(applicationContext, "Update failed: ${e.message}", Toast.LENGTH_SHORT).show()
                refreshWidgets(startId)
                stopSelf(startId)
            }
    }

    private fun moveToDeletedData(
        subject: String,
        subjectCode: String,
        lectureNo: String,
        details: Map<*, *>,
        callback: (Boolean) -> Unit
    ) {
        val firebaseAuth = FirebaseAuth.getInstance()
        if (firebaseAuth.currentUser == null) {
            callback(false)
            return
        }

        val userId = firebaseAuth.currentUser!!.uid
        val database = FirebaseDatabase.getInstance()

        // Reference to deleted data location
        val deletedRef = database.getReference("users/$userId/deleted_user_data/$subject/$subjectCode/$lectureNo")

        // Convert details to mutable map
        val dataToMove = HashMap<String, Any>()
        details.forEach { (key, value) ->
            if (key != null && value != null) {
                dataToMove[key.toString()] = value
            }
        }

        // Add deletion timestamp
        dataToMove["deleted_at"] = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())

        // Move to deleted data
        deletedRef.setValue(dataToMove)
            .addOnSuccessListener {
                // After successful move, delete from original location
                val originalRef = database.getReference("users/$userId/user_data/$subject/$subjectCode/$lectureNo")
                originalRef.removeValue()
                    .addOnSuccessListener {
                        clearProcessingState(subject, subjectCode, lectureNo) // NEW LINE
                        callback(true)
                    }
                    .addOnFailureListener {
                        clearProcessingState(subject, subjectCode, lectureNo) // NEW LINE
                        callback(false)
                    }
            }
            .addOnFailureListener {
                clearProcessingState(subject, subjectCode, lectureNo) // NEW LINE
                callback(false)
            }

    }

    private fun clearProcessingState(subject: String, subjectCode: String, lectureNo: String) {
        val prefs = applicationContext.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val processingItems = prefs.getStringSet(TodayWidget.PREF_PROCESSING_ITEMS, mutableSetOf()) ?: mutableSetOf()
        val itemKey = "${subject}_${subjectCode}_${lectureNo}"
        val newProcessingItems = processingItems.toMutableSet()
        newProcessingItems.remove(itemKey)
        prefs.edit().putStringSet(TodayWidget.PREF_PROCESSING_ITEMS, newProcessingItems).apply()
    }
}
