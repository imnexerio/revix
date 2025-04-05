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

        handleRecordClick(subject, subjectCode, lectureNo, startId)
        return START_STICKY
    }

    private fun handleRecordClick(subject: String, subjectCode: String, lectureNo: String, startId: Int) {
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
                        updateRecord(details, subject, subjectCode, lectureNo, startId)
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

    private fun updateRecord(details: Map<*, *>, subject: String, subjectCode: String, lectureNo: String, startId: Int) {
        try {
            // Get current date-time in the format needed
            val currentDateTime = SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.getDefault()).format(Date())
            val currentDate = currentDateTime.split("T")[0]

            // Process data similar to the Dart code
            val missedRevision = (details["missed_revision"] as? Number)?.toInt() ?: 0
            val scheduledDate = (details["date_scheduled"] as? String)?.let {
                SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse(it)
            } ?: Date()
            // Get revision frequency and revision count
            val revisionFrequency = details["revision_frequency"].toString()
            val noRevision = (details["no_revision"] as? Number)?.toInt() ?: 0

            // Calculate next revision date
            RevisionScheduler.calculateNextRevisionDate(
                applicationContext,
                revisionFrequency,
                noRevision+1,
                scheduledDate
            ) { nextRevisionDate ->
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
                updatedValues["dates_revised"] = newDatesRevised

                // Update no_revision
                val noRevision = (details["no_revision"] as? Number)?.toInt() ?: 0
                updatedValues["no_revision"] = noRevision + 1

                // Update date_scheduled with next revision date
                updatedValues["date_scheduled"] = nextRevisionDate


                // Update the record in Firebase
                val userId = FirebaseAuth.getInstance().currentUser!!.uid
                val recordPath = "users/$userId/user_data/$subject/$subjectCode/$lectureNo"
                FirebaseDatabase.getInstance().getReference(recordPath)
                    .updateChildren(updatedValues)
                    .addOnSuccessListener {
                        Toast.makeText(applicationContext, "Record updated successfully! , scheduled for $nextRevisionDate", Toast.LENGTH_SHORT).show()
                        refreshWidgets(startId)
                    }
                    .addOnFailureListener { e ->
                        Toast.makeText(applicationContext, "Update failed: ${e.message}", Toast.LENGTH_SHORT).show()
                        refreshWidgets(startId)
                        stopSelf(startId)
                    }
            }
        } catch (e: Exception) {
            Toast.makeText(applicationContext, "Error updating record: ${e.message}", Toast.LENGTH_SHORT).show()
            refreshWidgets(startId)
            e.printStackTrace()
            stopSelf(startId)
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