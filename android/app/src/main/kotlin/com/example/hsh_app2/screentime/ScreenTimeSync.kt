package com.example.hsh_app2.screentime

import android.content.Context
import android.os.PowerManager
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
 *
 * Each ping also carries:
 *  - `compliance`  — whether Usage Access / Accessibility / battery exemption
 *                    are still on, so the warden can spot tampering;
 *  - `blockEvents` — the audit queue of apps the blocker stopped;
 *  - `icon`        — a small PNG of each app's launcher icon, sent once per
 *                    package so the warden UI can show real icons.
 */
object ScreenTimeSync {
    private const val TAG = "ScreenTimeSync"

    private const val TICK_WORK = "hsh_screen_time_tick"
    private const val WATCHDOG_WORK = "hsh_screen_time_watchdog"
    private const val TICK_MINUTES = 5L
    private const val MINUTE_MS = 60_000L

    /** Bound the payload when a phone has dozens of never-reported apps. */
    private const val MAX_ICONS_PER_PING = 12

    const val STATUS_OK = "ok"
    const val STATUS_NO_SESSION = "no_session"
    const val STATUS_NO_PERMISSION = "no_permission"
    const val STATUS_UNAUTHORIZED = "unauthorized"
    const val STATUS_ERROR = "error"

    private fun dateFormat() = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    // ---------- Lifecycle ----------

    fun start(context: Context, token: String, baseUrl: String) {
        PolicyStore.saveSession(context, token, baseUrl)
        schedule(context)
    }

    fun stop(context: Context) {
        val wm = WorkManager.getInstance(context)
        wm.cancelUniqueWork(TICK_WORK)
        wm.cancelUniqueWork(WATCHDOG_WORK)
        PolicyStore.clearSession(context)
        // A logged-out phone must not keep enforcing the previous student's rules,
        // nor hand their queued breaches / gate pass to the next login.
        PolicyStore.savePolicy(context, DevicePolicy())
        PolicyStore.clearStudentState(context)
    }

    fun isConfigured(context: Context): Boolean = PolicyStore.hasSession(context)

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
        val token = PolicyStore.token(context)
        val baseUrl = PolicyStore.baseUrl(context)
        if (token.isNullOrEmpty() || baseUrl.isNullOrEmpty()) return STATUS_NO_SESSION

        val now = System.currentTimeMillis()
        val todayStart = UsageCollector.startOfDay(now)
        val today = dateFormat().format(todayStart)

        if (!UsageCollector.hasPermission(context)) {
            // Still heartbeat so the warden sees the device online (and non-compliant).
            val code = post(context, baseUrl, token, today, emptyMap(), UsageCollector.isScreenOn(context), null)
            return if (handleAuth(context, code)) STATUS_UNAUTHORIZED else STATUS_NO_PERMISSION
        }

        return try {
            // Day rolled over since the last successful sync: flush the tail of
            // the previous day first so the minutes before midnight aren't lost.
            val sentDate = PolicyStore.sentDate(context)
            if (sentDate != null && sentDate != today) {
                val prevStart = runCatching { dateFormat().parse(sentDate)?.time }.getOrNull()
                if (prevStart != null && todayStart - prevStart <= 2 * 24 * 60 * MINUTE_MS) {
                    val snap = UsageCollector.collect(context, prevStart, UsageCollector.nextDayStart(prevStart))
                    val status = sendDeltas(context, baseUrl, token, sentDate, snap, PolicyStore.sentMillis(context))
                    if (status != STATUS_OK) return status
                }
                PolicyStore.saveSent(context, today, emptyMap())
            }

            val snap = UsageCollector.collect(context, todayStart, UsageCollector.nextDayStart(todayStart))
            val sent = if (PolicyStore.sentDate(context) == today) PolicyStore.sentMillis(context) else emptyMap()
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

        val code = post(context, baseUrl, token, date, deltaMinutes, snap.isScreenOn, snap.currentPackage)
        if (handleAuth(context, code)) return STATUS_UNAUTHORIZED
        if (code !in 200..299) return STATUS_ERROR

        // Only advance by the whole minutes actually reported; remainders carry over.
        val newSent = HashMap(sent)
        for ((pkg, minutes) in deltaMinutes) {
            newSent[pkg] = (sent[pkg] ?: 0L) + minutes * MINUTE_MS
        }
        PolicyStore.saveSent(context, date, newSent)
        PolicyEvaluator.invalidateUsage()
        return STATUS_OK
    }

    /** Token rejected: stop syncing until the app hands us a fresh one. */
    private fun handleAuth(context: Context, code: Int): Boolean {
        if (code != 401) return false
        val wm = WorkManager.getInstance(context)
        wm.cancelUniqueWork(TICK_WORK)
        wm.cancelUniqueWork(WATCHDOG_WORK)
        PolicyStore.clearToken(context)
        return true
    }

    private fun post(
        context: Context,
        baseUrl: String,
        token: String,
        date: String,
        deltaMinutes: Map<String, Int>,
        isScreenOn: Boolean,
        currentPackage: String?,
    ): Int {
        val alreadySentIcons = PolicyStore.sentIcons(context)
        val iconsInThisPing = ArrayList<String>()

        val breakdown = JSONArray()
        for ((pkg, minutes) in deltaMinutes) {
            val entry = JSONObject()
                .put("packageName", pkg)
                .put("appName", UsageCollector.appLabel(context, pkg))
                .put("minutes", minutes)
            if (pkg !in alreadySentIcons && iconsInThisPing.size < MAX_ICONS_PER_PING) {
                UsageCollector.appIconBase64(context, pkg)?.let {
                    entry.put("icon", it)
                    iconsInThisPing.add(pkg)
                }
            }
            breakdown.put(entry)
        }

        val blockEvents = PolicyStore.pendingBlockEvents(context)
        val geofenceEvents = PolicyStore.pendingGeofenceEvents(context)
        val policy = PolicyStore.policy(context)

        val body = JSONObject()
            .put("date", date)
            .put("totalScreenTimeMinutes", deltaMinutes.values.sum())
            .put("isScreenOn", isScreenOn)
            .put("currentApp", currentPackage?.let { UsageCollector.appLabel(context, it) } ?: "Idle")
            .put("currentPackage", currentPackage ?: JSONObject.NULL)
            // Lets the backend detect a phone whose clock was moved to dodge curfew.
            .put("deviceTime", System.currentTimeMillis())
            .put("compliance", complianceJson(context, policy))
        if (breakdown.length() > 0) body.put("appUsageBreakdown", breakdown)
        if (blockEvents.length() > 0) body.put("blockEvents", blockEvents)
        if (geofenceEvents.length() > 0) body.put("geofenceEvents", geofenceEvents)

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
                PolicyStore.markIconsSent(context, iconsInThisPing)
                PolicyStore.dropBlockEvents(context, blockEvents.length())
                PolicyStore.dropGeofenceEvents(context, geofenceEvents.length())
                // The ping response echoes the current policy (older servers don't:
                // fetch it then). A stale echo is discarded inside applyPolicyJson.
                val resp = runCatching {
                    JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
                }.getOrNull()
                if (resp != null && resp.has("policy")) PolicyStore.applyPolicyJson(context, resp)
                else fetchAndSavePolicy(context)
            }
            code
        } catch (e: Exception) {
            Log.w(TAG, "ping failed: ${e.message}")
            -1
        } finally {
            conn?.disconnect()
        }
    }

    /** What the warden needs to know to trust this device's numbers. */
    fun complianceJson(context: Context, policy: DevicePolicy = PolicyStore.policy(context)): JSONObject {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val versionName = runCatching {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName
        }.getOrNull() ?: ""
        return JSONObject()
            .put("usageAccess", UsageCollector.hasPermission(context))
            .put("accessibilityEnabled", AppBlockerAccessibilityService.isEnabled(context))
            .put("batteryOptimizationIgnored", pm.isIgnoringBatteryOptimizations(context.packageName))
            .put("policyVersion", policy.version)
            .put("policyAppliedAt", PolicyStore.policyAppliedAt(context))
            .put("appVersion", versionName)
            .put("sdkInt", android.os.Build.VERSION.SDK_INT)
            .put("locationPermission", LocationSampler.permission(context).name.lowercase())
            .put("geofenceState", PolicyStore.geofenceState(context).name.lowercase())
            .put("geofenceLastSampleAt", PolicyStore.lastSampleAt(context))
            .put("manufacturer", android.os.Build.MANUFACTURER)
    }

    /** Outcome of one `GET /screen-time/policies/me`. [code] is -1 on a network error. */
    data class PolicyFetch(
        val code: Int,
        /** The server held the request until a change/timeout (supports long-poll). */
        val longPolled: Boolean = false,
        /** The response carried the curfew geofence (gate pass etc.) and it was applied. */
        val geofenceApplied: Boolean = false,
    )

    /**
     * Fetches the student's policy and applies it. With [waitSeconds] > 0 the
     * server holds the request until a warden changes something (or the wait
     * ends) — the near-real-time channel driven by [PolicyPollService].
     * Responses older than what's already applied are discarded by
     * [PolicyStore.applyPolicyJson], so concurrent fetches can't regress state.
     */
    fun fetchAndSavePolicy(context: Context, waitSeconds: Int = 0): PolicyFetch {
        val token = PolicyStore.token(context)
        val baseUrl = PolicyStore.baseUrl(context)
        if (token.isNullOrEmpty() || baseUrl.isNullOrEmpty()) return PolicyFetch(401)

        val query = if (waitSeconds > 0) "?wait=$waitSeconds&since=${PolicyStore.policyVersionNumber(context)}" else ""
        var conn: HttpURLConnection? = null
        return try {
            conn = (URL("$baseUrl/screen-time/policies/me$query").openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 10_000
                readTimeout = waitSeconds * 1000 + 15_000
                setRequestProperty("Accept", "application/json")
                setRequestProperty("Authorization", "Bearer $token")
            }
            val code = conn.responseCode
            if (code !in 200..299) return PolicyFetch(code)

            val json = JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
            PolicyStore.applyPolicyJson(context, json)
            // Gate pass / curfew changes ride along on the same channel.
            val geofenceApplied = json.optJSONObject("data")?.optJSONObject("geofence")
                ?.let { PolicyStore.applyGeofencePolicyJson(context, it) != null } ?: false
            PolicyFetch(code, longPolled = json.optBoolean("longPoll", false), geofenceApplied = geofenceApplied)
        } catch (e: Exception) {
            Log.d(TAG, "fetchAndSavePolicy error: ${e.message}")
            PolicyFetch(-1)
        } finally {
            conn?.disconnect()
        }
    }
}
