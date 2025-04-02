package com.imnexerio.retracker

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

class FetchTrackingTypesUtils {
    companion object {
        // Callback style method
        fun fetchTrackingTypes(callback: (List<String>) -> Unit) {
            val uid = FirebaseAuth.getInstance().currentUser?.uid
            if (uid == null) {
                callback(emptyList())
                return
            }

            val databaseRef = FirebaseDatabase.getInstance()
                .getReference("users/$uid/profile_data/custom_trackingType")

            databaseRef.addListenerForSingleValueEvent(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    val data = mutableListOf<String>()
                    if (snapshot.exists()) {
                        try {
                            // Try to cast to List
                            for (child in snapshot.children) {
                                child.getValue(String::class.java)?.let {
                                    data.add(it)
                                }
                            }
                        } catch (e: Exception) {
                            // Fallback if structure is different
                            // Provide default values
                            data.addAll(listOf("Lectures", "Handouts", "Others"))
                        }
                    }

                    // If no data was found, provide defaults
                    if (data.isEmpty()) {
                        data.addAll(listOf("Lectures", "Handouts", "Others"))
                    }

                    callback(data)
                }

                override fun onCancelled(error: DatabaseError) {
                    // Return default values on error
                    callback(listOf("Lectures", "Handouts", "Others"))
                }
            })
        }

        // Suspending function for use with coroutines
        suspend fun fetchTrackingTypesAsync(): List<String> = suspendCoroutine { continuation ->
            fetchTrackingTypes { types ->
                continuation.resume(types)
            }
        }
    }
}