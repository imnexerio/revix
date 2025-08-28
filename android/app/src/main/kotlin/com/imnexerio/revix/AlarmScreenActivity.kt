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

class AlarmScreenActivity : Activity() {    // Data class for shooting stars
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
        
        // Set up full screen over lock screen
        setupFullScreenOverLockScreen()
        
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

        // Three separate buttons layout like in the image
        val separateButtonsLayout = createSeparateButtonsLayout(
            accentColor = accentColor,
            textColor = textColor,
            dpToPx = dpToPx
        )


        // Assemble the glassmorphism layout
        contentOverlay.addView(topSpacer)
        contentOverlay.addView(timeCard)
        contentOverlay.addView(infoCard)
        contentOverlay.addView(flexSpacer)
        contentOverlay.addView(separateButtonsLayout) // Contains ignore, skip, and done buttons

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

    private fun createSeparateButtonsLayout(
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
                setMargins(dpToPx(30), dpToPx(16), dpToPx(30), dpToPx(24))
            }

            // Ignore button (small, centered, on top)
            val ignoreButton = Button(this@AlarmScreenActivity).apply {
                text = "Ignore"
                textSize = 20f
                setTypeface(null, android.graphics.Typeface.NORMAL)
                isAllCaps = false
                setTextColor(Color.argb(180, Color.red(textColor), Color.green(textColor), Color.blue(textColor)))
                
                val ignoreBackground = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = dpToPx(25).toFloat()
                    setColor(Color.argb(30, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)))
                    setStroke(dpToPx(1), Color.argb(80, 255, 255, 255))
                }
                background = ignoreBackground
                
                setPadding(dpToPx(24), dpToPx(12), dpToPx(24), dpToPx(12))
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ).apply {
                    gravity = Gravity.CENTER_HORIZONTAL
                    setMargins(0, 0, 0, dpToPx(20))
                }
                
                setOnClickListener { ignoreAlarm() }
                
                // Custom touch feedback instead of Android's yellow highlight
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
                    false // Let the click event continue
                }
            }

            // Bottom row: Skip and Done buttons side by side
            val bottomButtonsRow = LinearLayout(this@AlarmScreenActivity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )

                // Skip button (left)
                val skipButton = Button(this@AlarmScreenActivity).apply {
                    text = "Skip"
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
                    layoutParams = LinearLayout.LayoutParams(
                        0, // Use weight for equal width
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                        1f // Equal weight
                    ).apply {
                        setMargins(0, 0, dpToPx(8), 0) // Small gap between buttons
                    }
                    
                    setOnClickListener { skipAlarm() }
                    
                    // Custom touch feedback instead of Android's yellow highlight
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
                        false // Let the click event continue
                    }
                }

                // Done button (right)
                val doneButton = Button(this@AlarmScreenActivity).apply {
                    text = "Done"
                    textSize = 24f
                    setTypeface(null, android.graphics.Typeface.NORMAL)
                    isAllCaps = false
                    setTextColor(textColor)
                    
                    val doneBackground = GradientDrawable().apply {
                        shape = GradientDrawable.RECTANGLE
                        cornerRadius = dpToPx(25).toFloat()
                        setColor(Color.argb(40, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)))
                        setStroke(dpToPx(1), Color.argb(100, 255, 255, 255))
                    }
                    background = doneBackground
                    
                    setPadding(dpToPx(20), dpToPx(16), dpToPx(20), dpToPx(16))
                    layoutParams = LinearLayout.LayoutParams(
                        0, // Use weight for equal width
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                        1f // Equal weight
                    ).apply {
                        setMargins(dpToPx(8), 0, 0, 0) // Small gap between buttons
                    }
                    
                    setOnClickListener { markAsDone() }
                    
                    // Custom touch feedback instead of Android's yellow highlight
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
                        false // Let the click event continue
                    }
                }

                addView(skipButton)
                addView(doneButton)
            }

            addView(ignoreButton)
            addView(bottomButtonsRow)
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
}
