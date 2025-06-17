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
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.imnexerio.revix.AlarmService.Companion.NOTIFICATION_CHANNEL_ID
import com.imnexerio.revix.AlarmService.Companion.TAG
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import java.util.*

class AlarmService : Service() {    companion object {
        private const val TAG = "AlarmService"
        private const val NOTIFICATION_CHANNEL_ID = "record_alarms"
        private const val NOTIFICATION_CHANNEL_NAME = "Record Alarms"
        private const val FOREGROUND_NOTIFICATION_ID = 1000
        
        // Method to show data refresh notification - call this from Flutter when checking alarm status
        @JvmStatic
        fun showDataRefreshNotification(context: Context) {
            try {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                
                val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
                    .setSmallIcon(R.drawable.ic_launcher_foreground)
                    .setContentTitle("Checking for upcoming reminders...")
                    .setContentText("Refreshing data to check for alarms in the next minute")
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .setCategory(NotificationCompat.CATEGORY_STATUS)
                    .setAutoCancel(true)
                    .setTimeoutAfter(5000) // Auto-dismiss after 5 seconds
                    .build()
                
                val notificationId = "data_refresh".hashCode()
                notificationManager.notify(notificationId, notification)
                
                Log.d(TAG, "Data refresh notification shown")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to show data refresh notification", e)
            }
        }
    }

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Start as foreground service with media playback type for Android 14+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                FOREGROUND_NOTIFICATION_ID, 
                createForegroundNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(FOREGROUND_NOTIFICATION_ID, createForegroundNotification())
        }

        intent?.let { processIntent(it) }

        // Stop the service after processing
        stopSelf()
        return START_NOT_STICKY
    }    private fun processIntent(intent: Intent) {
        when (intent.action) {
            "PRECHECK_RECORD_STATUS" -> {
                handlePrecheckRecordStatus(intent)
            }
            "RESCHEDULE_ALARMS" -> {
                handleRescheduleAlarms()
            }
            "MARK_AS_DONE" -> {
                handleMarkAsDone(intent)
            }
            "STOP_ALL_ALARMS" -> {
                handleStopAllAlarms()
            }
            else -> {
                handleAlarmTrigger(intent)
            }
        }
    }

    private fun handlePrecheckRecordStatus(intent: Intent) {
        val category = intent.getStringExtra(AlarmReceiver.EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(AlarmReceiver.EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(AlarmReceiver.EXTRA_RECORD_TITLE) ?: ""

        Log.d(TAG, "Prechecking record status: $category - $subCategory - $recordTitle")

        // Trigger Flutter background callback to refresh data
        triggerFlutterBackgroundCallback("record_check", mapOf(
            "category" to category,
            "sub_category" to subCategory,
            "record_title" to recordTitle
        ))
    }

    private fun handleMarkAsDone(intent: Intent) {
        val category = intent.getStringExtra(AlarmReceiver.EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(AlarmReceiver.EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(AlarmReceiver.EXTRA_RECORD_TITLE) ?: ""

        Log.d(TAG, "Handling mark as done: $category - $subCategory - $recordTitle")

        // Trigger Flutter background callback to mark record as done
        triggerFlutterBackgroundCallback("record_update", mapOf(
            "category" to category,
            "sub_category" to subCategory,
            "record_title" to recordTitle,
            "requestId" to System.currentTimeMillis().toString()
        ))
    }

    private fun handleRescheduleAlarms() {
        Log.d(TAG, "Rescheduling alarms after boot")        // Trigger Flutter background callback to reschedule alarms
        triggerFlutterBackgroundCallback("alarm_reschedule", emptyMap())
    }

    private fun handleStopAllAlarms() {
        Log.d(TAG, "Stopping all ongoing alarms")
        
        // Stop any playing alarm sounds
        stopAlarmSound()
        
        // Stop vibration
        vibrator?.cancel()
        
        Log.d(TAG, "All ongoing alarms stopped")
    }

    private fun handleAlarmTrigger(intent: Intent) {
        val alarmType = intent.getIntExtra(AlarmReceiver.EXTRA_ALARM_TYPE, 0)
        val category = intent.getStringExtra(AlarmReceiver.EXTRA_CATEGORY) ?: ""
        val subCategory = intent.getStringExtra(AlarmReceiver.EXTRA_SUB_CATEGORY) ?: ""
        val recordTitle = intent.getStringExtra(AlarmReceiver.EXTRA_RECORD_TITLE) ?: ""
        val description = intent.getStringExtra(AlarmReceiver.EXTRA_DESCRIPTION) ?: ""
        val isPrecheck = intent.getBooleanExtra(AlarmReceiver.EXTRA_IS_PRECHECK, false)
        val snoozeCount = intent.getIntExtra("SNOOZE_COUNT", 0)

        Log.d(TAG, "Handling alarm: $category - $subCategory - $recordTitle (Type: $alarmType, Snooze: $snoozeCount)")

        // Create notification based on alarm type
        when (alarmType) {
            0 -> {
                // No Reminder - do nothing
                Log.d(TAG, "No reminder alarm type - skipping")
                return
            }
            1 -> {
                // Notification Only
                showNotification(category, subCategory, recordTitle, description, isPrecheck, false, false, false, snoozeCount)
            }
            2 -> {
                // Vibration Only
                triggerVibration()
                showNotification(category, subCategory, recordTitle, description, isPrecheck, true, false, false, snoozeCount)
            }
            3 -> {
                // Sound
                playAlarmSound(false)
                showNotification(category, subCategory, recordTitle, description, isPrecheck, false, true, false, snoozeCount)
            }
            4 -> {
                // Sound + Vibration
                triggerVibration()
                playAlarmSound(false)
                showNotification(category, subCategory, recordTitle, description, isPrecheck, true, true, false, snoozeCount)
            }            5 -> {
                // Loud Alarm
                triggerVibration()
                playAlarmSound(true)
                showNotification(category, subCategory, recordTitle, description, isPrecheck, true, true, true, snoozeCount)
            }
        }

        // Schedule auto-snooze if this is not a precheck and we haven't reached the limit
        if (!isPrecheck && snoozeCount < 5) {
            scheduleAutoSnooze(category, subCategory, recordTitle, description, alarmType, snoozeCount + 1)
        }
    }    private fun showNotification(
        category: String,
        subCategory: String,
        recordTitle: String,
        description: String,
        isPrecheck: Boolean,
        withVibration: Boolean,
        withSound: Boolean,
        isLoudAlarm: Boolean,
        snoozeCount: Int = 0
    ) {
        val title = if (isPrecheck) "Reminder: $recordTitle" else "Time for: $recordTitle"
        val snoozeText = if (snoozeCount > 0) " (Snoozed ${snoozeCount}x)" else ""
        val content = if (isPrecheck) {
            "Don't forget about your upcoming record in $category - $subCategory$snoozeText"
        } else {
            "$description in $category - $subCategory$snoozeText"
        }

        // Create intent to open the app
        val appIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 
            System.currentTimeMillis().toInt(),
            appIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )        // Create mark as done intent
        val markDoneIntent = Intent(this, AlarmReceiver::class.java).apply {
            action = "MARK_AS_DONE"
            putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
        }
        val markDonePendingIntent = PendingIntent.getBroadcast(
            this,
            System.currentTimeMillis().toInt(),
            markDoneIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )        // Create ignore alarm intent
        val ignoreIntent = Intent(this, AlarmReceiver::class.java).apply {
            action = "IGNORE_ALARM"
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

        // Create manual snooze intent (only if we haven't reached the limit)
        var snoozePendingIntent: PendingIntent? = null
        if (snoozeCount < 5) {
            val snoozeIntent = Intent(this, AlarmReceiver::class.java).apply {
                action = "MANUAL_SNOOZE"
                putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
                putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
                putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
                putExtra(AlarmReceiver.EXTRA_DESCRIPTION, description)
                putExtra(AlarmReceiver.EXTRA_ALARM_TYPE, if (withSound && withVibration && isLoudAlarm) 5 
                    else if (withSound && withVibration) 4 
                    else if (withSound) 3 
                    else if (withVibration) 2 
                    else 1)
                putExtra("SNOOZE_COUNT", snoozeCount + 1)
            }
            snoozePendingIntent = PendingIntent.getBroadcast(
                this,
                System.currentTimeMillis().toInt() + 2,
                snoozeIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        val notificationBuilder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setPriority(if (isLoudAlarm) NotificationCompat.PRIORITY_MAX else NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .addAction(R.drawable.ic_launcher_foreground, "Mark as Done", markDonePendingIntent)

        // Add snooze button only if we haven't reached the limit
        if (snoozePendingIntent != null) {
            notificationBuilder.addAction(R.drawable.ic_launcher_foreground, "Snooze 5min", snoozePendingIntent)
        }
        
        // Always add ignore button
        notificationBuilder.addAction(R.drawable.ic_launcher_foreground, "Ignore", ignorePendingIntent)

        // Configure sound and vibration
        if (withSound || withVibration || isLoudAlarm) {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            if (withSound || isLoudAlarm) {
                val soundUri = RingtoneManager.getDefaultUri(
                    if (isLoudAlarm) RingtoneManager.TYPE_ALARM else RingtoneManager.TYPE_NOTIFICATION
                )
                notificationBuilder.setSound(soundUri, AudioManager.STREAM_ALARM)
            }

            if (withVibration || isLoudAlarm) {
                val pattern = if (isLoudAlarm) {
                    longArrayOf(0, 1000, 500, 1000, 500, 1000)
                } else {
                    longArrayOf(0, 500, 250, 500)
                }
                notificationBuilder.setVibrate(pattern)
            }
        }

        // For loud alarms, use full screen intent
        if (isLoudAlarm) {
            notificationBuilder.setFullScreenIntent(pendingIntent, true)
        }

        try {
            val notificationManager = NotificationManagerCompat.from(this)
            val notificationId = (category + subCategory + recordTitle).hashCode()
            notificationManager.notify(notificationId, notificationBuilder.build())
        } catch (e: SecurityException) {
            Log.e(TAG, "Failed to show notification - permission denied", e)
        }
    }

    private fun triggerVibration() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val vibrationEffect = VibrationEffect.createWaveform(
                    longArrayOf(0, 500, 250, 500, 250, 500),
                    -1
                )
                vibrator?.vibrate(vibrationEffect)
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(longArrayOf(0, 500, 250, 500, 250, 500), -1)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to trigger vibration", e)
        }
    }

    private fun playAlarmSound(isLoudAlarm: Boolean) {
        try {
            mediaPlayer?.release()
            mediaPlayer = MediaPlayer().apply {
                val soundUri = RingtoneManager.getDefaultUri(
                    if (isLoudAlarm) RingtoneManager.TYPE_ALARM else RingtoneManager.TYPE_NOTIFICATION
                )
                setDataSource(this@AlarmService, soundUri)
                setAudioStreamType(AudioManager.STREAM_ALARM)
                isLooping = isLoudAlarm
                prepare()
                start()
            }            // Auto-stop after 1 minute for loud alarms, 30 seconds for regular sounds
            val duration = if (isLoudAlarm) 60000L else 30000L
            Timer().schedule(object : TimerTask() {
                override fun run() {
                    stopAlarmSound()
                }
            }, duration)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to play alarm sound", e)
        }
    }

    private fun stopAlarmSound() {
        try {
            mediaPlayer?.apply {
                if (isPlaying) {
                    stop()
                }
                release()
            }
            mediaPlayer = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop alarm sound", e)
        }    }

    private fun scheduleAutoSnooze(
        category: String,
        subCategory: String,
        recordTitle: String,
        description: String,
        alarmType: Int,
        snoozeCount: Int
    ) {
        val snoozeTime = System.currentTimeMillis() + (5 * 60 * 1000) // 5 minutes from now
        
        val snoozeIntent = Intent(this, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_RECORD_ALARM
            putExtra(AlarmReceiver.EXTRA_CATEGORY, category)
            putExtra(AlarmReceiver.EXTRA_SUB_CATEGORY, subCategory)
            putExtra(AlarmReceiver.EXTRA_RECORD_TITLE, recordTitle)
            putExtra(AlarmReceiver.EXTRA_DESCRIPTION, description)
            putExtra(AlarmReceiver.EXTRA_ALARM_TYPE, alarmType)
            putExtra(AlarmReceiver.EXTRA_IS_PRECHECK, false)
            putExtra("SNOOZE_COUNT", snoozeCount)
        }

        val snoozePendingIntent = PendingIntent.getBroadcast(
            this,
            ("$category$subCategory$recordTitle$snoozeCount").hashCode(),
            snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    snoozeTime,
                    snoozePendingIntent
                )
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, snoozeTime, snoozePendingIntent)
            }
            Log.d(TAG, "Auto-snooze scheduled for $recordTitle in 5 minutes (attempt $snoozeCount/5)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule auto-snooze", e)
        }
    }

    private fun triggerFlutterBackgroundCallback(action: String, params: Map<String, String>) {
        try {
            // Build URI with parameters
            val uriBuilder = StringBuilder("homewidget://$action")
            if (params.isNotEmpty()) {
                uriBuilder.append("?")
                params.entries.forEachIndexed { index, entry ->
                    if (index > 0) uriBuilder.append("&")
                    uriBuilder.append("${entry.key}=${entry.value}")
                }
            }
            val uri = Uri.parse(uriBuilder.toString())
            Log.d(TAG, "Triggering Flutter callback: $uri")
            
            // Note: Widget updates are handled by the Flutter side when the app processes the alarm
            // The alarm functionality works independently of whether users have home widgets installed
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to trigger Flutter background callback", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for record alarms"
                enableVibration(true)
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)        }
    }

    private fun createForegroundNotification(): Notification {
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("Record Alarm Service")
            .setContentText("Processing record alarms...")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAlarmSound()
        vibrator = null
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
