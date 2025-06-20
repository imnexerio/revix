package com.imnexerio.revix

import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import kotlin.math.abs
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
            text = "Swipe the circle in any direction to mark as done"
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
    }

    private fun createCircularSwipeButton(
        text: String,
        accentColor: Int,
        textColor: Int,
        dpToPx: (Int) -> Int,
        onSwipe: () -> Unit
    ): TextView {
        return TextView(this).apply {
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
            
            // Set circular dimensions
            val size = dpToPx(120)
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                setMargins(0, 0, 0, dpToPx(24))
            }
            
            // Add gesture detection for swipe
            val gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
                private val SWIPE_THRESHOLD = 50
                private val SWIPE_VELOCITY_THRESHOLD = 50
                
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
                    val velocity = sqrt(velocityX * velocityX + velocityY * velocityY)
                    
                    // Check if swipe meets threshold requirements
                    if (distance > SWIPE_THRESHOLD && velocity > SWIPE_VELOCITY_THRESHOLD) {
                        Log.d(TAG, "Swipe gesture detected - marking as done")
                        onSwipe()
                        return true
                    }
                    return false
                }
                
                override fun onDown(e: MotionEvent): Boolean {
                    // Provide visual feedback on touch
                    alpha = 0.7f
                    return true
                }
            })
            
            setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        // Reset visual feedback
                        alpha = 1.0f
                    }
                }
                gestureDetector.onTouchEvent(event)
            }
            
            // Add subtle animation hint
            animate().scaleX(1.05f).scaleY(1.05f).setDuration(1000).withEndAction {
                animate().scaleX(1.0f).scaleY(1.0f).setDuration(1000).withEndAction {
                    // Repeat the breathing animation
                    post {
                        animate().scaleX(1.05f).scaleY(1.05f).setDuration(1000).withEndAction {
                            animate().scaleX(1.0f).scaleY(1.0f).setDuration(1000)
                        }
                    }
                }
            }
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
