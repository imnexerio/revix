package com.imnexerio.revix

import android.app.AlertDialog
import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.util.Log
import android.view.MotionEvent
import android.view.View
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.*
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.*

class AddLectureActivity : AppCompatActivity(), CustomFrequencySelector.OnFrequencySelectedListener {
    private lateinit var categorySpinner: Spinner
    private lateinit var addNewCategoryLayout: LinearLayout
    private lateinit var newCategoryEditText: EditText
    private lateinit var subCategorySpinner: Spinner
    private lateinit var addNewSubCategoryLayout: LinearLayout
    private lateinit var newSubCategoryEditText: EditText
    private lateinit var lectureTypeSpinner: Spinner
    private lateinit var titleEditText: EditText
    private lateinit var reminderTimeEditText: EditText
    private lateinit var allDayCheckBox: CheckBox
    private lateinit var initiationDateEditText: EditText
    private lateinit var initiationDateCheckbox: CheckBox // New checkbox
    private lateinit var revisionFrequencySpinner: Spinner
    private lateinit var reviewFrequencyCheckbox: CheckBox // New checkbox
    private lateinit var scheduledDateEditText: EditText
    private lateinit var durationSpinner: Spinner
    private lateinit var descriptionEditText: EditText
    private lateinit var saveButton: Button
    private lateinit var revisionFrequencyText: TextView
    private lateinit var firstReminderDate: TextView
    private lateinit var reminderDurationText: TextView
    private lateinit var cancelButton: Button
    private lateinit var revision_FrequencyCard: CardView

    // Data
    private var subjects = mutableListOf<String>()
    private var subCategories = mutableMapOf<String, List<String>>()
    private var selectedCategory = "DEFAULT_VALUE"
    private var selectedCategoryCode = ""
    private var lectureType = "Lectures"
    private var revisionFrequency = "Default"
    private var todayDate = ""
    private var dateScheduled = ""
    private var noRevision = 0

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
    private var customFrequencyData: HashMap<String, Any> = HashMap()    // Database reference
    private lateinit var database: FirebaseDatabase
    private lateinit var auth: FirebaseAuth
    private var revisionData: MutableMap<String, Any?> = mutableMapOf()
    val recordData = HashMap<String, Any>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_add_lecture)

        // Initialize Firebase
        database = FirebaseDatabase.getInstance()
        auth = FirebaseAuth.getInstance()

        // Initialize UI elements
        initializeViews()

        // Set up initial data
        setInitialDates()

        loadCustomData()
    }

    private fun initializeViews() {
        // Find all views
        categorySpinner = findViewById(R.id.category_spinner)
        addNewCategoryLayout = findViewById(R.id.add_new_category_layout)
        newCategoryEditText = findViewById(R.id.new_category_edit_text)
        subCategorySpinner = findViewById(R.id.subcategory_spinner)
        addNewSubCategoryLayout = findViewById(R.id.add_new_subcategory_layout)
        newSubCategoryEditText = findViewById(R.id.new_subcategory_edit_text)
        lectureTypeSpinner = findViewById(R.id.lecture_type_spinner)
        titleEditText = findViewById(R.id.title_edit_text)
        reminderTimeEditText = findViewById(R.id.reminder_time_edit_text)
        allDayCheckBox = findViewById(R.id.all_day_checkbox)
        initiationDateEditText = findViewById(R.id.initiation_date_edit_text)
        initiationDateCheckbox = findViewById(R.id.initiation_date_checkbox) // Initialize new checkbox
        revisionFrequencySpinner = findViewById(R.id.revision_frequency_spinner)
        reviewFrequencyCheckbox = findViewById(R.id.review_frequency_checkbox) // Initialize new checkbox
        scheduledDateEditText = findViewById(R.id.scheduled_date_edit_text)
        durationSpinner = findViewById(R.id.duration_spinner)
        descriptionEditText = findViewById(R.id.description_edit_text)
        saveButton = findViewById(R.id.save_button)
        revisionFrequencyText = findViewById(R.id.revision_frequency_text)
        firstReminderDate = findViewById(R.id.scheduled_date_text)
        reminderDurationText = findViewById(R.id.reminder_duration_text)
        cancelButton = findViewById(R.id.cancel_button)
        revision_FrequencyCard = findViewById(R.id.revision_frequency_card)

        // Set up initial states
        addNewCategoryLayout.visibility = View.GONE
        addNewSubCategoryLayout.visibility = View.GONE
        reminderTimeEditText.setText("All Day")
        setupDurationSpinner()

        // Set up checkboxes initial state
        // Set initial checkbox states
        initiationDateCheckbox.isChecked = false
        reviewFrequencyCheckbox.isChecked = false
    }    private fun loadCustomData() {
        // Show a loading indicator if needed

        // First, trigger a frequency data refresh to ensure we have the latest data
        refreshFrequencyData()

        // Add a small delay to allow frequency data to be refreshed by Flutter
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            // Fetch tracking types using SharedPreferences approach like frequency data
            fetchTrackingTypesFromFlutter { types ->
                trackingTypes.clear()
                trackingTypes.addAll(types)

                // Update UI with tracking types
                updateLectureTypeSpinner()                // Fetch frequencies using SharedPreferences approach like TodayWidget
                FrequencyCalculationUtils.fetchCustomFrequencies(this) { frequenciesMap ->
                    frequencies.clear()
                    frequencies.putAll(frequenciesMap)                    // Get frequency names for spinner
                    frequencyNames.clear()
                    frequencyNames.addAll(FrequencyCalculationUtils.getFrequencyNames(frequenciesMap))
                    frequencyNames.add("Custom")
                    frequencyNames.add("No Repetition")

                    // Update UI with frequencies
                    updateRevisionFrequencySpinner()

                    // Now load subjects
                    loadCategoriesAndSubCategories()
                }
            }
        }, 500) // Wait 500ms for Flutter to process the frequency refresh
    }

    private fun updateLectureTypeSpinner() {
        runOnUiThread {
            val adapter = ArrayAdapter(
                this,
                android.R.layout.simple_spinner_item,
                trackingTypes
            )
            adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
            lectureTypeSpinner.adapter = adapter

            // Set up listener
            lectureTypeSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                    lectureType = parent?.getItemAtPosition(position).toString()
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

    private fun updateRevisionFrequencySpinner() {
        runOnUiThread {
            val adapter = ArrayAdapter(
                this,
                android.R.layout.simple_spinner_item,
                frequencyNames
            )
            adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
            revisionFrequencySpinner.adapter = adapter

            // Set up listener
            revisionFrequencySpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                    revisionFrequency = parent?.getItemAtPosition(position).toString()

                    if (revisionFrequency == "Custom") {
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
            revisionFrequencySpinner.setOnTouchListener { _, event ->
                if (event.action == MotionEvent.ACTION_UP) {
                    if (revisionFrequency == "Custom") {
                        updateRevisionFrequencySpinner()
                        return@setOnTouchListener true
                    }
                }
                return@setOnTouchListener false
            }
        }
    }


    private fun openCustomFrequencySelector() {
        val dialog = CustomFrequencySelector.newInstance(customFrequencyData)
        dialog.show(supportFragmentManager, "CustomFrequencySelector")
    }

    // Add the onFrequencySelected implementation to the main class
    override fun onFrequencySelected(customData: HashMap<String, Any>) {
        // Store the custom frequency data
        customFrequencyData = customData
        if (customFrequencyData.isEmpty() && revisionFrequency == "Custom") {
            updateRevisionFrequencySpinner()
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
        }

        // Initiation date checkbox
        initiationDateCheckbox.setOnCheckedChangeListener { _, isChecked ->
            updateInitiationDateVisibility(isChecked)

            // Fix: When initiation date is unspecified, automatically check "No Repetition"
            if (isChecked) {
                reviewFrequencyCheckbox.isChecked = true
                todayDate = "Unspecified"
            } else {
                // Restore the date when unchecked
                setInitialDates()
                // Don't automatically uncheck review frequency
            }

            // Update scheduled date based on new settings
            updateScheduledDate()
        }

        // Review frequency checkbox
        reviewFrequencyCheckbox.setOnCheckedChangeListener { _, isChecked ->
            updateReviewFrequencyVisibility(isChecked)

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
            if (!initiationDateCheckbox.isChecked && !reviewFrequencyCheckbox.isChecked) {
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

            // Hide all revision-related fields
            revisionFrequencyText.visibility = View.GONE
            revisionFrequencySpinner.visibility = View.GONE
            reviewFrequencyCheckbox.visibility = View.GONE
            firstReminderDate.visibility = View.GONE
            scheduledDateEditText.visibility = View.GONE
            reminderDurationText.visibility = View.GONE
            durationSpinner.visibility = View.GONE
            revision_FrequencyCard.visibility = View.GONE

            // Force "No Repetition" when unspecified
            revisionFrequency = "No Repetition"
        } else {
            // Restore the date or set to current date
            setInitialDates() // This will update initiationDateEditText with today's date

            // Show revision frequency field
            revisionFrequencyText.visibility = View.VISIBLE
            revisionFrequencySpinner.visibility = View.VISIBLE
            reviewFrequencyCheckbox.visibility = View.VISIBLE

            // Update review frequency visibility based on its checkbox state
            updateReviewFrequencyVisibility(reviewFrequencyCheckbox.isChecked)
            revision_FrequencyCard.visibility = View.VISIBLE
        }
    }

    private fun updateReviewFrequencyVisibility(isNoRepetition: Boolean) {
        if (isNoRepetition) {
            // Find the index of "No Repetition" in frequency names
            val noRepetitionIndex = frequencyNames.indexOf("No Repetition")
            if (noRepetitionIndex >= 0) {
                revisionFrequencySpinner.setSelection(noRepetitionIndex)
            } else {
                // Fallback to last item if not found
                revisionFrequencySpinner.setSelection(frequencyNames.size - 1)
            }

            // Set the revision frequency directly
            revisionFrequency = "No Repetition"

            // Hide revision-related fields but keep the frequency spinner
            firstReminderDate.visibility = View.GONE
            scheduledDateEditText.visibility = View.GONE
            reminderDurationText.visibility = View.GONE
            durationSpinner.visibility = View.GONE
        } else {
            // Restore normal text
            revisionFrequencyText.text = "Revision Frequency"

            // Show all revision-related fields
            firstReminderDate.visibility = View.VISIBLE
            scheduledDateEditText.visibility = View.VISIBLE
            reminderDurationText.visibility = View.VISIBLE
            durationSpinner.visibility = View.VISIBLE

            // Let the spinner selection determine the frequency
            revisionFrequency = revisionFrequencySpinner.selectedItem.toString()
        }
    }    private fun loadCategoriesAndSubCategories() {
        // Use CategoriesDataUtils to fetch data from SharedPreferences instead of direct Firebase call
        CategoriesDataUtils.fetchCategoriesAndSubCategories(this) { subjectsList, subCategoriesMap ->
            subjects.clear()
            subCategories.clear()

            // Add subjects
            subjects.addAll(subjectsList)

            // Add sub categories
            subCategories.putAll(subCategoriesMap)

            // Update the spinners
            updateCategorySpinner()

            // Set initial selection
            if (subjects.isNotEmpty()) {
                selectedCategory = subjects[0]
                updateSubCategorySpinner()
            }

            // Set up all listeners after data is loaded
            setupListeners()
        }
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
        if (revisionFrequency == "No Repetition" || reviewFrequencyCheckbox.isChecked) {
            scheduledDateEditText.setText(todayDate) // Use initiation date for no repetition
            dateScheduled = todayDate
            return
        }

        // Set up revision data for different frequencies
        if (revisionFrequency == "Custom" && customFrequencyData.isNotEmpty()) {
            revisionData["frequency"] = "Custom"
            revisionData["custom_params"] = customFrequencyData
            recordData["recurrence_data"] = revisionData
            try {
                val dateScheduled_ = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse(todayDate)
                val scheduledCalendar_ = Calendar.getInstance()
                scheduledCalendar_.time = dateScheduled_ ?: Date()
                val nextDate = CalculateCustomNextDate.calculateCustomNextDate(scheduledCalendar_, revisionData)
                dateScheduled = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(nextDate.time)
                scheduledDateEditText.setText(dateScheduled)
            } catch (e: Exception) {
//                Log.e("AddLectureActivity", "Error calculating custom date: ${e.message}")
                // Fallback to today's date if calculation fails
                dateScheduled = todayDate
                scheduledDateEditText.setText(dateScheduled)
            }
        } else {
            // For standard frequencies
            revisionData["frequency"] = revisionFrequency
            recordData["recurrence_data"] = revisionData

            try {
                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val initialDate = dateFormat.parse(todayDate) ?: Calendar.getInstance().time

                val currentCalendar = Calendar.getInstance()
                val currentDate = dateFormat.parse(dateFormat.format(currentCalendar.time))
                FrequencyCalculationUtils.calculateNextRevisionDate(
                    this,
                    revisionFrequency,
                    0, // Initial revision
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
//                        e.printStackTrace()
                    }
                }
            } catch (e: Exception) {
                // Log.e("AddLectureActivity", "Error setting date: ${e.message}")
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
            },
            hour,
            minute,
            true
        )
        timePickerDialog.show()
    }

    // Replace your current showDatePicker method with this improved version
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
            val user = auth.currentUser
            if (user == null) {
                Toast.makeText(this, "No authenticated user", Toast.LENGTH_SHORT).show()
                return
            }

            val uid = user.uid
            val ref = database.getReference("users/$uid/user_data")
                .child(selectedCategory)
                .child(selectedCategoryCode)
                .child(title)

            // Handle date values based on checkboxes
            val isUnspecifiedInitiationDate = initiationDateCheckbox.isChecked
            val isNoRepetition = reviewFrequencyCheckbox.isChecked

            // Fix 2: Set correct values based on checkbox states
            if (isUnspecifiedInitiationDate) {
                todayDate = "Unspecified"
                dateScheduled = "Unspecified"
                noRevision = -1
                revisionFrequency = "No Repetition"
            } else if (isNoRepetition) {
                dateScheduled = todayDate // Use initiation date as scheduled date for no repetition
                noRevision = -1
                revisionFrequency = "No Repetition"
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
                            // If initiated date is not today, disable revision
                            noRevision = -1
                        } else {
                            // It's today, enable revision
                            noRevision = 0
                        }
                    }
                } catch (e: Exception) {
//                    Log.e("AddLectureActivity", "Date parsing error: ${e.message}")
                    noRevision = 0 // Default fallback
                }
            }

            // Fix 3: Set recordData values based on the current state
            recordData["start_timestamp"] = SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.getDefault()).format(Calendar.getInstance().time)
            recordData["reminder_time"] = reminderTime
            recordData["entry_type"] = lectureType
            recordData["date_initiated"] = todayDate
            recordData["date_updated"] = todayDate
            recordData["scheduled_date"] = dateScheduled
            recordData["description"] = description
            recordData["missed_counts"] = 0
            recordData["completion_counts"] = noRevision
            recordData["recurrence_frequency"] = revisionFrequency
            recordData["status"] = "Enabled"
            recordData["duration"] = durationData

            // If we have custom frequency data and it's not "Unspecified" or "No Repetition"
            if (revisionFrequency == "Custom" && !isUnspecifiedInitiationDate && !isNoRepetition) {
                revisionData["frequency"] = "Custom"
                revisionData["custom_params"] = customFrequencyData
                recordData["recurrence_data"] = revisionData
            } else if (!isUnspecifiedInitiationDate && !isNoRepetition) {
                // For standard frequencies
                revisionData["frequency"] = revisionFrequency
                recordData["recurrence_data"] = revisionData
            } else {
                // For "Unspecified" or "No Repetition", set minimal revision data
                revisionData["frequency"] = "No Repetition"
                recordData["recurrence_data"] = revisionData
            }

            // Save to Firebase
            ref.setValue(recordData)
                .addOnSuccessListener {
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
                }
                .addOnFailureListener { e ->
                    Toast.makeText(this, "Failed to save record: ${e.message}", Toast.LENGTH_SHORT).show()
                }

        } catch (e: Exception) {
            Toast.makeText(this, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }private fun refreshFrequencyData() {
        FrequencyCalculationUtils.refreshFrequencyData(this)
        
        // Give a small delay for the background update to complete, then refresh our local cache
        GlobalScope.launch(Dispatchers.Main) {
            delay(100) // Small delay to ensure background update completes
            
            FrequencyCalculationUtils.fetchCustomFrequencies(this@AddLectureActivity) { frequencyData ->
                Log.d("AddLectureActivity", "Frequency data refreshed: $frequencyData")
                // Data is now updated in our local cache via SharedPreferences
                // Any subsequent calls to fetchCustomFrequencies will get the fresh data
            }
        }
    }

    // Fetch tracking types from SharedPreferences (similar to frequency data)
    private fun fetchTrackingTypesFromFlutter(callback: (List<String>) -> Unit) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                // Get tracking types data from SharedPreferences that Flutter stores
                val sharedPrefs = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
                val trackingTypesJson = sharedPrefs.getString("trackingTypes", null)
                
                val data = mutableListOf<String>()
                
                if (trackingTypesJson != null && trackingTypesJson.isNotEmpty()) {
                    try {
                        // Parse JSON data - expecting array format like ["Lectures", "Handouts", "Others"]
                        val jsonArray = org.json.JSONArray(trackingTypesJson)
                        
                        for (i in 0 until jsonArray.length()) {
                            val value = jsonArray.getString(i)
                            data.add(value)
                        }
                        
                        Log.d("AddLectureActivity", "Parsed tracking types: $data")
                    } catch (e: Exception) {
                        Log.e("AddLectureActivity", "Error parsing tracking types JSON data: $e")
                    }
                }
                
                // If no valid data was parsed, use default tracking types
                if (data.isEmpty()) {
                    data.addAll(getDefaultTrackingTypes())
                    Log.d("AddLectureActivity", "No tracking types data found, using defaults: $data")
                }
                
                // Switch back to main thread for callback
                runOnUiThread {
                    callback(data)
                }
            } catch (e: Exception) {
                Log.e("AddLectureActivity", "Error fetching tracking types: ${e.message}", e)
                runOnUiThread {
                    callback(getDefaultTrackingTypes())
                }
            }
        }
    }

    // Get default tracking types when Flutter communication fails
    private fun getDefaultTrackingTypes(): List<String> {
        return listOf("Lectures", "Handouts", "Others")
    }
}