package com.imnexerio.retracker

import android.content.Context
import android.os.Bundle
import android.text.InputType
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.fragment.app.DialogFragment
import com.imnexerio.retracker.databinding.CustomFrequencySelectorBinding
import java.util.*

class CustomFrequencySelector : DialogFragment() {
    private var _binding: CustomFrequencySelectorBinding? = null
    private val binding get() = _binding!!

    private lateinit var dayController: EditText
    private lateinit var weekController: EditText
    private lateinit var monthController: EditText
    private lateinit var yearController: EditText
    private var frequencyType: String = "week"
    private var selectedDaysOfWeek: MutableList<Boolean> = MutableList(7) { false }
    private var selectedDates: MutableList<Int> = mutableListOf()
    private var showDateSelection: Boolean = false
    private var currentDate: Calendar = Calendar.getInstance()
    private var currentDayOfMonth: Int = 0
    private var currentMonth: String = ""
    private var currentDayOfWeek: String = ""
    private var currentWeekOfMonth: Int = 0

    private var monthlyOption: String = "day"
    private var selectedDayOfMonth: Int = 0
    private var selectedWeekOfMonth: Int = 0
    private var selectedDayOfWeek: String = ""

    private var yearlyOption: String = "day"
    private var selectedMonthDay: Int = 0
    private var selectedMonth: String = ""
    private var selectedWeekOfYear: Int = 0
    private var selectedDayOfWeekForYear: String = ""
    private var selectedMonths: MutableList<Boolean> = MutableList(12) { false }
    private var showMonthSelection: Boolean = false

    // Interface for callback when user saves frequency settings
    interface OnFrequencySelectedListener {
        fun onFrequencySelected(customData: HashMap<String, Any>)
    }

    private var listener: OnFrequencySelectedListener? = null
    private var initialParams: HashMap<String, Any> = HashMap()

    companion object {
        fun newInstance(initialParams: HashMap<String, Any> = HashMap()): CustomFrequencySelector {
            val fragment = CustomFrequencySelector()
            fragment.initialParams = initialParams
            return fragment
        }
    }

    override fun onAttach(context: Context) {
        super.onAttach(context)
        if (context is OnFrequencySelectedListener) {
            listener = context
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setStyle(STYLE_NORMAL, R.style.NormalTheme)
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = CustomFrequencySelectorBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        initializeDefaultValues()
        setupControllers()
        loadInitialParams()
        setupListeners()
    }

    private fun initializeDefaultValues() {
        currentDate = Calendar.getInstance()
        currentDayOfMonth = currentDate.get(Calendar.DAY_OF_MONTH)
        currentMonth = getMonthAbbreviation(currentDate.get(Calendar.MONTH) + 1)
        currentDayOfWeek = getDayOfWeekName(currentDate.get(Calendar.DAY_OF_WEEK))
        currentWeekOfMonth = (currentDate.get(Calendar.DAY_OF_MONTH) / 7.0).toInt() + 1

        frequencyType = "week"
        selectedDaysOfWeek = MutableList(7) { false }
        val currentWeekday = convertWeekdayToUIIndex(currentDate.get(Calendar.DAY_OF_WEEK))
        selectedDaysOfWeek[currentWeekday] = true

        monthlyOption = "day"
        selectedDayOfMonth = currentDayOfMonth
        selectedWeekOfMonth = currentWeekOfMonth
        selectedDayOfWeek = currentDayOfWeek
        selectedDates = mutableListOf(currentDayOfMonth)

        yearlyOption = "day"
        selectedMonthDay = currentDayOfMonth
        selectedMonth = currentMonth
        selectedWeekOfYear = currentWeekOfMonth
        selectedDayOfWeekForYear = currentDayOfWeek
        selectedMonths = MutableList(12) { false }
        selectedMonths[currentDate.get(Calendar.MONTH)] = true
    }

    private fun setupControllers() {
        dayController = binding.dayInput
        weekController = binding.weekInput
        monthController = binding.monthInput
        yearController = binding.yearInput

        dayController.setText("1")
        weekController.setText("1")
        monthController.setText("1")
        yearController.setText("1")

        // Set input type to number
        dayController.inputType = InputType.TYPE_CLASS_NUMBER
        weekController.inputType = InputType.TYPE_CLASS_NUMBER
        monthController.inputType = InputType.TYPE_CLASS_NUMBER
        yearController.inputType = InputType.TYPE_CLASS_NUMBER
    }

    private fun convertWeekdayToUIIndex(dateTimeWeekday: Int): Int {
        // Convert Calendar.DAY_OF_WEEK (Sunday = 1) to our UI index (Sunday = 0)
        return (dateTimeWeekday - 1) % 7
    }

    private fun getMonthAbbreviation(month: Int): String {
        val monthAbbreviations = arrayOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
        return monthAbbreviations[month - 1]
    }

    private fun getDayOfWeekName(weekday: Int): String {
        // Calendar.DAY_OF_WEEK: Sunday = 1, Monday = 2, ..., Saturday = 7
        val dayNames = arrayOf("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
        return dayNames[weekday - 1]
    }

    private fun getOrdinalSuffix(number: Int): String {
        if (number in 11..13) {
            return "th"
        }

        return when (number % 10) {
            1 -> "st"
            2 -> "nd"
            3 -> "rd"
            else -> "th"
        }
    }

    private fun loadInitialParams() {
        if (initialParams.isNotEmpty()) {
            frequencyType = initialParams["frequencyType"] as? String ?: "week"

            when (frequencyType) {
                "day" -> {
                    val value = initialParams["value"] as? Int ?: 1
                    dayController.setText(value.toString())
                }
                "week" -> {
                    val value = initialParams["value"] as? Int ?: 1
                    weekController.setText(value.toString())
                    if (initialParams["daysOfWeek"] != null) {
                        selectedDaysOfWeek = (initialParams["daysOfWeek"] as? List<Boolean>)?.toMutableList()
                            ?: MutableList(7) { false }
                    }
                    updateWeekdaySelectionUI()
                }
                "month" -> {
                    val value = initialParams["value"] as? Int ?: 1
                    monthController.setText(value.toString())
                    monthlyOption = initialParams["monthlyOption"] as? String ?: "day"

                    if (monthlyOption == "day") {
                        selectedDayOfMonth = initialParams["dayOfMonth"] as? Int ?: currentDayOfMonth
                    } else if (monthlyOption == "weekday") {
                        selectedWeekOfMonth = initialParams["weekOfMonth"] as? Int ?: currentWeekOfMonth
                        selectedDayOfWeek = initialParams["dayOfWeek"] as? String ?: currentDayOfWeek
                    } else if (monthlyOption == "dates") {
                        if (initialParams["selectedDates"] != null) {
                            selectedDates = (initialParams["selectedDates"] as? List<Int>)?.toMutableList()
                                ?: mutableListOf()
                        }
                        showDateSelection = true
                    }
                    updateMonthlyOptionsUI()
                }
                "year" -> {
                    val value = initialParams["value"] as? Int ?: 1
                    yearController.setText(value.toString())
                    yearlyOption = initialParams["yearlyOption"] as? String ?: "day"

                    if (yearlyOption == "day") {
                        selectedMonthDay = initialParams["monthDay"] as? Int ?: currentDayOfMonth
                    } else {
                        selectedWeekOfYear = initialParams["weekOfYear"] as? Int ?: currentWeekOfMonth
                        selectedDayOfWeekForYear = initialParams["dayOfWeekForYear"] as? String ?: currentDayOfWeek
                    }

                    selectedMonth = initialParams["month"] as? String ?: currentMonth

                    if (initialParams["selectedMonths"] != null) {
                        selectedMonths = (initialParams["selectedMonths"] as? List<Boolean>)?.toMutableList()
                            ?: MutableList(12) { false }
                        if (selectedMonths.contains(true)) {
                            showMonthSelection = true
                        }
                    }
                    updateYearlyOptionsUI()
                }
            }

            // Update UI based on selected frequency type
            updateFrequencyTypeUI()
        }
    }

    private fun updateFrequencyTypeUI() {
        // Update radio buttons
        binding.radioDayOption.isChecked = frequencyType == "day"
        binding.radioWeekOption.isChecked = frequencyType == "week"
        binding.radioMonthOption.isChecked = frequencyType == "month"
        binding.radioYearOption.isChecked = frequencyType == "year"

        // Show/hide appropriate sections
        binding.weeklyOptionsLayout.visibility = if (frequencyType == "week") View.VISIBLE else View.GONE
        binding.monthlyOptionsLayout.visibility = if (frequencyType == "month") View.VISIBLE else View.GONE
        binding.yearlyOptionsLayout.visibility = if (frequencyType == "year") View.VISIBLE else View.GONE
    }

    private fun updateWeekdaySelectionUI() {
        // Update the weekday circle selections
        val weekdayContainers = listOf(
            binding.daySunday, binding.dayMonday, binding.dayTuesday,
            binding.dayWednesday, binding.dayThursday, binding.dayFriday, binding.daySaturday
        )

        for (i in selectedDaysOfWeek.indices) {
            weekdayContainers[i].isSelected = selectedDaysOfWeek[i]
            updateDayCircleAppearance(weekdayContainers[i], selectedDaysOfWeek[i])
        }
    }

    private fun updateMonthlyOptionsUI() {
        binding.monthOptionDay.isSelected = monthlyOption == "day"
        binding.monthOptionWeekday.isSelected = monthlyOption == "weekday"
        binding.monthOptionDates.isSelected = monthlyOption == "dates"

        // Update option button texts
        binding.monthOptionDay.text = "Repeat on the $selectedDayOfMonth${getOrdinalSuffix(selectedDayOfMonth)}"
        binding.monthOptionWeekday.text = "Repeat on the $selectedWeekOfMonth${getOrdinalSuffix(selectedWeekOfMonth)} $selectedDayOfWeek"

        updateOptionButtonStyles()

        // Update date selection visibility
        binding.dateSelectionGrid.visibility = if (showDateSelection && monthlyOption == "dates") View.VISIBLE else View.GONE

        if (showDateSelection && monthlyOption == "dates") {
            refreshDateSelectionGrid()
        }
    }

    private fun updateYearlyOptionsUI() {
        binding.yearOptionDay.isSelected = yearlyOption == "day"
        binding.yearOptionWeekday.isSelected = yearlyOption == "weekday"

        // Update option button texts
        binding.yearOptionDay.text = "Repeat on ${selectedMonthDay}${getOrdinalSuffix(selectedMonthDay)} $selectedMonth"
        binding.yearOptionWeekday.text = "Repeat on the ${selectedWeekOfYear}${getOrdinalSuffix(selectedWeekOfYear)} $selectedDayOfWeekForYear of $selectedMonth"

        updateYearlyOptionButtonStyles()

        // Update month selection visibility
        binding.monthSelectionGrid.visibility = if (showMonthSelection) View.VISIBLE else View.GONE

        if (showMonthSelection) {
            refreshMonthSelectionGrid()
        }

        // Update month selection button text
        updateMonthSelectionButtonText()
    }

    private fun updateMonthSelectionButtonText() {
        val selectedCount = selectedMonths.count { it }
        val dayText = if (yearlyOption == "day")
            "${selectedMonthDay}${getOrdinalSuffix(selectedMonthDay)} day"
        else
            "the ${selectedWeekOfYear}${getOrdinalSuffix(selectedWeekOfYear)} $selectedDayOfWeekForYear"

        binding.monthSelectionButton.text = if (selectedCount == 1)
            "Select months to repeat on $dayText"
        else
            "Repeat on $dayText in $selectedCount months"
    }

    private fun updateOptionButtonStyles() {
        val MarkAsDone = ContextCompat.getColor(requireContext(), R.color.MarkAsDone)
        val text = ContextCompat.getColor(requireContext(), R.color.text)
        val divider = ContextCompat.getColor(requireContext(), R.color.divider)

        // Update Monthly Options
        updateOptionButtonStyle(binding.monthOptionDay, monthlyOption == "day", MarkAsDone, text, divider)
        updateOptionButtonStyle(binding.monthOptionWeekday, monthlyOption == "weekday", MarkAsDone, text, divider)
        updateOptionButtonStyle(binding.monthOptionDates, monthlyOption == "dates", MarkAsDone, text, divider)
    }

    private fun updateYearlyOptionButtonStyles() {
        val MarkAsDone = ContextCompat.getColor(requireContext(), R.color.MarkAsDone)
        val text = ContextCompat.getColor(requireContext(), R.color.text)
        val divider = ContextCompat.getColor(requireContext(), R.color.divider)

        // Update Yearly Options
        updateOptionButtonStyle(binding.yearOptionDay, yearlyOption == "day", MarkAsDone, text, divider)
        updateOptionButtonStyle(binding.yearOptionWeekday, yearlyOption == "weekday", MarkAsDone, text, divider)
        updateOptionButtonStyle(binding.monthSelectionButton, showMonthSelection, MarkAsDone, text, divider)
    }

    private fun updateOptionButtonStyle(button: TextView, isSelected: Boolean, MarkAsDone: Int, text: Int, divider: Int) {
        val bgColor = if (isSelected) MarkAsDone else ContextCompat.getColor(requireContext(), android.R.color.transparent)
        val textColor = if (isSelected) text else divider

        button.setBackgroundColor(bgColor)
        button.setTextColor(textColor)
    }

    private fun updateDayCircleAppearance(view: TextView, isSelected: Boolean) {
        val MarkAsDone = ContextCompat.getColor(requireContext(), R.color.MarkAsDone)
        val text = ContextCompat.getColor(requireContext(), R.color.text)
        val divider = ContextCompat.getColor(requireContext(), R.color.divider)

        view.setBackgroundResource(if (isSelected) R.drawable.circle_selected else R.drawable.circle_unselected)
        view.setTextColor(if (isSelected) text else divider)
    }

    private fun refreshDateSelectionGrid() {
        binding.dateSelectionGrid.removeAllViews()

        val daysInMonth = getLastDayOfMonth(currentDate.get(Calendar.YEAR), currentDate.get(Calendar.MONTH))
        val inflater = LayoutInflater.from(requireContext())

        for (day in 1..daysInMonth) {
            val dateCircle = inflater.inflate(R.layout.item_date_circle, binding.dateSelectionGrid, false) as TextView
            dateCircle.text = day.toString()
            dateCircle.isSelected = selectedDates.contains(day)
            updateDateCircleAppearance(dateCircle, day)

            dateCircle.setOnClickListener {
                toggleDateSelection(day)
                updateDateCircleAppearance(dateCircle, day)
            }

            binding.dateSelectionGrid.addView(dateCircle)
        }
    }

    private fun updateDateCircleAppearance(view: TextView, day: Int) {
        val isSelected = selectedDates.contains(day)
        val MarkAsDone = ContextCompat.getColor(requireContext(), R.color.MarkAsDone)
        val text = ContextCompat.getColor(requireContext(), R.color.text)
        val divider = ContextCompat.getColor(requireContext(), R.color.divider)

        view.setBackgroundResource(if (isSelected) R.drawable.circle_selected else R.drawable.circle_unselected)
        view.setTextColor(if (isSelected) text else divider)
    }

    private fun refreshMonthSelectionGrid() {
        binding.monthSelectionGrid.removeAllViews()

        val monthNames = arrayOf("JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEPT", "OCT", "NOV", "DEC")
        val inflater = LayoutInflater.from(requireContext())

        for (i in 0 until 12) {
            val monthCircle = inflater.inflate(R.layout.item_month_circle, binding.monthSelectionGrid, false) as TextView
            monthCircle.text = monthNames[i]
            monthCircle.isSelected = selectedMonths[i]
            updateMonthCircleAppearance(monthCircle, i)

            monthCircle.setOnClickListener {
                toggleMonthSelection(i)
                updateMonthCircleAppearance(monthCircle, i)
                updateMonthSelectionButtonText()
            }

            binding.monthSelectionGrid.addView(monthCircle)
        }
    }

    private fun updateMonthCircleAppearance(view: TextView, monthIndex: Int) {
        val isSelected = selectedMonths[monthIndex]
        val MarkAsDone = ContextCompat.getColor(requireContext(), R.color.MarkAsDone)
        val text = ContextCompat.getColor(requireContext(), R.color.text)
        val divider = ContextCompat.getColor(requireContext(), R.color.divider)

        view.setBackgroundResource(if (isSelected) R.drawable.circle_selected else R.drawable.circle_unselected)
        view.setTextColor(if (isSelected) text else divider)
    }

    private fun getLastDayOfMonth(year: Int, month: Int): Int {
        val calendar = Calendar.getInstance()
        calendar.set(year, month, 1)
        return calendar.getActualMaximum(Calendar.DAY_OF_MONTH)
    }

    private fun toggleDateSelection(date: Int) {
        if (selectedDates.contains(date)) {
            selectedDates.remove(date)
        } else {
            selectedDates.add(date)
        }
    }

    private fun toggleMonthSelection(monthIndex: Int) {
        selectedMonths[monthIndex] = !selectedMonths[monthIndex]

        if (selectedMonths.count { it } == 1 && selectedMonths[monthIndex]) {
            selectedMonth = getMonthAbbreviation(monthIndex + 1)
        }
    }

    private fun setupListeners() {
        // Frequency type selection
        binding.radioDayOption.setOnClickListener { updateFrequencyType("day") }
        binding.radioWeekOption.setOnClickListener { updateFrequencyType("week") }
        binding.radioMonthOption.setOnClickListener { updateFrequencyType("month") }
        binding.radioYearOption.setOnClickListener { updateFrequencyType("year") }

        // Weekday selection
        val weekdayViews = listOf(
            binding.daySunday, binding.dayMonday, binding.dayTuesday,
            binding.dayWednesday, binding.dayThursday, binding.dayFriday, binding.daySaturday
        )

        for (i in weekdayViews.indices) {
            weekdayViews[i].setOnClickListener {
                selectedDaysOfWeek[i] = !selectedDaysOfWeek[i]
                updateDayCircleAppearance(weekdayViews[i], selectedDaysOfWeek[i])
            }
        }

        // Monthly options
        binding.monthOptionDay.setOnClickListener {
            monthlyOption = "day"
            selectedDayOfMonth = currentDayOfMonth
            showDateSelection = false
            updateMonthlyOptionsUI()
        }

        binding.monthOptionWeekday.setOnClickListener {
            monthlyOption = "weekday"
            selectedWeekOfMonth = currentWeekOfMonth
            selectedDayOfWeek = currentDayOfWeek
            showDateSelection = false
            updateMonthlyOptionsUI()
        }

        binding.monthOptionDates.setOnClickListener {
            monthlyOption = "dates"
            showDateSelection = true
            updateMonthlyOptionsUI()
        }

        // Yearly options
        binding.yearOptionDay.setOnClickListener {
            yearlyOption = "day"
            selectedMonthDay = currentDayOfMonth
            selectedMonth = currentMonth
            updateYearlyOptionsUI()
        }

        binding.yearOptionWeekday.setOnClickListener {
            yearlyOption = "weekday"
            selectedWeekOfYear = currentWeekOfMonth
            selectedDayOfWeekForYear = currentDayOfWeek
            selectedMonth = currentMonth
            updateYearlyOptionsUI()
        }

        binding.monthSelectionButton.setOnClickListener {
            showMonthSelection = !showMonthSelection
            updateYearlyOptionsUI()
        }

        // Button handlers
        binding.cancelButton.setOnClickListener {
            dismiss()
        }

        binding.saveButton.setOnClickListener {
            val activeController = when (frequencyType) {
                "day" -> dayController
                "week" -> weekController
                "month" -> monthController
                "year" -> yearController
                else -> dayController
            }

            val customData = hashMapOf<String, Any>(
                "frequencyType" to frequencyType,
                "value" to (activeController.text.toString().toIntOrNull() ?: 1)
            )

            when (frequencyType) {
                "week" -> {
                    customData["daysOfWeek"] = selectedDaysOfWeek
                }
                "month" -> {
                    customData["monthlyOption"] = monthlyOption
                    when (monthlyOption) {
                        "day" -> customData["dayOfMonth"] = selectedDayOfMonth
                        "weekday" -> {
                            customData["weekOfMonth"] = selectedWeekOfMonth
                            customData["dayOfWeek"] = selectedDayOfWeek
                        }
                        "dates" -> customData["selectedDates"] = selectedDates
                    }
                }
                "year" -> {
                    customData["yearlyOption"] = yearlyOption
                    customData["month"] = selectedMonth
                    customData["selectedMonths"] = selectedMonths
                    if (yearlyOption == "day") {
                        customData["monthDay"] = selectedMonthDay
                    } else {
                        customData["weekOfYear"] = selectedWeekOfYear
                        customData["dayOfWeekForYear"] = selectedDayOfWeekForYear
                    }
                }
            }

            listener?.onFrequencySelected(customData)
            dismiss()
        }
    }

    private fun updateFrequencyType(type: String) {
        frequencyType = type
        updateFrequencyTypeUI()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
    
}