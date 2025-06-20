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
        
        Log.d(TAG, "AlarmScreenActivity created for: $recordTitle")
        
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
        }
    }    private fun createAlarmUI() {
        val dpToPx = { dp: Int ->
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp.toFloat(), resources.displayMetrics).toInt()
        }        // Get colors from resources
        val backgroundColor = ContextCompat.getColor(this, R.color.WidgetBackground)
        val textColor = ContextCompat.getColor(this, R.color.text)
        val accentColor = ContextCompat.getColor(this, R.color.colorOnPrimary)
        
        // Main container with full screen background
        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(backgroundColor)
            setPadding(dpToPx(32), dpToPx(64), dpToPx(32), dpToPx(64))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        
        // Top spacer for centering content
        val topSpacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1.0f
            )
        }
          // Content container (no card styling)
        val contentLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
          // Alarm icon (using text for now)
        val alarmIcon = TextView(this).apply {
            text = "⏰"
            textSize = 64f
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(24))
            }
        }
          // Title text with modern typography
        val titleText = TextView(this).apply {
            text = "REMINDER ALERT"
            textSize = 32f
            setTextColor(textColor)
            gravity = Gravity.CENTER
            setTypeface(null, android.graphics.Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(32))
            }
        }
          // Category info with better styling
        val categoryText = TextView(this).apply {
            text = category.uppercase()
            textSize = 16f
            setTextColor(accentColor)
            gravity = Gravity.CENTER
            setTypeface(null, android.graphics.Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(12))
            }
        }
          // Sub-category text
        val subCategoryText = TextView(this).apply {
            text = subCategory
            textSize = 18f
            setTextColor(textColor)
            gravity = Gravity.CENTER
            alpha = 0.8f
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(20))
            }
        }
          // Record title with emphasis
        val recordTitleText = TextView(this).apply {
            text = recordTitle
            textSize = 24f
            setTextColor(textColor)
            gravity = Gravity.CENTER
            setTypeface(null, android.graphics.Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(48))
            }
        }
          // Button container
        val buttonContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
          // Instruction text for swipe button
        val instructionText = TextView(this).apply {
            text = "Hold and swipe the glowing circle to mark as done"
            textSize = 12f
            setTextColor(textColor)
            gravity = Gravity.CENTER
            alpha = 0.7f
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(16))
            }
        }// Mark as Done button with circular swipe gesture
        val doneButton = createCircularSwipeButton(
            text = "SWIPE TO\nMARK DONE",
            accentColor = accentColor,
            textColor = backgroundColor,
            dpToPx = dpToPx
        ) {
            markAsDone()
        }
        
        // Ignore button with secondary styling
        val ignoreButton = createModernButton(
            text = "IGNORE",
            isPrimary = false,
            accentColor = accentColor,
            textColor = textColor,
            dpToPx = dpToPx
        ) {
            ignoreAlarm()
        }
        
        // Bottom spacer for centering content
        val bottomSpacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1.0f
            )
        }        // Assemble the layout
        contentLayout.addView(alarmIcon)
        contentLayout.addView(titleText)
        contentLayout.addView(categoryText)
        contentLayout.addView(subCategoryText)
        contentLayout.addView(recordTitleText)
        
        buttonContainer.addView(instructionText)
        buttonContainer.addView(doneButton)
        buttonContainer.addView(ignoreButton)
        contentLayout.addView(buttonContainer)
        
        mainLayout.addView(topSpacer)
        mainLayout.addView(contentLayout)
        mainLayout.addView(bottomSpacer)
        
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
                setMargins(0, 0, 0, dpToPx(16))
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
    ): View {
        // Container for button and glow effect
        val container = FrameLayout(this).apply {
            val size = dpToPx(140) // Slightly larger for glow effect
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                setMargins(0, 0, 0, dpToPx(24))
            }
        }        // Glow effect view with permanent circular gradient
        val glowView = object : View(this) {
            private var baseGlowIntensity = 1f // Always visible base glow
            private var interactionGlowIntensity = 0f // Additional glow during interaction
            
            private val gradientPaint = Paint().apply {
                isAntiAlias = true
            }
            
            private fun updateGradient() {
                val centerX = width / 2f
                val centerY = height / 2f
                val baseRadius = dpToPx(60).toFloat()
                val glowRadius = dpToPx(80).toFloat() + (interactionGlowIntensity * dpToPx(20))
                
                // Create radial gradient from accent color to transparent
                val totalIntensity = baseGlowIntensity + interactionGlowIntensity
                val centerAlpha = (totalIntensity * 120).toInt().coerceIn(0, 255)
                val edgeAlpha = (totalIntensity * 30).toInt().coerceIn(0, 255)
                
                gradientPaint.shader = RadialGradient(
                    centerX, centerY, glowRadius,
                    intArrayOf(
                        Color.argb(centerAlpha, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)),
                        Color.argb((centerAlpha * 0.7f).toInt(), Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)),
                        Color.argb((centerAlpha * 0.4f).toInt(), Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)),
                        Color.argb(edgeAlpha, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor)),
                        Color.TRANSPARENT
                    ),
                    floatArrayOf(0f, 0.3f, 0.6f, 0.8f, 1f),
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
            }
            
            override fun onDraw(canvas: Canvas) {
                super.onDraw(canvas)
                updateGradient()
                
                val centerX = width / 2f
                val centerY = height / 2f
                val glowRadius = dpToPx(80).toFloat() + (interactionGlowIntensity * dpToPx(20))
                
                // Draw the circular gradient glow
                canvas.drawCircle(centerX, centerY, glowRadius, gradientPaint)
            }
        }.apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setLayerType(View.LAYER_TYPE_SOFTWARE, null) // Enable advanced rendering
            
            // Animate the base glow with a breathing effect
            val breathingGlowAnimator = ValueAnimator.ofFloat(0.8f, 1.2f).apply {
                duration = 3000
                repeatCount = ValueAnimator.INFINITE
                repeatMode = ValueAnimator.REVERSE
                addUpdateListener { animator ->
                    setBaseGlowIntensity(animator.animatedValue as Float)
                }
                start()
            }
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
                gestureDetector.onTouchEvent(event)
            }
            
            // Subtle breathing animation when not being touched
            val breathingAnimator = ValueAnimator.ofFloat(1.0f, 1.05f).apply {
                duration = 2000
                repeatCount = ValueAnimator.INFINITE
                repeatMode = ValueAnimator.REVERSE
                addUpdateListener { animator ->
                    if (!isPressed) {
                        val scale = animator.animatedValue as Float
                        scaleX = scale
                        scaleY = scale
                    }
                }
                start()
            }
        }
        
        // Add views to container
        container.addView(glowView)
        container.addView(button)
        
        return container
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
    }    override fun onStart() {
        super.onStart()
        Log.d(TAG, "AlarmScreenActivity onStart() called")
    }    override fun onResume() {
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
    }    override fun onPause() {
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
    }
}
