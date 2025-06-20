package com.imnexerio.revix

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView

class AlarmScreenActivity : Activity() {
    companion object {
        private const val TAG = "AlarmScreenActivity"
        const val EXTRA_CATEGORY = "category"
        const val EXTRA_SUB_CATEGORY = "sub_category"
        const val EXTRA_RECORD_TITLE = "record_title"
        
        fun checkOverlayPermission(context: Context): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Settings.canDrawOverlays(context)
            } else {
                true // Permission not needed on older versions
            }
        }

        fun requestOverlayPermission(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${context.packageName}")
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
            }
        }
    }

    private var category: String = ""
    private var subCategory: String = ""
    private var recordTitle: String = ""
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "AlarmScreenActivity onCreate() called")
        
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
    }    private fun setupFullScreenOverLockScreen() {
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
    }

    private fun createAlarmUI() {
        // Create a simple layout programmatically
        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setBackgroundColor(android.graphics.Color.BLACK)
            setPadding(50, 100, 50, 100)
        }
        
        // Title text
        val titleText = TextView(this).apply {
            text = "ALARM"
            textSize = 36f
            setTextColor(android.graphics.Color.WHITE)
            gravity = android.view.Gravity.CENTER
            setPadding(0, 0, 0, 50)
        }
        
        // Alarm details text
        val detailsText = TextView(this).apply {
            text = "$category · $subCategory\n$recordTitle"
            textSize = 20f
            setTextColor(android.graphics.Color.WHITE)
            gravity = android.view.Gravity.CENTER
            setPadding(0, 0, 0, 100)
        }
        
        // Mark as Done button
        val doneButton = Button(this).apply {
            text = "MARK AS DONE"
            textSize = 18f
            setPadding(50, 30, 50, 30)
            setOnClickListener {
                markAsDone()
            }
        }
        
        // Ignore button
        val ignoreButton = Button(this).apply {
            text = "IGNORE"
            textSize = 18f
            setPadding(50, 30, 50, 30)
            setOnClickListener {
                ignoreAlarm()
            }
        }
        
        // Add views to layout
        layout.addView(titleText)
        layout.addView(detailsText)
        layout.addView(doneButton)
        layout.addView(ignoreButton)
        
        setContentView(layout)
    }

    private fun markAsDone() {
        Log.d(TAG, "Mark as done clicked for: $recordTitle")
        
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
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "AlarmScreenActivity onResume() called - should be visible now")
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "AlarmScreenActivity onPause() called")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "AlarmScreenActivity destroyed")
    }
}
