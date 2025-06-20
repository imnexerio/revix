package com.imnexerio.revix

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import java.util.*

data class ActiveAlarm(
    val alarmKey: String,
    val category: String,
    val subCategory: String,
    val recordTitle: String,
    val alarmType: Int,
    val startTime: Long = System.currentTimeMillis()
)

class AlarmService : Service() {    companion object {
        private const val TAG = "AlarmService"
        private const val AUTO_STOP_TIMEOUT = 5 * 1000L // Auto-stop timeout in milliseconds
    }

    // Multi-alarm state management
    private val activeAlarms = mutableMapOf<String, ActiveAlarm>()
    private var currentAudioAlarm: String? = null // Which alarm is currently playing audio
    
    // Audio/vibration components (single instances for priority-based audio)
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    
    // Wake lock for device wake-up (screen management handled by AlarmScreenActivity)
    private var wakeLock: PowerManager.WakeLock? = null
    private var autoStopTimer: Timer? = null
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        initializeWakeLock()
    }    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Existing alarm service channel
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel("alarm_service", "Record Alarms", importance).apply {
                description = "Notifications for record alarms and reminders"
                enableVibration(false) // We handle vibration manually
                setSound(null, null) // We handle sound manually
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
            
            // New channel for task reminders (after service stops)
            val reminderImportance = NotificationManager.IMPORTANCE_DEFAULT
            val reminderChannel = NotificationChannel("task_reminders", "Task Reminders", reminderImportance).apply {
                description = "Persistent reminders for tasks after alarm stops"
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(reminderChannel)
        }
    }
      private fun createForegroundNotification(category: String, subCategory: String, recordTitle: String): Notification {
        val title = "Alarm: $category · $subCategory · $recordTitle"
        val content = "Time for your scheduled task"

        // Create mark as done intent
        val markDoneIntent = Intent(this, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_MARK_AS_DONE
            putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
        }
        val markDonePendingIntent = PendingIntent.getBroadcast(
            this,
            System.currentTimeMillis().toInt(),
            markDoneIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Create ignore alarm intent
        val ignoreIntent = Intent(this, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_IGNORE_ALARM
            putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
        }
        val ignorePendingIntent = PendingIntent.getBroadcast(
            this,
            System.currentTimeMillis().toInt() + 1,
            ignoreIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, "alarm_service")
                .setSmallIcon(R.drawable.ic_launcher_icon)
                .setContentTitle(title)
                .setContentText(content)
                .setStyle(Notification.BigTextStyle().bigText(content))
                .setPriority(Notification.PRIORITY_HIGH)
                .setCategory(Notification.CATEGORY_ALARM)
                .setAutoCancel(false)
                .setOngoing(true)
                .setDeleteIntent(ignorePendingIntent) // Handle notification dismissal like ignore
                .addAction(R.drawable.ic_launcher_icon, "Mark as Done", markDonePendingIntent)
                .addAction(R.drawable.ic_launcher_icon, "Ignore", ignorePendingIntent)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setShowWhen(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(R.drawable.ic_launcher_icon)
                .setContentTitle(title)
                .setContentText(content)
                .setAutoCancel(false)
                .setOngoing(true)
                .setDeleteIntent(ignorePendingIntent)
                .addAction(R.drawable.ic_launcher_icon, "Mark as Done", markDonePendingIntent)
                .addAction(R.drawable.ic_launcher_icon, "Ignore", ignorePendingIntent)
                .build()
        }
    }

    private fun createReminderNotification(category: String, subCategory: String, recordTitle: String): Notification {
        val title = "Task Reminder: $category · $subCategory"
        val content = recordTitle

        // Create mark as done intent (same as foreground notification)
        val markDoneIntent = Intent(this, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_MARK_AS_DONE
            putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
        }
        val markDonePendingIntent = PendingIntent.getBroadcast(
            this,
            System.currentTimeMillis().toInt(),
            markDoneIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Create ignore alarm intent (same as foreground notification)
        val ignoreIntent = Intent(this, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_IGNORE_ALARM
            putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
        }
        val ignorePendingIntent = PendingIntent.getBroadcast(
            this,
            System.currentTimeMillis().toInt() + 1,
            ignoreIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, "task_reminders")
                .setSmallIcon(R.drawable.ic_launcher_icon)
                .setContentTitle(title)
                .setContentText(content)
                .setStyle(Notification.BigTextStyle().bigText(content))
                .setPriority(Notification.PRIORITY_DEFAULT)
                .setCategory(Notification.CATEGORY_REMINDER)
                .setAutoCancel(false)
                .setOngoing(false) // Can be dismissed unlike foreground notification
                .setDeleteIntent(ignorePendingIntent) // Handle notification dismissal like ignore
                .addAction(R.drawable.ic_launcher_icon, "Mark as Done", markDonePendingIntent)
                .addAction(R.drawable.ic_launcher_icon, "Ignore", ignorePendingIntent)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setShowWhen(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(R.drawable.ic_launcher_icon)
                .setContentTitle(title)
                .setContentText(content)
                .setAutoCancel(false)
                .setOngoing(false)
                .setDeleteIntent(ignorePendingIntent)
                .addAction(R.drawable.ic_launcher_icon, "Mark as Done", markDonePendingIntent)
                .addAction(R.drawable.ic_launcher_icon, "Ignore", ignorePendingIntent)
                .build()
        }
    }

    private fun initializeWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        // Simple partial wake lock just to wake the device - screen handling is done by activity
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "AlarmService::WakeLock"
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.let { processIntent(it) }
        return START_NOT_STICKY
    }
    private fun processIntent(intent: Intent) {
        when (intent.action) {
            "STOP_ALL_ALARMS" -> {
                handleStopAllAlarms()
            }
            "STOP_SPECIFIC_ALARM" -> {
                handleStopSpecificAlarm(intent)
            }
            else -> {
                handleAlarmTrigger(intent)
            }
        }
    }    private fun handleAlarmTrigger(intent: Intent) {
        val alarmType = intent.getIntExtra(AlarmReceiver.EXTRA_ALARM_TYPE, 0)
        val category = intent.getStringExtra(AlarmReceiver.EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(AlarmReceiver.EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(AlarmReceiver.EXTRA_RECORD_TITLE) ?: ""
        val alarmKey = "$category$subCategory$recordTitle"

        Log.d(TAG, "Handling alarm: $recordTitle (Type: $alarmType)")

        // Create alarm metadata
        val alarm = ActiveAlarm(
            alarmKey = alarmKey,
            category = category,
            subCategory = subCategory,
            recordTitle = recordTitle,
            alarmType = alarmType)        // Add to active alarms
        activeAlarms[alarmKey] = alarm

        // Start as foreground service if first alarm
        if (activeAlarms.size == 1) {
            val notification = createForegroundNotification(category, subCategory, recordTitle)
            startForeground(999, notification)
        }

        // Launch full-screen alarm and handle audio/vibration
        handleAudioForAlarm(alarm)

        // Start auto-stop timer for this specific alarm
        startAutoStopTimerForAlarm(alarmKey)
    }private fun handleAudioForAlarm(alarm: ActiveAlarm) {
        // Wake device and launch full-screen alarm activity
        acquireWakeLock()
        launchAlarmScreen(alarm)
        
        // Handle audio/vibration based on alarm type
        val needsAudio = alarm.alarmType in 2..5
        
        if (!needsAudio) {
            Log.d(TAG, "Notification only alarm for: ${alarm.recordTitle}")
            return
        }

        // If no audio currently playing, start audio for this alarm
        if (currentAudioAlarm == null) {
            currentAudioAlarm = alarm.alarmKey
            startAudioForAlarmType(alarm)
            Log.d(TAG, "Started audio for alarm: ${alarm.recordTitle}")
        } else {
            Log.d(TAG, "Audio already playing for another alarm, ${alarm.recordTitle} will show notification only")
        }
    }

    private fun startAudioForAlarmType(alarm: ActiveAlarm) {
        when (alarm.alarmType) {
            2 -> startVibration(VibrationPattern.NORMAL) // Vibration only
            3 -> startSound(SoundLevel.NORMAL) // Sound only
            4 -> { // Sound + Vibration
                startSound(SoundLevel.NORMAL)
                startVibration(VibrationPattern.NORMAL)
            }
            5 -> { // Loud alarm
                startSound(SoundLevel.LOUD)
                startVibration(VibrationPattern.INTENSE)
            }
        }
    }    private fun handleStopAllAlarms() {
        Log.d(TAG, "Stopping all ongoing alarms")
        
        // Stop audio/vibration and release wake lock
        stopSoundAndVibration()
        releaseWakeLock()
        currentAudioAlarm = null
          // Cancel all timers and clean up active alarms
        activeAlarms.values.forEach { alarm ->
            cancelAutoStopTimerForAlarm(alarm.alarmKey)
        }
        
        // Clear all active alarms
        activeAlarms.clear()
        
        // Release resources and stop service
        autoStopTimer?.cancel()
        stopSelf()
    }private fun handleStopSpecificAlarm(intent: Intent) {
        val category = intent.getStringExtra(AlarmReceiver.EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(AlarmReceiver.EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(AlarmReceiver.EXTRA_RECORD_TITLE) ?: ""
        val alarmKey = "$category$subCategory$recordTitle"

        Log.d(TAG, "Stopping specific alarm: $recordTitle")

        val alarm = activeAlarms[alarmKey]
        if (alarm != null) {
            // Cancel auto-stop timer for this alarm
            cancelAutoStopTimerForAlarm(alarmKey)
            
            // If this alarm was playing audio, stop it and check for next
            if (currentAudioAlarm == alarmKey) {
                stopSoundAndVibration()
                currentAudioAlarm = null
                
                // Check if any other active alarm needs audio
                checkForNextAudioAlarm()
            }
              // Remove from active alarms
            activeAlarms.remove(alarmKey)
            
            // If no more alarms, stop service and release wake lock
            if (activeAlarms.isEmpty()) {
                releaseWakeLock()
                stopSelf()
            }
        }    }

    private fun checkForNextAudioAlarm() {
        // Find the oldest alarm that needs audio
        val nextAudioAlarm = activeAlarms.values
            .filter { it.alarmType in 2..5 }
            .minByOrNull { it.startTime }
            
        if (nextAudioAlarm != null) {
            currentAudioAlarm = nextAudioAlarm.alarmKey
            startAudioForAlarmType(nextAudioAlarm)
            Log.d(TAG, "Started audio for next alarm: ${nextAudioAlarm.recordTitle}")
        }    }

    private val alarmTimers = mutableMapOf<String, Timer>()
    private fun startAutoStopTimerForAlarm(alarmKey: String) {
        // Cancel existing timer if any
        cancelAutoStopTimerForAlarm(alarmKey)
          val timer = Timer().apply {            schedule(object : TimerTask() {                override fun run() {
                    Log.d(TAG, "Auto-stopping alarm completely after ${AUTO_STOP_TIMEOUT / 1000}s for alarm: $alarmKey")
                    
                    // Stop audio if this alarm was playing it
                    if (currentAudioAlarm == alarmKey) {
                        stopSoundAndVibration()
                        currentAudioAlarm = null
                        
                        // Check for next audio alarm
                        checkForNextAudioAlarm()
                    }
                    
                    // Convert to reminder notification BEFORE removing from active alarms
                    val alarm = activeAlarms[alarmKey]
                    if (alarm != null) {
                        convertToReminderNotification(alarm)
                    }
                    
                    // Remove the alarm directly
                    activeAlarms.remove(alarmKey)
                    
                    // If this was the last alarm, release wake lock AND stop service
                    if (activeAlarms.isEmpty()) {
                        releaseWakeLock()
                        stopSelf() // Stop service - reminder notification will persist
                        Log.d(TAG, "All alarms completed - service stopped, reminder notifications persist")
                    }
                }
            }, AUTO_STOP_TIMEOUT)
        }
        
        alarmTimers[alarmKey] = timer
        Log.d(TAG, "Auto-stop timer started for alarm: $alarmKey")
    }

    private fun cancelAutoStopTimerForAlarm(alarmKey: String) {
        alarmTimers[alarmKey]?.cancel()
        alarmTimers.remove(alarmKey)
    }

    private enum class SoundLevel { NORMAL, LOUD }
    private enum class VibrationPattern { NORMAL, INTENSE }

    private fun startSound(level: SoundLevel) {
        try {
            stopSound() // Stop any existing sound

            val defaultRingtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            mediaPlayer = MediaPlayer().apply {
                setDataSource(this@AlarmService, defaultRingtoneUri)
                isLooping = true

                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )

                // Set volume based on level
                val volume = when (level) {
                    SoundLevel.NORMAL -> 0.7f
                    SoundLevel.LOUD -> 1.0f
                }
                setVolume(volume, volume)

                prepare()
                start()
            }

            Log.d(TAG, "Started ${level.name.lowercase()} sound")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start sound", e)
        }
    }

    private fun startVibration(pattern: VibrationPattern) {
        try {
            stopVibration() // Stop any existing vibration

            val vibrationPattern = when (pattern) {
                VibrationPattern.NORMAL -> longArrayOf(0, 500, 200, 500, 200, 500)
                VibrationPattern.INTENSE -> longArrayOf(0, 800, 200, 800, 200, 800, 200, 800)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val vibrationEffect = VibrationEffect.createWaveform(vibrationPattern, 0) // 0 = repeat
                vibrator?.vibrate(vibrationEffect)
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(vibrationPattern, 0)
            }
            Log.d(TAG, "Started ${pattern.name.lowercase()} vibration")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start vibration", e)
        }
    }    private fun acquireWakeLock() {
        try {
            if (wakeLock?.isHeld != true) {
                wakeLock?.acquire(10000) // Brief wake lock just to wake device, activity handles the rest
                Log.d(TAG, "Wake lock acquired - Device woken up")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire wake lock", e)
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "Wake lock released")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release wake lock", e)
        }
    }    private fun launchAlarmScreen(alarm: ActiveAlarm) {
        try {
            Log.d(TAG, "Attempting to launch alarm screen for: ${alarm.recordTitle}")
            
            val intent = Intent(this, AlarmScreenActivity::class.java).apply {
                putExtra(AlarmScreenActivity.EXTRA_CATEGORY, alarm.category)
                putExtra(AlarmScreenActivity.EXTRA_SUB_CATEGORY, alarm.subCategory)
                putExtra(AlarmScreenActivity.EXTRA_RECORD_TITLE, alarm.recordTitle)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_NO_USER_ACTION or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                )
            }
            
            startActivity(intent)
            Log.d(TAG, "Successfully launched alarm screen for: ${alarm.recordTitle}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch alarm screen for: ${alarm.recordTitle}", e)
            // Fallback: try to show with less restrictive flags
            try {
                val fallbackIntent = Intent(this, AlarmScreenActivity::class.java).apply {
                    putExtra(AlarmScreenActivity.EXTRA_CATEGORY, alarm.category)
                    putExtra(AlarmScreenActivity.EXTRA_SUB_CATEGORY, alarm.subCategory)
                    putExtra(AlarmScreenActivity.EXTRA_RECORD_TITLE, alarm.recordTitle)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(fallbackIntent)
                Log.d(TAG, "Fallback launch successful for: ${alarm.recordTitle}")
            } catch (fallbackException: Exception) {
                Log.e(TAG, "Fallback launch also failed for: ${alarm.recordTitle}", fallbackException)
            }
        }
    }private fun stopSoundAndVibration() {
        stopSound()
        stopVibration()
    }

    private fun stopSound() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            }
            mediaPlayer = null
            Log.d(TAG, "Sound stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping sound", e)
        }
    }

    private fun stopVibration() {
        try {
            vibrator?.cancel()
            Log.d(TAG, "Vibration stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping vibration", e)        }
    }

    override fun onDestroy() {
        Log.d(TAG, "AlarmService destroyed")
        stopSoundAndVibration()
        releaseWakeLock()
          // Cancel all timers
        alarmTimers.values.forEach { it.cancel() }
        alarmTimers.clear()
        autoStopTimer?.cancel()
        
        // Clear all active alarms
        activeAlarms.clear()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun convertToReminderNotification(alarm: ActiveAlarm) {
        try {
            Log.d(TAG, "Converting foreground notification to reminder for: ${alarm.recordTitle}")
            
            val reminderNotification = createReminderNotification(alarm.category, alarm.subCategory, alarm.recordTitle)
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val notificationId = (alarm.category + alarm.subCategory + alarm.recordTitle).hashCode()
            
            // Post regular notification with same ID as foreground notification
            // This ensures seamless transition
            notificationManager.notify(notificationId, reminderNotification)
            
            Log.d(TAG, "Successfully converted to reminder notification for: ${alarm.recordTitle}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to convert notification for: ${alarm.recordTitle}", e)
        }
    }
}
