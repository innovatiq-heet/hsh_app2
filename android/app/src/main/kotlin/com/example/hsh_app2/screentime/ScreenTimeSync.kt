package com.example.hsh_app2.screentime

import android.content.Context
import android.util.Log
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.concurrent.TimeUnit

/**
 * Pushes the device's real screen time to `POST /screen-time/ping`.
 *
 * The backend accumulates *deltas*, so we remember how many millis per app
 * were already reported today and only send the difference (in whole
 * minutes — leftover seconds carry over to the next sync, nothing is lost or
 * double-counted). Runs entirely natively so it keeps working while the
 * Flutter UI is closed.
 */
object ScreenTimeSync {
    private const val TAG = "ScreenTimeSync"
    private const val PREFS = "hsh_screen_time"
    private const val KEY_TOKEN = "token"
    private const val KEY_BASE_URL = "base_url"
    private const val KEY_SENT_DATE = "sent_date"
    private const val KEY_SENT_MILLIS = "sent_millis"

    private const val TICK_WORK = "hsh_screen_time_tick"
    private const val WATCHDOG_WORK = "hsh_screen_time_watchdog"
    private const val TICK_MINUTES = 5L
    private const val MINUTE_MS = 60_000L

    const val STATUS_OK = "ok"
    const val STATUS_NO_SESSION = "no_session"
    const val STATUS_NO_PERMISSION = "no_permission"
    const val STATUS_UNAUTHORIZED = "unauthorized"
    const val STATUS_ERROR = "error"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun dateFormat() = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    // ---------- Lifecycle ----------

    fun start(context: Context, token: String, baseUrl: String) {
        prefs(context).edit()
            .putString(KEY_TOKEN, token)
            .putString(KEY_BASE_URL, baseUrl.trimEnd('/'))
            .apply()
        schedule(context)
    }

    fun stop(context: Context) {
        val wm = WorkManager.getInstance(context)
        wm.cancelUniqueWork(TICK_WORK)
        wm.cancelUniqueWork(WATCHDOG_WORK)
        // Keep the "already sent" bookkeeping: if the same student logs back in
        // today we must not re-report minutes the backend already has.
        prefs(context).edit().remove(KEY_TOKEN).remove(KEY_BASE_URL).apply()
    }

    fun isConfigured(context: Context): Boolean =
        !prefs(context).getString(KEY_TOKEN, null).isNullOrEmpty()

    /**
     * A 15-min periodic watchdog (survives reboots / process death) plus a
     * self-rescheduling 5-min tick for near-live status. The watchdog revives
     * the tick chain if the OS ever drops it.
     */
    fun schedule(context: Context) {
        val wm = WorkManager.getInstance(context)
        val watchdog = PeriodicWorkRequestBuilder<ScreenTimeWorker>(15, TimeUnit.MINUTES)
            .setConstraints(
                Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build(),
            )
            .setInputData(workDataOf(ScreenTimeWorker.KEY_KIND to ScreenTimeWorker.KIND_WATCHDOG))
            .build()
        wm.enqueueUniquePeriodicWork(WATCHDOG_WORK, ExistingPeriodicWorkPolicy.KEEP, watchdog)
        enqueueTick(context, delayMinutes = 0, policy = ExistingWorkPolicy.KEEP)
    }

    /** Called from inside a running tick: appends the next tick after it. */
    fun scheduleNextTick(context: Context) =
        enqueueTick(context, TICK_MINUTES, ExistingWorkPolicy.APPEND_OR_REPLACE)

    /** Called from the watchdog: restarts the tick chain only if it died. */
    fun ensureTick(context: Context) =
        enqueueTick(context, TICK_MINUTES, ExistingWorkPolicy.KEEP)

    private fun enqueueTick(context: Context, delayMinutes: Long, policy: ExistingWorkPolicy) {
        val tick = OneTimeWorkRequestBuilder<ScreenTimeWorker>()
            .setInitialDelay(delayMinutes, TimeUnit.MINUTES)
            .setInputData(workDataOf(ScreenTimeWorker.KEY_KIND to ScreenTimeWorker.KIND_TICK))
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(TICK_WORK, policy, tick)
    }

    // ---------- Sync ----------

    /** Blocking — call off the main thread. Serialized so worker + UI never race. */
    @Synchronized
    fun syncNow(context: Context): String {
        val p = prefs(context)
        val token = p.getString(KEY_TOKEN, null)
        val baseUrl = p.getString(KEY_BASE_URL, null)
        if (token.isNullOrEmpty() || baseUrl.isNullOrEmpty()) return STATUS_NO_SESSION

        val now = System.currentTimeMillis()
        val todayStart = UsageCollector.startOfDay(now)
        val today = dateFormat().format(todayStart)

        if (!UsageCollector.hasPermission(context)) {
            // Still heartbeat so the warden sees the device online, with zero usage.
            val code = post(baseUrl, token, today, emptyMap(), UsageCollector.isScreenOn(context), null, context)
            return if (handleAuth(context, code)) STATUS_UNAUTHORIZED else STATUS_NO_PERMISSION
        }

        return try {
            // Day rolled over since the last successful sync: flush the tail of
            // the previous day first so the minutes before midnight aren't lost.
            val sentDate = p.getString(KEY_SENT_DATE, null)
            if (sentDate != null && sentDate != today) {
                val prevStart = runCatching { dateFormat().parse(sentDate)?.time }.getOrNull()
                if (prevStart != null && todayStart - prevStart <= 2 * 24 * 60 * MINUTE_MS) {
                    val snap = UsageCollector.collect(context, prevStart, UsageCollector.nextDayStart(prevStart))
                    val status = sendDeltas(context, baseUrl, token, sentDate, snap, loadSent(p))
                    if (status != STATUS_OK) return status
                }
                saveSent(p, today, emptyMap())
            }

            val snap = UsageCollector.collect(context, todayStart, UsageCollector.nextDayStart(todayStart))
            val sent = if (p.getString(KEY_SENT_DATE, null) == today) loadSent(p) else emptyMap()
            sendDeltas(context, baseUrl, token, today, snap, sent)
        } catch (e: Exception) {
            Log.w(TAG, "sync failed", e)
            STATUS_ERROR
        }
    }

    private fun sendDeltas(
        context: Context,
        baseUrl: String,
        token: String,
        date: String,
        snap: UsageSnapshot,
        sent: Map<String, Long>,
    ): String {
        val deltaMinutes = LinkedHashMap<String, Int>()
        for ((pkg, millis) in snap.appMillis) {
            val delta = ((millis - (sent[pkg] ?: 0L)) / MINUTE_MS).toInt()
            if (delta > 0) deltaMinutes[pkg] = delta
        }

        val code = post(baseUrl, token, date, deltaMinutes, snap.isScreenOn, snap.currentPackage, context)
        if (handleAuth(context, code)) return STATUS_UNAUTHORIZED
        if (code !in 200..299) return STATUS_ERROR

        // Only advance by the whole minutes actually reported; remainders carry over.
        val newSent = HashMap(sent)
        for ((pkg, minutes) in deltaMinutes) {
            newSent[pkg] = (sent[pkg] ?: 0L) + minutes * MINUTE_MS
        }
        saveSent(prefs(context), date, newSent)
        return STATUS_OK
    }

    /** Token rejected: stop syncing until the app hands us a fresh one. */
    private fun handleAuth(context: Context, code: Int): Boolean {
        if (code != 401) return false
        val wm = WorkManager.getInstance(context)
        wm.cancelUniqueWork(TICK_WORK)
        wm.cancelUniqueWork(WATCHDOG_WORK)
        prefs(context).edit().remove(KEY_TOKEN).apply()
        return true
    }

    private fun post(
        baseUrl: String,
        token: String,
        date: String,
        deltaMinutes: Map<String, Int>,
        isScreenOn: Boolean,
        currentPackage: String?,
        context: Context,
    ): Int {
        val breakdown = JSONArray()
        for ((pkg, minutes) in deltaMinutes) {
            breakdown.put(
                JSONObject()
                    .put("packageName", pkg)
                    .put("appName", UsageCollector.appLabel(context, pkg))
                    .put("minutes", minutes),
            )
        }
        val body = JSONObject()
            .put("date", date)
            .put("totalScreenTimeMinutes", deltaMinutes.values.sum())
            .put("isScreenOn", isScreenOn)
            .put(
                "currentApp",
                currentPackage?.let { UsageCollector.appLabel(context, it) } ?: "Idle",
            )
        if (breakdown.length() > 0) body.put("appUsageBreakdown", breakdown)

        var conn: HttpURLConnection? = null
        return try {
            conn = (URL("$baseUrl/screen-time/ping").openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 20_000
                readTimeout = 20_000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept", "application/json")
                setRequestProperty("Authorization", "Bearer $token")
            }
            conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val code = conn.responseCode
            if (code in 200..299) {
                try {
                    val respStr = conn.inputStream.bufferedReader().use { it.readText() }
                    val respJson = JSONObject(respStr)
                    val data = respJson.optJSONObject("data") ?: respJson
                    val blockedArr = data.optJSONArray("blockedPackages")
                        ?: data.optJSONArray("blocked_packages")
                    val isLocked = data.optBoolean("is_locked", data.optBoolean("isLocked", false))
                    if (blockedArr != null) {
                        val blockedSet = mutableSetOf<String>()
                        for (i in 0 until blockedArr.length()) {
                            blockedSet.add(blockedArr.getString(i))
                        }
                        context.getSharedPreferences("hsh_screen_time_policy", Context.MODE_PRIVATE)
                            .edit()
                            .putStringSet("blocked_packages", blockedSet)
                            .putBoolean("is_locked", isLocked)
                            .apply()
                    } else {
                        // Ping didn't include policy; fetch directly from policy endpoint
                        fetchAndSavePolicy(context, baseUrl, token)
                    }
                } catch (_: Exception) {
                    fetchAndSavePolicy(context, baseUrl, token)
                }
            }
            code
        } catch (e: Exception) {
            Log.w(TAG, "ping failed: ${e.message}")
            -1
        } finally {
            conn?.disconnect()
        }
    }

    private fun loadSent(p: android.content.SharedPreferences): Map<String, Long> {
        val raw = p.getString(KEY_SENT_MILLIS, null) ?: return emptyMap()
        return try {
            val json = JSONObject(raw)
            json.keys().asSequence().associateWith { json.getLong(it) }
        } catch (_: Exception) {
            emptyMap()
        }
    }

    private fun saveSent(p: android.content.SharedPreferences, date: String, sent: Map<String, Long>) {
        p.edit()
            .putString(KEY_SENT_DATE, date)
            .putString(KEY_SENT_MILLIS, JSONObject(sent as Map<*, *>).toString())
            .apply()
    }

    private fun fetchAndSavePolicy(context: Context, baseUrl: String, token: String) {
        var polConn: HttpURLConnection? = null
        try {
            polConn = (URL("$baseUrl/screen-time/policies/me").openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 10_000
                readTimeout = 10_000
                setRequestProperty("Accept", "application/json")
                setRequestProperty("Authorization", "Bearer $token")
            }
            if (polConn.responseCode in 200..299) {
                val respStr = polConn.inputStream.bufferedReader().use { it.readText() }
                val respJson = JSONObject(respStr)
                val data = respJson.optJSONObject("data") ?: respJson
                val blockedArr = data.optJSONArray("blockedPackages")
                    ?: data.optJSONArray("blocked_packages")
                val isLocked = data.optBoolean("is_locked", data.optBoolean("isLocked", false))
                val polObj = data.optJSONObject("policy")
                val lockedFinal = if (polObj != null) {
                    polObj.optBoolean("is_locked", polObj.optBoolean("isLocked", isLocked))
                } else isLocked

                val editor = context.getSharedPreferences("hsh_screen_time_policy", Context.MODE_PRIVATE).edit()
                editor.putBoolean("is_locked", lockedFinal)
                if (blockedArr != null) {
                    val blockedSet = mutableSetOf<String>()
                    for (i in 0 until blockedArr.length()) {
                        blockedSet.add(blockedArr.getString(i))
                    }
                    editor.putStringSet("blocked_packages", blockedSet)
                }
                editor.apply()
                Log.d(TAG, "Successfully fetched and saved policy from backend")
            }
        } catch (e: Exception) {
            Log.d(TAG, "fetchAndSavePolicy error: ${e.message}")
        } finally {
            polConn?.disconnect()
        }
    }
}
