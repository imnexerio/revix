package com.imnexerio.retracker

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.*
import java.text.SimpleDateFormat
import java.util.*

class AddLectureActivity : AppCompatActivity() {

    // Form elements
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
    private lateinit var revisionFrequencySpinner: Spinner
    private lateinit var scheduledDateEditText: EditText
    private lateinit var descriptionEditText: EditText
    private lateinit var statusSwitch: Switch
    private lateinit var noRepetitionSwitch: Switch
    private lateinit var saveButton: Button
    private lateinit var cancelButton: Button

    // Data
    private var subjects = mutableListOf<String>()
    private var subjectCodes = mutableMapOf<String, List<String>>()
    private var selectedSubject = "DEFAULT_VALUE"
    private var selectedSubjectCode = ""
    private var lectureType = "Lectures"
    private var revisionFrequency = "Default"
    private var isEnabled = true
    private var onlyOnce = false
    private var todayDate = ""
    private var dateScheduled = ""
    private var noRevision = 0

    // Custom data
    private var trackingTypes = mutableListOf<String>()
    private var frequencies = mutableMapOf<String, List<Int>>()
    private var frequencyNames = mutableListOf<String>()

    // Database reference
    private lateinit var database: FirebaseDatabase
    private lateinit var auth: FirebaseAuth

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
        revisionFrequencySpinner = findViewById(R.id.revision_frequency_spinner)
        scheduledDateEditText = findViewById(R.id.scheduled_date_edit_text)
        descriptionEditText = findViewById(R.id.description_edit_text)
        statusSwitch = findViewById(R.id.status_switch)
        noRepetitionSwitch = findViewById(R.id.no_repetition_switch)
        saveButton = findViewById(R.id.save_button)
        cancelButton = findViewById(R.id.cancel_button)

        // Set up initial states
        addNewCategoryLayout.visibility = View.GONE
        addNewSubCategoryLayout.visibility = View.GONE
        reminderTimeEditText.setText("All Day")
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
                    updateScheduledDate()
                }

                override fun onNothingSelected(parent: AdapterView<*>?) {
                    // Do nothing
                }
            }
        }
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

        // Switches
        statusSwitch.setOnCheckedChangeListener { _, isChecked ->
            isEnabled = isChecked
        }

        noRepetitionSwitch.setOnCheckedChangeListener { _, isChecked ->
            onlyOnce = isChecked
            if (isChecked) {
                revisionFrequencySpinner.visibility = View.GONE
                scheduledDateEditText.visibility = View.GONE
            } else {
                revisionFrequencySpinner.visibility = View.VISIBLE
                scheduledDateEditText.visibility = View.VISIBLE
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
            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val initialDate = dateFormat.parse(todayDate) ?: Calendar.getInstance().time

            // Calculate next revision date based on frequency
            val nextDate = calculateNextRevisionDate(initialDate)
            dateScheduled = dateFormat.format(nextDate)
            scheduledDateEditText.setText(dateScheduled)
        } catch (e: Exception) {
            Toast.makeText(this, "Error setting date: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    private fun calculateNextRevisionDate(startDate: Date): Date {
        val calendar = Calendar.getInstance()
        calendar.time = startDate

        // Use the selected frequency to determine the next date
        val frequencyDays = frequencies[revisionFrequency]?.firstOrNull() ?: 1

        // Add the number of days from the frequency list
        calendar.add(Calendar.DAY_OF_YEAR, frequencyDays)

        return calendar.time
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

            val initiatedOn = SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.getDefault())
                .format(Calendar.getInstance().time)

            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            dateFormat.isLenient = false

            val currentDate = dateFormat.parse(dateFormat.format(Date()))
            val initiatedDate = dateFormat.parse(todayDate)
            if (initiatedDate != null && initiatedDate.before(currentDate)) {
                noRevision = -1
            }

            // Create the record data
            val recordData = HashMap<String, Any>()
            recordData["initiated_on"] = initiatedOn
            recordData["reminder_time"] = reminderTime
            recordData["lecture_type"] = lectureType
            recordData["date_learnt"] = todayDate
            recordData["date_revised"] = initiatedOn
            recordData["date_scheduled"] = dateScheduled
            recordData["description"] = description
            recordData["missed_revision"] = 0
            recordData["no_revision"] = noRevision
            recordData["revision_frequency"] = revisionFrequency
            recordData["only_once"] = if (onlyOnce) 1 else 0
            recordData["status"] = if (isEnabled) "Enabled" else "Disabled"

            // Save to Firebase
            ref.setValue(recordData)
                .addOnSuccessListener {
                    Toast.makeText(this, "Record added successfully", Toast.LENGTH_SHORT).show()

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