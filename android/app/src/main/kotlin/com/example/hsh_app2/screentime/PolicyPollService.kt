package com.example.hsh_app2.screentime

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

/**
 * Foreground service that keeps the device policy in sync with the backend so
 * a remote lock or app block lands on the device within seconds, with the app
 * closed.
 *
 * Policy sync runs on its own thread as a long-poll: while the screen is on
 * the server holds `GET /screen-time/policies/me?wait=…` open and answers the
 * moment a warden changes something, then the next request goes out at once.
 * With the screen off it falls back to a plain fetch every [POLL_IDLE_MS]
 * (woken early by screen-on or [requestRefresh]); against a server without
 * long-poll it fetches every [POLL_ACTIVE_MS]; offline it backs off.
 * Every applied change notifies [PolicyStore] listeners, which is what makes
 * [AppBlockerAccessibilityService] re-check the app currently on screen.
 *
 * A separate tick handles the curfew geofence and re-checks the foreground
 * app for time-based rules (bedtime start, daily limit reached mid-use).
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

        /** Tick / fallback poll: fast while the phone is in use, relaxed when the screen is off. */
        private const val POLL_ACTIVE_MS = 30_000L
        private const val POLL_IDLE_MS = 120_000L
        /** How long the server may hold a policy request open (server caps it at 25 s). */
        private const val LONG_POLL_SECONDS = 25
        /** Offline / server error backoff for the policy sync. */
        private const val RETRY_MIN_MS = 5_000L
        private const val RETRY_MAX_MS = 60_000L
        /**
         * Tick cadence with the screen off. Short so a 1-minute location
         * interval is honoured; a tick does no work unless something is due.
         */
        private const val TICK_IDLE_MS = 60_000L
        /** Curfew rules change rarely; the lock/block policy is what needs to be fast. */
        private const val GEO_POLICY_TTL_MS = 10 * 60 * 1000L

        @Volatile private var instance: PolicyPollService? = null

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

        /** Fetch the policy now (app opened, setup finished…); starts the service if it isn't running. */
        fun requestRefresh(context: Context) {
            instance?.wakeSync() ?: start(context)
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val syncExecutor = Executors.newSingleThreadExecutor()
    /** Interruptible sleep for the sync loop: anything offered here wakes it early. */
    private val syncWakeups = LinkedBlockingQueue<Unit>()
    @Volatile private var running = false
    @Volatile private var geoPolicyFetchedAt = 0L

    private val screenOnReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            // Leave the idle interval at once and resume the real-time channel.
            wakeSync()
            AppBlockerAccessibilityService.recheckForeground()
        }
    }

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!running) return
            executor.execute {
                fetchGeofencePolicyIfStale()
                sampleGeofenceIfDue()
                reportLocationIfNew()
            }
            // Time-based rules (bedtime starting, daily limit reached) can begin
            // while an app is already open; there is no window event for that.
            AppBlockerAccessibilityService.recheckForeground()
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            handler.postDelayed(this, if (pm.isInteractive) POLL_ACTIVE_MS else TICK_IDLE_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        val notification = buildNotification()
        // Declaring the LOCATION type without the permission throws on API 34+,
        // so only claim it when the student has actually granted location.
        val hasLocation = LocationSampler.hasAnyPermission(this)
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> {
                var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                if (hasLocation) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> ServiceCompat.startForeground(
                this, NOTIFICATION_ID, notification,
                if (hasLocation) ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION else 0,
            )
            else -> startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!PolicyStore.hasSession(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (!running) {
            running = true
            instance = this
            ContextCompat.registerReceiver(
                this, screenOnReceiver, IntentFilter(Intent.ACTION_SCREEN_ON), ContextCompat.RECEIVER_NOT_EXPORTED,
            )
            handler.post(pollRunnable)
            syncExecutor.execute { syncLoop() }
            Log.d(TAG, "started")
        } else {
            wakeSync()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        if (instance === this) instance = null
        runCatching { unregisterReceiver(screenOnReceiver) }
        handler.removeCallbacks(pollRunnable)
        executor.shutdownNow()
        syncExecutor.shutdownNow() // interrupts the loop's sleep / in-flight wait
        super.onDestroy()
    }

    private fun wakeSync() {
        syncWakeups.offer(Unit)
    }

    /** Sleeps up to [ms], returning early when [wakeSync] is called. False when interrupted (shutting down). */
    private fun sleepUntilWoken(ms: Long): Boolean = try {
        syncWakeups.poll(ms, TimeUnit.MILLISECONDS)
        syncWakeups.clear()
        true
    } catch (_: InterruptedException) {
        false
    }

    /** Keeps the device policy current; see the class comment for the cadence. */
    private fun syncLoop() {
        var retryMs = RETRY_MIN_MS
        while (running) {
            if (!PolicyStore.hasSession(this)) {
                handler.post { stopSelf() }
                return
            }
            val interactive = (getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive
            val result = ScreenTimeSync.fetchAndSavePolicy(this, if (interactive) LONG_POLL_SECONDS else 0)
            if (!running) return
            if (result.geofenceApplied) geoPolicyFetchedAt = System.currentTimeMillis()

            val pause = when {
                result.code == 401 -> {
                    // Session is dead; stop until the app hands us a fresh token.
                    PolicyStore.clearToken(this)
                    handler.post { stopSelf() }
                    return
                }
                result.code in 200..299 -> {
                    retryMs = RETRY_MIN_MS
                    when {
                        // The server already waited for a change: ask again right away.
                        result.longPolled -> 0L
                        interactive -> POLL_ACTIVE_MS
                        else -> POLL_IDLE_MS
                    }
                }
                // Offline or server error: retry with backoff, keep the last good policy.
                else -> retryMs.also { retryMs = (retryMs * 2).coerceAtMost(RETRY_MAX_MS) }
            }
            if (pause > 0 && !sleepUntilWoken(pause)) return
        }
    }

    private fun fetchGeofencePolicyIfStale() {
        val now = System.currentTimeMillis()
        if (now - geoPolicyFetchedAt < GEO_POLICY_TTL_MS) return
        val token = PolicyStore.token(this) ?: return
        val baseUrl = PolicyStore.baseUrl(this) ?: return
        var conn: HttpURLConnection? = null
        try {
            conn = (URL("$baseUrl/geofence/policy").openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 10_000
                readTimeout = 10_000
                setRequestProperty("Accept", "application/json")
                setRequestProperty("Authorization", "Bearer $token")
            }
            if (conn.responseCode in 200..299) {
                val body = conn.inputStream.bufferedReader().use { it.readText() }
                PolicyStore.applyGeofencePolicyJson(this, JSONObject(body))
                geoPolicyFetchedAt = now
            }
        } catch (e: Exception) {
            Log.d(TAG, "geofence policy fetch failed: ${e.message}")
        } finally {
            conn?.disconnect()
        }
    }

    /**
     * During curfew, take a fix every `checkIntervalMinutes` (more often while
     * we're still deciding whether an exit is real) and run the fence check.
     * An exit or spoofing event is pushed to the backend straight away.
     */
    private fun sampleGeofenceIfDue() {
        if (!GeofenceEvaluator.isEnforcing(this)) {
            GeofenceEvaluator.clearStaleState(this)
            sampleLocationIfDue()
            return
        }
        val unavailable = when {
            !LocationSampler.hasAnyPermission(this) -> "permission_denied"
            !LocationSampler.isLocationEnabled(this) -> "location_disabled"
            else -> null
        }
        if (unavailable != null) {
            // Can't check the fence at all — tell the warden instead of going silent.
            if (GeofenceEvaluator.reportLocationUnavailable(this, unavailable)) ScreenTimeSync.syncNow(this)
            return
        }
        val policy = PolicyStore.geofencePolicy(this)
        val now = System.currentTimeMillis()
        val deciding = PolicyStore.geofenceStreak(this) > 0
        val interval = if (deciding) 60_000L else policy.intervalMinutes.coerceAtLeast(1) * 60_000L
        if (now - PolicyStore.lastSampleAt(this) < interval) return

        PolicyStore.markSampleAttempt(this)
        val fix = LocationSampler.sample(this) ?: return
        when (GeofenceEvaluator.process(this, fix)) {
            "exit", "mock_location", "enter" -> ScreenTimeSync.syncNow(this)
        }
    }

    /**
     * Outside curfew: keep the warden's location list current with one fix
     * per warden-configured interval (`checkIntervalMinutes`, the same one the
     * curfew check above uses). Nothing is evaluated or reported as a breach here.
     */
    private fun sampleLocationIfDue() {
        if (!LocationSampler.hasAnyPermission(this) || !LocationSampler.isLocationEnabled(this)) return
        val interval = PolicyStore.geofencePolicy(this).intervalMinutes.coerceAtLeast(1) * 60_000L
        if (System.currentTimeMillis() - PolicyStore.lastSampleAt(this) < interval) return
        PolicyStore.markSampleAttempt(this)
        LocationSampler.sample(this)?.let { PolicyStore.saveLastFix(this, it) }
    }

    /** Uploads the latest fix if the backend hasn't accepted it yet (retried next tick when offline). */
    private fun reportLocationIfNew() {
        val fix = PolicyStore.lastFix(this) ?: return
        if (fix.timeMillis <= PolicyStore.lastReportedFixAt(this)) return
        val token = PolicyStore.token(this) ?: return
        val baseUrl = PolicyStore.baseUrl(this) ?: return
        val polygon = PolicyStore.geofencePolicy(this).polygon
        val body = JSONObject()
            .put("latitude", fix.latitude)
            .put("longitude", fix.longitude)
            .put("accuracyMeters", fix.accuracyMeters.toDouble())
            .put("time", fix.timeMillis)
            .put("mocked", fix.mocked)
            .put("insideCampus", GeofenceEvaluator.isInside(polygon, fix.latitude, fix.longitude))
            .put("distanceMeters", GeofenceEvaluator.distanceToEdgeMeters(polygon, fix.latitude, fix.longitude))

        var conn: HttpURLConnection? = null
        try {
            conn = (URL("$baseUrl/geofence/location").openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 10_000
                readTimeout = 10_000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept", "application/json")
                setRequestProperty("Authorization", "Bearer $token")
            }
            conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            when (conn.responseCode) {
                in 200..299 -> PolicyStore.markFixReported(this, fix.timeMillis)
                // Rejected as invalid/stale: don't retry this fix forever.
                400 -> PolicyStore.markFixReported(this, fix.timeMillis)
            }
        } catch (e: Exception) {
            Log.d(TAG, "location report failed: ${e.message}")
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
