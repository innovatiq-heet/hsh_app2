package com.example.hsh_app2.screentime

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Foreground service that polls `/screen-time/policies/me` so a remote lock or
 * block lands on the device within seconds, with the app closed.
 *
 * It must be a *foreground* service: since Android 8 a plain background
 * service is killed about a minute after the app leaves the screen, and
 * starting one from a boot broadcast throws. The persistent low-priority
 * notification is also what keeps the process alive on aggressive OEM ROMs.
 */
class PolicyPollService : Service() {

    companion object {
        private const val TAG = "PolicyPollService"
        private const val CHANNEL_ID = "hsh_monitoring"
        private const val NOTIFICATION_ID = 7101

        /** Fast while the student is actually using the phone, relaxed when the screen is off. */
        private const val POLL_ACTIVE_MS = 30_000L
        private const val POLL_IDLE_MS = 120_000L

        fun start(context: Context) {
            if (!PolicyStore.hasSession(context)) return
            try {
                ContextCompat.startForegroundService(context, Intent(context, PolicyPollService::class.java))
            } catch (e: Exception) {
                Log.w(TAG, "start failed: ${e.message}")
            }
        }

        fun stop(context: Context) {
            runCatching { context.stopService(Intent(context, PolicyPollService::class.java)) }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private var running = false

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!running) return
            executor.execute { fetchPolicy() }
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            handler.postDelayed(this, if (pm.isInteractive) POLL_ACTIVE_MS else POLL_IDLE_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceCompat.startForeground(
                this, NOTIFICATION_ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!PolicyStore.hasSession(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (!running) {
            running = true
            handler.post(pollRunnable)
            Log.d(TAG, "started")
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacks(pollRunnable)
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun fetchPolicy() {
        val token = PolicyStore.token(this)
        val baseUrl = PolicyStore.baseUrl(this)
        if (token.isNullOrEmpty() || baseUrl.isNullOrEmpty()) {
            handler.post { stopSelf() }
            return
        }

        var conn: HttpURLConnection? = null
        try {
            conn = (URL("$baseUrl/screen-time/policies/me").openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 10_000
                readTimeout = 10_000
                setRequestProperty("Accept", "application/json")
                setRequestProperty("Authorization", "Bearer $token")
            }
            when (conn.responseCode) {
                in 200..299 -> {
                    val body = conn.inputStream.bufferedReader().use { it.readText() }
                    PolicyStore.applyPolicyJson(this, JSONObject(body))
                }
                401 -> {
                    // Session is dead; stop until the app hands us a fresh token.
                    PolicyStore.clearToken(this)
                    handler.post { stopSelf() }
                }
            }
        } catch (e: Exception) {
            Log.d(TAG, "poll failed: ${e.message}")
        } finally {
            conn?.disconnect()
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID, "Hostel monitoring", NotificationManager.IMPORTANCE_MIN,
        ).apply {
            description = "Keeps screen-time monitoring active"
            setShowBadge(false)
        }
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pending = launch?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentTitle("Hostel monitoring active")
            .setContentText("Screen-time rules are being applied on this phone")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(pending)
            .build()
    }
}
