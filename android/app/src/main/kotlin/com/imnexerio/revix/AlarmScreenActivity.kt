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
          Log.d(TAG, "AlarmScreenActivity created for: $recordTitle")
        
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
        }        // Get colors from resources
        val backgroundColor = ContextCompat.getColor(this, R.color.WidgetBackground)
        val textColor = ContextCompat.getColor(this, R.color.text)
        val accentColor = ContextCompat.getColor(this, R.color.colorOnPrimary)
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
          // Second layer: Content overlay with responsive layout
        val contentOverlay = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(24), dpToPx(32), dpToPx(24), dpToPx(32))
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        
        // Minimal top spacer - responsive to screen size
        val topSpacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                0.15f  // Very small weight for minimal top spacing
            )
        }        // Content container with flexible layout
        val contentLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                0.6f  // Reduced to give more space to button area
            )
        }
        
        // Title text with responsive typography
        val timeText = TextView(this).apply {
            text = "Time -> $reminderTime"
            textSize = 28f  // Slightly smaller for better fit
            setTextColor(textColor)
            gravity = Gravity.CENTER
            setTypeface(null, android.graphics.Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(24))  // Reduced margin
            }
        }
        
        // Category info with responsive styling
        val categoryText = TextView(this).apply {
            text = "Category -> $category"
            textSize = 18f  // Slightly smaller
            setTextColor(textColor)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(8))  // Reduced margin
            }
        }
        
        // Sub-category text
        val subCategoryText = TextView(this).apply {
            text = "Sub Category -> $subCategory"
            textSize = 18f  // Slightly smaller
            setTextColor(textColor)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(12))  // Reduced margin
            }
        }
        
        // Record title with emphasis
        val recordTitleText = TextView(this).apply {
            text = "Title -> $recordTitle"
            textSize = 18f  // Slightly smaller
            setTextColor(textColor)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(32))  // Reduced margin
            }
        }        // Container for swipe button with flexible layout
        val swipeButtonContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                0.5f  // Increased space for button area
            )
        }
        
        // Simple swipe button (gradient will be in background layer)
        val doneButton = createSimpleSwipeButton(
            text = "SWIPE TO\nMARK DONE",
            accentColor = accentColor,
            textColor = backgroundColor,
            dpToPx = dpToPx
        ) {
            markAsDone()
        }// Ignore button with secondary styling - will be placed at bottom
        val ignoreButton = createModernButton(
            text = "IGNORE",
            isPrimary = false,
            accentColor = accentColor,
            textColor = textColor,
            dpToPx = dpToPx
        ) {
            ignoreAlarm()
        }        // Bottom section for ignore button with more visible space
        val bottomSection = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.TOP  // Changed to TOP to move button up within its section
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                0.2f  // Increased space for better visibility
            )
        }
        
        // Assemble the content overlay with responsive weights
        contentOverlay.addView(topSpacer)
        contentOverlay.addView(contentLayout)
        contentOverlay.addView(swipeButtonContainer)
        contentOverlay.addView(bottomSection)
        
        // Add ignore button to bottom section
        bottomSection.addView(ignoreButton)
          // Add text content to main content layout
        contentLayout.addView(timeText)
        contentLayout.addView(categoryText)
        contentLayout.addView(subCategoryText)
        contentLayout.addView(recordTitleText)
          // Add swipe button to its container
        swipeButtonContainer.addView(doneButton)
        
        // Layer the components: stars background first, then gradient background, then content overlay
        mainLayout.addView(starsBackground)  // First layer (background stars)
        mainLayout.addView(gradientLayer)    // Second layer (gradient)
        mainLayout.addView(contentOverlay)   // Third layer (content)
        
        setContentView(mainLayout)
    }
      private fun createModernButton(
        text: String,
        isPrimary: Boolean,
        accentColor: Int,
        textColor: Int,
        dpToPx: (Int) -> Int,
        onClick: () -> Unit
    ): Button {
        return Button(this).apply {
            this.text = text
            textSize = 16f
            setTypeface(null, android.graphics.Typeface.BOLD)
            isAllCaps = false
            
            // Set text color before creating background
            setTextColor(textColor)
            
            val buttonBackground = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(12).toFloat()
                
                if (isPrimary) {
                    setColor(accentColor)
                } else {
                    setColor(android.graphics.Color.TRANSPARENT)
                    setStroke(dpToPx(2), accentColor)
                }
            }
            
            background = buttonBackground
            setPadding(dpToPx(24), dpToPx(16), dpToPx(24), dpToPx(16))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(dpToPx(24), dpToPx(8), dpToPx(24), dpToPx(8))  // More prominent margins
            }
            
            setOnClickListener { onClick() }
            
            // Add touch feedback
            foreground = ContextCompat.getDrawable(context, android.R.drawable.list_selector_background)
        }
    }    private fun createCircularSwipeButton(
        text: String,
        accentColor: Int,
        textColor: Int,
        dpToPx: (Int) -> Int,
        onSwipe: () -> Unit
    ): View {        // Container for button and glow effect - full screen size for edge-to-edge gradient
        val container = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(24))
            }
        }
        // Glow effect view with circular gradient, clipped to circle
        val glowView = object : View(this) {            private var baseGlowIntensity = 0.4f // More subtle base glow
            private var interactionGlowIntensity = 0f // Additional glow during interaction
            
            private val gradientPaint = Paint().apply {
                isAntiAlias = true
            }
              private fun updateGradient() {
                val centerX = width / 2f
                val centerY = height / 2f
                
                // Use a moderate radius to avoid square edge effect
                val baseRadius = dpToPx(180).toFloat() // Fixed moderate radius
                val glowRadius = baseRadius + (interactionGlowIntensity * dpToPx(80))
                
                // Create subtle radial gradient with lower opacity
                val totalIntensity = baseGlowIntensity + interactionGlowIntensity
                val centerAlpha = (totalIntensity * 80).toInt().coerceIn(0, 255) // Reduced alpha
                val midAlpha = (totalIntensity * 40).toInt().coerceIn(0, 255)
                val edgeAlpha = (totalIntensity * 15).toInt().coerceIn(0, 255)
                
                gradientPaint.shader = RadialGradient(
                    centerX, centerY, glowRadius,
                    intArrayOf(
                        Color.argb(centerAlpha, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)),
                        Color.argb((centerAlpha * 0.7f).toInt(), Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)),
                        Color.argb((centerAlpha * 0.5f).toInt(), Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)),
                        Color.argb(midAlpha, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)),
                        Color.argb(edgeAlpha, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)),
                        Color.TRANSPARENT
                    ),
                    floatArrayOf(0f, 0.25f, 0.5f, 0.75f, 0.9f, 1f),
                    Shader.TileMode.CLAMP
                )
            }
            
            var totalGlowIntensity: Float
                get() = baseGlowIntensity + interactionGlowIntensity
                set(value) {
                    interactionGlowIntensity = (value - baseGlowIntensity).coerceAtLeast(0f)
                    invalidate()
                }
            
            fun setBaseGlowIntensity(intensity: Float) {
                baseGlowIntensity = intensity
                invalidate()
            }
            
            override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
                super.onSizeChanged(w, h, oldw, oldh)
                updateGradient()
            }            override fun onDraw(canvas: Canvas) {
                super.onDraw(canvas)
                updateGradient()
                
                val centerX = width / 2f
                val centerY = height / 2f
                
                // Use moderate radius to avoid square edge effect
                val baseRadius = dpToPx(180).toFloat()
                val glowRadius = baseRadius + (interactionGlowIntensity * dpToPx(80))
                
                // Draw circular gradient with smooth edges (no square boundary)
                canvas.drawCircle(centerX, centerY, glowRadius, gradientPaint)
            }
        }.apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setLayerType(View.LAYER_TYPE_SOFTWARE, null) // Enable advanced rendering
            
            // No breathing animation - stable glow
        }
        
        // Main button
        val button = TextView(this).apply {
            this.text = text
            textSize = 14f
            setTextColor(textColor)
            gravity = Gravity.CENTER
            setTypeface(null, android.graphics.Typeface.BOLD)
            
            // Create circular background
            val circularBackground = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(accentColor)
                setStroke(dpToPx(3), textColor)
            }
            background = circularBackground
            
            // Set circular dimensions (smaller than container for glow space)
            val buttonSize = dpToPx(120)
            layoutParams = FrameLayout.LayoutParams(buttonSize, buttonSize).apply {
                gravity = Gravity.CENTER
            }
            
            // Track touch state and swipe progress
            var isPressed = false
            var swipeProgress = 0f
            var startX = 0f
            var startY = 0f
            var glowAnimator: ValueAnimator? = null
            
            // Gesture detector for swipe
            val gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
                private val MIN_SWIPE_DISTANCE = dpToPx(80) // Minimum swipe distance
                
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
                    
                    // Check if minimum swipe distance is met
                    if (distance >= MIN_SWIPE_DISTANCE) {
                        Log.d(TAG, "Swipe completed - distance: $distance, required: $MIN_SWIPE_DISTANCE")
                        
                        // Success feedback
                        animate()
                            .scaleX(1.2f)
                            .scaleY(1.2f)
                            .setDuration(150)
                            .withEndAction {
                                onSwipe()
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
                when (event.action) {                    MotionEvent.ACTION_DOWN -> {
                        isPressed = true
                        startX = event.x
                        startY = event.y
                        
                        // Enhance glow animation on touch
                        glowAnimator?.cancel()
                        glowAnimator = ValueAnimator.ofFloat(glowView.totalGlowIntensity, 2.5f).apply {
                            duration = 300
                            addUpdateListener { animator ->
                                val intensity = animator.animatedValue as Float
                                glowView.totalGlowIntensity = intensity
                                alpha = 0.8f + ((intensity - 1f) * 0.2f)
                                scaleX = 1f + ((intensity - 1f) * 0.1f)
                                scaleY = 1f + ((intensity - 1f) * 0.1f)
                            }
                            start()
                        }
                    }
                    
                    MotionEvent.ACTION_MOVE -> {
                        if (isPressed) {
                            val diffX = event.x - startX
                            val diffY = event.y - startY
                            val currentDistance = sqrt(diffX * diffX + diffY * diffY)
                            
                            // Calculate progress (0 to 1) based on minimum swipe distance
                            swipeProgress = min(currentDistance / dpToPx(80), 1f)
                            
                            // Enhanced visual feedback based on progress
                            val progressAlpha = 0.8f + (swipeProgress * 0.2f)
                            val progressScale = 1f + (swipeProgress * 0.3f)
                            val progressGlow = 2.5f + (swipeProgress * 1.5f) // Increase glow further during swipe
                            
                            alpha = progressAlpha
                            scaleX = progressScale
                            scaleY = progressScale
                            glowView.totalGlowIntensity = progressGlow
                            
                            // Change color tint as user gets closer to completion
                            if (swipeProgress > 0.7f) {
                                setTextColor(Color.WHITE)
                            } else {
                                setTextColor(textColor)
                            }
                        }
                    }
                    
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        isPressed = false
                        swipeProgress = 0f
                        
                        // Reset to base glow state
                        glowAnimator?.cancel()
                        glowAnimator = ValueAnimator.ofFloat(glowView.totalGlowIntensity, 1f).apply {
                            duration = 400
                            addUpdateListener { animator ->
                                val intensity = animator.animatedValue as Float
                                glowView.totalGlowIntensity = intensity
                            }
                            start()
                        }
                        
                        animate()
                            .alpha(1.0f)
                            .scaleX(1.0f)
                            .scaleY(1.0f)
                            .setDuration(400)
                            .start()
                        
                        setTextColor(textColor)
                    }
                }
                gestureDetector.onTouchEvent(event)            }
            
            // No breathing animation - button remains stable
        }
        
        // Add views to container
        container.addView(glowView)
        container.addView(button)
        
        return container
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
    }    private fun createFallingStarsBackground(
        textColor: Int,
        dpToPx: (Int) -> Int
    ): View {
        return object : View(this) {
            private val stars = mutableListOf<Star>()
            private val random = Random()
            private val starPaint = Paint().apply {
                isAntiAlias = true
                color = textColor
            }
            private val trailPaint = Paint().apply {
                isAntiAlias = true
                color = textColor
                strokeCap = Paint.Cap.ROUND
                // strokeWidth will be set dynamically per star
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
                val minTrailLength = 5
                val maxTrailLength = 15
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
    }        override fun onResume() {
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
    }    override fun onPause() {
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
    }    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        Log.d(TAG, "AlarmScreenActivity onNewIntent() called with action: ${intent?.action}")
        // Simplified - just log for debugging, actual close is handled by broadcast receiver
    }    private fun createSimpleSwipeButton(
        text: String,
        accentColor: Int,
        textColor: Int,
        dpToPx: (Int) -> Int,
        onSwipe: () -> Unit
    ): View {        // Container for button and animated glow ring
        val container = FrameLayout(this).apply {
            val containerSize = dpToPx(200) // Further increased container size for larger ripple
            layoutParams = LinearLayout.LayoutParams(containerSize, containerSize).apply {
                gravity = Gravity.CENTER
                setMargins(0, 0, 0, dpToPx(24))
            }
        }
          // Animated ripple ring view (expanding from button edge)
        val glowRing = object : View(this) {
            private var rippleProgress = 0f
            private val glowPaint = Paint().apply {
                isAntiAlias = true
                style = Paint.Style.STROKE
                strokeWidth = dpToPx(4).toFloat()
            }
            
            override fun onDraw(canvas: Canvas) {
                super.onDraw(canvas)
                
                val centerX = width / 2f
                val centerY = height / 2f
                  // Button radius (where ripple starts)
                val buttonRadius = dpToPx(60).toFloat() // Half of button size (120dp)
                // Maximum ripple radius (where it disappears)
                val maxRippleRadius = dpToPx(100).toFloat() // Increased maximum radius
                
                // Calculate current ripple radius based on progress
                val currentRadius = buttonRadius + (rippleProgress * (maxRippleRadius - buttonRadius))
                  // Create fading alpha - starts strong, fades as it expands
                val alpha = ((1f - rippleProgress) * 255).toInt().coerceIn(0, 255) // Increased opacity - now full alpha at start
                
                // Use same color as button's edge (textColor) but with transparency
                glowPaint.color = Color.argb(alpha, Color.red(textColor), Color.green(textColor), Color.blue(textColor))
                
                // Draw the expanding ripple ring
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
        
        // Main button (stays constant size)
        val button = TextView(this).apply {
            this.text = text
            textSize = 14f
            setTextColor(textColor)
            gravity = Gravity.CENTER
            setTypeface(null, android.graphics.Typeface.BOLD)
            
            // Create circular background
            val circularBackground = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(accentColor)
                setStroke(dpToPx(3), textColor)
            }
            background = circularBackground
            
            // Set circular dimensions (button stays this size)
            val buttonSize = dpToPx(120)
            layoutParams = FrameLayout.LayoutParams(buttonSize, buttonSize).apply {
                gravity = Gravity.CENTER
            }
            
            // Track touch state and swipe progress
            var isPressed = false
            var startX = 0f
            var startY = 0f
            var glowAnimator: ValueAnimator? = null
              // Start ripple animation (expanding from button edge)
            fun startGlowAnimation() {
                glowAnimator?.cancel()
                glowAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
                    duration = 1500 // 1.5 seconds for each ripple
                    repeatCount = ValueAnimator.INFINITE
                    repeatMode = ValueAnimator.RESTART // Restart (not reverse) for ripple effect
                    
                    addUpdateListener { animator ->
                        if (!isPressed) { // Only animate when not being touched
                            val progress = animator.animatedValue as Float
                            glowRing.setRippleProgress(progress)
                        }
                    }
                    start()
                }
            }
            
            // Stop ripple animation
            fun stopGlowAnimation() {
                glowAnimator?.cancel()
                glowRing.setRippleProgress(0f)
            }
            
            // Start the glow animation immediately
            post { startGlowAnimation() }            // Gesture detector for swipe
            val gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
                private val MIN_SWIPE_DISTANCE = dpToPx(80)
                
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
                        
                        // Success feedback (only button scales, not glow)
                        animate()
                            .scaleX(1.2f)
                            .scaleY(1.2f)
                            .setDuration(150)
                            .withEndAction {
                                onSwipe()
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
                        startX = event.x
                        startY = event.y
                        
                        // Stop glow animation and provide touch feedback (button only)
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
                            val diffX = event.x - startX
                            val diffY = event.y - startY
                            val currentDistance = sqrt(diffX * diffX + diffY * diffY)
                            
                            // Calculate progress and provide visual feedback (button only)
                            val swipeProgress = min(currentDistance / dpToPx(80), 1f)
                            val progressScale = 1.1f + (swipeProgress * 0.2f)
                            
                            scaleX = progressScale
                            scaleY = progressScale
                            
                            // Change color as user swipes
                            if (swipeProgress > 0.7f) {
                                setTextColor(Color.WHITE)
                            } else {
                                setTextColor(textColor)
                            }
                        }
                    }
                    
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        isPressed = false
                        
                        // Reset button to normal state and restart glow animation
                        animate()
                            .alpha(1.0f)
                            .scaleX(1.0f)
                            .scaleY(1.0f)
                            .setDuration(300)
                            .withEndAction {
                                // Restart glow animation after reset
                                startGlowAnimation()
                            }
                            .start()
                        
                        setTextColor(textColor)
                    }
                }
                gestureDetector.onTouchEvent(event)
            }
        }
        
        // Add glow ring first (behind button), then button
        container.addView(glowRing)
        container.addView(button)
        
        return container
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
            
            // Device tilted right (positive X beyond threshold)
            deviceTiltX > tiltThreshold -> Pair(-30f, 90f)
            
            // Device tilted left (negative X beyond threshold)  
            deviceTiltX < -tiltThreshold -> Pair(-90f, 30f)
            
            // Default - minimal tilt or within threshold
            else -> Pair(-30f, 30f)
        }
    }
}
