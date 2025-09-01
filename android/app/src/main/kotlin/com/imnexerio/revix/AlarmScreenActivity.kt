package com.imnexerio.revix

import android.animation.ValueAnimator
import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.graphics.drawable.GradientDrawable
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
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.content.ContextCompat
import kotlin.math.sqrt

class AlarmScreenActivity : Activity() {

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

    // Brjoadcast receiver to listen for alarm service events
    private val alarmServiceReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_CLOSE_ALARM_SCREEN -> {
                    val receivedCategory = intent.getStringExtra(AlarmReceiver.EXTRA_CATEGORY) ?: ""
                    val receivedSubCategory = intent.getStringExtra(AlarmReceiver.EXTRA_SUB_CATEGORY) ?: ""
                    val receivedRecordTitle = intent.getStringExtra(AlarmReceiver.EXTRA_RECORD_TITLE) ?: ""

                    // Check if this broadcast is for this specific alarm
                    if (receivedCategory == category && receivedSubCategory == subCategory && receivedRecordTitle == recordTitle) {
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

        // Check if this is details mode or alarm mode
        val isDetailsMode = intent.getBooleanExtra("DETAILS_MODE", false)

        // Set up screen behavior based on mode
        if (isDetailsMode) {
            setupNormalActivity()
        } else {
            setupFullScreenOverLockScreen()
        }

        // Create and set content view
        createAlarmUI()

        Log.d(TAG, "AlarmScreenActivity setup complete for: $recordTitle")
    }
    private fun setupFullScreenOverLockScreen() {
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
        }    }

    private fun setupNormalActivity() {
        Log.d(TAG, "Setting up normal activity mode")
        
        // Simple activity setup - just keep screen on
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun createAlarmUI() {
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


        // Time and Date (no card background)
        val timeDisplay = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dpToPx(24), dpToPx(20), dpToPx(24), dpToPx(20))

            // Time text
            val timeText = TextView(this@AlarmScreenActivity).apply {
                text = reminderTime
                textSize = 64f
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
                textSize = 24f
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
                    textSize = 22f
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
                    textSize = 22f
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
                    textSize = 22f  // Same as category and subcategory
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
                
                val completionText = TextView(this@AlarmScreenActivity).apply {
                    val completionValue = calculateCompletionFromCache()
                    val recordData = getRecordDataFromWidgetCache()
                    val missedCounts = recordData?.get("missed_counts") ?: "0"
                    val skippedCounts = recordData?.get("skip_counts") ?: "0"
                    text = "Completed: $completionValue\nMissed: $missedCounts | Skipped: $skippedCounts"
                    textSize = 22f
                    setTextColor(textColor)
                    gravity = Gravity.START  // Left aligned
                    maxLines = 2  // Two lines for completed and missed
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
                    textSize = 22f  // Increased from 14f
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
                addView(completionText)
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

        // Create button layer with ConstraintLayout for precise positioning
        val buttonLayer = createButtonLayer(
            accentColor = accentColor,
            textColor = textColor,
            dpToPx = dpToPx
        )


        contentOverlay.addView(timeDisplay)
        contentOverlay.addView(infoCard)
        contentOverlay.addView(flexSpacer)

        // Layer the components: gradient, content overlay, button layer
        mainLayout.addView(gradientLayer)
        mainLayout.addView(contentOverlay)
        mainLayout.addView(buttonLayer) // New ConstraintLayout button layer

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

    // Create button layer with ConstraintLayout for precise positioning
    private fun createButtonLayer(
        accentColor: Int,
        textColor: Int,
        dpToPx: (Int) -> Int
    ): ConstraintLayout {
        return ConstraintLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            // Add padding to ensure buttons don't touch screen edges
            setPadding(0, 0, 0, dpToPx(16)) // 16dp bottom padding for extra safety
            
            // Skip button (bottom-left)
            val skipButton = Button(this@AlarmScreenActivity).apply {
                id = android.view.View.generateViewId()
                text = "SKIP"
                textSize = 24f
                setTypeface(null, android.graphics.Typeface.NORMAL)
                isAllCaps = false
                setTextColor(textColor)

                val skipBackground = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = dpToPx(25).toFloat()
                    setColor(Color.argb(40, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)))
                    setStroke(dpToPx(1), Color.argb(100, 255, 255, 255))
                }
                background = skipBackground

                setPadding(dpToPx(20), dpToPx(16), dpToPx(20), dpToPx(16))

                setOnClickListener { skipAlarm() }

                // Custom touch feedback
                setOnTouchListener { view, event ->
                    when (event.action) {
                        android.view.MotionEvent.ACTION_DOWN -> {
                            view.alpha = 0.7f
                            view.scaleX = 0.95f
                            view.scaleY = 0.95f
                        }
                        android.view.MotionEvent.ACTION_UP, android.view.MotionEvent.ACTION_CANCEL -> {
                            view.alpha = 1.0f
                            view.scaleX = 1.0f
                            view.scaleY = 1.0f
                        }
                    }
                    false
                }
            }

            // Ignore button (bottom-right)
            val ignoreButton = Button(this@AlarmScreenActivity).apply {
                id = android.view.View.generateViewId()
                text = "IGNORE"
                textSize = 24f
                setTypeface(null, android.graphics.Typeface.NORMAL)
                isAllCaps = false
                setTextColor(textColor)

                val ignoreBackground = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = dpToPx(25).toFloat()
                    setColor(Color.argb(40, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)))
                    setStroke(dpToPx(1), Color.argb(100, 255, 255, 255))
                }
                background = ignoreBackground

                setPadding(dpToPx(20), dpToPx(16), dpToPx(20), dpToPx(16))

                setOnClickListener { ignoreAlarm() }

                // Custom touch feedback
                setOnTouchListener { view, event ->
                    when (event.action) {
                        android.view.MotionEvent.ACTION_DOWN -> {
                            view.alpha = 0.7f
                            view.scaleX = 0.95f
                            view.scaleY = 0.95f
                        }
                        android.view.MotionEvent.ACTION_UP, android.view.MotionEvent.ACTION_CANCEL -> {
                            view.alpha = 1.0f
                            view.scaleX = 1.0f
                            view.scaleY = 1.0f
                        }
                    }
                    false
                }
            }

            // Create glass swipe button with glow animation
            val glowViewSize = dpToPx(220) // Large enough for 100dp radius glow (200dp diameter + 20dp padding)
            
            // Single glass button with glow animation that can draw beyond bounds
            val glassButton = object : TextView(this@AlarmScreenActivity) {
                private var rippleProgress = 0f
                private val glowPaint = Paint().apply {
                    isAntiAlias = true
                    style = Paint.Style.STROKE
                    strokeWidth = dpToPx(3).toFloat()
                }
                private val buttonPaint = Paint().apply {
                    isAntiAlias = true
                    style = Paint.Style.FILL
                }
                private val buttonStrokePaint = Paint().apply {
                    isAntiAlias = true
                    style = Paint.Style.STROKE
                    strokeWidth = dpToPx(2).toFloat()
                }
                
                override fun onDraw(canvas: Canvas) {
                    val centerX = width / 2f
                    val centerY = height / 2f
                    val buttonRadius = dpToPx(60).toFloat() // 120dp diameter
                    
                    // Draw glow ring animation first
                    val maxRippleRadius = dpToPx(100).toFloat()
                    val currentRadius = buttonRadius + (rippleProgress * (maxRippleRadius - buttonRadius))
                    val alpha = ((1f - rippleProgress) * 120).toInt().coerceIn(0, 120)
                    
                    glowPaint.color = Color.argb(alpha, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor))
                    
                    if (rippleProgress > 0f) {
                        canvas.drawCircle(centerX, centerY, currentRadius, glowPaint)
                    }
                    
                    // Draw the glass button background
                    val glassColor = Color.argb(
                        40,
                        (Color.red(accentColor) * 0.3f + 255 * 0.7f).toInt(),
                        (Color.green(accentColor) * 0.3f + 255 * 0.7f).toInt(),
                        (Color.blue(accentColor) * 0.3f + 255 * 0.7f).toInt()
                    )
                    buttonPaint.color = glassColor
                    canvas.drawCircle(centerX, centerY, buttonRadius, buttonPaint)
                    
                    // Draw button border
                    buttonStrokePaint.color = Color.argb(60, 255, 255, 255)
                    canvas.drawCircle(centerX, centerY, buttonRadius, buttonStrokePaint)
                    
                    // Draw the button text on top
                    super.onDraw(canvas)
                }
                
                fun setRippleProgress(progress: Float) {
                    rippleProgress = progress
                    invalidate()
                }
            }.apply {
                id = android.view.View.generateViewId()
                text = "SWIPE TO\nMARK DONE"
                textSize = 14f
                setTextColor(textColor)
                gravity = Gravity.CENTER
                setTypeface(null, android.graphics.Typeface.BOLD)
                
                // Remove background drawable since we're drawing manually
                background = null
                
                // Animation and interaction logic
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
                                setRippleProgress(progress)
                            }
                        }
                        start()
                    }
                }
                
                fun stopGlowAnimation() {
                    glowAnimator?.cancel()
                    setRippleProgress(0f)
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
                            Log.d(TAG, "Swipe completed - distance: $distance")
                            
                            animate()
                                .scaleX(1.2f)
                                .scaleY(1.2f)
                                .setDuration(150)
                                .withEndAction {
                                    markAsDone()
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

            // Add buttons to layout
            addView(skipButton)
            addView(ignoreButton)
            addView(glassButton)

            // Skip button constraints (bottom-left with margins)
            val skipConstraints = ConstraintLayout.LayoutParams(
                ConstraintLayout.LayoutParams.WRAP_CONTENT,
                ConstraintLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomToBottom = ConstraintLayout.LayoutParams.PARENT_ID
                startToStart = ConstraintLayout.LayoutParams.PARENT_ID
                setMargins(dpToPx(30), 0, dpToPx(4), dpToPx(24)) // Left margin 30dp, right margin 4dp, bottom margin 24dp
            }
            skipButton.layoutParams = skipConstraints

            // Ignore button constraints (bottom-right with margins)
            val ignoreConstraints = ConstraintLayout.LayoutParams(
                ConstraintLayout.LayoutParams.WRAP_CONTENT,
                ConstraintLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomToBottom = ConstraintLayout.LayoutParams.PARENT_ID
                endToEnd = ConstraintLayout.LayoutParams.PARENT_ID
                setMargins(dpToPx(4), 0, dpToPx(30), dpToPx(24)) // Left margin 4dp, right margin 30dp, bottom margin 24dp
            }
            ignoreButton.layoutParams = ignoreConstraints

            // Glass button constraints (centered, large enough for glow animation)
            val glassButtonConstraints = ConstraintLayout.LayoutParams(
                glowViewSize, // 220dp for the view (accommodates 100dp glow radius)
                glowViewSize
            ).apply {
                bottomToTop = skipButton.id
                startToStart = ConstraintLayout.LayoutParams.PARENT_ID
                endToEnd = ConstraintLayout.LayoutParams.PARENT_ID
                setMargins(0, 0, 0, dpToPx(0))
            }
            glassButton.layoutParams = glassButtonConstraints
        }
    }


    private fun createGradientBackground(
        accentColor: Int,
        dpToPx: (Int) -> Int
    ): View {
        return object : View(this) {
            private var animationTime = 0f
            private val maxAnimationSpeed = 0.03f // Optimized speed for smoother animation
            private var currentAnimationSpeed = 0f // Start at 0 speed
            private val rampUpDurationMs = 10000L // 10 seconds to reach full speed
            private val startTime = System.currentTimeMillis()
            private var lastFrameTime = System.currentTimeMillis()
            
            // Pre-calculate values to reduce computation
            private var cachedCenterX = 0f
            private var cachedCenterY = 0f
            private var cachedRadius = 0f
            private var frameCount = 0
            private val updateInterval = 33L // ~30 FPS for smooth animation
            
            private val gradientPaint = Paint().apply {
                isAntiAlias = true
                isDither = true // Smooth color transitions
            }

            // Get dynamic white color from theme
            private val whiteColor = ContextCompat.getColor(this@AlarmScreenActivity, R.color.white)

            override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
                super.onSizeChanged(w, h, oldw, oldh)
                // Pre-calculate base values
                cachedCenterX = w / 2f
                cachedCenterY = h / 2f
                cachedRadius = kotlin.math.max(w, h).toFloat() * 0.8f
                updateGradient()
                // Start animation immediately when view is sized
                post { invalidate() }
            }

            private fun updateAnimationSpeed() {
                val elapsedTime = System.currentTimeMillis() - startTime
                val progress = (elapsedTime.toFloat() / rampUpDurationMs).coerceIn(0f, 1f)
                
                // Smooth easing function for gradual acceleration
                val easedProgress = 1f - (1f - progress) * (1f - progress) // Ease-out curve
                currentAnimationSpeed = maxAnimationSpeed * easedProgress
            }

            private fun updateGradient() {
                if (width <= 0 || height <= 0) return
                
                // Update animation speed based on elapsed time
                updateAnimationSpeed()
                
                // Optimized wave calculations - use time-based instead of frame-based
                val time = animationTime.toDouble()
                
                // Pre-calculate wave values
                val wave1 = kotlin.math.sin(time * 0.7).toFloat()
                val wave2 = kotlin.math.cos(time * 1.1).toFloat()
                val wave3 = kotlin.math.sin(time * 0.9).toFloat()
                
                // Dynamic center point with smoother movement
                val centerX = cachedCenterX + wave1 * cachedCenterX * 0.1f  // Reduced movement for smoothness
                val centerY = cachedCenterY + wave2 * cachedCenterY * 0.15f
                
                // Dynamic radius with gentler breathing
                val radius = cachedRadius * (1f + wave3 * 0.1f)
                
                // Optimized color blending - reduce calculations
                val blendStep = 0.125f // 1/8 for 8 colors
                val colors = IntArray(8)
                val positions = FloatArray(8)
                
                // Generate colors more efficiently
                for (i in 0 until 8) {
                    val baseBlend = 1f - (i * blendStep) // From 1.0 to 0.0
                    val waveInfluence = when(i % 3) {
                        0 -> wave1 * 0.03f
                        1 -> wave2 * 0.03f
                        else -> wave3 * 0.03f
                    }
                    val blendFactor = (baseBlend + waveInfluence).coerceIn(0f, 1f)
                    
                    colors[i] = Color.argb(255,
                        (Color.red(whiteColor) * blendFactor + Color.red(accentColor) * (1f - blendFactor)).toInt(),
                        (Color.green(whiteColor) * blendFactor + Color.green(accentColor) * (1f - blendFactor)).toInt(),
                        (Color.blue(whiteColor) * blendFactor + Color.blue(accentColor) * (1f - blendFactor)).toInt()
                    )
                    
                    positions[i] = i * 0.142857f // 1/7 spacing for even distribution
                }
                
                // Create optimized radial gradient
                gradientPaint.shader = android.graphics.RadialGradient(
                    centerX, centerY,         // Dynamic center point
                    radius,                   // Breathing radius
                    colors,
                    positions,
                    Shader.TileMode.CLAMP
                )
            }

            override fun onDraw(canvas: Canvas) {
                super.onDraw(canvas)
                
                // Optimized frame timing
                val currentTime = System.currentTimeMillis()
                val deltaTime = currentTime - lastFrameTime
                
                if (deltaTime >= updateInterval) {
                    // Calculate smooth time progression
                    val smoothDelta = deltaTime / 1000f // Convert to seconds
                    animationTime += currentAnimationSpeed * smoothDelta * 60f // Normalize for 60fps
                    
                    lastFrameTime = currentTime
                    updateGradient()
                    frameCount++
                }
                
                // Draw the animated gradient
                canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), gradientPaint)
                
                // Smooth animation continuation
                if (currentAnimationSpeed > 0f || frameCount < 300) { // Keep animating for first 10 seconds
                    postInvalidateDelayed(updateInterval)
                } else {
                    // Reduce update frequency when animation is subtle
                    postInvalidateDelayed(updateInterval * 2)
                }
            }

            override fun onAttachedToWindow() {
                super.onAttachedToWindow()
                // Reset timing when attached
                lastFrameTime = System.currentTimeMillis()
                post { invalidate() }
            }
            
            override fun onDetachedFromWindow() {
                super.onDetachedFromWindow()
                // Clean up when detached
                gradientPaint.shader = null
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

        // Check if this is details mode or alarm mode
        val isDetailsMode = intent.getBooleanExtra("DETAILS_MODE", false)
        
        if (isDetailsMode) {
            // In details mode, ignore just closes the activity (no alarm to stop)
            Log.d(TAG, "Details mode - simply closing activity for: $recordTitle")
            finish()
        } else {
            // In alarm mode, ignore converts alarm to reminder notification
            Log.d(TAG, "Alarm mode - sending ignore broadcast for: $recordTitle")
            val intent = Intent(this, AlarmReceiver::class.java).apply {
                action = AlarmReceiver.ACTION_IGNORE_ALARM
                putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
                putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
                putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
            }
            sendBroadcast(intent)
            finish()
        }
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

        // Check if this is details mode or alarm mode
        val isDetailsMode = intent.getBooleanExtra("DETAILS_MODE", false)
        
        if (isDetailsMode) {
            // In details mode, just closing activity (no alarm to ignore)
            Log.d(TAG, "Details mode - activity closed without action for: $recordTitle")
        } else {
            // In alarm mode, treat as ignore (convert to reminder)
            Log.d(TAG, "Alarm mode - treating as ignore for: $recordTitle")
            val intent = Intent(this, AlarmReceiver::class.java).apply {
                action = AlarmReceiver.ACTION_IGNORE_ALARM
                putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
                putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
                putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
            }
            sendBroadcast(intent)
        }

        Log.d(TAG, "Handled activity dismissal for: $recordTitle")
    }

    private fun calculateCompletionFromCache(): String {
        return try {
            val recordData = getRecordDataFromWidgetCache()
            val completionCountsStr = recordData?.get("completion_counts") ?: "0"
            val durationStr = recordData?.get("duration") ?: ""

            val completionCount = completionCountsStr.toIntOrNull() ?: 0
            
            if (durationStr.isEmpty()) {
                Log.d(TAG, "No duration data available, using basic count: $completionCount")
                return completionCount.toString()
            }

            // Parse duration JSON - same logic as Dart Map<String, dynamic>
            val duration = try {
                org.json.JSONObject(durationStr)
            } catch (e: Exception) {
                Log.d(TAG, "Failed to parse as JSON, trying to extract from simple format: $durationStr")
                // Try to handle simple format like {type=forever, numberOfTimes=4}
                parseSimpleDurationFormat(durationStr)
            }

            if (duration == null) {
                Log.d(TAG, "Could not parse duration, returning count: $completionCount")
                return completionCount.toString()
            }

            val durationType = duration.optString("type", "")
            
            val result = when (durationType) {
                "specificTimes" -> {
                    val numberOfTimes = duration.optInt("numberOfTimes", 0)
                    "$completionCount/$numberOfTimes"
                }
                "until" -> {
                    val endDate = duration.optString("endDate", "")
                    if (endDate.isNotEmpty()) {
                        "$completionCount/$endDate"
                    } else {
                        "$completionCount/date"
                    }
                }
                "forever" -> {
                    "$completionCount/∞"
                }
                else -> {
                    completionCount.toString()
                }
            }
            
            Log.d(TAG, "Calculated completion value: $result (count=$completionCount, type=$durationType)")
            result
            
        } catch (e: Exception) {
            Log.e(TAG, "Error calculating completion value", e)
            "0" // Fallback to "0" if all else fails
        }
    }

    private fun parseSimpleDurationFormat(durationStr: String): org.json.JSONObject? {
        return try {
            val json = org.json.JSONObject()
            
            // Extract type
            val typeRegex = "type\\s*[=:]\\s*([^,}]+)".toRegex()
            val typeMatch = typeRegex.find(durationStr)
            if (typeMatch != null) {
                json.put("type", typeMatch.groupValues[1].trim())
            }
            
            // Extract numberOfTimes
            val timesRegex = "numberOfTimes\\s*[=:]\\s*(\\d+)".toRegex()
            val timesMatch = timesRegex.find(durationStr)
            if (timesMatch != null) {
                json.put("numberOfTimes", timesMatch.groupValues[1].toInt())
            }
            
            // Extract endDate
            val dateRegex = "endDate\\s*[=:]\\s*([^,}]+)".toRegex()
            val dateMatch = dateRegex.find(durationStr)
            if (dateMatch != null) {
                json.put("endDate", dateMatch.groupValues[1].trim())
            }
            
            Log.d(TAG, "Parsed simple format to JSON: $json")
            json
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse simple duration format: $durationStr", e)
            null
        }
    }

    private fun getRecordDataFromWidgetCache(): Map<String, String>? {
        return try {
            val sharedPrefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            
            val recordSources = listOf("todayRecords", "tomorrowRecords")
            
            for (source in recordSources) {
                val recordsJson = sharedPrefs.getString(source, "[]") ?: "[]"
                if (recordsJson != "[]") {
                    val jsonArray = org.json.JSONArray(recordsJson)
                    
                    for (i in 0 until jsonArray.length()) {
                        val record = jsonArray.getJSONObject(i)
                        val recordCategory = record.optString("category", "")
                        val recordSubCategory = record.optString("sub_category", "")
                        val recordTitleMatch = record.optString("record_title", "")
                        
                        if (recordCategory == category && 
                            recordSubCategory == subCategory && 
                            recordTitleMatch == recordTitle) {
                            
                            // Found matching record, extract all data
                            val recordData = mutableMapOf<String, String>()
                            val keys = record.keys()
                            while (keys.hasNext()) {
                                val key = keys.next()
                                recordData[key] = record.optString(key, "")
                            }
                            
                            Log.d(TAG, "Found matching record in $source: $recordData")
                            return recordData
                        }
                    }
                }
            }
            
            Log.d(TAG, "No matching record found in HomeWidget cache for: $category/$subCategory/$recordTitle")
            null
        } catch (e: Exception) {
            Log.e(TAG, "Error accessing HomeWidget cache: ${e.message}", e)
            null
        }
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        Log.d(TAG, "AlarmScreenActivity onNewIntent() called with action: ${intent?.action}")
        // Simplified - just log for debugging, actual close is handled by broadcast receiver
    }
}
