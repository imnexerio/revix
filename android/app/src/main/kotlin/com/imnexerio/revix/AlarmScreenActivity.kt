package com.imnexerio.revix

import android.animation.ValueAnimator
import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.graphics.drawable.GradientDrawable
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import java.util.Random
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.GestureDetector
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.sqrt

class AlarmScreenActivity : Activity(), SensorEventListener {    // Data class for shooting stars
    data class Star(
        var x: Float,
        var y: Float,
        var velocityX: Float,
        var velocityY: Float,
        var size: Float,
        var alpha: Float,
        var twinklePhase: Float,
        var trailLength: Int,
        var trailThickness: Float,
        var trail: MutableList<Pair<Float, Float>> = mutableListOf()
    )
    
    companion object {
        private const val TAG = "AlarmScreenActivity"
        const val EXTRA_CATEGORY = "category"
        const val EXTRA_SUB_CATEGORY = "sub_category"
        const val EXTRA_RECORD_TITLE = "record_title"
        const val ACTION_CLOSE_ALARM_SCREEN = "CLOSE_ALARM_SCREEN"
    }

    private var category: String = ""
    private var subCategory: String = ""
    private var recordTitle: String = ""
    private var reminderTime: String = ""
    private var entryType: String = ""
    private var scheduledDate: String = ""
    private var description: String = ""
    private var userActionTaken: Boolean = false // Track if user clicked a button
    
    // Sensor properties for device tilt detection
    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var deviceTiltX: Float = 0f // Device tilt in X direction (left/right)
    private var deviceTiltY: Float = 0f // Device tilt in Y direction (forward/back)
    private val tiltThreshold = 15f // Minimum tilt in degrees to trigger directional change
    
    // Brjoadcast receiver to listen for alarm service events
    private val alarmServiceReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            Log.d(TAG, "Broadcast received with action: ${intent?.action}")
            when (intent?.action) {
                ACTION_CLOSE_ALARM_SCREEN -> {
                    val receivedCategory = intent.getStringExtra(AlarmReceiver.EXTRA_CATEGORY) ?: ""
                    val receivedSubCategory = intent.getStringExtra(AlarmReceiver.EXTRA_SUB_CATEGORY) ?: ""
                    val receivedRecordTitle = intent.getStringExtra(AlarmReceiver.EXTRA_RECORD_TITLE) ?: ""
                    
                    Log.d(TAG, "Close alarm screen broadcast received for: $receivedRecordTitle, current alarm: $recordTitle")
                    
                    // Check if this broadcast is for this specific alarm
                    if (receivedCategory == category && receivedSubCategory == subCategory && receivedRecordTitle == recordTitle) {
                        Log.d(TAG, "Broadcast matches current alarm - closing activity for: $recordTitle")
                        userActionTaken = true // Mark as handled to prevent duplicate dismissal
                        finish()
                    } else {
                        Log.d(TAG, "Broadcast doesn't match current alarm - ignoring")
                    }
                }
                else -> {
                    Log.d(TAG, "Unknown broadcast action: ${intent?.action}")
                }
            }
        }
    }
      override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "AlarmScreenActivity onCreate() called")
        
        // Check if this is a close activity intent
        if (intent?.action == "CLOSE_ALARM_ACTIVITY") {
            Log.d(TAG, "Received close activity intent - finishing immediately")
            finish()
            return
        }
          // Extract alarm details from intent
        category = intent.getStringExtra(EXTRA_CATEGORY) ?: ""
        subCategory = intent.getStringExtra(EXTRA_SUB_CATEGORY) ?: ""
        recordTitle = intent.getStringExtra(EXTRA_RECORD_TITLE) ?: ""
        reminderTime = intent.getStringExtra("reminder_time") ?: ""
        entryType = intent.getStringExtra("entry_type") ?: ""
        scheduledDate = intent.getStringExtra("scheduled_date") ?: ""
        description = intent.getStringExtra("description") ?: ""
        
        // Initialize sensor for device tilt detection
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        
        // Set up full screen over lock screen
        setupFullScreenOverLockScreen()
        
        // Create and set content view
        createAlarmUI()
        
        Log.d(TAG, "AlarmScreenActivity setup complete for: $recordTitle")
    }private fun setupFullScreenOverLockScreen() {
        Log.d(TAG, "Setting up full screen over lock screen")
        
        // Critical flags for showing over lock screen regardless of notification settings
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            Log.d(TAG, "Using modern Android (O_MR1+) lock screen flags")
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            // Request to dismiss keyguard (lock screen)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            Log.d(TAG, "Using legacy Android lock screen flags")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        
        // Essential flags for alarm apps to show over everything
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
        )        // Set window type for system alert (shows over lock screen)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // For Android 8.0+, check overlay permission
                if (Settings.canDrawOverlays(this)) {
                    Log.d(TAG, "Setting window type to TYPE_APPLICATION_OVERLAY")
                    window.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
                } else {
                    Log.w(TAG, "SYSTEM_ALERT_WINDOW permission not granted, using fallback method")
                    // Don't set special window type, rely on activity flags
                }
            } else {
                // For older versions, use TYPE_SYSTEM_ALERT
                Log.d(TAG, "Setting window type to TYPE_SYSTEM_ALERT (legacy)")
                @Suppress("DEPRECATION")
                window.setType(WindowManager.LayoutParams.TYPE_SYSTEM_ALERT)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set window type", e)
        }
        
        // Full screen and immersive flags
        window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        
        // Make sure it appears on top of everything
        window.addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL)
        window.addFlags(WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH)
        
        // Hide system UI for immersive full screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )
        }    }    private fun createAlarmUI() {
        val dpToPx = { dp: Int ->
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp.toFloat(), resources.displayMetrics).toInt()
        }

        // Get colors from resources
        val backgroundColor = ContextCompat.getColor(this, R.color.WidgetBackground)
        val textColor = ContextCompat.getColor(this, R.color.text)
        
        // Get dynamic accent color based on entry_type, fallback to default if empty
        val accentColor = if (entryType.isNotEmpty()) {
            LectureColors.getLectureTypeColorSync(this, entryType)
        } else {
            ContextCompat.getColor(this, R.color.colorOnPrimary)
        }

        // Main container - FrameLayout for layering
        val mainLayout = FrameLayout(this).apply {
            setBackgroundColor(backgroundColor)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        
        // First layer: Animated falling stars background
        val starsBackground = createFallingStarsBackground(textColor, dpToPx)
        
        // Second layer: Gradient background starting from button position
        val gradientLayer = createGradientBackground(accentColor, dpToPx)

        // Third layer: Glassmorphism content overlay
        val contentOverlay = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(20), dpToPx(40), dpToPx(20), dpToPx(40))
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        
        // Top spacer for better positioning
        val topSpacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                0.1f
            )
        }

        // Time and Date Glass Card
        val timeCard = createGlassCard(dpToPx, accentColor).apply {
            val cardContent = LinearLayout(this@AlarmScreenActivity).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dpToPx(24), dpToPx(20), dpToPx(24), dpToPx(20))
                
                // Time text
                val timeText = TextView(this@AlarmScreenActivity).apply {
                    text = reminderTime
                    textSize = 32f
                    setTextColor(textColor)
                    gravity = Gravity.CENTER
                    setTypeface(null, android.graphics.Typeface.BOLD)
                    layoutParams = LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                    ).apply {
                        setMargins(0, 0, 0, dpToPx(8))
                    }
                }
                
                // Date text
                val dateText = TextView(this@AlarmScreenActivity).apply {
                    text = scheduledDate
                    textSize = 18f
                    setTextColor(textColor)
                    gravity = Gravity.CENTER
                    alpha = 0.8f
                    layoutParams = LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                    )
                }
                
                addView(timeText)
                addView(dateText)
            }
            
            addView(cardContent)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(24))
            }
        }
        
        // Information Glass Card
        val infoCard = createGlassCard(dpToPx, accentColor).apply {
            val cardContent = LinearLayout(this@AlarmScreenActivity).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dpToPx(24), dpToPx(20), dpToPx(24), dpToPx(20))
                
                // Category text
                val categoryText = TextView(this@AlarmScreenActivity).apply {
                    text = "Category : $category"
                    textSize = 16f
                    setTextColor(textColor)
                    gravity = Gravity.START  // Left aligned
                    maxLines = 1  // Single line
                    ellipsize = android.text.TextUtils.TruncateAt.END  // Truncate with "..."
                    layoutParams = LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                    ).apply {
                        setMargins(0, 0, 0, dpToPx(8))
                    }
                }
                
                // Sub-category text
                val subCategoryText = TextView(this@AlarmScreenActivity).apply {
                    text = "Sub Category : $subCategory"
                    textSize = 16f
                    setTextColor(textColor)
                    gravity = Gravity.START  // Left aligned
                    maxLines = 1  // Single line
                    ellipsize = android.text.TextUtils.TruncateAt.END  // Truncate with "..."
                    layoutParams = LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                    ).apply {
                        setMargins(0, 0, 0, dpToPx(8))
                    }
                }
                
                // Record title text
                val recordTitleText = TextView(this@AlarmScreenActivity).apply {
                    text = "Title : $recordTitle"
                    textSize = 16f  // Same as category and subcategory
                    setTextColor(textColor)
                    gravity = Gravity.START  // Left aligned
                    maxLines = 1  // Single line
                    ellipsize = android.text.TextUtils.TruncateAt.END  // Truncate with "..."
                    layoutParams = LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                    ).apply {
                        setMargins(0, 0, 0, dpToPx(12))
                    }
                }
                
                // Description text with proper 4-line truncation
                val descriptionText = TextView(this@AlarmScreenActivity).apply {
                    val displayDescription = if (description.isNotEmpty()) {
                        description
                    } else {
                        "No description available"
                    }
                    text = "Description : $displayDescription"
                    textSize = 16f  // Increased from 14f
                    setTextColor(textColor)
                    gravity = Gravity.START  // Left aligned
                    // Removed alpha for better visibility
                    maxLines = 4  // Show maximum 4 lines
                    ellipsize = android.text.TextUtils.TruncateAt.END  // Auto truncate with "..."
                    layoutParams = LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                    )
                }
                
                addView(categoryText)
                addView(subCategoryText)
                addView(recordTitleText)
                addView(descriptionText)
            }
            
            addView(cardContent)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(32))
            }
        }        
        // Flexible spacer
        val flexSpacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }

        // Call-style button layout similar to the UI image (adapted for schedule tracker)
        val scheduleButtonsLayout = createScheduleStyleButtonsLayout(
            accentColor = accentColor,
            textColor = textColor,
            dpToPx = dpToPx
        )

        val ignoreButton = createIgnoreButton(
            accentColor = accentColor,
            textColor = textColor,
            dpToPx = dpToPx
        ) {
            ignoreAlarm()
        }

        // Assemble the glassmorphism layout
        contentOverlay.addView(topSpacer)
        contentOverlay.addView(timeCard)
        contentOverlay.addView(infoCard)
        contentOverlay.addView(flexSpacer)
        contentOverlay.addView(ignoreButton)
        contentOverlay.addView(scheduleButtonsLayout)

        // Layer the components: stars background, gradient, content overlay
        mainLayout.addView(starsBackground)
        mainLayout.addView(gradientLayer)
        mainLayout.addView(contentOverlay)
        
        setContentView(mainLayout)
    }

    // Create glassmorphism card with clear readable content
    private fun createGlassCard(dpToPx: (Int) -> Int, accentColor: Int): FrameLayout {
        return FrameLayout(this).apply {
            // Create glass background with NO blur effect on content
            val glassBackground = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(16).toFloat()
                
                // Semi-transparent white with slight accent tint for glassmorphism
                val glassAlpha = 35 // Slightly more opaque for better readability
                
                // Blend white with slight accent color
                val glassColor = Color.argb(
                    glassAlpha,
                    (Color.red(accentColor) * 0.1f + 255 * 0.9f).toInt(),
                    (Color.green(accentColor) * 0.1f + 255 * 0.9f).toInt(),
                    (Color.blue(accentColor) * 0.1f + 255 * 0.9f).toInt()
                )
                setColor(glassColor)
                
                // Subtle border for glass effect
                setStroke(dpToPx(1), Color.argb(60, 255, 255, 255))
            }
            
            background = glassBackground
            
            // Add subtle shadow effect
            elevation = dpToPx(8).toFloat()
            
            // NO blur effect on cards - content stays perfectly readable
        }
    }

    // Create glassmorphism swipe button
    private fun createGlassSwipeButton(
        text: String,
        accentColor: Int,
        textColor: Int,
        dpToPx: (Int) -> Int,
        onSwipe: (String) -> Unit
    ): View {
        // Container for button and animated glow ring
        val container = FrameLayout(this).apply {
            val containerSize = dpToPx(200)
            layoutParams = LinearLayout.LayoutParams(containerSize, containerSize).apply {
                gravity = Gravity.CENTER
                setMargins(0, 0, 0, dpToPx(16))
            }
        }

        // Animated ripple ring view (same as before but with glass effect)
        val glowRing = object : View(this) {
            private var rippleProgress = 0f
            private val glowPaint = Paint().apply {
                isAntiAlias = true
                style = Paint.Style.STROKE
                strokeWidth = dpToPx(3).toFloat()
            }
            
            override fun onDraw(canvas: Canvas) {
                super.onDraw(canvas)
                
                val centerX = width / 2f
                val centerY = height / 2f
                val buttonRadius = dpToPx(60).toFloat()
                val maxRippleRadius = dpToPx(100).toFloat()
                val currentRadius = buttonRadius + (rippleProgress * (maxRippleRadius - buttonRadius))
                val alpha = ((1f - rippleProgress) * 120).toInt().coerceIn(0, 120) // More subtle
                
                // Glass-like ripple with accent color
                glowPaint.color = Color.argb(alpha, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor))
                
                if (rippleProgress > 0f) {
                    canvas.drawCircle(centerX, centerY, currentRadius, glowPaint)
                }
            }
            
            fun setRippleProgress(progress: Float) {
                rippleProgress = progress
                invalidate()
            }
        }.apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        // Glass button
        val button = TextView(this).apply {
            this.text = text
            textSize = 14f
            setTextColor(textColor)
            gravity = Gravity.CENTER
            setTypeface(null, android.graphics.Typeface.BOLD)
            
            // Create glass circular background
            val glassBackground = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                
                // Glass effect with accent color tint
                val glassColor = Color.argb(
                    40, // More opacity for button
                    (Color.red(accentColor) * 0.3f + 255 * 0.7f).toInt(),
                    (Color.green(accentColor) * 0.3f + 255 * 0.7f).toInt(),
                    (Color.blue(accentColor) * 0.3f + 255 * 0.7f).toInt()
                )
                setColor(glassColor)
                setStroke(dpToPx(2), Color.argb(60, 255, 255, 255))
            }
            background = glassBackground
            
            val buttonSize = dpToPx(120)
            layoutParams = FrameLayout.LayoutParams(buttonSize, buttonSize).apply {
                gravity = Gravity.CENTER
            }
            
            // NO blur effect on button text - keep "SWIPE TO MARK DONE" readable
            
            // Keep all the existing touch and swipe functionality
            var isPressed = false
            var glowAnimator: ValueAnimator? = null
            
            fun startGlowAnimation() {
                glowAnimator?.cancel()
                glowAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
                    duration = 1500
                    repeatCount = ValueAnimator.INFINITE
                    repeatMode = ValueAnimator.RESTART
                    
                    addUpdateListener { animator ->
                        if (!isPressed) {
                            val progress = animator.animatedValue as Float
                            glowRing.setRippleProgress(progress)
                        }
                    }
                    start()
                }
            }
            
            fun stopGlowAnimation() {
                glowAnimator?.cancel()
                glowRing.setRippleProgress(0f)
            }
            
            post { startGlowAnimation() }
            
            val gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
                private val MIN_SWIPE_DISTANCE = dpToPx(100)
                
                override fun onFling(
                    e1: MotionEvent?,
                    e2: MotionEvent,
                    velocityX: Float,
                    velocityY: Float
                ): Boolean {
                    if (e1 == null) return false
                    
                    val diffX = e2.x - e1.x
                    val diffY = e2.y - e1.y
                    val distance = sqrt(diffX * diffX + diffY * diffY)
                    
                    if (distance >= MIN_SWIPE_DISTANCE) {
                        // Determine swipe direction based on horizontal movement
                        val direction = if (abs(diffX) > abs(diffY)) {
                            if (diffX > 0) "RIGHT" else "LEFT"
                        } else {
                            "RIGHT" // Default to right for vertical swipes
                        }
                        
                        Log.d(TAG, "Swipe completed - distance: $distance, direction: $direction")
                        
                        animate()
                            .scaleX(1.2f)
                            .scaleY(1.2f)
                            .setDuration(150)
                            .withEndAction {
                                onSwipe(direction)
                            }
                        return true
                    }
                    return false
                }
                
                override fun onDown(e: MotionEvent): Boolean {
                    return true
                }
            })
            
            setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        isPressed = true
                        stopGlowAnimation()
                        animate()
                            .scaleX(1.1f)
                            .scaleY(1.1f)
                            .alpha(0.9f)
                            .setDuration(200)
                            .start()
                    }
                    
                    MotionEvent.ACTION_MOVE -> {
                        if (isPressed) {
                            val diffX = event.x - (width / 2f)
                            val diffY = event.y - (height / 2f)
                            val distance = sqrt(diffX * diffX + diffY * diffY)
                            val progress = (distance / dpToPx(100)).coerceIn(0f, 1f)
                            
                            val progressAlpha = 0.9f + (progress * 0.1f)
                            val progressScale = 1.1f + (progress * 0.2f)
                            
                            alpha = progressAlpha
                            scaleX = progressScale
                            scaleY = progressScale
                            
                            if (progress > 0.7f) {
                                setTextColor(Color.WHITE)
                            } else {
                                setTextColor(textColor)
                            }
                        }
                    }
                    
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        isPressed = false
                        
                        animate()
                            .alpha(1.0f)
                            .scaleX(1.0f)
                            .scaleY(1.0f)
                            .setDuration(300)
                            .withEndAction {
                                startGlowAnimation()
                            }
                            .start()
                        
                        setTextColor(textColor)
                    }
                }
                gestureDetector.onTouchEvent(event)
            }
        }
        
        container.addView(glowRing)
        container.addView(button)
        
        return container
    }

    // Create schedule-style button layout similar to the UI image (adapted for schedule tracker)
    private fun createScheduleStyleButtonsLayout(
        accentColor: Int,
        textColor: Int,
        dpToPx: (Int) -> Int
    ): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(dpToPx(30), dpToPx(32), dpToPx(30), dpToPx(24))
            }

            // Simplified curved container with screen-adaptive sizing
            val slideContainer = FrameLayout(this@AlarmScreenActivity).apply {
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dpToPx(kotlin.math.max(70, (resources.displayMetrics.heightPixels * 0.035f).toInt())) // Reduced: min 70dp or 5% of screen height
                )
                
                // Simple curved background with less rounding
                val containerHeight = dpToPx(kotlin.math.max(70, (resources.displayMetrics.heightPixels * 0.04f).toInt()))
                val background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = (containerHeight / 2.0).toFloat() // Less rounded - third instead of half for softer curves
                    setColor(Color.argb(50, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)))
                    setStroke(dpToPx(2), Color.argb(100, 255, 255, 255))
                }
                setBackground(background)
                elevation = dpToPx(12).toFloat()
                
                // Left hint (Skip)
                val leftHint = TextView(this@AlarmScreenActivity).apply {
                    text = "Skip"
                    textSize = 14f
                    setTextColor(textColor) // Use textColor instead of custom color
                    gravity = Gravity.CENTER
                    layoutParams = FrameLayout.LayoutParams(
                        dpToPx(80),
                        FrameLayout.LayoutParams.MATCH_PARENT
                    ).apply {
                        gravity = Gravity.CENTER_VERTICAL or Gravity.START
                        setMargins(dpToPx(20), 0, 0, 0)
                    }
                }
                
                // Right hint (Done)
                val rightHint = TextView(this@AlarmScreenActivity).apply {
                    text = "Done"
                    textSize = 14f
                    setTextColor(textColor) // Use textColor instead of custom color
                    gravity = Gravity.CENTER
                    layoutParams = FrameLayout.LayoutParams(
                        dpToPx(80),
                        FrameLayout.LayoutParams.MATCH_PARENT
                    ).apply {
                        gravity = Gravity.CENTER_VERTICAL or Gravity.END
                        setMargins(0, 0, dpToPx(20), 0)
                    }
                }
                
                // Simple oval button with adaptive sizing
                val slideButton = View(this@AlarmScreenActivity).apply {
                    // Calculate adaptive button size based on container (increased height)
                    val containerHeight = kotlin.math.max(70, (resources.displayMetrics.heightPixels * 0.04f).toInt())
                    val buttonHeight = (containerHeight * 0.65f).toInt() // Increased to 75% of container height
                    val buttonWidth = (buttonHeight * 1.2f).toInt() // Reduced width ratio from 2.0x to 1.5x
                    
                    layoutParams = FrameLayout.LayoutParams(
                        dpToPx(buttonWidth),
                        dpToPx(buttonHeight)
                    ).apply {
                        gravity = Gravity.CENTER
                    }
                    
                    // Pre-create reusable backgrounds with better rounding (dynamic)
                    val buttonCornerRadius = (dpToPx(buttonHeight) / 2.0f).toFloat() // Better rounding - between quarter and half
                    
                    val originalBackground = GradientDrawable().apply {
                        shape = GradientDrawable.RECTANGLE
                        cornerRadius = buttonCornerRadius
                        setColor(accentColor)
                        setStroke(dpToPx(2), Color.argb(150, 255, 255, 255))
                    }
                    
                    val redBackground = GradientDrawable().apply {
                        shape = GradientDrawable.RECTANGLE
                        cornerRadius = buttonCornerRadius
                        setColor(Color.argb(255, 244, 67, 54))
                        setStroke(dpToPx(2), Color.argb(150, 255, 255, 255))
                    }
                    
                    val greenBackground = GradientDrawable().apply {
                        shape = GradientDrawable.RECTANGLE
                        cornerRadius = buttonCornerRadius
                        setColor(Color.argb(255, 76, 175, 80))
                        setStroke(dpToPx(2), Color.argb(150, 255, 255, 255))
                    }
                    
                    setBackground(originalBackground)
                    elevation = dpToPx(8).toFloat()
                    
                    // Simple sliding logic
                    var startX = 0f
                    var isSliding = false
                    var currentBackground = originalBackground
                    val slideThreshold = dpToPx(80).toFloat()
                    val maxSlide = dpToPx(100).toFloat()
                    
                    setOnTouchListener { view, event ->
                        when (event.action) {
                            MotionEvent.ACTION_DOWN -> {
                                startX = event.rawX
                                isSliding = true
                                animate().scaleX(0.95f).scaleY(0.95f).setDuration(150).start()
                                true
                            }
                            
                            MotionEvent.ACTION_MOVE -> {
                                if (isSliding) {
                                    val deltaX = event.rawX - startX
                                    val constrainedDelta = deltaX.coerceIn(-maxSlide, maxSlide)
                                    translationX = constrainedDelta
                                    
                                    // Calculate intensity and update existing background color
                                    val slideProgress = kotlin.math.abs(constrainedDelta) / maxSlide
                                    val intensity = (50 + slideProgress * 205).toInt().coerceIn(50, 255)
                                    
                                    // Efficiently update color without creating new objects
                                    when {
                                        constrainedDelta < -slideThreshold * 0.3f -> {
                                            if (currentBackground != redBackground) {
                                                currentBackground = redBackground
                                                setBackground(redBackground)
                                            }
                                            // Update alpha for intensity
                                            redBackground.alpha = intensity
                                            leftHint.animate().alpha(1.0f).setDuration(100).start()
                                            rightHint.animate().alpha(0.3f).setDuration(100).start()
                                        }
                                        constrainedDelta > slideThreshold * 0.3f -> {
                                            if (currentBackground != greenBackground) {
                                                currentBackground = greenBackground
                                                setBackground(greenBackground)
                                            }
                                            // Update alpha for intensity
                                            greenBackground.alpha = intensity
                                            rightHint.animate().alpha(1.0f).setDuration(100).start()
                                            leftHint.animate().alpha(0.3f).setDuration(100).start()
                                        }
                                        else -> {
                                            if (currentBackground != originalBackground) {
                                                currentBackground = originalBackground
                                                setBackground(originalBackground)
                                            }
                                            leftHint.animate().alpha(0.6f).setDuration(100).start()
                                            rightHint.animate().alpha(0.6f).setDuration(100).start()
                                        }
                                    }
                                }
                                true
                            }
                            
                            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                                if (isSliding) {
                                    val deltaX = event.rawX - startX
                                    
                                    if (kotlin.math.abs(deltaX) >= slideThreshold) {
                                        // Action triggered - keep the intense color
                                        if (deltaX < 0) {
                                            skipAlarm()
                                        } else {
                                            markAsDone()
                                        }
                                    } else {
                                        // Return to center - restore original color
                                        animate()
                                            .translationX(0f)
                                            .scaleX(1.0f)
                                            .scaleY(1.0f)
                                            .setDuration(300)
                                            .start()
                                        
                                        // Reset to original background efficiently
                                        if (currentBackground != originalBackground) {
                                            currentBackground = originalBackground
                                            setBackground(originalBackground)
                                        }
                                        
                                        leftHint.animate().alpha(0.6f).setDuration(200).start()
                                        rightHint.animate().alpha(0.6f).setDuration(200).start()
                                    }
                                    isSliding = false
                                }
                                true
                            }
                            
                            else -> false
                        }
                    }
                }
                
                addView(leftHint)
                addView(rightHint)
                addView(slideButton)
            }

            addView(slideContainer)
        }
    }

    // Create individual schedule-style button
    private fun createScheduleButton(
        text: String,
        backgroundColor: Int,
        textColor: Int,
        iconType: String,
        dpToPx: (Int) -> Int,
        onClick: () -> Unit
    ): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                dpToPx(120),
                dpToPx(120)
            )

            // Button icon
            val iconButton = TextView(this@AlarmScreenActivity).apply {
                setText(when (iconType) {
                    "skip" -> "" // Removed skip emoji
                    "done" -> "" // Removed done emoji  
                    else -> "●"
                })
                textSize = 28f
                gravity = Gravity.CENTER
                setTextColor(textColor)
                
                // Circular glass background
                val buttonBackground = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(backgroundColor)
                    setStroke(dpToPx(2), Color.argb(100, 255, 255, 255))
                }
                background = buttonBackground
                
                val buttonSize = dpToPx(80)
                layoutParams = LinearLayout.LayoutParams(buttonSize, buttonSize).apply {
                    setMargins(0, 0, 0, dpToPx(8))
                }
                
                elevation = dpToPx(6).toFloat()
                
                // Touch feedback
                setOnClickListener {
                    // Scale animation on click
                    animate()
                        .scaleX(1.2f)
                        .scaleY(1.2f)
                        .setDuration(150)
                        .withEndAction {
                            animate()
                                .scaleX(1.0f)
                                .scaleY(1.0f)
                                .setDuration(150)
                                .withEndAction {
                                    onClick()
                                }
                                .start()
                        }
                        .start()
                }
                
                // Touch state feedback
                setOnTouchListener { _, event ->
                    when (event.action) {
                        MotionEvent.ACTION_DOWN -> {
                            animate()
                                .scaleX(0.95f)
                                .scaleY(0.95f)
                                .alpha(0.8f)
                                .setDuration(100)
                                .start()
                        }
                        MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                            animate()
                                .scaleX(1.0f)
                                .scaleY(1.0f)
                                .alpha(1.0f)
                                .setDuration(100)
                                .start()
                        }
                    }
                    false // Let click listener handle the actual click
                }
            }

            // Button label
            val labelText = TextView(this@AlarmScreenActivity).apply {
                setText(text)
                textSize = 14f
                setTextColor(textColor)
                gravity = Gravity.CENTER
                setTypeface(null, android.graphics.Typeface.BOLD)
                alpha = 0.9f
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )
            }

            addView(iconButton)
            addView(labelText)
        }
    }

    private fun createIgnoreButton(
        accentColor: Int,
        textColor: Int,
        dpToPx: (Int) -> Int,
        onClick: () -> Unit
    ): Button {
        return Button(this).apply {
            text = "✖ Ignore"
            textSize = 12f // Smaller text
            setTypeface(null, android.graphics.Typeface.NORMAL)
            isAllCaps = false
            setTextColor(Color.argb(180, Color.red(textColor), Color.green(textColor), Color.blue(textColor))) // Slightly faded

            val cuteBackground = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(20).toFloat()
                
                // Soft translucent background
                setColor(Color.argb(30, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)))
                setStroke(dpToPx(1), Color.argb(80, 255, 255, 255))
            }
            
            background = cuteBackground
            
            // Small padding for compact size
            setPadding(dpToPx(16), dpToPx(8), dpToPx(16), dpToPx(8))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, // Wrap content for small size
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                setMargins(0, dpToPx(8), 0, dpToPx(12)) // Small margins
            }
            
            setOnClickListener { onClick() }
            
            // Subtle touch feedback
            foreground = ContextCompat.getDrawable(context, android.R.drawable.list_selector_background)
        }
    }


    private fun createGradientBackground(
        accentColor: Int,
        dpToPx: (Int) -> Int
    ): View {
        return object : View(this) {
            private var glowIntensity = 0.6f
            
            private val gradientPaint = Paint().apply {
                isAntiAlias = true
            }
            
            override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
                super.onSizeChanged(w, h, oldw, oldh)
                updateGradient()
            }
            
            private fun updateGradient() {
                // Button will be positioned in the center-bottom area
                val centerX = width / 2f
                val centerY = height * 0.7f // Position where button will be
                
                // Create gradient radiating from button position
                val maxRadius = kotlin.math.max(
                    kotlin.math.sqrt((centerX * centerX + centerY * centerY).toDouble()),
                    kotlin.math.sqrt(((width - centerX) * (width - centerX) + (height - centerY) * (height - centerY)).toDouble())
                ).toFloat()
                
                val centerAlpha = (glowIntensity * 100).toInt().coerceIn(0, 255)
                val midAlpha = (glowIntensity * 60).toInt().coerceIn(0, 255)
                val edgeAlpha = (glowIntensity * 20).toInt().coerceIn(0, 255)
                
                gradientPaint.shader = RadialGradient(
                    centerX, centerY, maxRadius,
                    intArrayOf(
                        Color.argb(centerAlpha, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)),
                        Color.argb(midAlpha, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)),
                        Color.argb(edgeAlpha, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)),
                        Color.TRANSPARENT
                    ),
                    floatArrayOf(0f, 0.4f, 0.8f, 1f),
                    Shader.TileMode.CLAMP
                )
            }
            
            override fun onDraw(canvas: Canvas) {
                super.onDraw(canvas)
                updateGradient()
                
                // Button position
                val centerX = width / 2f
                val centerY = height * 0.7f
                
                val maxRadius = kotlin.math.max(
                    kotlin.math.sqrt((centerX * centerX + centerY * centerY).toDouble()),
                    kotlin.math.sqrt(((width - centerX) * (width - centerX) + (height - centerY) * (height - centerY)).toDouble())
                ).toFloat()
                
                // Draw gradient starting from button position
                canvas.drawCircle(centerX, centerY, maxRadius, gradientPaint)
            }
            
            fun updateIntensity(intensity: Float) {
                glowIntensity = intensity
                invalidate()
            }
        }.apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )        }
    }

    private fun createFallingStarsBackground(
        textColor: Int,
        dpToPx: (Int) -> Int
    ): View {
        return object : View(this) {
            private val stars = mutableListOf<Star>()
            private val random = Random()            // Pre-calculate warm color once for better performance
            private val warmStarColor = blendWithWarmColor(textColor)
            
            private val starPaint = Paint().apply {
                isAntiAlias = true
                color = warmStarColor
            }
            private val trailPaint = Paint().apply {
                isAntiAlias = true
                color = warmStarColor
                strokeCap = Paint.Cap.ROUND
                // strokeWidth will be set dynamically per star
                 }
            
            // Helper function to blend textColor with warm orange/yellow tint
            private fun blendWithWarmColor(baseColor: Int): Int {
                val baseRed = Color.red(baseColor)
                val baseGreen = Color.green(baseColor)
                val baseBlue = Color.blue(baseColor)
                val baseAlpha = Color.alpha(baseColor)
                
                // Add warm orange/yellow tint (increase red and green, reduce blue slightly)
                val warmRed = minOf(255, (baseRed * 1.1f + 40).toInt())      // Boost red
                val warmGreen = minOf(255, (baseGreen * 1.05f + 25).toInt()) // Slight green boost
                val warmBlue = maxOf(0, (baseBlue * 0.8f).toInt())           // Reduce blue for warmth
                
                return Color.argb(baseAlpha, warmRed, warmGreen, warmBlue)
            }
            
            private val minStars = 1 // Minimum stars on screen
            private val maxStars = 6 // Maximum stars on screen
            private var lastTime = System.currentTimeMillis()
            
            private fun initializeStars() {
                stars.clear()
                // Create random number of stars between 1-6 at initialization
                val initialStarCount = minStars + random.nextInt(maxStars - minStars + 1)
                repeat(initialStarCount) {
                    createNewStar()
                }
            }
            private fun createNewStar(): Star {
                // Get dynamic angle range based on device tilt
                val angleRange = getStarAngleRange()
                val minAngle = angleRange.first
                val maxAngle = angleRange.second
                val angleDifference = maxAngle - minAngle
                val randomAngle = minAngle + random.nextFloat() * angleDifference
                val angle = Math.toRadians(randomAngle.toDouble())
                
                // Random speed properties
                val minSpeed = dpToPx(30).toFloat()  // Minimum speed
                val maxSpeed = dpToPx(100).toFloat()  // Maximum speed
                val randomSpeed = minSpeed + random.nextFloat() * (maxSpeed - minSpeed)
                
                // Random trail properties
                val minTrailLength = 8
                val maxTrailLength = 18
                val randomTrailLength = minTrailLength + (random.nextFloat() * (maxTrailLength - minTrailLength)).toInt()
                
                val minTrailThickness = dpToPx(1).toFloat()
                val maxTrailThickness = dpToPx(4).toFloat()
                val randomTrailThickness = minTrailThickness + random.nextFloat() * (maxTrailThickness - minTrailThickness)
                  val star = Star(
                    x = random.nextFloat() * width, // Start anywhere across the top
                    y = -dpToPx(50).toFloat(), // Start above screen
                    velocityX = (Math.sin(angle) * randomSpeed).toFloat(), // Horizontal component (left/right)
                    velocityY = (Math.cos(angle) * randomSpeed).toFloat(), // Vertical component (down)
                    size = dpToPx(2).toFloat() + random.nextFloat() * dpToPx(4), // Star size: min 2dp + random 0-4dp = 2-6dp total
                    alpha = 0.6f + random.nextFloat() * 0.4f, // More visible
                    twinklePhase = random.nextFloat() * 2f * Math.PI.toFloat(),
                    trailLength = randomTrailLength, // Random trail length: 6-18 points
                    trailThickness = randomTrailThickness // Random trail thickness: 1-4dp
                )
                stars.add(star)
                return star
            }
            
            override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
                super.onSizeChanged(w, h, oldw, oldh)
                if (w > 0 && h > 0) {
                    initializeStars()
                }
            }
            
            override fun onDraw(canvas: Canvas) {
                super.onDraw(canvas)
                
                val currentTime = System.currentTimeMillis()
                val deltaTime = (currentTime - lastTime) / 1000f // Convert to seconds
                lastTime = currentTime
                
                updateStars(deltaTime)
                drawStars(canvas)
                
                // Continue animation
                invalidate()
            }
            
            private fun updateStars(deltaTime: Float) {
                val starsToRemove = mutableListOf<Star>()
                
                stars.forEach { star ->
                    // Update position with velocity
                    star.x += star.velocityX * deltaTime
                    star.y += star.velocityY * deltaTime
                    
                    // Update twinkle phase
                    star.twinklePhase += deltaTime * 3f                    // Add to trail with more frequent updates
                    star.trail.add(Pair(star.x, star.y))
                    if (star.trail.size > star.trailLength) { // Use individual star's trail length
                        star.trail.removeAt(0)
                    }
                    
                    // Remove star when it goes off screen
                    if (star.y > height + dpToPx(100) || star.x < -dpToPx(100) || star.x > width + dpToPx(100)) {
                        starsToRemove.add(star)
                    }
                }
                  // Remove off-screen stars and create new ones
                starsToRemove.forEach { stars.remove(it) }
                
                // Smart star replacement logic
                if (starsToRemove.isNotEmpty()) {
                    // Calculate how many new stars to create (1-6 random, but don't exceed maxStars)
                    val randomNewStars = minStars + random.nextInt(maxStars - minStars + 1)
                    val availableSlots = maxStars - stars.size
                    val starsToCreate = minOf(randomNewStars, availableSlots)
                    
                    repeat(starsToCreate) {
                        createNewStar()
                    }
                }
                
                // Ensure minimum star count (safety check)
                if (stars.size < minStars) {
                    repeat(minStars - stars.size) {
                        createNewStar()
                    }
                }
            }
            
            private fun drawStars(canvas: Canvas) {
                stars.forEach { star ->
                    // Calculate twinkling alpha
                    val twinkleAlpha = star.alpha + (Math.sin(star.twinklePhase.toDouble()) * 0.3f).toFloat()
                    val clampedAlpha = twinkleAlpha.coerceIn(0.2f, 1.0f)                    // Draw bright trail (brightest at head, fading towards tail)
                    if (star.trail.size > 1) {
                        // Set the trail thickness for this specific star
                        trailPaint.strokeWidth = star.trailThickness
                        
                        for (i in 0 until star.trail.size - 1) {
                            // Trail alpha: brightest at newest position (end of trail array), fading towards oldest (start of array)
                            val trailProgress = i.toFloat() / (star.trail.size - 1)
                            val trailAlpha = clampedAlpha * trailProgress * 0.7f // Start dim (old positions), get brighter towards current position
                            trailPaint.alpha = (trailAlpha * 255).toInt()
                            
                            val currentPos = star.trail[i]
                            val nextPos = star.trail[i + 1]
                            
                            // Draw trail lines with individual star's thickness
                            canvas.drawLine(
                                currentPos.first, currentPos.second,
                                nextPos.first, nextPos.second,
                                trailPaint
                            )
                        }
                    }
                    
                    // Draw main star (brighter and larger)
                    starPaint.alpha = (clampedAlpha * 255).toInt()
                    canvas.drawCircle(star.x, star.y, star.size, starPaint)
                    
                    // Draw bright cross sparkle for all stars
                    val sparkleAlpha = clampedAlpha * 0.8f
                    starPaint.alpha = (sparkleAlpha * 255).toInt()
                    
                    // Horizontal line
                    canvas.drawLine(
                        star.x - star.size * 2f, star.y,
                        star.x + star.size * 2f, star.y,
                        starPaint
                    )
                    
                    // Vertical line
                    canvas.drawLine(
                        star.x, star.y - star.size * 2f,
                        star.x, star.y + star.size * 2f,
                        starPaint
                    )
                    
                    // Diagonal lines for extra sparkle
                    canvas.drawLine(
                        star.x - star.size * 1.4f, star.y - star.size * 1.4f,
                        star.x + star.size * 1.4f, star.y + star.size * 1.4f,
                        starPaint
                    )
                    
                    canvas.drawLine(
                        star.x - star.size * 1.4f, star.y + star.size * 1.4f,
                        star.x + star.size * 1.4f, star.y - star.size * 1.4f,
                        starPaint
                    )
                }
            }
        }.apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
    }

    private fun markAsDone() {
        Log.d(TAG, "Mark as done clicked for: $recordTitle")
        
        userActionTaken = true // User clicked a button
        
        // Send broadcast to mark alarm as done
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_MARK_AS_DONE
            putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
        }
        sendBroadcast(intent)
        
        finish()
    }

    private fun skipAlarm() {
        Log.d(TAG, "Skip clicked for: $recordTitle")
        
        userActionTaken = true // User clicked a button
        
        // Send broadcast to skip alarm
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_SKIP_ALARM
            putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
        }
        sendBroadcast(intent)
        
        finish()
    }

    private fun ignoreAlarm() {
        Log.d(TAG, "Ignore clicked for: $recordTitle")
        
        userActionTaken = true // User clicked a button
        
        // Send broadcast to ignore alarm
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_IGNORE_ALARM
            putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
        }
        sendBroadcast(intent)
        
        finish()
    }

    override fun onBackPressed() {
        // Prevent back button from closing the alarm
        // User must explicitly choose an action
    }
        override fun onStart() {
        super.onStart()
        Log.d(TAG, "AlarmScreenActivity onStart() called")
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "AlarmScreenActivity onResume() called - should be visible now")
        
        // Register sensor listener for device tilt
        accelerometer?.let { 
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
        
        // Register broadcast receiver to listen for alarm service events
        val filter = IntentFilter(ACTION_CLOSE_ALARM_SCREEN)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(alarmServiceReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(alarmServiceReceiver, filter)
        }
        Log.d(TAG, "Registered alarm service receiver")
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "AlarmScreenActivity onPause() called")
        
        // Unregister sensor listener
        sensorManager.unregisterListener(this)
        
        // Unregister broadcast receiver
        try {
            unregisterReceiver(alarmServiceReceiver)
            Log.d(TAG, "Unregistered alarm service receiver")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to unregister receiver", e)
        }
    }

    override fun onStop() {
        super.onStop()
        Log.d(TAG, "AlarmScreenActivity onStop() called")
        
        // If user didn't take any action and activity is being stopped, treat as ignore
        if (!userActionTaken) {
            Log.d(TAG, "Activity stopped without user action - treating as ignore for: $recordTitle")
            handleAlarmIgnore()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "AlarmScreenActivity destroyed")
        
        // Unregister sensor listener
        sensorManager.unregisterListener(this)
        
        // Backup check - if user didn't take any action, treat it as ignore
        if (!userActionTaken) {
            Log.d(TAG, "Activity destroyed without user action - treating as ignore for: $recordTitle")
            handleAlarmIgnore()
        }
    }

    private fun handleAlarmIgnore() {
        // Prevent duplicate handling
        if (userActionTaken) {
            Log.d(TAG, "User action already taken, skipping ignore handling for: $recordTitle")
            return
        }
        
        userActionTaken = true // Mark as handled
        
        // Send the same broadcast as the ignore button
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_IGNORE_ALARM
            putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
        }
        sendBroadcast(intent)
        
        Log.d(TAG, "Sent ignore broadcast for: $recordTitle")
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        Log.d(TAG, "AlarmScreenActivity onNewIntent() called with action: ${intent?.action}")
        // Simplified - just log for debugging, actual close is handled by broadcast receiver
    }


    // Sensor event handling for device tilt detection
    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_ACCELEROMETER) {
            val x = event.values[0]
            val y = event.values[1]
            val z = event.values[2]
            
            // Calculate tilt angles in degrees
            deviceTiltX = Math.toDegrees(kotlin.math.atan2(x.toDouble(), kotlin.math.sqrt((y * y + z * z).toDouble()))).toFloat()
            deviceTiltY = Math.toDegrees(kotlin.math.atan2(y.toDouble(), kotlin.math.sqrt((x * x + z * z).toDouble()))).toFloat()
        }
    }
    
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Not needed for this implementation
    }
      // Calculate shooting star angle range based on device tilt
    private fun getStarAngleRange(): Pair<Float, Float> {
        val absX = kotlin.math.abs(deviceTiltX)
        val absY = kotlin.math.abs(deviceTiltY)
          return when {
            // Device is upside down (extreme Y tilt) - use left, bottom, right directions
            absY > 120f -> Pair(-90f, 90f)
            
            // Device tilted right (positive X beyond threshold) - stars should go right
            deviceTiltX > tiltThreshold -> Pair(-90f, 30f)
            
            // Device tilted left (negative X beyond threshold) - stars should go left
            deviceTiltX < -tiltThreshold -> Pair(-30f, 90f)
            
            // Default - minimal tilt or within threshold
            else -> Pair(-30f, 30f)
        }
    }
}
