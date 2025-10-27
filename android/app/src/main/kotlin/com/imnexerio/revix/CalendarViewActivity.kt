package com.imnexerio.revix

import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.abs

class CalendarViewActivity : AppCompatActivity() {
    
    companion object {
        // Event type color mapping - single source of truth
        fun getEventTypeColor(type: String): Int {
            return when (type) {
                "initiated", "learned" -> android.graphics.Color.rgb(33, 150, 243) // Light Blue
                "revised" -> Color.GREEN
                "scheduled" -> android.graphics.Color.rgb(255, 165, 0) // Orange
                "missed" -> Color.RED
                else -> Color.GRAY
            }
        }
        
        fun getEventTypeEmoji(type: String): String {
            return when (type) {
                "initiated", "learned" -> "🔵"
                "revised" -> "🟢"
                "scheduled" -> "🟠"
                "missed" -> "🔴"
                else -> "⚪"
            }
        }
    }
    
    private lateinit var todayButton: Button
    private lateinit var monthYearText: TextView
    private lateinit var calendarGrid: GridLayout
    private lateinit var eventsRecyclerView: RecyclerView
    private lateinit var emptyView: TextView
    
    private var currentCalendar = Calendar.getInstance()
    private var selectedDate = Calendar.getInstance()
    private var events = mutableMapOf<String, List<CalendarEvent>>()
    private lateinit var eventAdapter: CalendarEventAdapter
    private lateinit var gestureDetector: GestureDetector
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_calendar_view)
        
        initializeViews()
        loadEvents()
        setupListeners()
        updateCalendar()
        updateEventsList()
    }
    
    private fun initializeViews() {
        todayButton = findViewById(R.id.today_button)
        monthYearText = findViewById(R.id.month_year_text)
        calendarGrid = findViewById(R.id.calendar_grid)
        eventsRecyclerView = findViewById(R.id.events_recycler_view)
        emptyView = findViewById(R.id.empty_view)
        
        // Setup RecyclerView
        eventAdapter = CalendarEventAdapter(listOf(), this)
        eventsRecyclerView.layoutManager = LinearLayoutManager(this)
        eventsRecyclerView.adapter = eventAdapter
    }
    
    private fun setupListeners() {
        // Setup swipe gestures for month navigation
        gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onFling(
                e1: MotionEvent?,
                e2: MotionEvent,
                velocityX: Float,
                velocityY: Float
            ): Boolean {
                if (e1 == null) return false
                
                val diffX = e2.x - e1.x
                val diffY = e2.y - e1.y
                
                if (abs(diffX) > abs(diffY) && abs(diffX) > 100 && abs(velocityX) > 100) {
                    if (diffX > 0) {
                        // Swipe right - previous month
                        currentCalendar.add(Calendar.MONTH, -1)
                        updateCalendar()
                        updateEventsList()
                        return true
                    } else {
                        // Swipe left - next month
                        currentCalendar.add(Calendar.MONTH, 1)
                        updateCalendar()
                        updateEventsList()
                        return true
                    }
                }
                return false
            }
        })
        
        // Setup today button
        todayButton.setOnClickListener {
            val today = Calendar.getInstance()
            currentCalendar.set(today.get(Calendar.YEAR), today.get(Calendar.MONTH), today.get(Calendar.DAY_OF_MONTH))
            selectedDate.set(today.get(Calendar.YEAR), today.get(Calendar.MONTH), today.get(Calendar.DAY_OF_MONTH))
            updateCalendar()
            updateEventsList()
        }
    }
    
    override fun onTouchEvent(event: MotionEvent): Boolean {
        return if (gestureDetector.onTouchEvent(event)) {
            true
        } else {
            super.onTouchEvent(event)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Clear gesture detector to prevent memory leak
        gestureDetector.setOnDoubleTapListener(null)
    }
    
    private fun updateCalendar() {
        // Update month/year text
        val monthYearFormat = SimpleDateFormat("MMMM yyyy", Locale.getDefault())
        monthYearText.text = monthYearFormat.format(currentCalendar.time)
        
        // Get today's calendar for comparisons
        val today = Calendar.getInstance()
        
        // Update today button state
        val isCurrentMonth = (currentCalendar.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                              currentCalendar.get(Calendar.MONTH) == today.get(Calendar.MONTH))
        
        todayButton.isEnabled = !isCurrentMonth
        todayButton.alpha = if (isCurrentMonth) 0.5f else 1.0f
        
        // Clear existing day views
        calendarGrid.removeAllViews()
        
        // Add weekday headers (Mon-Sun)
        val weekdays = arrayOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
        for (weekday in weekdays) {
            val headerView = TextView(this).apply {
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
        val tempCalendar = currentCalendar.clone() as Calendar
        tempCalendar.set(Calendar.DAY_OF_MONTH, 1)
        
        val firstDayOfWeek = tempCalendar.get(Calendar.DAY_OF_WEEK)
        val daysInMonth = tempCalendar.getActualMaximum(Calendar.DAY_OF_MONTH)
        
        // Convert to Monday-first (0=Monday, 6=Sunday)
        val startPosition = if (firstDayOfWeek == Calendar.SUNDAY) 6 else firstDayOfWeek - 2
        
        // Create day views
        val totalCells = 42 // 6 rows * 7 days
        for (i in 0 until totalCells) {
            val layoutParams = GridLayout.LayoutParams()
            layoutParams.width = 0
            layoutParams.height = GridLayout.LayoutParams.WRAP_CONTENT
            layoutParams.columnSpec = GridLayout.spec(i % 7, 1f)
            layoutParams.rowSpec = GridLayout.spec((i / 7) + 1) // +1 to account for header row
            layoutParams.setMargins(4, 4, 4, 4)
            
            val dayNumber = i - startPosition + 1
            
            if (dayNumber in 1..daysInMonth) {
                // Check if this is today
                val isToday = (tempCalendar.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                        tempCalendar.get(Calendar.MONTH) == today.get(Calendar.MONTH) &&
                        dayNumber == today.get(Calendar.DAY_OF_MONTH))
                
                // Check if this is selected day
                val isSelected = (tempCalendar.get(Calendar.YEAR) == selectedDate.get(Calendar.YEAR) &&
                        tempCalendar.get(Calendar.MONTH) == selectedDate.get(Calendar.MONTH) &&
                        dayNumber == selectedDate.get(Calendar.DAY_OF_MONTH))
                
                // Get events for this day
                val dateKey = getDateKey(tempCalendar.get(Calendar.YEAR), 
                    tempCalendar.get(Calendar.MONTH), dayNumber)
                val dayEvents = events[dateKey]
                
                // Create day cell (with or without ring)
                val dayCellView = createDayCell(dayNumber, isToday, isSelected, dayEvents)
                dayCellView.layoutParams = layoutParams
                
                // Click listener
                dayCellView.setOnClickListener {
                    onDaySelected(tempCalendar.get(Calendar.YEAR), 
                        tempCalendar.get(Calendar.MONTH), dayNumber)
                }
                
                calendarGrid.addView(dayCellView)
            } else {
                // Empty cell
                val emptyView = TextView(this)
                emptyView.layoutParams = layoutParams
                emptyView.text = ""
                emptyView.isEnabled = false
                calendarGrid.addView(emptyView)
            }
        }
    }
    
    private data class EventSegment(val count: Int, val color: Int)
    
    private fun createDayCell(dayNumber: Int, isToday: Boolean, isSelected: Boolean, dayEvents: List<CalendarEvent>?): View {
        val density = resources.displayMetrics.density
        
        // Create simple TextView for day number
        val dayView = TextView(this).apply {
            text = dayNumber.toString()
            textSize = 16f
            gravity = android.view.Gravity.CENTER
            setPadding(8, 16, 8, 16)
            setTextColor(getColor(R.color.text))
            
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
                        val radius = (size / 2f) - (strokeWidth / 2f) - density // Increased radius more (was 2 * density)
                        
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
                            }
                            
                            canvas.drawArc(rectF, startAngle, sweepAngle, false, paint)
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
    

    
    private fun onDaySelected(year: Int, month: Int, day: Int) {
        selectedDate.set(year, month, day)
        updateCalendar()
        updateEventsList()
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
            val typeOrder = listOf("initiated", "revised", "scheduled", "missed")
            
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
                updateCalendar()
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
        
        // Parse dates_updated (revised)
        val datesUpdated = recordObject.optJSONArray("dates_updated")
        if (datesUpdated != null) {
            for (i in 0 until datesUpdated.length()) {
                try {
                    val dateStr = datesUpdated.getString(i)
                    val date = parseDate(dateStr)
                    if (date != null) {
                        addEventToMap(eventsMap, date, CalendarEvent(
                            type = "revised",
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
}

data class CalendarEvent(
    val type: String, // initiated, revised, scheduled, missed
    val category: String,
    val subCategory: String,
    val recordTitle: String,
    val description: String,
    val status: String,
    val entryType: String
)
