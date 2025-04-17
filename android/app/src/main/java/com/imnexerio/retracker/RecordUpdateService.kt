package com.imnexerio.retracker

import android.app.Service
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
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

class RecordUpdateService : Service() {
    private val handler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        val subject = intent.getStringExtra("subject") ?: ""
        val subjectCode = intent.getStringExtra("subject_code") ?: ""
        val lectureNo = intent.getStringExtra("lecture_no") ?: ""

        if (subject.isEmpty() || subjectCode.isEmpty() || lectureNo.isEmpty()) {
            Toast.makeText(this, "Invalid record information", Toast.LENGTH_SHORT).show()
            stopSelf(startId)
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
                        refreshWidgets(startId)
                    } else {
                        Toast.makeText(applicationContext, "Marking as done...", Toast.LENGTH_SHORT).show()
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
        if(noRevision<1){
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
                Toast.makeText(applicationContext, "Record updated successfully! Scheduled for $nextRevisionDate", Toast.LENGTH_SHORT).show()
                refreshWidgets(startId)
            }
            .addOnFailureListener { e ->
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
                        callback(true)
                    }
                    .addOnFailureListener {
                        callback(false)
                    }
            }
            .addOnFailureListener {
                callback(false)
            }

    }

    private fun refreshWidgets(startId: Int) {
        // Refresh widgets to show updated data
        TodayWidget.updateWidgets(this)

        // Trigger a refresh of the widget data
        val refreshIntent = Intent(this, WidgetRefreshService::class.java)
        startService(refreshIntent)

        // Stop the service after a delay
        handler.postDelayed({
            stopSelf(startId)
        }, 1000)
    }
}