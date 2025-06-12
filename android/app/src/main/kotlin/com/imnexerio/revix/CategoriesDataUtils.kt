package com.imnexerio.revix

import android.content.Context
import android.util.Log
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject

/**
 * Utility object for categories and subcategories data
 * Used by AddLectureActivity to fetch categories data from SharedPreferences
 * This replaces the direct Firebase database calls for better performance and consistency
 */
object CategoriesDataUtils {

    /**
     * Fetch categories and subcategories data from SharedPreferences
     * This uses cached data that HomeWidgetManager updates
     */
    fun fetchCategoriesAndSubCategories(context: Context, callback: (List<String>, Map<String, List<String>>) -> Unit) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                // Get categories data from SharedPreferences that HomeWidgetManager updates
                val sharedPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val categoriesDataJson = sharedPrefs.getString("categoriesData", null)

                val subjects = mutableListOf<String>()
                val subCategories = mutableMapOf<String, List<String>>()

                if (categoriesDataJson != null && categoriesDataJson.isNotEmpty() && categoriesDataJson != "{}") {
                    try {
                        Log.d("CategoriesDataUtils", "Fetching categories data from SharedPrefs: $categoriesDataJson")

                        val jsonData = JSONObject(categoriesDataJson)

                        // Parse subjects array
                        if (jsonData.has("subjects")) {
                            val subjectsArray = jsonData.getJSONArray("subjects")
                            for (i in 0 until subjectsArray.length()) {
                                subjects.add(subjectsArray.getString(i))
                            }
                        }

                        // Parse subCategories object
                        if (jsonData.has("subCategories")) {
                            val subCategoriesObject = jsonData.getJSONObject("subCategories")
                            val keys = subCategoriesObject.keys()

                            while (keys.hasNext()) {
                                val key = keys.next()
                                val value = subCategoriesObject.get(key)

                                when (value) {
                                    is JSONArray -> {
                                        val subCategoryList = mutableListOf<String>()
                                        for (i in 0 until value.length()) {
                                            subCategoryList.add(value.getString(i))
                                        }
                                        subCategories[key] = subCategoryList
                                    }
                                    else -> {
                                        Log.w("CategoriesDataUtils", "Unexpected value type for subcategory $key: $value")
                                        subCategories[key] = emptyList()
                                    }
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.e("CategoriesDataUtils", "Error parsing categories JSON data", e)
                    }
                } else {
                    Log.d("CategoriesDataUtils", "No categories data found in SharedPreferences, using empty data")
                }

                Log.d("CategoriesDataUtils", "Fetched categories data - Subjects: $subjects, SubCategories: $subCategories")

                // Switch back to main thread for callback
                withContext(Dispatchers.Main) {
                    callback(subjects, subCategories)
                }
            } catch (e: Exception) {
                Log.e("CategoriesDataUtils", "Error fetching categories and subcategories: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    callback(emptyList(), emptyMap())
                }
            }
        }
    }

    /**
     * Synchronous version of fetchCategoriesAndSubCategories for use when already on a background thread
     */
    fun fetchCategoriesAndSubCategoriesSync(context: Context): Pair<List<String>, Map<String, List<String>>> {
        return try {
            val sharedPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val categoriesDataJson = sharedPrefs.getString("categoriesData", null)

            val subjects = mutableListOf<String>()
            val subCategories = mutableMapOf<String, List<String>>()

            if (categoriesDataJson != null && categoriesDataJson.isNotEmpty() && categoriesDataJson != "{}") {
                try {
                    Log.d("CategoriesDataUtils", "Fetching categories data sync from SharedPrefs: $categoriesDataJson")

                    val jsonData = JSONObject(categoriesDataJson)

                    // Parse subjects array
                    if (jsonData.has("subjects")) {
                        val subjectsArray = jsonData.getJSONArray("subjects")
                        for (i in 0 until subjectsArray.length()) {
                            subjects.add(subjectsArray.getString(i))
                        }
                    }

                    // Parse subCategories object
                    if (jsonData.has("subCategories")) {
                        val subCategoriesObject = jsonData.getJSONObject("subCategories")
                        val keys = subCategoriesObject.keys()

                        while (keys.hasNext()) {
                            val key = keys.next()
                            val value = subCategoriesObject.get(key)

                            when (value) {
                                is JSONArray -> {
                                    val subCategoryList = mutableListOf<String>()
                                    for (i in 0 until value.length()) {
                                        subCategoryList.add(value.getString(i))
                                    }
                                    subCategories[key] = subCategoryList
                                }
                                else -> {
                                    Log.w("CategoriesDataUtils", "Unexpected value type for subcategory $key: $value")
                                    subCategories[key] = emptyList()
                                }
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e("CategoriesDataUtils", "Error parsing categories JSON data sync", e)
                }
            }

            Log.d("CategoriesDataUtils", "Fetched categories data sync - Subjects: $subjects, SubCategories: $subCategories")
            Pair(subjects, subCategories)
        } catch (e: Exception) {
            Log.e("CategoriesDataUtils", "Error fetching categories and subcategories sync: ${e.message}", e)
            Pair(emptyList(), emptyMap())
        }
    }
}
