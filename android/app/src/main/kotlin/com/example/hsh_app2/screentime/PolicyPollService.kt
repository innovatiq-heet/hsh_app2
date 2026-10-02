package com.example.hsh_app2.screentime

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * A lightweight background service that polls the lock/block policy from the
 * backend every 30 seconds so the student's device enforces remote lock
 * commands almost instantly (rather than waiting for the 5-minute WorkManager
 * tick).
 *
 * Runs as a normal (non-foreground) service. Android may kill it to reclaim
 * resources, but START_STICKY asks the OS to restart it, and the WorkManager
 * watchdog re-fetches policy anyway as a fallback.
 */
class PolicyPollService : Service() {

    companion object {
        private const val TAG = "PolicyPollService"
        private const val POLL_INTERVAL_MS = 30_000L // 30 seconds
        private const val PREFS_SESSION = "hsh_screen_time"
        private const val PREFS_POLICY = "hsh_screen_time_policy"

        fun start(context: Context) {
            try {
                context.startService(Intent(context, PolicyPollService::class.java))
            } catch (e: Exception) {
                Log.w(TAG, "Failed to start PolicyPollService: ${e.message}")
            }
        }

        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, PolicyPollService::class.java))
            } catch (_: Exception) {}
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private var running = false

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!running) return
            executor.execute { fetchPolicy() }
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!running) {
            running = true
            handler.post(pollRunnable)
            Log.d(TAG, "PolicyPollService started — polling every ${POLL_INTERVAL_MS / 1000}s")
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacks(pollRunnable)
        executor.shutdownNow()
        Log.d(TAG, "PolicyPollService destroyed")
        super.onDestroy()
    }

    private fun fetchPolicy() {
        val session = getSharedPreferences(PREFS_SESSION, MODE_PRIVATE)
        val token = session.getString("token", null)
        val baseUrl = session.getString("base_url", null)
        if (token.isNullOrEmpty() || baseUrl.isNullOrEmpty()) return

        var conn: HttpURLConnection? = null
        try {
            conn = (URL("$baseUrl/screen-time/policies/me").openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 10_000
                readTimeout = 10_000
                setRequestProperty("Accept", "application/json")
                setRequestProperty("Authorization", "Bearer $token")
            }
            if (conn.responseCode in 200..299) {
                val respStr = conn.inputStream.bufferedReader().use { it.readText() }
                val respJson = JSONObject(respStr)
                val data = respJson.optJSONObject("data") ?: respJson

                // Extract lock state
                val polObj = data.optJSONObject("policy")
                val isLocked = if (polObj != null) {
                    polObj.optBoolean("is_locked", polObj.optBoolean("isLocked", false))
                } else {
                    data.optBoolean("is_locked", data.optBoolean("isLocked", false))
                }

                // Extract blocked packages
                val blockedArr = data.optJSONArray("blockedPackages")
                    ?: data.optJSONArray("blocked_packages")
                    ?: polObj?.optJSONArray("blockedPackages")
                    ?: polObj?.optJSONArray("blocked_packages")

                val editor = getSharedPreferences(PREFS_POLICY, MODE_PRIVATE).edit()
                editor.putBoolean("is_locked", isLocked)
                if (blockedArr != null) {
                    val blockedSet = mutableSetOf<String>()
                    for (i in 0 until blockedArr.length()) {
                        blockedSet.add(blockedArr.getString(i))
                    }
                    editor.putStringSet("blocked_packages", blockedSet)
                }
                editor.apply()
                Log.d(TAG, "Policy synced: isLocked=$isLocked, blocked=${blockedArr?.length() ?: 0} apps")
            }
        } catch (e: Exception) {
            Log.d(TAG, "Policy poll failed: ${e.message}")
        } finally {
            conn?.disconnect()
        }
    }
}
