package com.imnexerio.revix

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import org.json.JSONArray
import org.json.JSONObject

class RecordSelectionActivity : AppCompatActivity() {

    private lateinit var categoriesRecycler: RecyclerView
    private lateinit var subcategoriesRecycler: RecyclerView
    private lateinit var recordsRecycler: RecyclerView
    private lateinit var btnCancel: Button

    private lateinit var categoriesAdapter: CategoriesAdapter
    private lateinit var subcategoriesAdapter: SubcategoriesAdapter
    private lateinit var recordsAdapter: RecordsAdapter

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var allRecords: Map<String, Map<String, List<JSONObject>>> = emptyMap()
    private var selectedCategory: String? = null
    private var selectedSubcategory: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_record_selection)

        // Get widget ID
        appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        )

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        initViews()
        loadAllRecords()
        setupRecyclerViews()
    }

    private fun initViews() {
        categoriesRecycler = findViewById(R.id.categories_recycler)
        subcategoriesRecycler = findViewById(R.id.subcategories_recycler)
        recordsRecycler = findViewById(R.id.records_recycler)
        btnCancel = findViewById(R.id.btn_cancel)

        btnCancel.setOnClickListener { finish() }
    }

    private fun loadAllRecords() {
        try {
            val sharedPreferences = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
            val allRecordsJson = sharedPreferences.getString("allRecords", "[]")
            val allRecordsArray = JSONArray(allRecordsJson ?: "[]")

            Log.d("RecordSelection", "Raw allRecords JSON: $allRecordsJson")
            Log.d("RecordSelection", "Parsed array length: ${allRecordsArray.length()}")

            allRecords = groupRecordsByCategory(allRecordsArray)
            Log.d("RecordSelection", "Loaded ${allRecords.size} categories")

        } catch (e: Exception) {
            Log.e("RecordSelection", "Error loading records: ${e.message}", e)
            allRecords = emptyMap()
        }
    }

    private fun groupRecordsByCategory(allRecordsArray: JSONArray): Map<String, Map<String, List<JSONObject>>> {
        val grouped = mutableMapOf<String, MutableMap<String, MutableList<JSONObject>>>()

        for (i in 0 until allRecordsArray.length()) {
            try {
                val record = allRecordsArray.getJSONObject(i)
                val category = record.getString("category")
                val subCategory = record.getString("sub_category")

                grouped.getOrPut(category) { mutableMapOf() }
                    .getOrPut(subCategory) { mutableListOf() }
                    .add(record)

            } catch (e: Exception) {
                Log.e("RecordSelection", "Error parsing record $i: ${e.message}")
            }
        }

        return grouped
    }

    private fun setupRecyclerViews() {
        // Categories RecyclerView
        categoriesRecycler.layoutManager = LinearLayoutManager(this, LinearLayoutManager.HORIZONTAL, false)
        categoriesAdapter = CategoriesAdapter(allRecords.keys.toList()) { category ->
            onCategorySelected(category)
        }
        categoriesRecycler.adapter = categoriesAdapter

        // Subcategories RecyclerView  
        subcategoriesRecycler.layoutManager = LinearLayoutManager(this, LinearLayoutManager.HORIZONTAL, false)
        subcategoriesAdapter = SubcategoriesAdapter(emptyList()) { subcategory ->
            onSubcategorySelected(subcategory)
        }
        subcategoriesRecycler.adapter = subcategoriesAdapter

        // Records RecyclerView
        recordsRecycler.layoutManager = LinearLayoutManager(this)
        recordsAdapter = RecordsAdapter(emptyList()) { record ->
            onRecordSelected(record)
        }
        recordsRecycler.adapter = recordsAdapter

        // Select first category if available
        if (allRecords.isNotEmpty()) {
            onCategorySelected(allRecords.keys.first())
        }
        
        Log.d("RecordSelection", "RecyclerViews setup complete. Categories: ${allRecords.keys.size}")
    }

    private fun onCategorySelected(category: String) {
        selectedCategory = category
        categoriesAdapter.setSelectedCategory(category)

        val subcategories = allRecords[category]?.keys?.toList() ?: emptyList()
        subcategoriesAdapter.updateSubcategories(subcategories)

        // Select first subcategory if available
        if (subcategories.isNotEmpty()) {
            onSubcategorySelected(subcategories.first())
        }
    }

    private fun onSubcategorySelected(subcategory: String) {
        selectedSubcategory = subcategory
        subcategoriesAdapter.setSelectedSubcategory(subcategory)

        val records = allRecords[selectedCategory]?.get(subcategory) ?: emptyList()
        recordsAdapter.updateRecords(records)
    }

    private fun onRecordSelected(record: JSONObject) {
        try {
            val category = record.optString("category", "")
            val subCategory = record.optString("sub_category", "")
            val recordTitle = record.optString("record_title", "")
            
            // Parse details - it might be a string instead of JSON object
            var details: JSONObject? = null
            val detailsString = record.optString("details", "")
            if (detailsString.isNotEmpty()) {
                try {
                    // Try to parse the details string as JSON
                    details = JSONObject(detailsString)
                    Log.d("RecordSelection", "Parsed details string as JSON for selection: $recordTitle")
                } catch (e: Exception) {
                    Log.d("RecordSelection", "Details string is not valid JSON for selection, will extract manually")
                    // The string is malformed JSON, extract scheduled_date manually
                }
            } else {
                // Try to get details as object
                details = record.optJSONObject("details")
            }

            Log.d("RecordSelection", "Record selection - Category: $category, SubCategory: $subCategory, Title: $recordTitle")

            if (category.isEmpty() || subCategory.isEmpty() || recordTitle.isEmpty()) {
                Log.e("RecordSelection", "Missing required fields in record: $record")
                return
            }

            // Try to get scheduled_date from details first, then from string, then directly from record
            var scheduledDate = details?.optString("scheduled_date", "") ?: ""
            
            if (scheduledDate.isEmpty() && detailsString.isNotEmpty()) {
                // Extract scheduled_date from the malformed JSON string using regex
                val scheduledDateRegex = Regex("scheduled_date:\\s*([^,}]+)")
                val matchResult = scheduledDateRegex.find(detailsString)
                if (matchResult != null) {
                    scheduledDate = matchResult.groupValues[1].trim()
                    Log.d("RecordSelection", "Extracted scheduled_date from string for selection: $scheduledDate")
                }
            }
            
            if (scheduledDate.isEmpty()) {
                scheduledDate = record.optString("scheduled_date", "")
                Log.d("RecordSelection", "Found scheduled_date directly in record: $scheduledDate")
            } else {
                Log.d("RecordSelection", "Found scheduled_date in details: $scheduledDate")
            }

            Log.d("RecordSelection", "Final scheduled date: $scheduledDate")

            if (category.isEmpty() || subCategory.isEmpty() || recordTitle.isEmpty() || scheduledDate.isEmpty() || scheduledDate == "Unspecified") {
                Log.e("RecordSelection", "Missing required fields or no scheduled date in record: $record")
                return
            }

            // Save selection for this widget - always use scheduled_date
            val prefs = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
            prefs.edit()
                .putString(CounterWidget.getSelectedRecordKey(appWidgetId), "${category}_${subCategory}_${recordTitle}")
                .putString(CounterWidget.getTargetDateKey(appWidgetId), scheduledDate)
                .putString(CounterWidget.getRecordTitleKey(appWidgetId), recordTitle)
                .putString(CounterWidget.getCategoryKey(appWidgetId), category)
                .putString(CounterWidget.getSubCategoryKey(appWidgetId), subCategory)
                .apply()

            Log.d("RecordSelection", "Selected record: $recordTitle, scheduled date: $scheduledDate")

            // Update the widget
            val appWidgetManager = AppWidgetManager.getInstance(this)
            CounterWidget.updateCounterWidget(this, appWidgetManager, appWidgetId)

            // Set result and finish
            val resultValue = Intent()
            resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            setResult(RESULT_OK, resultValue)
            finish()

        } catch (e: Exception) {
            Log.e("RecordSelection", "Error selecting record: ${e.message}", e)
            Log.e("RecordSelection", "Record data: ${record.toString()}")
        }
    }

    // Categories Adapter
    inner class CategoriesAdapter(
        private var categories: List<String>,
        private val onCategoryClick: (String) -> Unit
    ) : RecyclerView.Adapter<CategoriesAdapter.ViewHolder>() {

        private var selectedCategory: String? = null

        fun setSelectedCategory(category: String) {
            val oldSelected = selectedCategory
            selectedCategory = category
            oldSelected?.let { notifyItemChanged(categories.indexOf(it)) }
            notifyItemChanged(categories.indexOf(category))
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.item_category, parent, false)
            return ViewHolder(view)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            val category = categories[position]
            holder.textView.text = category
            
            // Apply selection styling
            if (category == selectedCategory) {
                holder.textView.setBackgroundColor(0xFF3F51B5.toInt()) // Primary color
                holder.textView.setTextColor(0xFFFFFFFF.toInt()) // White text
            } else {
                holder.textView.background = null
                holder.textView.setTextColor(0xFF000000.toInt()) // Black text
            }
            
            holder.itemView.setOnClickListener { onCategoryClick(category) }
        }

        override fun getItemCount() = categories.size

        inner class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
            val textView: TextView = view.findViewById(android.R.id.text1)
        }
    }

    // Subcategories Adapter
    inner class SubcategoriesAdapter(
        private var subcategories: List<String>,
        private val onSubcategoryClick: (String) -> Unit
    ) : RecyclerView.Adapter<SubcategoriesAdapter.ViewHolder>() {

        private var selectedSubcategory: String? = null

        fun updateSubcategories(newSubcategories: List<String>) {
            subcategories = newSubcategories
            selectedSubcategory = null
            notifyDataSetChanged()
        }

        fun setSelectedSubcategory(subcategory: String) {
            val oldSelected = selectedSubcategory
            selectedSubcategory = subcategory
            oldSelected?.let { notifyItemChanged(subcategories.indexOf(it)) }
            notifyItemChanged(subcategories.indexOf(subcategory))
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.item_subcategory, parent, false)
            return ViewHolder(view)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            val subcategory = subcategories[position]
            holder.textView.text = subcategory
            
            // Apply selection styling
            if (subcategory == selectedSubcategory) {
                holder.textView.setBackgroundColor(0xFF3F51B5.toInt()) // Primary color
                holder.textView.setTextColor(0xFFFFFFFF.toInt()) // White text
            } else {
                holder.textView.background = null
                holder.textView.setTextColor(0xFF000000.toInt()) // Black text
            }
            
            holder.itemView.setOnClickListener { onSubcategoryClick(subcategory) }
        }

        override fun getItemCount() = subcategories.size

        inner class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
            val textView: TextView = view.findViewById(android.R.id.text1)
        }
    }

    // Records Adapter
    inner class RecordsAdapter(
        private var records: List<JSONObject>,
        private val onRecordClick: (JSONObject) -> Unit
    ) : RecyclerView.Adapter<RecordsAdapter.ViewHolder>() {

        fun updateRecords(newRecords: List<JSONObject>) {
            records = newRecords
            notifyDataSetChanged()
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(android.R.layout.simple_list_item_2, parent, false)
            return ViewHolder(view)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            val record = records[position]
            try {
                val title = record.optString("record_title", "Unknown")
                
                // Parse details - it might be a string instead of JSON object
                var details: JSONObject? = null
                val detailsString = record.optString("details", "")
                if (detailsString.isNotEmpty()) {
                    try {
                        // Try to parse the details string as JSON
                        details = JSONObject(detailsString)
                        Log.d("RecordSelection", "Parsed details string as JSON for record: $title")
                    } catch (e: Exception) {
                        Log.d("RecordSelection", "Details string is not valid JSON, will extract manually")
                        // The string is malformed JSON, extract scheduled_date manually
                    }
                } else {
                    // Try to get details as object
                    details = record.optJSONObject("details")
                }
                
                // Try to get scheduled_date from details first, then from string, then directly from record
                var targetDate = details?.optString("scheduled_date", "") ?: ""
                
                if (targetDate.isEmpty() && detailsString.isNotEmpty()) {
                    // Extract scheduled_date from the malformed JSON string using regex
                    val scheduledDateRegex = Regex("scheduled_date:\\s*([^,}]+)")
                    val matchResult = scheduledDateRegex.find(detailsString)
                    if (matchResult != null) {
                        targetDate = matchResult.groupValues[1].trim()
                        Log.d("RecordSelection", "Extracted scheduled_date from string: $targetDate")
                    }
                }
                
                if (targetDate.isEmpty() || targetDate == "No date") {
                    targetDate = record.optString("scheduled_date", "No date")
                    Log.d("RecordSelection", "Found scheduled_date directly in record: $targetDate")
                } else {
                    Log.d("RecordSelection", "Found scheduled_date in details: $targetDate")
                }
                
                // Similarly extract description
                var description = details?.optString("description", "") ?: ""
                if (description.isEmpty() && detailsString.isNotEmpty()) {
                    // Extract description from the malformed JSON string using regex
                    val descriptionRegex = Regex("description:\\s*([^,}]+)")
                    val matchResult = descriptionRegex.find(detailsString)
                    if (matchResult != null) {
                        description = matchResult.groupValues[1].trim()
                        Log.d("RecordSelection", "Extracted description from string: $description")
                    }
                }
                if (description.isEmpty()) {
                    description = record.optString("description", "")
                }
                
                // Debug: Check if scheduled_date exists directly in record (not in details)
                val directScheduledDate = record.optString("scheduled_date", "")
                if (directScheduledDate.isNotEmpty()) {
                    Log.d("RecordSelection", "Found scheduled_date directly in record: $directScheduledDate")
                }

                holder.titleText.text = title
                holder.subtitleText.text = if (description.isNotEmpty()) {
                    "$targetDate • ${description.take(50)}${if (description.length > 50) "..." else ""}"
                } else {
                    targetDate
                }

                holder.itemView.setOnClickListener { onRecordClick(record) }
                
                Log.d("RecordSelection", "Showing record: $title, date: $targetDate")
            } catch (e: Exception) {
                Log.e("RecordSelection", "Error displaying record $position: ${e.message}", e)
                holder.titleText.text = "Invalid record (${e.message})"
                holder.subtitleText.text = "Debug: ${record.toString().take(100)}"
            }
        }

        override fun getItemCount() = records.size

        inner class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
            val titleText: TextView = view.findViewById(android.R.id.text1)
            val subtitleText: TextView = view.findViewById(android.R.id.text2)
        }
    }
}