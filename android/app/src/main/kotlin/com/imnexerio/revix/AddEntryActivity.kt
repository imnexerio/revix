package com.imnexerio.revix

import android.app.AlertDialog
import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.util.Log
import android.view.MotionEvent
import android.view.View
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.*

class AddEntryActivity : AppCompatActivity(), CustomFrequencySelector.OnFrequencySelectedListener {
    private lateinit var categorySpinner: Spinner
    private lateinit var addNewCategoryLayout: LinearLayout
    private lateinit var newCategoryEditText: EditText
    private lateinit var subCategorySpinner: Spinner
    private lateinit var addNewSubCategoryLayout: LinearLayout
    private lateinit var newSubCategoryEditText: EditText
    private lateinit var entryTypeSpinner: Spinner
    private lateinit var titleEditText: EditText
    private lateinit var reminderTimeEditText: EditText
    private lateinit var allDayCheckBox: CheckBox
    private lateinit var initiationDateEditText: EditText
    private lateinit var initiationDateCheckbox: CheckBox
    private lateinit var recurrenceFrequencySpinner: Spinner
    private lateinit var recurrenceFrequencyCheckbox: CheckBox
    private lateinit var scheduledDateEditText: EditText
    private lateinit var durationSpinner: Spinner
    private lateinit var descriptionEditText: EditText
    private lateinit var saveButton: Button
    private lateinit var recurrenceFrequencyText: TextView
    private lateinit var firstReminderDate: TextView
    private lateinit var reminderDurationText: TextView
    private lateinit var cancelButton: Button
    private lateinit var recurrence_FrequencyCard: CardView
    private lateinit var alarmTypeSpinner: Spinner

    // Data
    private var subjects = mutableListOf<String>()
    private var subCategories = mutableMapOf<String, List<String>>()
    private var selectedCategory = "DEFAULT_VALUE"
    private var selectedCategoryCode = ""
    private var entryType = "Lectures"
    private var recurrenceFrequency = "Default"
    private var todayDate = ""
    private var dateScheduled = ""
    private var completionCount = 0

    // Alarm type variables
    private var alarmType = 0 // 0: no reminder, 1: notification only, 2: vibration only, 3: sound, 4: sound + vibration, 5: loud alarm
    private val alarmOptions = listOf("No Reminder", "Notification Only", "Vibration Only", "Sound", "Sound + Vibration", "Loud Alarm")

    private var duration = "Forever"
    private val durationOptions = listOf("Forever", "Specific Number of Times", "Until")
    private val durationData = HashMap<String, Any?>().apply {
        put("type", "forever")
        put("numberOfTimes", null)
        put("endDate", null)
    }
    private var previousDuration = "Forever"
    private var trackingTypes = mutableListOf<String>()
    private var frequencies = mutableMapOf<String, List<Int>>()
    private var frequencyNames = mutableListOf<String>()
    private var customFrequencyData: HashMap<String, Any> = HashMap()
    private var recurrenceData: MutableMap<String, Any?> = mutableMapOf()
    val recordData = HashMap<String, Any>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_add_entry)

        // Initialize UI elements
        initializeViews()

        // Set up initial data
        setInitialDates()

        loadCustomDataAsync()
    }

    private fun initializeViews() {
        // Find all views
        categorySpinner = findViewById(R.id.category_spinner)
        addNewCategoryLayout = findViewById(R.id.add_new_category_layout)
        newCategoryEditText = findViewById(R.id.new_category_edit_text)
        subCategorySpinner = findViewById(R.id.subcategory_spinner)
        addNewSubCategoryLayout = findViewById(R.id.add_new_subcategory_layout)
        newSubCategoryEditText = findViewById(R.id.new_subcategory_edit_text)
        entryTypeSpinner = findViewById(R.id.entry_type_spinner)
        titleEditText = findViewById(R.id.title_edit_text)
        reminderTimeEditText = findViewById(R.id.reminder_time_edit_text)
        allDayCheckBox = findViewById(R.id.all_day_checkbox)
        initiationDateEditText = findViewById(R.id.initiation_date_edit_text)
        initiationDateCheckbox = findViewById(R.id.initiation_date_checkbox)
        recurrenceFrequencySpinner = findViewById(R.id.recurrence_frequency_spinner)
        recurrenceFrequencyCheckbox = findViewById(R.id.recurrence_frequency_checkbox)
        scheduledDateEditText = findViewById(R.id.scheduled_date_edit_text)
        durationSpinner = findViewById(R.id.duration_spinner)
        descriptionEditText = findViewById(R.id.description_edit_text)
        saveButton = findViewById(R.id.save_button)
        recurrenceFrequencyText = findViewById(R.id.recurrence_frequency_text)
        firstReminderDate = findViewById(R.id.scheduled_date_text)
        reminderDurationText = findViewById(R.id.reminder_duration_text)
        cancelButton = findViewById(R.id.cancel_button)
        recurrence_FrequencyCard = findViewById(R.id.recurrence_frequency_card)
        alarmTypeSpinner = findViewById(R.id.alarm_type_spinner)
        
        // Set up ONLY initial states - defer spinner setup to reduce blocking
        addNewCategoryLayout.visibility = View.GONE
        addNewSubCategoryLayout.visibility = View.GONE
        reminderTimeEditText.setText("All Day")
        
        // Defer these to after layout is shown
        // setupDurationSpinner() - will be called after data loads
        // setupAlarmTypeSpinner() - will be called after data loads

        // Set initial checkbox states
        initiationDateCheckbox.isChecked = false
        recurrenceFrequencyCheckbox.isChecked = false
    }

    private fun setupAlarmTypeSpinner() {
        val adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_item,
            alarmOptions
        )
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        alarmTypeSpinner.adapter = adapter

        alarmTypeSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                alarmType = position
            }

            override fun onNothingSelected(parent: AdapterView<*>?) {
                // Do nothing
            }
        }
        
        // Update initial visibility based on current reminder time
        updateAlarmTypeVisibility()
    }

    private fun updateAlarmTypeVisibility() {
        val isAllDay = reminderTimeEditText.text.toString() == "All Day"
        if (isAllDay) {
            alarmTypeSpinner.visibility = View.GONE
            alarmType = 0 // Reset to "No Reminder" when hidden
            alarmTypeSpinner.setSelection(0)
        } else {
            alarmTypeSpinner.visibility = View.VISIBLE
        }
    }

    private fun loadCustomDataAsync() {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                val trackingTypesDeferred = async { fetchTrackingTypesSync() }
                val frequenciesDeferred = async { fetchFrequenciesSync() }
                val categoriesDeferred = async { fetchCategoriesSync() }

                val trackingTypesResult = trackingTypesDeferred.await()
                val frequenciesResult = frequenciesDeferred.await()
                val categoriesResult = categoriesDeferred.await()

                withContext(Dispatchers.Main) {
                    // Setup deferred spinners first
                    setupDurationSpinner()
                    setupAlarmTypeSpinner()
                    
                    // Update tracking types
                    trackingTypes.clear()
                    trackingTypes.addAll(trackingTypesResult)
                    updateEntryTypeSpinner()
                    
                    // Update frequencies
                    frequencies.clear()
                    frequencies.putAll(frequenciesResult)
                    frequencyNames.clear()
                    frequencyNames.addAll(FrequencyCalculationUtils.getFrequencyNames(frequenciesResult))
                    frequencyNames.add("Custom")
                    frequencyNames.add("No Repetition")
                    updateRecurrenceFrequencySpinner()
                    
                    // Update categories
                    subjects.clear()
                    subjects.addAll(categoriesResult.first)
                    subCategories.clear()
                    subCategories.putAll(categoriesResult.second)
                    updateCategorySpinner()
                    
                    if (subjects.isNotEmpty()) {
                        selectedCategory = subjects[0]
                        updateSubCategorySpinner()
                    }
                    
                    // Setup all listeners after data is loaded
                    setupListeners()
                }
            } catch (e: Exception) {
                Log.e("AddEntryActivity", "Error loading custom data: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@AddEntryActivity, "Error loading data", Toast.LENGTH_SHORT).show()
                    // Still setup spinners and listeners even on error
                    setupDurationSpinner()
                    setupAlarmTypeSpinner()
                    setupListeners()
                }
            }
        }
    }

    private fun updateEntryTypeSpinner() {
        runOnUiThread {
            val adapter = ArrayAdapter(
                this,
                android.R.layout.simple_spinner_item,
                trackingTypes
            )
            adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
            entryTypeSpinner.adapter = adapter

            // Set up listener
            entryTypeSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                    entryType = parent?.getItemAtPosition(position).toString()
                }

                override fun onNothingSelected(parent: AdapterView<*>?) {
                    // Do nothing
                }
            }
        }
    }

    private fun setupDurationSpinner() {
        val adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_item,
            durationOptions
        )
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        durationSpinner.adapter = adapter

        durationSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                val selectedDuration = durationOptions[position]

                // Only process if there's an actual change
                if (selectedDuration != duration) {
                    when (selectedDuration) {
                        "Forever" -> {
                            previousDuration = selectedDuration
                            duration = selectedDuration
                            durationData["type"] = "forever"
                            durationData["numberOfTimes"] = null
                            durationData["endDate"] = null
                        }
                        "Specific Number of Times" -> {
                            showNumberOfTimesDialog()
                        }
                        "Until" -> {
                            showEndDatePicker()
                        }
                    }
                }
            }

            override fun onNothingSelected(parent: AdapterView<*>?) {
                // Do nothing
            }
        }

        durationSpinner.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_UP) {
                val selectedItem = durationOptions[durationSpinner.selectedItemPosition]
                if (selectedItem == duration && (selectedItem == "Specific Number of Times" || selectedItem == "Until")) {
                    when (selectedItem) {
                        "Specific Number of Times" -> showNumberOfTimesDialog()
                        "Until" -> showEndDatePicker()
                    }
                    return@setOnTouchListener true
                }
            }
            return@setOnTouchListener false
        }
    }

    private fun showNumberOfTimesDialog() {
        val builder = AlertDialog.Builder(this)
        builder.setTitle("Enter Number of Times")

        // Set up the input
        val input = EditText(this)
        input.inputType = InputType.TYPE_CLASS_NUMBER
        input.hint = "Enter a value >= 1"

        // Pre-fill with existing value if any
        val existingValue = durationData["numberOfTimes"]
        if (existingValue != null) {
            input.setText(existingValue.toString())
        }

        builder.setView(input)

        // Set up the buttons
        builder.setPositiveButton("OK") { _, _ ->
            val inputValue = input.text.toString()
            val parsedValue = inputValue.toIntOrNull()

            if (parsedValue != null && parsedValue >= 1) {
                previousDuration = duration
                duration = "Specific Number of Times"
                durationData["type"] = "specificTimes"
                durationData["numberOfTimes"] = parsedValue
                durationData["endDate"] = null
            } else {
                // Show error feedback
                Toast.makeText(
                    this,
                    "Please enter a valid number (minimum 1)",
                    Toast.LENGTH_SHORT
                ).show()

                // Reset spinner to previous valid selection
                resetSpinnerToPreviousSelection()
            }
        }

        builder.setNegativeButton("Cancel") { dialog, _ ->
            dialog.cancel()
            // Reset spinner to previous valid selection
            resetSpinnerToPreviousSelection()
        }

        // Handle dismissal by clicking outside the dialog
        builder.setOnCancelListener {
            resetSpinnerToPreviousSelection()
        }

        builder.show()
    }

    // Add this method to handle the "Until" option
    private fun showEndDatePicker() {
        val calendar = Calendar.getInstance()
        val year = calendar.get(Calendar.YEAR)
        val month = calendar.get(Calendar.MONTH)
        val day = calendar.get(Calendar.DAY_OF_MONTH)

        val datePickerDialog = DatePickerDialog(
            this,
            { _, selectedYear, selectedMonth, selectedDay ->
                val selectedDate = Calendar.getInstance()
                selectedDate.set(selectedYear, selectedMonth, selectedDay)

                // Format the date as YYYY-MM-DD to match the Flutter app
                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val formattedDate = dateFormat.format(selectedDate.time)

                previousDuration = duration
                duration = "Until"
                durationData["type"] = "until"
                durationData["numberOfTimes"] = null
                durationData["endDate"] = formattedDate
            },
            year,
            month,
            day
        )

        // Set minimum date to today
        datePickerDialog.datePicker.minDate = calendar.timeInMillis

        // Handle cancel event
        datePickerDialog.setOnCancelListener {
            resetSpinnerToPreviousSelection()
        }

        datePickerDialog.show()
    }

    private fun resetSpinnerToPreviousSelection() {
        // Find the index of the previous selection
        val previousIndex = durationOptions.indexOf(previousDuration)
        if (previousIndex >= 0) {
            // This will trigger onItemSelected but with the previous value
            durationSpinner.setSelection(previousIndex)
            // Also update the duration variable
            duration = previousDuration
        } else {
            // Fallback to "Forever" if previous selection can't be found
            durationSpinner.setSelection(0)
            duration = "Forever"
            durationData["type"] = "forever"
            durationData["numberOfTimes"] = null
            durationData["endDate"] = null
        }
    }

    private fun updateRecurrenceFrequencySpinner() {
        runOnUiThread {
            val adapter = ArrayAdapter(
                this,
                android.R.layout.simple_spinner_item,
                frequencyNames
            )
            adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
            recurrenceFrequencySpinner.adapter = adapter

            // Set up listener
            recurrenceFrequencySpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                    recurrenceFrequency = parent?.getItemAtPosition(position).toString()

                    if (recurrenceFrequency == "Custom") {
                        openCustomFrequencySelector()
                    } else {
//                        customFrequencyData = null // Reset custom data if not using custom frequency
                    }
                    updateScheduledDate()
                }

                override fun onNothingSelected(parent: AdapterView<*>?) {
                    // Do nothing
                }
            }
            recurrenceFrequencySpinner.setOnTouchListener { _, event ->
                if (event.action == MotionEvent.ACTION_UP) {
                    if (recurrenceFrequency == "Custom") {
                        updateRecurrenceFrequencySpinner()
                        return@setOnTouchListener true
                    }
                }
                return@setOnTouchListener false
            }
        }
    }


    private fun openCustomFrequencySelector() {
        // Parse todayDate to Calendar for reference, fallback to current date
        val referenceCal = if (todayDate != "Unspecified" && todayDate.isNotEmpty()) {
            try {
                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val parsedDate = dateFormat.parse(todayDate)
                Calendar.getInstance().apply {
                    if (parsedDate != null) {
                        time = parsedDate
                    }
                }
            } catch (e: Exception) {
                Calendar.getInstance()
            }
        } else {
            Calendar.getInstance()
        }
        
        val dialog = CustomFrequencySelector.newInstance(customFrequencyData, referenceCal)
        dialog.show(supportFragmentManager, "CustomFrequencySelector")
    }

    // Add the onFrequencySelected implementation to the main class
    override fun onFrequencySelected(customData: HashMap<String, Any>) {
        // Store the custom frequency data
        customFrequencyData = customData
        if (customFrequencyData.isEmpty() && recurrenceFrequency == "Custom") {
            updateRecurrenceFrequencySpinner()
        }
        updateScheduledDate()
    }


    private fun setupListeners() {
        // Category spinner
        categorySpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                val selectedItem = parent?.getItemAtPosition(position).toString()
                if (selectedItem == "Add New Category") {
                    addNewCategoryLayout.visibility = View.VISIBLE
                    subCategorySpinner.visibility = View.GONE
                    // Show subcategory input field when adding a new category
                    addNewSubCategoryLayout.visibility = View.VISIBLE
                } else {
                    addNewCategoryLayout.visibility = View.GONE
                    subCategorySpinner.visibility = View.VISIBLE
                    selectedCategory = selectedItem
                    updateSubCategorySpinner()
                }
            }

            override fun onNothingSelected(parent: AdapterView<*>?) {
                // Do nothing
            }
        }

        // Subcategory spinner
        subCategorySpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                val selectedItem = parent?.getItemAtPosition(position).toString()
                if (selectedItem == "Add New Sub Category") {
                    addNewSubCategoryLayout.visibility = View.VISIBLE
                } else {
                    addNewSubCategoryLayout.visibility = View.GONE
                    selectedCategoryCode = selectedItem
                }
            }

            override fun onNothingSelected(parent: AdapterView<*>?) {
                // Do nothing
            }
        }

        // Time picker
        reminderTimeEditText.setOnClickListener {
            showTimePicker()
        }

        // All day checkbox
        allDayCheckBox.setOnCheckedChangeListener { _, isChecked ->
            if (isChecked) {
                reminderTimeEditText.setText("All Day")
            } else {
                val now = Calendar.getInstance()
                val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
                reminderTimeEditText.setText(timeFormat.format(now.time))
            }
            updateAlarmTypeVisibility()
        }

        // Initiation date checkbox
        initiationDateCheckbox.setOnCheckedChangeListener { _, isChecked ->
            updateInitiationDateVisibility(isChecked)

            // Fix: When initiation date is unspecified, automatically check "No Repetition"
            if (isChecked) {
                recurrenceFrequencyCheckbox.isChecked = true
                todayDate = "Unspecified"
            } else {
                // Restore the date when unchecked
                setInitialDates()
                // Don't automatically uncheck recurrence frequency
            }

            // Update scheduled date based on new settings
            updateScheduledDate()
        }

        // Recurrence frequency checkbox
        recurrenceFrequencyCheckbox.setOnCheckedChangeListener { _, isChecked ->
            updateRecurrenceFrequencyVisibility(isChecked)

            // Update the scheduled date based on new frequency settings
            updateScheduledDate()
        }

        // Date pickers
        initiationDateEditText.setOnClickListener {
            // Only show date picker if not unspecified
            if (!initiationDateCheckbox.isChecked) {
                showDatePicker(initiationDateEditText) { date ->
                    todayDate = date
                    updateScheduledDate()
                }
            }
        }

        scheduledDateEditText.setOnClickListener {
            // Only show date picker if neither unspecified nor no repetition
            if (!initiationDateCheckbox.isChecked && !recurrenceFrequencyCheckbox.isChecked) {
                showDatePicker(scheduledDateEditText) { date ->
                    dateScheduled = date
                }
            }
        }

        // Buttons
        saveButton.setOnClickListener {
            saveRecord()
        }

        cancelButton.setOnClickListener {
            finish()
        }
    }

    private fun updateInitiationDateVisibility(isUnspecified: Boolean) {
        if (isUnspecified) {
            // Update text field to show "Unspecified"
            initiationDateEditText.setText("Unspecified")
            todayDate = "Unspecified"

            // Hide all recurrence-related fields
            recurrenceFrequencyText.visibility = View.GONE
            recurrenceFrequencySpinner.visibility = View.GONE
            recurrenceFrequencyCheckbox.visibility = View.GONE
            firstReminderDate.visibility = View.GONE
            scheduledDateEditText.visibility = View.GONE
            reminderDurationText.visibility = View.GONE
            durationSpinner.visibility = View.GONE
            recurrence_FrequencyCard.visibility = View.GONE

            // Force "No Repetition" when unspecified
            recurrenceFrequency = "No Repetition"
        } else {
            // Restore the date or set to current date
            setInitialDates() // This will update initiationDateEditText with today's date

            // Show recurrence frequency field
            recurrenceFrequencyText.visibility = View.VISIBLE
            recurrenceFrequencySpinner.visibility = View.VISIBLE
            recurrenceFrequencyCheckbox.visibility = View.VISIBLE

            // Update recurrence frequency visibility based on its checkbox state
            updateRecurrenceFrequencyVisibility(recurrenceFrequencyCheckbox.isChecked)
            recurrence_FrequencyCard.visibility = View.VISIBLE
        }
    }

    private fun updateRecurrenceFrequencyVisibility(isNoRepetition: Boolean) {
        if (isNoRepetition) {
            // Find the index of "No Repetition" in frequency names
            val noRepetitionIndex = frequencyNames.indexOf("No Repetition")
            if (noRepetitionIndex >= 0) {
                recurrenceFrequencySpinner.setSelection(noRepetitionIndex)
            } else {
                // Fallback to last item if not found
                recurrenceFrequencySpinner.setSelection(frequencyNames.size - 1)
            }

            // Set the recurrence frequency directly
            recurrenceFrequency = "No Repetition"

            // Hide recurrence-related fields but keep the frequency spinner
            firstReminderDate.visibility = View.GONE
            scheduledDateEditText.visibility = View.GONE
            reminderDurationText.visibility = View.GONE
            durationSpinner.visibility = View.GONE
        } else {
            // Restore normal text
            recurrenceFrequencyText.text = "Recurrence Frequency"

            // Show all recurrence-related fields
            firstReminderDate.visibility = View.VISIBLE
            scheduledDateEditText.visibility = View.VISIBLE
            reminderDurationText.visibility = View.VISIBLE
            durationSpinner.visibility = View.VISIBLE

            // Let the spinner selection determine the frequency
            recurrenceFrequency = recurrenceFrequencySpinner.selectedItem.toString()
        }
    }

    private fun fetchCategoriesSync(): Pair<List<String>, Map<String, List<String>>> {
        val sharedPrefs = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
        val categoriesDataJson = sharedPrefs.getString("categoriesData", null)
        
        val subjectsList = mutableListOf<String>()
        val subCategoriesMap = mutableMapOf<String, List<String>>()
        
        if (categoriesDataJson != null && categoriesDataJson.isNotEmpty() && categoriesDataJson != "{}") {
            try {
                val jsonData = org.json.JSONObject(categoriesDataJson)
                
                // Parse subjects array
                if (jsonData.has("subjects")) {
                    val subjectsArray = jsonData.getJSONArray("subjects")
                    for (i in 0 until subjectsArray.length()) {
                        subjectsList.add(subjectsArray.getString(i))
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
                            is org.json.JSONArray -> {
                                val subCategoryList = mutableListOf<String>()
                                for (i in 0 until value.length()) {
                                    subCategoryList.add(value.getString(i))
                                }
                                subCategoriesMap[key] = subCategoryList
                            }
                            else -> {
                                Log.w("AddEntryActivity", "Unexpected value type for subcategory $key: $value")
                                subCategoriesMap[key] = emptyList()
                            }
                        }
                    }
                }
                
                Log.d("AddEntryActivity", "Fetched categories - Subjects: $subjectsList, SubCategories: $subCategoriesMap")
            } catch (e: Exception) {
                Log.e("AddEntryActivity", "Error parsing categories JSON: $e")
            }
        } else {
            Log.d("AddEntryActivity", "No categories data found in SharedPreferences")
        }
        
        return Pair(subjectsList, subCategoriesMap)
    }

    private fun updateCategorySpinner() {
        val spinnerItems = subjects + "Add New Category"
        val adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_item,
            spinnerItems
        )
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        categorySpinner.adapter = adapter
    }

    private fun updateSubCategorySpinner() {
        val codes = subCategories[selectedCategory] ?: listOf()
        val spinnerItems = codes + "Add New Sub Category"
        val adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_item,
            spinnerItems
        )
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        subCategorySpinner.adapter = adapter

        if (codes.isNotEmpty()) {
            selectedCategoryCode = codes[0]
        }
    }

    private fun setInitialDates() {
        val initialDate = Calendar.getInstance()
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        todayDate = dateFormat.format(initialDate.time)
        initiationDateEditText.setText(todayDate)

        // We'll set scheduled date after loading frequency data
    }

    private fun updateScheduledDate() {
        // Check if initiation date is unspecified
        if (todayDate == "Unspecified" || initiationDateCheckbox.isChecked) {
            scheduledDateEditText.setText("Unspecified")
            dateScheduled = "Unspecified"
            return
        }

        // Check if no repetition is selected
        if (recurrenceFrequency == "No Repetition" || recurrenceFrequencyCheckbox.isChecked) {
            scheduledDateEditText.setText(todayDate) // Use initiation date for no repetition
            dateScheduled = todayDate
            return
        }

        // Set up recurrence data for different frequencies
        if (recurrenceFrequency == "Custom" && customFrequencyData.isNotEmpty()) {
            recurrenceData["frequency"] = "Custom"
            recurrenceData["custom_params"] = customFrequencyData
            recordData["recurrence_data"] = recurrenceData
            try {
                val dateScheduled_ = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse(todayDate)
                val scheduledCalendar_ = Calendar.getInstance()
                scheduledCalendar_.time = dateScheduled_ ?: Date()
                val nextDate = CalculateCustomNextDate.calculateCustomNextDate(scheduledCalendar_, recurrenceData)
                dateScheduled = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(nextDate.time)
                scheduledDateEditText.setText(dateScheduled)
            } catch (e: Exception) {
                // Fallback to today's date if calculation fails
                dateScheduled = todayDate
                scheduledDateEditText.setText(dateScheduled)
            }
        } else {
            // For standard frequencies
            recurrenceData["frequency"] = recurrenceFrequency
            recordData["recurrence_data"] = recurrenceData

            try {
                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val initialDate = dateFormat.parse(todayDate) ?: Calendar.getInstance().time

                val currentCalendar = Calendar.getInstance()
                val currentDate = dateFormat.parse(dateFormat.format(currentCalendar.time))
                FrequencyCalculationUtils.calculateNextRecurrenceDate(
                    this,
                    recurrenceFrequency,
                    0, // Initial recurrence
                    initialDate
                ) { calculatedDate ->
                    try {
                        if (currentDate.before(initialDate)) {
                            dateScheduled = todayDate
                        } else {
                            dateScheduled = calculatedDate
                        }

                        scheduledDateEditText.setText(dateScheduled)
                    } catch (e: Exception) {
                        dateScheduled = calculatedDate
                        scheduledDateEditText.setText(dateScheduled)
                    }
                }
            } catch (e: Exception) {
                Toast.makeText(this, "Error setting date: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        }
    }


    private fun showTimePicker() {
        val calendar = Calendar.getInstance()
        val hour = calendar.get(Calendar.HOUR_OF_DAY)
        val minute = calendar.get(Calendar.MINUTE)

        val timePickerDialog = TimePickerDialog(
            this,
            { _, selectedHour, selectedMinute ->
                allDayCheckBox.isChecked = false
                val time = String.format("%02d:%02d", selectedHour, selectedMinute)
                reminderTimeEditText.setText(time)
                updateAlarmTypeVisibility()
            },
            hour,
            minute,
            true
        )
        timePickerDialog.show()
    }

    private fun showDatePicker(editText: EditText, onDateSelected: (String) -> Unit) {
        val calendar = Calendar.getInstance()

        val currentText = editText.text.toString()
        if (currentText != "Unspecified") {
            try {
                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val parsedDate = dateFormat.parse(currentText)
                if (parsedDate != null) {
                    calendar.time = parsedDate
                }
            } catch (e: Exception) {
                // If parsing fails, use current date (calendar is already initialized to now)
            }
        }

        val year = calendar.get(Calendar.YEAR)
        val month = calendar.get(Calendar.MONTH)
        val day = calendar.get(Calendar.DAY_OF_MONTH)

        val datePickerDialog = DatePickerDialog(
            this,
            { _, selectedYear, selectedMonth, selectedDay ->
                val selectedDate = Calendar.getInstance()
                selectedDate.set(selectedYear, selectedMonth, selectedDay)
                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val formattedDate = dateFormat.format(selectedDate.time)
                editText.setText(formattedDate)
                onDateSelected(formattedDate)
            },
            year,
            month,
            day
        )

        datePickerDialog.datePicker.minDate = Calendar.getInstance().timeInMillis

        datePickerDialog.show()
    }

    private fun saveRecord() {
        // Validate input
        val title = titleEditText.text.toString().trim()
        val description = descriptionEditText.text.toString().trim()

        if (title.isEmpty()) {
            Toast.makeText(this, "Please enter a title", Toast.LENGTH_SHORT).show()
            return
        }

        if (description.isEmpty()) {
            Toast.makeText(this, "Please enter a description", Toast.LENGTH_SHORT).show()
            return
        }

        // Handle new category input
        if (addNewCategoryLayout.visibility == View.VISIBLE) {
            selectedCategory = newCategoryEditText.text.toString().trim()
            if (selectedCategory.isEmpty()) {
                Toast.makeText(this, "Please enter a category name", Toast.LENGTH_SHORT).show()
                return
            }
        }

        // Handle new subcategory input
        if (addNewSubCategoryLayout.visibility == View.VISIBLE) {
            selectedCategoryCode = newSubCategoryEditText.text.toString().trim()
            if (selectedCategoryCode.isEmpty()) {
                Toast.makeText(this, "Please enter a subcategory name", Toast.LENGTH_SHORT).show()
                return
            }
        }

        // Get time
        val reminderTime = reminderTimeEditText.text.toString()

        // Save to Firebase
        try {

            // Handle date values based on checkboxes
            val isUnspecifiedInitiationDate = initiationDateCheckbox.isChecked
            val isNoRepetition = recurrenceFrequencyCheckbox.isChecked

            // Set correct values based on checkbox states
            if (isUnspecifiedInitiationDate) {
                todayDate = "Unspecified"
                dateScheduled = "Unspecified"
                completionCount = -1
                recurrenceFrequency = "No Repetition"
            } else if (isNoRepetition) {
                dateScheduled = todayDate // Use initiation date as scheduled date for no repetition
                completionCount = -1
                recurrenceFrequency = "No Repetition"
            } else {
                // If not unspecified or no repetition, check dates for validity
                try {
                    val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                    dateFormat.isLenient = false

                    val currentDateStr = dateFormat.format(Date())
                    val currentDate = dateFormat.parse(currentDateStr)
                    val initiatedDate = dateFormat.parse(todayDate)

                    if (initiatedDate != null) {
                        if (initiatedDate.before(currentDate)) {
                            // If initiated date is not today, disable recurrence
                            completionCount = -1
                        } else {
                            // It's today, enable recurrence
                            completionCount = 0
                        }
                    }
                } catch (e: Exception) {
                    completionCount = 0 // Default fallback
                }
            }

            // Set recordData values based on the current state
            recordData["start_timestamp"] = SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.getDefault()).format(Calendar.getInstance().time)
            recordData["reminder_time"] = reminderTime
            recordData["entry_type"] = entryType
            recordData["date_initiated"] = todayDate
            recordData["date_updated"] = todayDate
            recordData["scheduled_date"] = dateScheduled
            recordData["description"] = description
            recordData["missed_counts"] = 0
            recordData["completion_counts"] = completionCount
            recordData["recurrence_frequency"] = recurrenceFrequency
            recordData["status"] = "Enabled"
            recordData["duration"] = durationData
            recordData["alarm_type"] = alarmType

            // If we have custom frequency data and it's not "Unspecified" or "No Repetition"
            if (recurrenceFrequency == "Custom" && !isUnspecifiedInitiationDate && !isNoRepetition) {
                recurrenceData["frequency"] = "Custom"
                recurrenceData["custom_params"] = customFrequencyData
                recordData["recurrence_data"] = recurrenceData
            } else if (!isUnspecifiedInitiationDate && !isNoRepetition) {
                // For standard frequencies
                recurrenceData["frequency"] = recurrenceFrequency
                recordData["recurrence_data"] = recurrenceData
            } else {
                // For "Unspecified" or "No Repetition", set minimal recurrence data
                recurrenceData["frequency"] = "No Repetition"
                recordData["recurrence_data"] = recurrenceData
            }

            // Use HomeWidget background callback to save record via Dart
            try {
                // Show processing message first
                Toast.makeText(this, "Saving record...", Toast.LENGTH_SHORT).show()
                
                // Create unique request ID for tracking this save operation
                val requestId = System.currentTimeMillis().toString()
                
                // Create URI with all record data as query parameters
                val durationDataJson = org.json.JSONObject(recordData["duration"] as Map<String, Any?>).toString()
                val customFrequencyParamsJson = if (recurrenceFrequency == "Custom") {
                    org.json.JSONObject(customFrequencyData as Map<String, Any>).toString()
                } else {
                    "{}"
                }

                val uri = android.net.Uri.parse("homeWidget://record_create").buildUpon()
                    .appendQueryParameter("selectedCategory", selectedCategory)
                    .appendQueryParameter("selectedCategoryCode", selectedCategoryCode)
                    .appendQueryParameter("title", title)
                    .appendQueryParameter("startTimestamp", recordData["start_timestamp"]?.toString() ?: "")
                    .appendQueryParameter("reminderTime", reminderTime)
                    .appendQueryParameter("entryType", entryType)
                    .appendQueryParameter("todayDate", todayDate)
                    .appendQueryParameter("dateScheduled", dateScheduled)
                    .appendQueryParameter("description", description)
                    .appendQueryParameter("recurrenceFrequency", recurrenceFrequency)
                    .appendQueryParameter("durationData", durationDataJson)
                    .appendQueryParameter("customFrequencyParams", customFrequencyParamsJson)
                    .appendQueryParameter("alarmType", alarmType.toString())
                    .appendQueryParameter("requestId", requestId) // Add request ID for tracking
                    .build()
                
                // Trigger background callback
                val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                    this,
                    uri
                )
                backgroundIntent.send()
                
                // Wait for the save operation to complete and show result
                waitForSaveResult(requestId, isUnspecifiedInitiationDate, isNoRepetition, dateScheduled)
                
            } catch (e: Exception) {
                Log.e("AddEntryActivity", "Error triggering background record creation: ${e.message}")
                Toast.makeText(this, "Error saving record: ${e.message}", Toast.LENGTH_SHORT).show()
            }

        } catch (e: Exception) {
            Toast.makeText(this, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    // Method to wait for the Flutter background callback to complete and provide feedback
    private fun waitForSaveResult(
        requestId: String, 
        isUnspecifiedInitiationDate: Boolean, 
        isNoRepetition: Boolean, 
        dateScheduled: String
    ) {
        // Use a background thread to monitor the save result
        Thread {
            var retryCount = 0
            val maxRetries = 50 // 10 seconds max wait time (50 * 200ms)
            var saveCompleted = false
            var saveSuccess = false
            var errorMessage = ""
            
            while (retryCount < maxRetries && !saveCompleted) {
                try {
                    Thread.sleep(200) // Wait 200ms between checks
                    
                    val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                    val resultKey = "record_save_result_$requestId"
                    val result = prefs.getString(resultKey, null)
                    
                    if (result != null) {
                        saveCompleted = true
                        if (result.startsWith("SUCCESS")) {
                            saveSuccess = true
                        } else if (result.startsWith("ERROR:")) {
                            saveSuccess = false
                            errorMessage = result.substring(6) // Remove "ERROR:" prefix
                        }
                        
                        // Clean up the result from preferences
                        prefs.edit().remove(resultKey).apply()
                        break
                    }
                    
                    retryCount++
                } catch (e: InterruptedException) {
                    Log.e("AddEntryActivity", "Save result waiting interrupted: ${e.message}")
                    break
                }
            }
            
            // Show result on main thread
            runOnUiThread {
                if (saveCompleted) {
                    if (saveSuccess) {
                        val successMessage = if (isUnspecifiedInitiationDate) {
                            "Record added successfully with unspecified initiation date"
                        } else if (isNoRepetition) {
                            "Record added successfully with no repetition"
                        } else {
                            "Record added successfully, scheduled for $dateScheduled"
                        }
                        Toast.makeText(this, successMessage, Toast.LENGTH_SHORT).show()
                        
                        // Refresh the widget
                        val intent = Intent(this, TodayWidget::class.java)
                        intent.action = TodayWidget.ACTION_REFRESH
                        sendBroadcast(intent)
                        
                        // Close the activity
                        finish()
                    } else {
                        val displayError = if (errorMessage.isNotEmpty()) errorMessage else "Unknown error occurred"
                        Toast.makeText(this, "Failed to save record: $displayError", Toast.LENGTH_LONG).show()
                    }
                } else {
                    // Timeout occurred
                    Toast.makeText(this, "Save operation timed out. Please try again.", Toast.LENGTH_LONG).show()
                }
            }
        }.start()
    }

    private fun fetchTrackingTypesSync(): List<String> {
        val sharedPrefs = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
        val trackingTypesJson = sharedPrefs.getString("trackingTypes", null)
        val data = mutableListOf<String>()
        
        if (trackingTypesJson != null && trackingTypesJson.isNotEmpty()) {
            try {
                val jsonArray = org.json.JSONArray(trackingTypesJson)
                for (i in 0 until jsonArray.length()) {
                    data.add(jsonArray.getString(i))
                }
                Log.d("AddEntryActivity", "Parsed tracking types: $data")
            } catch (e: Exception) {
                Log.e("AddEntryActivity", "Error parsing tracking types: $e")
            }
        }
        
        if (data.isEmpty()) {
            Log.d("AddEntryActivity", "No tracking types found, using empty list")
        }
        
        return data
    }
    
    private fun fetchFrequenciesSync(): Map<String, List<Int>> {
        val sharedPrefs = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
        val frequencyDataJson = sharedPrefs.getString("frequencyData", null)
        val frequencies = mutableMapOf<String, List<Int>>()
        
        if (frequencyDataJson != null && frequencyDataJson.isNotEmpty()) {
            try {
                val jsonData = org.json.JSONObject(frequencyDataJson)
                val keys = jsonData.keys()
                
                while (keys.hasNext()) {
                    val key = keys.next()
                    val value = jsonData.get(key)
                    
                    when (value) {
                        is org.json.JSONArray -> {
                            val frequencyList = mutableListOf<Int>()
                            for (i in 0 until value.length()) {
                                frequencyList.add(value.getInt(i))
                            }
                            frequencies[key] = frequencyList
                        }
                        else -> {
                            Log.w("AddEntryActivity", "Unexpected value type for frequency $key: $value")
                        }
                    }
                }
                
                Log.d("AddEntryActivity", "Fetched frequencies: $frequencies")
            } catch (e: Exception) {
                Log.e("AddEntryActivity", "Error parsing frequencies JSON: $e")
            }
        } else {
            Log.d("AddEntryActivity", "No frequency data found in SharedPreferences")
        }
        
        return frequencies
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up any stale save result entries
        cleanupOldSaveResults()
    }

    private fun cleanupOldSaveResults() {
        try {
            val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            val allKeys = prefs.all.keys
            val currentTime = System.currentTimeMillis()
            
            // Remove save result entries older than 1 minute
            for (key in allKeys) {
                if (key.startsWith("record_save_result_") || 
                    key.startsWith("record_update_result_") || 
                    key.startsWith("record_delete_result_")) {
                    try {
                        val parts = key.split("_")
                        if (parts.size >= 4) {
                            val timestamp = parts[3].toLongOrNull()
                            if (timestamp != null && (currentTime - timestamp) > 60 * 1000) {
                                // This entry is older than 1 minute, remove it
                                editor.remove(key)
                            }
                        }
                    } catch (e: Exception) {
                        // Ignore errors in cleanup
                    }
                }
            }
            editor.apply()
        } catch (e: Exception) {
            Log.e("AddEntryActivity", "Error cleaning up old save results: ${e.message}")
        }
    }
}
