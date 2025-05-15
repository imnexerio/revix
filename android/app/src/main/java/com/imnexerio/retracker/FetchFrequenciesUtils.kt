package com.imnexerio.retracker

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

class FetchFrequenciesUtils {
    companion object {
        // Callback style method
        fun fetchFrequencies(callback: (Map<String, List<Int>>) -> Unit) {
            val uid = FirebaseAuth.getInstance().currentUser?.uid
            if (uid == null) {
//                callback(getDefaultFrequencies())
                return
            }

            val databaseRef = FirebaseDatabase.getInstance()
                .getReference("users/$uid/profile_data/custom_frequencies")

            databaseRef.addListenerForSingleValueEvent(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    val data = mutableMapOf<String, List<Int>>()

                    if (snapshot.exists()) {
                        try {
                            for (child in snapshot.children) {
                                val frequencyName = child.key as String
                                val valuesList = mutableListOf<Int>()

                                for (valueSnapshot in child.children) {
                                    valueSnapshot.getValue(Int::class.java)?.let {
                                        valuesList.add(it)
                                    }
                                }

                                if (valuesList.isNotEmpty()) {
                                    data[frequencyName] = valuesList
                                }
                            }
                        } catch (e: Exception) {
                            // Return default values if there's an error parsing
//                            callback(getDefaultFrequencies())
                            return
                        }
                    }

                    // If no data was found, provide defaults
                    if (data.isEmpty()) {
//                        callback(getDefaultFrequencies())
                    } else {
                        callback(data)
                    }
                }

                override fun onCancelled(error: DatabaseError) {
                    // Return default values on error
//                    callback(getDefaultFrequencies())
                }
            })
        }

        // Suspending function for use with coroutines
        suspend fun fetchFrequenciesAsync(): Map<String, List<Int>> = suspendCoroutine { continuation ->
            fetchFrequencies { frequencies ->
                continuation.resume(frequencies)
            }
        }


        // Utility function to get a list of frequency names
        fun getFrequencyNames(frequenciesMap: Map<String, List<Int>>): List<String> {
            return frequenciesMap.keys.toList()
        }
    }
}