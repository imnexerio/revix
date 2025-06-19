package com.imnexerio.revix

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.*

data class ActiveAlarm(
    val alarmKey: String,
    val notificationId: Int,
    val category: String,
    val subCategory: String,
    val recordTitle: String,
    val alarmType: Int,
    val startTime: Long = System.currentTimeMillis()
)

class AlarmService : Service() {
    companion object {
        private const val TAG = "AlarmService"
        private const val NOTIFICATION_CHANNEL_ID = "record_alarms"
        private const val NOTIFICATION_CHANNEL_NAME = "Record Alarms"
        private const val AUTO_STOP_TIMEOUT = 5 * 60 * 1000L // 5 minutes
    }

    // Multi-alarm state management
    private val activeAlarms = mutableMapOf<String, ActiveAlarm>()
    private var currentAudioAlarm: String? = null // Which alarm is currently playing audio
    
    // Audio/vibration components (single instances for priority-based audio)
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var autoStopTimer: Timer? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "revix:AlarmWakeLock"
            )
            wakeLock?.acquire(30000) // Hold for 30 seconds max
            Log.d(TAG, "Wake lock acquired - screen should turn on")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire wake lock", e)
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d(TAG, "Wake lock released")
                }
            }
            wakeLock = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release wake lock", e)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.let { processIntent(it) }
        return START_NOT_STICKY
    }    private fun processIntent(intent: Intent) {
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
        val notificationId = (category + subCategory + recordTitle).hashCode()

        Log.d(TAG, "Handling alarm: $recordTitle (Type: $alarmType)")

        // Create alarm metadata
        val alarm = ActiveAlarm(
            alarmKey = alarmKey,
            notificationId = notificationId,
            category = category,
            subCategory = subCategory,
            recordTitle = recordTitle,
            alarmType = alarmType
        )

        // Add to active alarms
        activeAlarms[alarmKey] = alarm

        // Acquire wake lock to turn on screen
        acquireWakeLock()

        // Create and show notification
        val notification = createAlarmNotification(category, subCategory, recordTitle)
        
        // Start foreground service with first alarm, others as regular notifications
        if (activeAlarms.size == 1) {
            startForeground(notificationId, notification)
        } else {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(notificationId, notification)
        }

        // Handle audio/vibration based on priority
        handleAudioForAlarm(alarm)

        // Start auto-stop timer for this specific alarm
        startAutoStopTimerForAlarm(alarmKey)
    }    private fun handleAudioForAlarm(alarm: ActiveAlarm) {
        // Check if this alarm should play audio (sound types: 2,3,4,5)
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
        
        // Stop audio/vibration
        stopSoundAndVibration()
        currentAudioAlarm = null
        
        // Cancel all timers and dismiss all notifications
        activeAlarms.values.forEach { alarm ->
            cancelAutoStopTimerForAlarm(alarm.alarmKey)
            dismissNotification(alarm.notificationId)
        }
        
        // Clear all active alarms
        activeAlarms.clear()
        
        // Release resources and stop service
        autoStopTimer?.cancel()
        releaseWakeLock()
        stopSelf()
    }

    private fun handleStopSpecificAlarm(intent: Intent) {
        val category = intent.getStringExtra(AlarmReceiver.EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(AlarmReceiver.EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(AlarmReceiver.EXTRA_RECORD_TITLE) ?: ""
        val alarmKey = "$category$subCategory$recordTitle"

        Log.d(TAG, "Stopping specific alarm: $recordTitle")

        val alarm = activeAlarms[alarmKey]
        if (alarm != null) {
            // Cancel auto-stop timer for this alarm
            cancelAutoStopTimerForAlarm(alarmKey)
            
            // Dismiss notification
            dismissNotification(alarm.notificationId)
            
            // If this alarm was playing audio, stop it and check for next
            if (currentAudioAlarm == alarmKey) {
                stopSoundAndVibration()
                currentAudioAlarm = null
                
                // Check if any other active alarm needs audio
                checkForNextAudioAlarm()
            }
            
            // Remove from active alarms
            activeAlarms.remove(alarmKey)
            
            // If no more alarms, stop service
            if (activeAlarms.isEmpty()) {
                releaseWakeLock()
                stopSelf()
            }
        }
    }

    private fun checkForNextAudioAlarm() {
        // Find the oldest alarm that needs audio
        val nextAudioAlarm = activeAlarms.values
            .filter { it.alarmType in 2..5 }
            .minByOrNull { it.startTime }
            
        if (nextAudioAlarm != null) {
            currentAudioAlarm = nextAudioAlarm.alarmKey
            startAudioForAlarmType(nextAudioAlarm)
            Log.d(TAG, "Started audio for next alarm: ${nextAudioAlarm.recordTitle}")
        }
    }

    private fun dismissNotification(notificationId: Int) {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId)
            Log.d(TAG, "Dismissed notification: $notificationId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to dismiss notification: $notificationId", e)
        }
    }    private val alarmTimers = mutableMapOf<String, Timer>()

    private fun startAutoStopTimerForAlarm(alarmKey: String) {
        // Cancel existing timer if any
        cancelAutoStopTimerForAlarm(alarmKey)
        
        val timer = Timer().apply {
            schedule(object : TimerTask() {
                override fun run() {
                    Log.d(TAG, "Auto-stopping alarm after 5 minutes: $alarmKey")
                    
                    // Stop audio if this alarm was playing it
                    if (currentAudioAlarm == alarmKey) {
                        stopSoundAndVibration()
                        currentAudioAlarm = null
                        
                        // Check for next audio alarm
                        checkForNextAudioAlarm()
                    }
                    
                    // Keep notification but stop sound/vibration
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
    }    private fun stopSoundAndVibration() {
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
            Log.e(TAG, "Error stopping vibration", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, NOTIFICATION_CHANNEL_NAME, importance).apply {
                description = "Notifications for record alarms and reminders"
                enableVibration(false) // We handle vibration manually
                setSound(null, null) // We handle sound manually
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createAlarmNotification(category: String, subCategory: String, recordTitle: String): Notification {
        val title = "Alarm: $category · $subCategory · $recordTitle"
        val content = "Time for your scheduled task"

        // Create intent to open the app
        val appIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            appIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

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

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_icon)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(false)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .addAction(R.drawable.ic_launcher_icon, "Mark as Done", markDonePendingIntent)
            .addAction(R.drawable.ic_launcher_icon, "Ignore", ignorePendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setShowWhen(true)
            .setFullScreenIntent(pendingIntent, true)
            .build()
    }    override fun onDestroy() {
        Log.d(TAG, "AlarmService destroyed")
        stopSoundAndVibration()
        
        // Cancel all timers
        alarmTimers.values.forEach { it.cancel() }
        alarmTimers.clear()
        autoStopTimer?.cancel()
        
        // Dismiss all notifications
        activeAlarms.values.forEach { alarm ->
            dismissNotification(alarm.notificationId)
        }
        activeAlarms.clear()
        
        releaseWakeLock()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
