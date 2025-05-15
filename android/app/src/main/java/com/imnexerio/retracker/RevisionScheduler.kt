package com.imnexerio.retracker.utils

import android.content.Context
import android.widget.Toast
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

object RevisionScheduler {

    /**
     * Calculates the next revision date based on frequency pattern
     *
     * @param context Application context for error messages
     * @param frequency The frequency identifier string
     * @param noRevision Current revision count
     * @param scheduledDate The base scheduled date
     * @param callback Callback that returns the next revision date string (yyyy-MM-dd)
     */
    fun calculateNextRevisionDate(
        context: Context?,
        frequency: String,
        noRevision: Int,
        scheduledDate: Date,
        callback: (String) -> Unit
    ) {
        val userId = FirebaseAuth.getInstance().currentUser?.uid
        if (userId == null) {
            val nextDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(scheduledDate)
            callback(nextDate)
            return
        }

        val frequencyPath = "users/$userId/profile_data/custom_frequencies"

        FirebaseDatabase.getInstance().getReference(frequencyPath)
            .addListenerForSingleValueEvent(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    try {
                        if (snapshot.exists() && snapshot.hasChild(frequency)) {
                            val customFrequencyData = snapshot.child(frequency).getValue()
                            val intervals = ArrayList<Int>()

                            when (customFrequencyData) {
                                is List<*> -> {
                                    customFrequencyData.forEach { item ->
                                        (item as? Number)?.toInt()?.let { intervals.add(it) }
                                    }
                                }
                                is String -> {
                                    customFrequencyData.split(",").forEach { item ->
                                        item.trim().toIntOrNull()?.let { intervals.add(it) }
                                    }
                                }
                                is Map<*, *> -> {
                                    val values = customFrequencyData.values.toList()
                                    values.forEach { item ->
                                        (item as? Number)?.toInt()?.let { intervals.add(it) }
                                    }
                                }
                            }

                            if (intervals.isNotEmpty()) {
                                val nextInterval = if (noRevision < intervals.size) intervals[noRevision] else intervals.last()

                                val calendar = Calendar.getInstance()
                                calendar.time = scheduledDate
                                calendar.add(Calendar.DAY_OF_YEAR, nextInterval)

                                val nextDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(calendar.time)
                                callback(nextDate)
                                return
                            }
                        }

                        // Default fallback
                        val nextDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(scheduledDate)
                        callback(nextDate)

                    } catch (e: Exception) {
                        e.printStackTrace()
                        context?.let {
                            Toast.makeText(it, "Error parsing custom frequency: ${e.message}", Toast.LENGTH_SHORT).show()
                        }
                        val nextDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(scheduledDate)
                        callback(nextDate)
                    }
                }

                override fun onCancelled(error: DatabaseError) {
                    context?.let {
                        Toast.makeText(it, "Database error: ${error.message}", Toast.LENGTH_SHORT).show()
                    }
                    val nextDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(scheduledDate)
                    callback(nextDate)
                }
            })
    }
}