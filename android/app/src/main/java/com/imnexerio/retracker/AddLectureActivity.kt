package com.imnexerio.retracker

import android.app.AlertDialog
import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.view.View
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.*
import com.imnexerio.retracker.CalculateCustomNextDate.Companion.calculateCustomNextDate
import com.imnexerio.retracker.utils.RevisionScheduler
import java.text.SimpleDateFormat
import java.util.*

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
    private var subjectCodes = mutableMapOf<String, List<String>>()
    private var selectedSubject = "DEFAULT_VALUE"
    private var selectedSubjectCode = ""
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

    // Custom data
    private var trackingTypes = mutableListOf<String>()
    private var frequencies = mutableMapOf<String, List<Int>>()
    private var frequencyNames = mutableListOf<String>()
    private var customFrequencyData: HashMap<String, Any> = HashMap()

    // Database reference
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

        // Load custom data first, then proceed to load subjects
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
    }

    private fun loadCustomData() {
        // Show a loading indicator if needed

        // Fetch tracking types
        FetchTrackingTypesUtils.fetchTrackingTypes { types ->
            trackingTypes.clear()
            trackingTypes.addAll(types)

            // Update UI with tracking types
            updateLectureTypeSpinner()

            // Fetch frequencies next
            FetchFrequenciesUtils.fetchFrequencies { frequenciesMap ->
                frequencies.clear()
                frequencies.putAll(frequenciesMap)

                // Get frequency names for spinner
                frequencyNames.clear()
                frequencyNames.addAll(FetchFrequenciesUtils.getFrequencyNames(frequenciesMap))
                frequencyNames.add("Custom")
                frequencyNames.add("No Repetition")

                // Update UI with frequencies
                updateRevisionFrequencySpinner()

                // Now load subjects
                loadSubjectsAndCodes()
            }
        }
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
                duration = durationOptions[position]

                when (duration) {
                    "Forever" -> {
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

            override fun onNothingSelected(parent: AdapterView<*>?) {
                // Do nothing
            }
        }
    }
    private fun showNumberOfTimesDialog() {
        val builder = AlertDialog.Builder(this)
        builder.setTitle("Enter Number of Times")

        // Set up the input
        val input = EditText(this)
        input.inputType = InputType.TYPE_CLASS_NUMBER
        input.hint = "Enter a value ≥ 1"

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

                // Reset to "Forever" if invalid input
                durationSpinner.setSelection(0)
            }
        }

        builder.setNegativeButton("Cancel") { dialog, _ ->
            dialog.cancel()
            // Reset to previous selection or "Forever"
            durationSpinner.setSelection(0)
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

        datePickerDialog.show()
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
        }
    }


    private fun openCustomFrequencySelector() {
        println("Custom frequency data openCustomFrequencySelector: $customFrequencyData")
        val dialog = CustomFrequencySelector.newInstance(customFrequencyData)
        dialog.show(supportFragmentManager, "CustomFrequencySelector")
    }

    // Add the onFrequencySelected implementation to the main class
    override fun onFrequencySelected(customData: HashMap<String, Any>) {
        // Store the custom frequency data
        customFrequencyData = customData
        if (revisionFrequency == "Custom" && customFrequencyData != null) {
            revisionData["frequency"] = "Custom"
            revisionData["custom_params"] = customFrequencyData!!
            recordData["revision_data"] = revisionData
        } else {
            // For non-custom frequencies, just store the frequency name
            revisionData["frequency"] = revisionFrequency
            recordData["revision_data"] = revisionData
        }
        println("Custom frequency data onFrequencySelected: $customFrequencyData")
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
                    selectedSubject = selectedItem
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
                    selectedSubjectCode = selectedItem
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
        }

        // Review frequency checkbox
        reviewFrequencyCheckbox.setOnCheckedChangeListener { _, isChecked ->
            updateReviewFrequencyVisibility(isChecked)
        }

        // Date pickers
        initiationDateEditText.setOnClickListener {
            showDatePicker(initiationDateEditText) { date ->
                todayDate = date
                updateScheduledDate()
            }
        }

        scheduledDateEditText.setOnClickListener {
            showDatePicker(scheduledDateEditText) { date ->
                dateScheduled = date
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

            // Hide all revision-related fields
            revisionFrequencyText.visibility = View.GONE
            revisionFrequencySpinner.visibility = View.GONE
            reviewFrequencyCheckbox.visibility = View.GONE
            firstReminderDate.visibility = View.GONE
            scheduledDateEditText.visibility = View.GONE
            reminderDurationText.visibility = View.GONE
            durationSpinner.visibility = View.GONE
            revision_FrequencyCard.visibility = View.GONE
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
            revisionFrequencySpinner.setSelection(frequencyNames.size -1) // Select "No Repetition"

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
        }
    }

    private fun loadSubjectsAndCodes() {
        val user = auth.currentUser
        if (user == null) {
            Toast.makeText(this, "Please login to continue", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        val uid = user.uid
        val dataRef = database.getReference("users/$uid/user_data")

        dataRef.addListenerForSingleValueEvent(object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                subjects.clear()
                subjectCodes.clear()

                // Add subjects
                for (subjectSnapshot in snapshot.children) {
                    val subject = subjectSnapshot.key ?: continue
                    subjects.add(subject)

                    // Add subject codes
                    val codesList = mutableListOf<String>()
                    for (codeSnapshot in subjectSnapshot.children) {
                        val code = codeSnapshot.key ?: continue
                        codesList.add(code)
                    }
                    subjectCodes[subject] = codesList
                }

                // Update the spinners
                updateCategorySpinner()

                // Set initial selection
                if (subjects.isNotEmpty()) {
                    selectedSubject = subjects[0]
                    updateSubCategorySpinner()
                }

                // Set up all listeners after data is loaded
                setupListeners()
            }

            override fun onCancelled(error: DatabaseError) {
                Toast.makeText(this@AddLectureActivity,
                    "Error loading data: ${error.message}",
                    Toast.LENGTH_SHORT).show()
            }
        })
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
        val codes = subjectCodes[selectedSubject] ?: listOf()
        val spinnerItems = codes + "Add New Sub Category"
        val adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_item,
            spinnerItems
        )
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        subCategorySpinner.adapter = adapter

        if (codes.isNotEmpty()) {
            selectedSubjectCode = codes[0]
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
        try {
            if (todayDate == "Unspecified") {
                scheduledDateEditText.setText("Unspecified")
                dateScheduled = "Unspecified"
                return
            }
            else{
                if(revisionFrequency== "No Repetition"){
                    scheduledDateEditText.setText("Unspecified")
                    dateScheduled = "Unspecified"
                    return
                }
                if(revisionFrequency== "Custom"){
                    val dateScheduled_ = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse(todayDate)
                    val scheduledCalendar_ = Calendar.getInstance()
                    scheduledCalendar_.time = dateScheduled_ ?: Date()
                    val nextDate = calculateCustomNextDate(scheduledCalendar_, revisionData)
                    dateScheduled = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(nextDate.time)
                    return
                }else{
                    val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                    val initialDate = dateFormat.parse(todayDate) ?: Calendar.getInstance().time

                    // Use the utility class to calculate next revision date
                    RevisionScheduler.calculateNextRevisionDate(
                        this,
                        revisionFrequency,
                        0, // Initial revision
                        initialDate
                    ) { calculatedDate ->
                        dateScheduled = calculatedDate
                        scheduledDateEditText.setText(dateScheduled)
                    }
                }
            }
        } catch (e: Exception) {
            Toast.makeText(this, "Error setting date: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    private fun showTimePicker() {
        val calendar = Calendar.getInstance()
        val hour = calendar.get(Calendar.HOUR_OF_DAY)
        val minute = calendar.get(Calendar.MINUTE)

        val timePickerDialog = TimePickerDialog(
            this,
            { _, selectedHour, selectedMinute ->
                val time = String.format("%02d:%02d", selectedHour, selectedMinute)
                reminderTimeEditText.setText(time)
                allDayCheckBox.isChecked = false
            },
            hour,
            minute,
            true
        )
        timePickerDialog.show()
    }

    private fun showDatePicker(editText: EditText, onDateSelected: (String) -> Unit) {
        val calendar = Calendar.getInstance()
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
            selectedSubject = newCategoryEditText.text.toString().trim()
            if (selectedSubject.isEmpty()) {
                Toast.makeText(this, "Please enter a category name", Toast.LENGTH_SHORT).show()
                return
            }
        }

        // Handle new subcategory input
        if (addNewSubCategoryLayout.visibility == View.VISIBLE) {
            selectedSubjectCode = newSubCategoryEditText.text.toString().trim()
            if (selectedSubjectCode.isEmpty()) {
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
                .child(selectedSubject)
                .child(selectedSubjectCode)
                .child(title)


            // Handle date values based on checkboxes
            val isUnspecifiedInitiationDate = initiationDateCheckbox.isChecked
            val isNoRepetition = reviewFrequencyCheckbox.isChecked

            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            dateFormat.isLenient = false

            // Set noRevision value based on checkboxes
            if (isUnspecifiedInitiationDate) {
                noRevision = -1
            } else if (isNoRepetition) {
                noRevision = -1
            } else {
                val currentDateStr = dateFormat.format(Date())
                val currentDate = dateFormat.parse(currentDateStr)
                val initiatedDate = dateFormat.parse(todayDate)
                if (initiatedDate != null && initiatedDate.before(currentDate)) {
                    noRevision = -1
                } else if (initiatedDate != null && initiatedDate.after(currentDate)) {
                    noRevision = -1
                }
            }

            recordData["initiated_on"] = SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.getDefault()).format(Calendar.getInstance().time)
            recordData["reminder_time"] = reminderTime
            recordData["lecture_type"] = lectureType
            recordData["date_learnt"] = todayDate
            recordData["date_revised"] = todayDate
            recordData["date_scheduled"] = dateScheduled
            recordData["description"] = description
            recordData["missed_revision"] = 0
            recordData["no_revision"] = noRevision
            recordData["revision_frequency"] = revisionFrequency
            recordData["status"] = "Enabled"
            recordData["duration"] = durationData


            // Handle custom frequency data if available
            println("Custom frequency data saverecord: $customFrequencyData")


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
    }
}