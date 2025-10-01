package com.imnexerio.revix

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
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
        btnCancel = findViewById(R.id.cancel_button)

        btnCancel.setOnClickListener { finish() }
    }

    private fun loadAllRecords() {
        try {
            val sharedPreferences = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
            val allRecordsJson = sharedPreferences.getString("allRecords", "{}")
            val allRecordsObject = JSONObject(allRecordsJson ?: "{}")

            Log.d("RecordSelection", "Raw allRecords JSON length: ${allRecordsJson?.length ?: 0}")

            allRecords = parseNestedStructure(allRecordsObject)
            Log.d("RecordSelection", "Loaded ${allRecords.size} categories")

        } catch (e: Exception) {
            Log.e("RecordSelection", "Error loading records: ${e.message}", e)
            allRecords = emptyMap()
        }
    }

    private fun parseNestedStructure(data: JSONObject): Map<String, Map<String, List<JSONObject>>> {
        val grouped = mutableMapOf<String, MutableMap<String, MutableList<JSONObject>>>()

        // Iterate categories
        val categoryKeys = data.keys()
        while (categoryKeys.hasNext()) {
            val category = categoryKeys.next()
            val subcategoriesObject = data.getJSONObject(category)

            // Iterate subcategories
            val subcategoryKeys = subcategoriesObject.keys()
            while (subcategoryKeys.hasNext()) {
                val subcategory = subcategoryKeys.next()
                val recordsObject = subcategoriesObject.getJSONObject(subcategory)

                // Iterate records
                val recordKeys = recordsObject.keys()
                while (recordKeys.hasNext()) {
                    val recordId = recordKeys.next()
                    val recordData = recordsObject.getJSONObject(recordId)

                    // Add category, subcategory, and title to record data
                    val enrichedRecord = JSONObject(recordData.toString())
                    enrichedRecord.put("category", category)
                    enrichedRecord.put("sub_category", subcategory)
                    enrichedRecord.put("record_title", recordId)

                    // Group by category and subcategory
                    grouped.getOrPut(category) { mutableMapOf() }
                        .getOrPut(subcategory) { mutableListOf() }
                        .add(enrichedRecord)
                }
            }
        }

        Log.d("RecordSelection", "Parsed nested structure: ${grouped.size} categories")
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
            val status = record.optString("status", "Enabled")

            Log.d("RecordSelection", "Record selection - Category: $category, SubCategory: $subCategory, Title: $recordTitle, Status: $status")

            // Option C3: Block selection of disabled records
            if (status == "Disabled") {
                Toast.makeText(this, "This record is disabled and cannot be selected", Toast.LENGTH_SHORT).show()
                return
            }

            if (category.isEmpty() || subCategory.isEmpty() || recordTitle.isEmpty()) {
                Log.e("RecordSelection", "Missing required fields in record")
                Toast.makeText(this, "Invalid record data", Toast.LENGTH_SHORT).show()
                return
            }

            // Extract scheduled_date directly from record object (Option A)
            var scheduledDate = record.optString("scheduled_date", "")

            // Normalize empty dates to "Unspecified"
            if (scheduledDate.isEmpty()) {
                scheduledDate = "Unspecified"
                Log.d("RecordSelection", "Normalized empty scheduled_date to 'Unspecified'")
            }

            Log.d("RecordSelection", "Final scheduled date: $scheduledDate")

            // Save selection for this widget
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
            Toast.makeText(this, "Error selecting record: ${e.message}", Toast.LENGTH_SHORT).show()
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
                holder.textView.setBackgroundResource(android.R.drawable.btn_default)
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
                holder.textView.setBackgroundResource(android.R.drawable.btn_default)
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
                .inflate(R.layout.item_record, parent, false)
            return ViewHolder(view)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            val record = records[position]
            try {
                val title = record.optString("record_title", "Unknown")
                val scheduledDate = record.optString("scheduled_date", "Unspecified")
                val status = record.optString("status", "Enabled")
                val entryType = record.optString("entry_type", "")

                // Format display text
                holder.titleText.text = title
                holder.dateText.text = "Scheduled: $scheduledDate"

                // Set colored indicator based on entry_type
                val color = LectureColors.getLectureTypeColorSync(holder.itemView.context, entryType)
                holder.indicator.setColorFilter(color)

                // Visual distinction for disabled records (Option C3)
                if (status == "Disabled") {
                    holder.titleText.alpha = 0.5f
                    holder.dateText.alpha = 0.5f
                    holder.indicator.alpha = 0.5f
                } else {
                    holder.titleText.alpha = 1.0f
                    holder.dateText.alpha = 1.0f
                    holder.indicator.alpha = 1.0f
                }

                holder.itemView.setOnClickListener { onRecordClick(record) }

            } catch (e: Exception) {
                Log.e("RecordSelection", "Error displaying record $position: ${e.message}", e)
                holder.titleText.text = "Invalid record"
                holder.dateText.text = e.message ?: "Unknown error"
            }
        }

        override fun getItemCount() = records.size

        inner class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
            val indicator: ImageView = view.findViewById(R.id.lecture_type_indicator)
            val titleText: TextView = view.findViewById(R.id.record_title_text)
            val dateText: TextView = view.findViewById(R.id.scheduled_date_text)
        }
    }
}
