package com.example.hsh_app2.screentime

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/** Warden-configured curfew geofence rules. */
data class GeofencePolicy(
    val active: Boolean = true,
    /** "HH:mm" local time. */
    val start: String = "22:00",
    val end: String = "06:00",
    /** "Daily" or weekday names ("Mon", "Tue", …): the day the curfew *starts*. */
    val repeatDays: List<String> = listOf("Daily"),
    /** Minutes between location fixes (day and curfew), set by the warden. */
    val intervalMinutes: Int = 2,
    /** Gate pass: epoch millis until which this student may be outside. */
    val exemptUntil: Long = 0L,
    /** Fence as (lat, lng) pairs; falls back to the built-in campus outline. */
    val polygon: List<Pair<Double, Double>> = GeofenceEvaluator.CAMPUS_POLYGON,
    val version: String = "",
) {
    fun isExempt(now: Long = System.currentTimeMillis()) = exemptUntil > now

    companion object {
        fun fromJson(root: JSONObject, current: GeofencePolicy = GeofencePolicy()): GeofencePolicy? {
            val data = root.optJSONObject("data") ?: root
            val pol = data.optJSONObject("policy") ?: data.optJSONObject("geofence") ?: data
            val known = listOf("isActive", "is_active", "startTime", "start_time", "endTime", "end_time",
                "exemptUntil", "exempt_until", "polygon")
            if (known.none { pol.has(it) }) return null

            val days = pol.optJSONArray("repeatDays") ?: pol.optJSONArray("repeat_days")
            val poly = pol.optJSONArray("polygon")?.let { arr ->
                (0 until arr.length()).mapNotNull { i ->
                    val p = arr.opt(i)
                    when (p) {
                        is JSONObject -> {
                            val lat = p.optDouble("latitude", p.optDouble("lat", Double.NaN))
                            val lng = p.optDouble("longitude", p.optDouble("lng", Double.NaN))
                            if (lat.isNaN() || lng.isNaN()) null else lat to lng
                        }
                        is JSONArray -> if (p.length() >= 2) p.optDouble(0) to p.optDouble(1) else null
                        else -> null
                    }
                }.takeIf { it.size >= 3 }
            }
            val exemptKey = listOf("exemptUntil", "exempt_until").firstOrNull { pol.has(it) }
            val exempt = exemptKey?.let { pol.opt(it) }

            return GeofencePolicy(
                active = optBool(pol, "isActive", "is_active") ?: current.active,
                start = optStr(pol, "startTime", "start_time") ?: current.start,
                end = optStr(pol, "endTime", "end_time") ?: current.end,
                repeatDays = days?.let { d -> (0 until d.length()).map { d.optString(it) } } ?: current.repeatDays,
                intervalMinutes = optInt(pol, "checkIntervalMinutes", "check_interval_minutes") ?: current.intervalMinutes,
                exemptUntil = when {
                    exemptKey == null -> current.exemptUntil
                    // Explicit null: no active gate pass (expired or revoked on the server).
                    pol.isNull(exemptKey) -> 0L
                    exempt is Number -> exempt.toLong().let { if (it < 1e12) it * 1000 else it }
                    exempt is String -> parseIso(exempt) ?: current.exemptUntil
                    else -> current.exemptUntil
                },
                polygon = poly ?: current.polygon,
                version = optStr(pol, "updatedAt", "updated_at") ?: optStr(pol, "version") ?: current.version,
            )
        }

        private fun parseIso(s: String): Long? = runCatching {
            java.time.OffsetDateTime.parse(s).toInstant().toEpochMilli()
        }.getOrElse {
            runCatching { java.time.LocalDateTime.parse(s).atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli() }.getOrNull()
        }

        private fun optBool(o: JSONObject, vararg keys: String): Boolean? {
            for (k in keys) if (o.has(k) && !o.isNull(k)) return when (val v = o.opt(k)) {
                is Boolean -> v
                is Number -> v.toInt() != 0
                is String -> v.equals("true", true) || v == "1"
                else -> null
            }
            return null
        }

        private fun optInt(o: JSONObject, vararg keys: String): Int? {
            for (k in keys) if (o.has(k) && !o.isNull(k)) return when (val v = o.opt(k)) {
                is Number -> v.toInt()
                is String -> v.toDoubleOrNull()?.toInt()
                else -> null
            }
            return null
        }

        private fun optStr(o: JSONObject, vararg keys: String): String? {
            for (k in keys) if (o.has(k) && !o.isNull(k)) return o.optString(k)
            return null
        }
    }

    fun toJson(): JSONObject = JSONObject()
        .put("isActive", active)
        .put("startTime", start)
        .put("endTime", end)
        .put("repeatDays", JSONArray(repeatDays))
        .put("checkIntervalMinutes", intervalMinutes)
        .put("exemptUntil", exemptUntil)
        .put("polygon", JSONArray(polygon.map { JSONObject().put("latitude", it.first).put("longitude", it.second) }))
        .put("version", version)
}

enum class GeofenceState { UNKNOWN, INSIDE, OUTSIDE }

/** One GPS reading. */
data class LocationFix(
    val latitude: Double,
    val longitude: Double,
    val accuracyMeters: Float,
    val timeMillis: Long,
    val mocked: Boolean,
)

/**
 * Decides, from a fresh fix, whether the student has left campus during
 * curfew. Keeps an inside/outside state machine with hysteresis so GPS noise
 * near the wall doesn't produce a breach, and queues events for the backend.
 */
object GeofenceEvaluator {
    private const val TAG = "Geofence"

    /** Fixes less precise than this can't tell inside from outside on a 200 m-wide campus. */
    const val MAX_ACCURACY_M = 75f

    /** Consecutive outside fixes required before we call it a breach. */
    private const val EXIT_STREAK = 2
    private const val MOCK_EVENT_THROTTLE_MS = 10 * 60 * 1000L

    /** Hari Saurabh Hostel outline (lat, lng). */
    val CAMPUS_POLYGON: List<Pair<Double, Double>> = listOf(
        22.558964147296141 to 72.91912238597169,
        22.558605678567648 to 72.917801267508437,
        22.558189217570671 to 72.917872586892443,
        22.558041473335201 to 72.917392613903246,
        22.55609092462787 to 72.918061373839208,
        22.555996869562829 to 72.91762963788878,
        22.555534142766259 to 72.917729845593044,
        22.55562669134369 to 72.918210848692425,
        22.553963188882381 to 72.918512935146424,
        22.554003697052291 to 72.918952455256232,
        22.55618098579334 to 72.919393558763247,
        22.557134125502561 to 72.919293597367883,
    )

    // ---------- Curfew window ----------

    fun isInCurfew(
        policy: GeofencePolicy,
        now: Calendar = Calendar.getInstance(),
        context: Context? = null,
    ): Boolean {
        if (!policy.active) return false
        val start = parseMinutes(policy.start) ?: return false
        val end = parseMinutes(policy.end) ?: return false
        if (start == end) return false

        // Anti-tamper: If user disabled automatic network time in Settings, fail closed
        if (context != null) {
            val autoTime = runCatching {
                android.provider.Settings.Global.getInt(context.contentResolver, android.provider.Settings.Global.AUTO_TIME, 1)
            }.getOrDefault(1)
            if (autoTime == 0) return true
        }

        val cur = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val overnight = start > end
        val inWindow = if (!overnight) cur in start until end else cur >= start || cur < end
        if (!inWindow) return false

        // Which day's curfew is this? Past midnight in an overnight window it's yesterday's.
        val day = (now.clone() as Calendar).apply { if (overnight && cur < end) add(Calendar.DAY_OF_YEAR, -1) }
        return matchesDay(policy.repeatDays, day.get(Calendar.DAY_OF_WEEK))
    }

    private fun matchesDay(days: List<String>, dayOfWeek: Int): Boolean {
        if (days.isEmpty() || days.any { it.equals("Daily", true) || it.equals("Everyday", true) }) return true
        val name = when (dayOfWeek) {
            Calendar.MONDAY -> "mon"; Calendar.TUESDAY -> "tue"; Calendar.WEDNESDAY -> "wed"
            Calendar.THURSDAY -> "thu"; Calendar.FRIDAY -> "fri"; Calendar.SATURDAY -> "sat"; else -> "sun"
        }
        return days.any { it.lowercase().startsWith(name) }
    }

    private fun parseMinutes(hhmm: String): Int? {
        val p = hhmm.trim().split(":")
        if (p.size < 2) return null
        val h = p[0].toIntOrNull() ?: return null
        val m = p[1].take(2).toIntOrNull() ?: return null
        return if (h in 0..23 && m in 0..59) h * 60 + m else null
    }

    /** Curfew is on, no gate pass → the fence is being enforced right now. */
    fun isEnforcing(context: Context, now: Long = System.currentTimeMillis()): Boolean {
        val policy = PolicyStore.geofencePolicy(context)
        return policy.active && !policy.isExempt(now) && isInCurfew(policy, context = context)
    }

    /**
     * Outside curfew (or on a gate pass) the last inside/outside verdict goes
     * stale. Forget it, otherwise yesterday's OUTSIDE would be taken as the
     * starting state when the next curfew begins, before any fresh fix.
     */
    fun clearStaleState(context: Context) {
        if (PolicyStore.geofenceState(context) != GeofenceState.UNKNOWN || PolicyStore.geofenceStreak(context) != 0) {
            PolicyStore.saveGeofenceState(context, GeofenceState.UNKNOWN, streak = 0)
        }
    }

    /**
     * During curfew a phone with location switched off or permission revoked
     * can't be checked at all. Report that (at most once per check interval)
     * instead of going silent. Returns true when an event was queued.
     */
    fun reportLocationUnavailable(context: Context, reason: String): Boolean {
        val now = System.currentTimeMillis()
        if (!isEnforcing(context, now)) return false
        val policy = PolicyStore.geofencePolicy(context)
        val throttle = max(MOCK_EVENT_THROTTLE_MS, policy.intervalMinutes.coerceAtLeast(1) * 60_000L)
        if (now - PolicyStore.lastUnavailableEventAt(context) < throttle) return false
        PolicyStore.markUnavailableEvent(context, now)
        PolicyStore.recordGeofenceEvent(
            context,
            JSONObject().put("type", "location_off").put("reason", reason).put("at", now),
        )
        Log.w(TAG, "location unavailable during curfew: $reason")
        return true
    }

    // ---------- Geometry ----------

    fun isInside(polygon: List<Pair<Double, Double>>, lat: Double, lng: Double): Boolean {
        var inside = false
        var j = polygon.size - 1
        for (i in polygon.indices) {
            val (yi, xi) = polygon[i]
            val (yj, xj) = polygon[j]
            if ((yi > lat) != (yj > lat) && lng < (xj - xi) * (lat - yi) / (yj - yi) + xi) inside = !inside
            j = i
        }
        return inside
    }

    /**
     * Shortest distance in metres from the point to the fence *edge* (not the
     * nearest corner). Uses a local flat projection — exact enough for a campus.
     */
    fun distanceToEdgeMeters(polygon: List<Pair<Double, Double>>, lat: Double, lng: Double): Double {
        val mPerDegLat = 110_540.0
        val mPerDegLng = 111_320.0 * cos(Math.toRadians(lat))
        fun project(p: Pair<Double, Double>) = ((p.second - lng) * mPerDegLng) to ((p.first - lat) * mPerDegLat)

        var best = Double.MAX_VALUE
        var j = polygon.size - 1
        for (i in polygon.indices) {
            val (ax, ay) = project(polygon[j])
            val (bx, by) = project(polygon[i])
            val dx = bx - ax
            val dy = by - ay
            val len2 = dx * dx + dy * dy
            // Point is at the origin; t is where its projection lands on the segment.
            val t = if (len2 == 0.0) 0.0 else max(0.0, min(1.0, -(ax * dx + ay * dy) / len2))
            val cx = ax + t * dx
            val cy = ay + t * dy
            best = min(best, sqrt(cx * cx + cy * cy))
            j = i
        }
        return best
    }

    // ---------- State machine ----------

    /**
     * Feeds one fix through the state machine. Returns the event type queued
     * (exit / heartbeat / enter / mock_location) or null if nothing notable.
     */
    @Synchronized
    fun process(context: Context, fix: LocationFix): String? {
        val now = System.currentTimeMillis()
        val policy = PolicyStore.geofencePolicy(context)
        PolicyStore.saveLastFix(context, fix)

        if (!isEnforcing(context, now)) {
            // Curfew over or gate pass active: forget the streak, no event.
            PolicyStore.saveGeofenceState(context, GeofenceState.UNKNOWN, streak = 0)
            return null
        }

        if (fix.mocked) {
            // A spoofed location is itself a violation — and we can't trust the coordinates.
            val last = PolicyStore.lastMockEventAt(context)
            if (now - last < MOCK_EVENT_THROTTLE_MS) return null
            PolicyStore.markMockEvent(context, now)
            queue(context, "mock_location", fix, 0.0)
            return "mock_location"
        }
        if (fix.accuracyMeters > MAX_ACCURACY_M) {
            Log.d(TAG, "fix too coarse (${fix.accuracyMeters}m), ignored")
            return null
        }

        val inside = isInside(policy.polygon, fix.latitude, fix.longitude)
        val edge = distanceToEdgeMeters(policy.polygon, fix.latitude, fix.longitude)
        // Only count as outside when the fix's error circle is wholly past the wall.
        val clearlyOutside = !inside && edge > fix.accuracyMeters

        val state = PolicyStore.geofenceState(context)
        val streak = PolicyStore.geofenceStreak(context)

        if (clearlyOutside) {
            val newStreak = streak + 1
            if (state != GeofenceState.OUTSIDE) {
                if (newStreak >= EXIT_STREAK) {
                    PolicyStore.saveGeofenceState(context, GeofenceState.OUTSIDE, 0, heartbeatAt = now)
                    queue(context, "exit", fix, edge)
                    Log.w(TAG, "EXIT: ${edge.toInt()}m outside")
                    return "exit"
                }
                PolicyStore.saveGeofenceState(context, state, newStreak)
                return null
            }
            val sinceHeartbeat = now - PolicyStore.geofenceHeartbeatAt(context)
            if (sinceHeartbeat >= policy.intervalMinutes.coerceAtLeast(1) * 60_000L) {
                PolicyStore.saveGeofenceState(context, GeofenceState.OUTSIDE, 0, heartbeatAt = now)
                queue(context, "heartbeat", fix, edge)
                return "heartbeat"
            }
            return null
        }

        // Inside (or too close to the wall to be sure).
        val wasOutside = state == GeofenceState.OUTSIDE
        PolicyStore.saveGeofenceState(context, GeofenceState.INSIDE, 0)
        if (wasOutside) {
            queue(context, "enter", fix, if (inside) 0.0 else edge)
            Log.i(TAG, "ENTER: back on campus")
            return "enter"
        }
        return null
    }

    private fun queue(context: Context, type: String, fix: LocationFix, distance: Double) {
        PolicyStore.recordGeofenceEvent(
            context,
            JSONObject()
                .put("type", type)
                .put("latitude", fix.latitude)
                .put("longitude", fix.longitude)
                .put("accuracyMeters", fix.accuracyMeters.toDouble())
                .put("distanceMeters", distance)
                .put("mocked", fix.mocked)
                .put("fixTime", fix.timeMillis)
                .put("at", System.currentTimeMillis()),
        )
    }

    /** Snapshot for the Flutter side / compliance report. */
    fun statusJson(context: Context): JSONObject {
        val policy = PolicyStore.geofencePolicy(context)
        val fix = PolicyStore.lastFix(context)
        return JSONObject()
            .put("state", PolicyStore.geofenceState(context).name.lowercase())
            .put("inCurfew", isInCurfew(policy))
            .put("exempt", policy.isExempt())
            .put("enforcing", isEnforcing(context))
            .put("lastSampleAt", PolicyStore.lastSampleAt(context))
            .put("policy", policy.toJson())
            .put(
                "lastFix",
                fix?.let {
                    JSONObject()
                        .put("latitude", it.latitude)
                        .put("longitude", it.longitude)
                        .put("accuracyMeters", it.accuracyMeters.toDouble())
                        .put("time", it.timeMillis)
                        .put("mocked", it.mocked)
                        .put("inside", isInside(policy.polygon, it.latitude, it.longitude))
                        .put("distanceToEdgeMeters", distanceToEdgeMeters(policy.polygon, it.latitude, it.longitude))
                } ?: JSONObject.NULL,
            )
    }
}
