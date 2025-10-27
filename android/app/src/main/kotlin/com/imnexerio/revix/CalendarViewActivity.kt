package com.imnexerio.revix

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import androidx.lifecycle.lifecycleScope
import androidx.viewpager2.widget.ViewPager2
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.*

class CalendarViewActivity : AppCompatActivity() {
    
    companion object {
        // Event type color mapping - single source of truth
        fun getEventTypeColor(type: String): Int {
            return when (type) {
                "initiated", "learned" -> android.graphics.Color.rgb(33, 150, 243) // Light Blue
                "reviewed" -> android.graphics.Color.rgb(76, 175, 80) // Material Green
                "scheduled" -> android.graphics.Color.rgb(255, 165, 0) // Orange
                "missed" -> Color.RED
                else -> Color.GRAY
            }
        }
        
        fun getEventTypeEmoji(type: String): String {
            return when (type) {
                "initiated", "learned" -> "🔵"
                "reviewed" -> "🟢"
                "scheduled" -> "🟠"
                "missed" -> "🔴"
                else -> "⚪"
            }
        }
    }
    
    private lateinit var todayButton: Button
    private lateinit var monthYearText: TextView
    private lateinit var viewPager: ViewPager2
    private lateinit var eventsRecyclerView: RecyclerView
    private lateinit var emptyView: TextView
    private lateinit var eventAdapter: CalendarEventAdapter
    
    private var selectedDate = Calendar.getInstance()
    private var events = mutableMapOf<String, List<CalendarEvent>>()
    private lateinit var calendarPagerAdapter: CalendarPagerAdapter
    
    // ViewPager position mapping (position 12 = current month)
    private val INITIAL_POSITION = 12
    private val TOTAL_MONTHS = 25 // 12 previous + current + 12 next
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_calendar_view)
        
        initializeViews()
        loadEvents()
        setupListeners()
    }
    
    private fun initializeViews() {
        todayButton = findViewById(R.id.today_button)
        monthYearText = findViewById(R.id.month_year_text)
        viewPager = findViewById(R.id.calendar_view_pager)
        eventsRecyclerView = findViewById(R.id.events_recycler_view)
        emptyView = findViewById(R.id.empty_view)
        
        // Setup events RecyclerView (shared, not in ViewPager)
        eventAdapter = CalendarEventAdapter(listOf(), this)
        eventsRecyclerView.layoutManager = LinearLayoutManager(this)
        eventsRecyclerView.adapter = eventAdapter
        
        // Setup ViewPager2 with adapter
        calendarPagerAdapter = CalendarPagerAdapter()
        viewPager.adapter = calendarPagerAdapter
        viewPager.setCurrentItem(INITIAL_POSITION, false)
        
        // Update header to show current month
        updateHeader(INITIAL_POSITION)
    }
    
    private fun setupListeners() {
        // ViewPager2 page change listener
        viewPager.registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
            override fun onPageSelected(position: Int) {
                super.onPageSelected(position)
                updateHeader(position)
                calendarPagerAdapter.notifyPageSelected(position)
            }
        })
        
        // Setup today button
        todayButton.setOnClickListener {
            val today = Calendar.getInstance()
            selectedDate.set(today.get(Calendar.YEAR), today.get(Calendar.MONTH), today.get(Calendar.DAY_OF_MONTH))
            viewPager.setCurrentItem(INITIAL_POSITION, true)
        }
    }
    
    private fun updateHeader(position: Int) {
        val calendar = getCalendarForPosition(position)
        val monthYearFormat = SimpleDateFormat("MMMM yyyy", Locale.getDefault())
        monthYearText.text = monthYearFormat.format(calendar.time)
        
        // Update today button state
        val today = Calendar.getInstance()
        val isCurrentMonth = (calendar.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                              calendar.get(Calendar.MONTH) == today.get(Calendar.MONTH))
        
        todayButton.isEnabled = !isCurrentMonth
        todayButton.alpha = if (isCurrentMonth) 0.5f else 1.0f
    }
    
    private fun getCalendarForPosition(position: Int): Calendar {
        val calendar = Calendar.getInstance()
        val monthOffset = position - INITIAL_POSITION
        calendar.add(Calendar.MONTH, monthOffset)
        return calendar
    }
    
    private fun loadEvents() {
        lifecycleScope.launch {
            try {
                // Move heavy JSON parsing to background thread
                val parsedEvents = withContext(Dispatchers.IO) {
                    val prefs = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
                    val allRecordsJson = prefs.getString("allRecords", "{}")
                    
                    if (allRecordsJson.isNullOrEmpty() || allRecordsJson == "{}") {
                        Log.d("CalendarViewActivity", "No records found")
                        return@withContext mutableMapOf<String, List<CalendarEvent>>()
                    }
                    
                    val allRecordsObject = org.json.JSONObject(allRecordsJson)
                    val tempEvents = mutableMapOf<String, MutableList<CalendarEvent>>()
                    
                    // Parse records
                    val categoryKeys = allRecordsObject.keys()
                    while (categoryKeys.hasNext()) {
                        val category = categoryKeys.next()
                        val categoryObject = allRecordsObject.getJSONObject(category)
                        
                        val subcategoryKeys = categoryObject.keys()
                        while (subcategoryKeys.hasNext()) {
                            val subcategory = subcategoryKeys.next()
                            val subcategoryObject = categoryObject.getJSONObject(subcategory)
                            
                            val recordKeys = subcategoryObject.keys()
                            while (recordKeys.hasNext()) {
                                val recordTitle = recordKeys.next()
                                val recordObject = subcategoryObject.getJSONObject(recordTitle)
                                
                                parseRecordEventsToMap(category, subcategory, recordTitle, recordObject, tempEvents)
                            }
                        }
                    }
                    
                    tempEvents.mapValues { it.value.toList() }.toMutableMap()
                }
                
                // Update UI on main thread
                events = parsedEvents
                Log.d("CalendarViewActivity", "Loaded ${events.size} days with events")
                calendarPagerAdapter.notifyDataSetChanged()
                // Update events list for today's date after data is loaded
                updateEventsList()
            } catch (e: Exception) {
                Log.e("CalendarViewActivity", "Error loading events: ${e.message}", e)
            }
        }
    }
    
    private fun parseRecordEventsToMap(
        category: String, 
        subcategory: String, 
        recordTitle: String, 
        recordObject: org.json.JSONObject,
        eventsMap: MutableMap<String, MutableList<CalendarEvent>>
    ) {
        val status = recordObject.optString("status", "Enabled")
        val description = recordObject.optString("description", "No description")
        val entryType = recordObject.optString("entry_type", "")
        
        // Parse start_timestamp (initiated)
        val startTimestamp = recordObject.optString("start_timestamp", "")
        if (startTimestamp.isNotEmpty()) {
            try {
                val date = parseDate(startTimestamp)
                if (date != null) {
                    addEventToMap(eventsMap, date, CalendarEvent(
                        type = "initiated",
                        category = category,
                        subCategory = subcategory,
                        recordTitle = recordTitle,
                        description = description,
                        status = status,
                        entryType = entryType
                    ))
                }
            } catch (e: Exception) {
                Log.e("CalendarViewActivity", "Error parsing start_timestamp: ${e.message}")
            }
        }
        
        // Parse dates_updated (reviewed)
        val datesUpdated = recordObject.optJSONArray("dates_updated")
        if (datesUpdated != null) {
            for (i in 0 until datesUpdated.length()) {
                try {
                    val dateStr = datesUpdated.getString(i)
                    val date = parseDate(dateStr)
                    if (date != null) {
                        addEventToMap(eventsMap, date, CalendarEvent(
                            type = "reviewed",
                            category = category,
                            subCategory = subcategory,
                            recordTitle = recordTitle,
                            description = description,
                            status = status,
                            entryType = entryType
                        ))
                    }
                } catch (e: Exception) {
                    Log.e("CalendarViewActivity", "Error parsing dates_updated: ${e.message}")
                }
            }
        }
        
        // Parse scheduled_date
        val scheduledDate = recordObject.optString("scheduled_date", "")
        val dateInitiated = recordObject.optString("date_initiated", "")
        if (scheduledDate.isNotEmpty() && scheduledDate != "Unspecified" && 
            dateInitiated != "Unspecified" && status == "Enabled") {
            try {
                val date = parseDate(scheduledDate)
                if (date != null) {
                    addEventToMap(eventsMap, date, CalendarEvent(
                        type = "scheduled",
                        category = category,
                        subCategory = subcategory,
                        recordTitle = recordTitle,
                        description = description,
                        status = status,
                        entryType = entryType
                    ))
                }
            } catch (e: Exception) {
                Log.e("CalendarViewActivity", "Error parsing scheduled_date: ${e.message}")
            }
        }
        
        // Parse dates_missed_revisions
        val datesMissed = recordObject.optJSONArray("dates_missed_revisions")
        if (datesMissed != null) {
            for (i in 0 until datesMissed.length()) {
                try {
                    val dateStr = datesMissed.getString(i)
                    val date = parseDate(dateStr)
                    if (date != null) {
                        addEventToMap(eventsMap, date, CalendarEvent(
                            type = "missed",
                            category = category,
                            subCategory = subcategory,
                            recordTitle = recordTitle,
                            description = description,
                            status = status,
                            entryType = entryType
                        ))
                    }
                } catch (e: Exception) {
                    Log.e("CalendarViewActivity", "Error parsing dates_missed_revisions: ${e.message}")
                }
            }
        }
    }
    
    private fun parseDate(dateStr: String): Calendar? {
        return try {
            val formats = listOf(
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm",
                "yyyy-MM-dd"
            )
            
            for (format in formats) {
                try {
                    val sdf = SimpleDateFormat(format, Locale.getDefault())
                    val date = sdf.parse(dateStr)
                    if (date != null) {
                        val cal = Calendar.getInstance()
                        cal.time = date
                        return cal
                    }
                } catch (e: Exception) {
                    // Try next format
                }
            }
            null
        } catch (e: Exception) {
            null
        }
    }
    
    private fun addEventToMap(eventsMap: MutableMap<String, MutableList<CalendarEvent>>, date: Calendar, event: CalendarEvent) {
        val dateKey = getDateKey(date.get(Calendar.YEAR), 
            date.get(Calendar.MONTH), 
            date.get(Calendar.DAY_OF_MONTH))
        
        eventsMap.getOrPut(dateKey) { mutableListOf() }.add(event)
    }
    
    private fun getDateKey(year: Int, month: Int, day: Int): String {
        return "$year-${month + 1}-$day"
    }
    
    private fun updateEventsList() {
        val dateKey = getDateKey(selectedDate.get(Calendar.YEAR), 
            selectedDate.get(Calendar.MONTH), 
            selectedDate.get(Calendar.DAY_OF_MONTH))
        
        val dayEvents = events[dateKey] ?: emptyList()
        
        if (dayEvents.isEmpty()) {
            eventsRecyclerView.visibility = View.GONE
            emptyView.visibility = View.VISIBLE
        } else {
            eventsRecyclerView.visibility = View.VISIBLE
            emptyView.visibility = View.GONE
            
            // Single-pass grouping by normalizing type
            val normalizedEvents = dayEvents.map { event ->
                event.copy(type = if (event.type == "learned") "initiated" else event.type)
            }
            val eventsByType = normalizedEvents.groupBy { it.type }
            
            // Create list with separators in order
            val groupedItems = mutableListOf<Any>()
            val typeOrder = listOf("initiated", "reviewed", "scheduled", "missed")
            
            for (type in typeOrder) {
                val eventsOfType = eventsByType[type] ?: continue
                if (eventsOfType.isNotEmpty()) {
                    val emoji = getEventTypeEmoji(type)
                    val label = type.uppercase()
                    groupedItems.add("— $emoji $label (${eventsOfType.size}) —")
                    groupedItems.addAll(eventsOfType)
                }
            }
            
            eventAdapter.updateEvents(groupedItems)
        }
    }
    
    // ViewPager2 Adapter for calendar pages
    inner class CalendarPagerAdapter : RecyclerView.Adapter<CalendarPagerAdapter.CalendarPageViewHolder>() {
        
        override fun getItemCount() = TOTAL_MONTHS
        
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): CalendarPageViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.calendar_page_item, parent, false)
            return CalendarPageViewHolder(view)
        }
        
        override fun onBindViewHolder(holder: CalendarPageViewHolder, position: Int) {
            holder.bind(position)
        }
        
        fun notifyPageSelected(position: Int) {
            // Refresh the current page to update selected date highlight
            notifyItemChanged(position)
        }
        
        inner class CalendarPageViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
            private val calendarGrid: GridLayout = itemView as GridLayout
            
            fun bind(position: Int) {
                val monthCalendar = getCalendarForPosition(position)
                drawCalendarGrid(monthCalendar)
            }
            
            private fun drawCalendarGrid(monthCalendar: Calendar) {
                calendarGrid.removeAllViews()
                
                // Add weekday headers
                val weekdays = arrayOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
                for (weekday in weekdays) {
                    val headerView = TextView(this@CalendarViewActivity).apply {
                        text = weekday
                        textSize = 14f
                        gravity = android.view.Gravity.CENTER
                        setTextColor(getColor(R.color.textSecondary))
                        typeface = android.graphics.Typeface.DEFAULT_BOLD
                        setPadding(4, 8, 4, 8)
                    }
                    val headerParams = GridLayout.LayoutParams()
                    headerParams.width = 0
                    headerParams.height = GridLayout.LayoutParams.WRAP_CONTENT
                    headerParams.columnSpec = GridLayout.spec(weekdays.indexOf(weekday), 1f)
                    headerParams.rowSpec = GridLayout.spec(0)
                    headerView.layoutParams = headerParams
                    calendarGrid.addView(headerView)
                }
                
                // Get calendar data
                val tempCalendar = monthCalendar.clone() as Calendar
                val today = Calendar.getInstance()
                
                tempCalendar.set(Calendar.DAY_OF_MONTH, 1)
                val firstDayOfWeek = tempCalendar.get(Calendar.DAY_OF_WEEK)
                val daysInMonth = tempCalendar.getActualMaximum(Calendar.DAY_OF_MONTH)
                
                // Convert to Monday-first (0=Monday, 6=Sunday)
                val startPosition = if (firstDayOfWeek == Calendar.SUNDAY) 6 else firstDayOfWeek - 2
                
                // Get previous and next month info for filling empty cells
                val prevMonthCal = monthCalendar.clone() as Calendar
                prevMonthCal.add(Calendar.MONTH, -1)
                val daysInPrevMonth = prevMonthCal.getActualMaximum(Calendar.DAY_OF_MONTH)
                
                // Create day views
                val totalCells = 42 // 6 rows * 7 days
                for (i in 0 until totalCells) {
                    val layoutParams = GridLayout.LayoutParams()
                    layoutParams.width = 0
                    layoutParams.height = GridLayout.LayoutParams.WRAP_CONTENT
                    layoutParams.columnSpec = GridLayout.spec(i % 7, 1f)
                    layoutParams.rowSpec = GridLayout.spec((i / 7) + 1)
                    layoutParams.setMargins(4, 4, 4, 4)
                    
                    val dayNumber = i - startPosition + 1
                    
                    when {
                        dayNumber in 1..daysInMonth -> {
                            // Current month date
                            val isToday = (tempCalendar.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                                    tempCalendar.get(Calendar.MONTH) == today.get(Calendar.MONTH) &&
                                    dayNumber == today.get(Calendar.DAY_OF_MONTH))
                            
                            val isSelected = (tempCalendar.get(Calendar.YEAR) == selectedDate.get(Calendar.YEAR) &&
                                    tempCalendar.get(Calendar.MONTH) == selectedDate.get(Calendar.MONTH) &&
                                    dayNumber == selectedDate.get(Calendar.DAY_OF_MONTH))
                            
                            val dateKey = getDateKey(tempCalendar.get(Calendar.YEAR), 
                                tempCalendar.get(Calendar.MONTH), dayNumber)
                            val dayEvents = events[dateKey]
                            
                            val dayCellView = createDayCell(dayNumber, isToday, isSelected, dayEvents, false)
                            dayCellView.layoutParams = layoutParams
                            
                            dayCellView.setOnClickListener {
                                selectedDate.set(tempCalendar.get(Calendar.YEAR), 
                                    tempCalendar.get(Calendar.MONTH), dayNumber)
                                notifyItemChanged(adapterPosition)
                                updateEventsList()
                            }
                            
                            calendarGrid.addView(dayCellView)
                        }
                        dayNumber < 1 -> {
                            // Previous month date
                            val prevMonthDay = daysInPrevMonth + dayNumber
                            val prevMonthYear = prevMonthCal.get(Calendar.YEAR)
                            val prevMonth = prevMonthCal.get(Calendar.MONTH)
                            
                            val dateKey = getDateKey(prevMonthYear, prevMonth, prevMonthDay)
                            val dayEvents = events[dateKey]
                            
                            val dayCellView = createDayCell(prevMonthDay, false, false, dayEvents, true)
                            dayCellView.layoutParams = layoutParams
                            
                            dayCellView.setOnClickListener {
                                // Navigate to previous month
                                viewPager.setCurrentItem(adapterPosition - 1, true)
                                selectedDate.set(prevMonthYear, prevMonth, prevMonthDay)
                                updateEventsList()
                            }
                            
                            calendarGrid.addView(dayCellView)
                        }
                        else -> {
                            // Next month date
                            val nextMonthDay = dayNumber - daysInMonth
                            val nextMonthCal = monthCalendar.clone() as Calendar
                            nextMonthCal.add(Calendar.MONTH, 1)
                            val nextMonthYear = nextMonthCal.get(Calendar.YEAR)
                            val nextMonth = nextMonthCal.get(Calendar.MONTH)
                            
                            val dateKey = getDateKey(nextMonthYear, nextMonth, nextMonthDay)
                            val dayEvents = events[dateKey]
                            
                            val dayCellView = createDayCell(nextMonthDay, false, false, dayEvents, true)
                            dayCellView.layoutParams = layoutParams
                            
                            dayCellView.setOnClickListener {
                                // Navigate to next month
                                viewPager.setCurrentItem(adapterPosition + 1, true)
                                selectedDate.set(nextMonthYear, nextMonth, nextMonthDay)
                                updateEventsList()
                            }
                            
                            calendarGrid.addView(dayCellView)
                        }
                    }
                }
            }
        }
    }
    
    private data class EventSegment(val count: Int, val color: Int)
    
    private fun createDayCell(dayNumber: Int, isToday: Boolean, isSelected: Boolean, 
                               dayEvents: List<CalendarEvent>?, isDimmed: Boolean): View {
        val density = resources.displayMetrics.density
        
        // Create simple TextView for day number
        val dayView = TextView(this).apply {
            text = dayNumber.toString()
            textSize = 16f
            gravity = android.view.Gravity.CENTER
            setPadding(8, 16, 8, 16)
            setTextColor(getColor(R.color.text))
            
            // Apply dimming for prev/next month dates
            if (isDimmed) {
                alpha = 0.5f
            }
            
            if (isToday || isSelected) {
                typeface = android.graphics.Typeface.DEFAULT_BOLD
            }
        }
        
        // If there are events, wrap in custom view with ring
        if (!dayEvents.isNullOrEmpty()) {
            val eventCounts = dayEvents.groupBy { it.type }.mapValues { it.value.size }
            val totalEvents = eventCounts.values.sum()
            
            val segments = eventCounts.map { (type, count) ->
                EventSegment(count, getEventTypeColor(type))
            }.sortedByDescending { it.count }
            
            // Wrap TextView in custom FrameLayout that draws rings
            val container = object : FrameLayout(this) {
                override fun dispatchDraw(canvas: Canvas) {
                    super.dispatchDraw(canvas) // Draw children (TextView) first
                    
                    // Then draw rings on top
                    if (width > 0 && height > 0) {
                        val centerX = width / 2f
                        val centerY = height / 2f
                        val size = minOf(width, height).toFloat()
                        val strokeWidth = 4.5f * density
                        val radius = (size / 2f) - (strokeWidth / 2f) - density
                        
                        val rectF = RectF(
                            centerX - radius,
                            centerY - radius,
                            centerX + radius,
                            centerY + radius
                        )
                        
                        var startAngle = -90f
                        
                        for ((index, segment) in segments.withIndex()) {
                            val sweepAngle = (segment.count.toFloat() / totalEvents) * 360f
                            val currentStrokeWidth = strokeWidth - (index * 0.2f * density).coerceAtMost(density)
                            
                            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                                style = Paint.Style.STROKE
                                this.strokeWidth = currentStrokeWidth
                                strokeCap = Paint.Cap.ROUND
                                color = segment.color
                                // Apply dimming to rings too
                                if (isDimmed) {
                                    alpha = 128 // 50% opacity
                                }
                            }
                            
                            canvas.drawArc(rectF, startAngle, sweepAngle, false, paint)
                            startAngle += sweepAngle
                        }
                    }
                }
            }
            
            // Add today/selected styling
            if (isSelected) {
                container.setBackgroundResource(R.drawable.selected_day_background)
                dayView.setTextColor(getColor(R.color.colorOnPrimary))
            } else if (isToday) {
                val drawable = GradientDrawable()
                drawable.shape = GradientDrawable.OVAL
                drawable.setStroke((2 * density).toInt(), getColor(R.color.colorOnPrimary))
                container.background = drawable
            }
            
            container.addView(dayView, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            ))
            
            return container
            
        } else {
            // No events - just style the TextView
            if (isSelected) {
                dayView.setBackgroundResource(R.drawable.selected_day_background)
                dayView.setTextColor(getColor(R.color.colorOnPrimary))
            } else if (isToday) {
                val drawable = GradientDrawable()
                drawable.shape = GradientDrawable.OVAL
                drawable.setStroke((4 * density).toInt(), getColor(R.color.colorOnPrimary))
                dayView.background = drawable
            }
            
            return dayView
        }
    }
}

data class CalendarEvent(
    val type: String, // initiated, reviewed, scheduled, missed
    val category: String,
    val subCategory: String,
    val recordTitle: String,
    val description: String,
    val status: String,
    val entryType: String
)
